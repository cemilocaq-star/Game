extends RefCounted
## Measures how a built map plays, using the real collision (the same shapes the dedicated server
## uses). A walk graph is sampled on a 0.5 m grid: every standable surface with headroom becomes a
## node, nodes join when a player can step, jump or drop between them without a wall in the way.
## From that graph it reports the things level designers check by hand:
##  - connectivity: spawns, pickups and objective sites reachable and walkable back (no pits);
##  - route diversity: how many genuinely different routes join the two spawns;
##  - chokepoints: narrow passages on the busiest routes;
##  - sightlines: how often two random spots see each other, by distance;
##  - balance: how far each team's spawn is from the centre and from each objective;
##  - comfort: tight squeezes, jump-only steps on the main route, drop-in traps.

const CELL := 0.5
const HALF_X := 17.0
const HALF_Z := 14.0
const TOP_Y := 10.0
const BOTTOM_Y := -4.0
const STEP_WALK := 0.55
const STEP_JUMP := 1.25
const MAX_DROP := 4.0
const HEADROOM := 1.85
const EYE := 1.6
const PLAYER_RADIUS := 0.38
const CLEARANCE_PROBE := 1.5
const MIN_NODE_HEIGHT := -2.5 ## river beds and basins are fine, the void below is not

var space: PhysicsDirectSpaceState3D
var positions: Array[Vector3] = []
var clearance: Array[float] = []
var cells: Dictionary = {} ## Vector2i -> Array[int]
var adjacency: Array = [] ## per node: Array of Vector2(neighbour index, cost)
var reverse_adjacency: Array = []
var step_jump_edges := 0
var _heap: Array = []


func build(direct_space: PhysicsDirectSpaceState3D) -> void:
	space = direct_space
	positions.clear()
	clearance.clear()
	cells.clear()
	adjacency.clear()
	reverse_adjacency.clear()
	var cells_x := int(round(HALF_X * 2.0 / CELL))
	var cells_z := int(round(HALF_Z * 2.0 / CELL))
	for ix in range(cells_x):
		for iz in range(cells_z):
			var x := -HALF_X + (float(ix) + 0.5) * CELL
			var z := -HALF_Z + (float(iz) + 0.5) * CELL
			var ids: Array[int] = []
			for y in _surfaces(x, z):
				var spot := Vector3(x, y, z)
				var room := _clearance_at(spot)
				if room < PLAYER_RADIUS:
					continue
				positions.append(spot)
				clearance.append(room)
				adjacency.append([])
				reverse_adjacency.append([])
				ids.append(positions.size() - 1)
			if not ids.is_empty():
				cells[Vector2i(ix, iz)] = ids
	for key: Vector2i in cells:
		for neighbour_offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var other_key: Vector2i = key + neighbour_offset
			if not cells.has(other_key):
				continue
			for a: int in cells[key]:
				for b: int in cells[other_key]:
					_try_connect(a, b)


## Standable heights at (x, z): upward-facing surfaces with enough room above for a player.
func _surfaces(x: float, z: float) -> Array[float]:
	var found: Array[float] = []
	var from_y := TOP_Y
	for guard in range(12):
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, BOTTOM_Y, z))
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var point: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		from_y = point.y - 0.03
		if normal.y < 0.7 or point.y < MIN_NODE_HEIGHT:
			continue
		var up_query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.04, point + Vector3.UP * HEADROOM)
		if not space.intersect_ray(up_query).is_empty():
			continue
		found.append(point.y)
	return found


func _clearance_at(spot: Vector3) -> float:
	var room := CLEARANCE_PROBE
	for step in range(8):
		var angle := TAU * float(step) / 8.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var origin := spot + Vector3.UP * 0.7
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * CLEARANCE_PROBE)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			room = minf(room, origin.distance_to(hit.position))
	return room


func _try_connect(a: int, b: int) -> void:
	var from := positions[a]
	var to := positions[b]
	if absf(to.y - from.y) > MAX_DROP:
		return
	var height := maxf(from.y, to.y) + 0.5
	var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, height, from.z), Vector3(to.x, height, to.z))
	if not space.intersect_ray(query).is_empty():
		return
	var flat := Vector2(to.x - from.x, to.z - from.z).length()
	_add_edge(a, b, flat)
	_add_edge(b, a, flat)


## Directed move: climbs up to the jump height, drops any distance up to MAX_DROP. Steps beyond a
## walking step and big drops cost extra so routes prefer smooth ground.
func _add_edge(from: int, to: int, flat: float) -> void:
	var rise := positions[to].y - positions[from].y
	if rise > STEP_JUMP:
		return
	var cost := sqrt(flat * flat + rise * rise)
	if rise > STEP_WALK:
		cost += 3.0
		step_jump_edges += 1
	elif rise < -1.5:
		cost += 3.0
	adjacency[from].append(Vector2(to, cost))
	reverse_adjacency[to].append(Vector2(from, cost))


func node_count() -> int:
	return positions.size()


## Nearest standable node to a world point (prefers the matching floor level).
func nearest_node(point: Vector3) -> int:
	var ix := int(floor((point.x + HALF_X) / CELL))
	var iz := int(floor((point.z + HALF_Z) / CELL))
	var best := -1
	var best_score := INF
	for radius in range(0, 6):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var key := Vector2i(ix + dx, iz + dz)
				if not cells.has(key):
					continue
				for id: int in cells[key]:
					var score := Vector2(positions[id].x - point.x, positions[id].z - point.z).length() + absf(positions[id].y - point.y) * 2.0
					if score < best_score:
						best_score = score
						best = id
		if best >= 0 and radius >= 1:
			break
	return best


## Dijkstra over `graph` (adjacency or reverse_adjacency) from `source`. `blocked` nodes are skipped.
## Returns {"dist": PackedFloat32Array, "prev": PackedInt32Array}.
func _dijkstra(graph: Array, source: int, blocked: Dictionary = {}, target: int = -1) -> Dictionary:
	var count := positions.size()
	var dist := PackedFloat32Array()
	dist.resize(count)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(count)
	prev.fill(-1)
	_heap.clear()
	dist[source] = 0.0
	_heap_push(0.0, source)
	while not _heap.is_empty():
		var top: Vector2 = _heap_pop()
		var node := int(top.y)
		if top.x > dist[node]:
			continue
		if node == target:
			break
		for edge: Vector2 in graph[node]:
			var next := int(edge.x)
			if blocked.has(next):
				continue
			var candidate := top.x + edge.y
			if candidate < dist[next]:
				dist[next] = candidate
				prev[next] = node
				_heap_push(candidate, next)
	return {"dist": dist, "prev": prev}


func _heap_push(priority: float, node: int) -> void:
	_heap.append(Vector2(priority, node))
	var index := _heap.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if (_heap[parent] as Vector2).x <= (_heap[index] as Vector2).x:
			break
		var swap = _heap[parent]
		_heap[parent] = _heap[index]
		_heap[index] = swap
		index = parent


func _heap_pop() -> Vector2:
	var top: Vector2 = _heap[0]
	var last = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		var index := 0
		var size := _heap.size()
		while true:
			var left := index * 2 + 1
			var right := left + 1
			var smallest := index
			if left < size and (_heap[left] as Vector2).x < (_heap[smallest] as Vector2).x:
				smallest = left
			if right < size and (_heap[right] as Vector2).x < (_heap[smallest] as Vector2).x:
				smallest = right
			if smallest == index:
				break
			var swap = _heap[index]
			_heap[index] = _heap[smallest]
			_heap[smallest] = swap
			index = smallest
	return top


func path_between(from: int, to: int, blocked: Dictionary = {}) -> Array[int]:
	var result := _dijkstra(adjacency, from, blocked, to)
	var path: Array[int] = []
	if result.dist[to] == INF:
		return path
	var node := to
	while node != -1:
		path.append(node)
		node = result.prev[node]
	path.reverse()
	return path


func path_cost(path: Array[int]) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		for edge: Vector2 in adjacency[path[index - 1]]:
			if int(edge.x) == path[index]:
				total += edge.y
				break
	return total


## Nodes a player can both reach from `source` and return to it: the safe playable space.
func strongly_connected_to(source: int) -> Dictionary:
	var forward := _dijkstra(adjacency, source)
	var backward := _dijkstra(reverse_adjacency, source)
	var members := {}
	var reach_only := {}
	for node in range(positions.size()):
		var can_go: bool = forward.dist[node] < INF
		var can_return: bool = backward.dist[node] < INF
		if can_go and can_return:
			members[node] = true
		elif can_go:
			reach_only[node] = true
	return {"members": members, "pits": reach_only, "forward": forward}


func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a + Vector3.UP * EYE, b + Vector3.UP * EYE)
	return space.intersect_ray(query).is_empty()


## Share of random pairs (within `members`) that see each other, per distance band.
func sightline_report(members: Array, pairs: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bands := [[0.0, 8.0], [8.0, 16.0], [16.0, 100.0]]
	var seen := [0, 0, 0]
	var total := [0, 0, 0]
	var longest := 0.0
	if members.size() < 2:
		return {"bands": [0.0, 0.0, 0.0], "longest": 0.0, "samples": [0, 0, 0]}
	for sample in range(pairs):
		var a: int = members[rng.randi() % members.size()]
		var b: int = members[rng.randi() % members.size()]
		var distance := positions[a].distance_to(positions[b])
		for band in range(3):
			if distance >= bands[band][0] and distance < bands[band][1]:
				total[band] += 1
				if has_line_of_sight(positions[a], positions[b]):
					seen[band] += 1
					if band == 2:
						longest = maxf(longest, distance)
	var shares := []
	for band in range(3):
		shares.append(float(seen[band]) / maxf(1.0, float(total[band])))
	return {"bands": shares, "longest": longest, "samples": total}


## Fraction of the play space (beyond `min_distance`) that has a clear view of `spot`.
func exposure_of(spot: Vector3, members: Array, min_distance: float) -> float:
	var visible := 0
	var counted := 0
	for node: int in members:
		if positions[node].distance_to(spot) < min_distance:
			continue
		counted += 1
		if has_line_of_sight(spot, positions[node]):
			visible += 1
	return float(visible) / maxf(1.0, float(counted))


## Distinct routes between two nodes: the shortest, then each next one after closing the corridor
## (everything within `corridor` metres of the previous routes, except near the endpoints).
## Returns [{"cost": float, "min_clearance": float}, ...].
func distinct_routes(from: int, to: int, corridor: float = 2.5, end_margin: float = 7.0, max_routes: int = 4) -> Array:
	var routes: Array = []
	var blocked := {}
	for attempt in range(max_routes):
		var path := path_between(from, to, blocked)
		if path.is_empty():
			break
		var narrowest := CLEARANCE_PROBE
		for node in path:
			narrowest = minf(narrowest, clearance[node])
		routes.append({"cost": path_cost(path), "min_clearance": narrowest, "nodes": path.size()})
		for node in path:
			if positions[node].distance_to(positions[from]) < end_margin or positions[node].distance_to(positions[to]) < end_margin:
				continue
			_block_around(node, corridor, blocked, from, to, end_margin)
	return routes


func _block_around(centre: int, radius: float, blocked: Dictionary, from: int, to: int, end_margin: float) -> void:
	var centre_position := positions[centre]
	var cell_radius := int(ceil(radius / CELL))
	var ix := int(floor((centre_position.x + HALF_X) / CELL))
	var iz := int(floor((centre_position.z + HALF_Z) / CELL))
	for dx in range(-cell_radius, cell_radius + 1):
		for dz in range(-cell_radius, cell_radius + 1):
			var key := Vector2i(ix + dx, iz + dz)
			if not cells.has(key):
				continue
			for id: int in cells[key]:
				if absf(positions[id].y - centre_position.y) > 1.6:
					continue
				if Vector2(positions[id].x - centre_position.x, positions[id].z - centre_position.z).length() > radius:
					continue
				if positions[id].distance_to(positions[from]) < end_margin or positions[id].distance_to(positions[to]) < end_margin:
					continue
				blocked[id] = true


## Walks `pairs` random member-to-member shortest paths and counts how many cross each cell.
## Returns {"hot": [{"position": Vector3, "share": float}], "concentration": float, "narrow_hot": [...]}
## where concentration is the traffic share carried by the busiest 5 percent of cells.
func traffic_report(members: Array, pairs: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var visits := {}
	var total_visits := 0
	for sample in range(pairs):
		var a: int = members[rng.randi() % members.size()]
		var b: int = members[rng.randi() % members.size()]
		if positions[a].distance_to(positions[b]) < 12.0:
			continue
		var path := path_between(a, b)
		var seen_cells := {}
		for node in path:
			var key := Vector2i(int(floor(positions[node].x / 1.5)), int(floor(positions[node].z / 1.5)))
			if seen_cells.has(key):
				continue
			seen_cells[key] = true
			visits[key] = int(visits.get(key, 0)) + 1
			total_visits += 1
	var entries: Array = []
	for key: Vector2i in visits:
		entries.append({"key": key, "count": visits[key]})
	entries.sort_custom(func(left, right): return left.count > right.count)
	var top_count := maxi(1, int(ceil(float(entries.size()) * 0.05)))
	var top_total := 0
	var hot: Array = []
	for index in range(mini(top_count, entries.size())):
		top_total += int(entries[index].count)
		if index < 6:
			var key: Vector2i = entries[index].key
			hot.append({"position": Vector3((float(key.x) + 0.5) * 1.5, 0.0, (float(key.y) + 0.5) * 1.5), "share": float(entries[index].count) / maxf(1.0, float(total_visits))})
	return {"hot": hot, "concentration": float(top_total) / maxf(1.0, float(total_visits)), "cells": entries.size()}


## Narrowest clearance (m) among nodes within `radius` of a point, to flag chokepoints.
func tightest_near(point: Vector3, radius: float) -> float:
	var narrowest := CLEARANCE_PROBE
	for node in range(positions.size()):
		if Vector2(positions[node].x - point.x, positions[node].z - point.z).length() <= radius and absf(positions[node].y - point.y) < 1.6:
			narrowest = minf(narrowest, clearance[node])
	return narrowest
