extends SceneTree
## Plays-by-numbers report for every real map, measured on the real collision.

const ANALYSIS := preload("res://scripts/map_flow_analysis.gd")
const LAYOUT := preload("res://scripts/arena_layout.gd")
var failures: Array[String] = []
var report: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	for map_index in range(LAYOUT.MAP_COUNT):
		await _analyse_map(map_index)
	for line in report:
		print(line)
	if failures.is_empty():
		print("PASS: map flow checks for all %d maps" % LAYOUT.MAP_COUNT)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _fmt(point: Vector3) -> String:
	return "(%.1f,%.1f,%.1f)" % [point.x, point.y, point.z]


## Tall solid props (top at least 3 m, not boundary walls) per quadrant: x<0/x>0, z<0/z>0.
func _landmarks(node: Node, found: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			for part in body.get_children():
				if part is CollisionShape3D and (part as CollisionShape3D).shape != null:
					var shape := (part as CollisionShape3D).shape
					var height := 0.0
					if shape is BoxShape3D:
						height = (shape as BoxShape3D).size.y
					elif shape is CylinderShape3D:
						height = (shape as CylinderShape3D).height
					var centre: Vector3 = body.global_transform * (part as CollisionShape3D).position
					if height > 0.0 and centre.y + height * 0.5 >= 3.0 and absf(centre.x) < 16.4 and absf(centre.z) < 13.6:
						found.append(centre)
		_landmarks(child, found)


func _analyse_map(map_index: int) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var arena := LAYOUT.build_collision(holder, map_index)
	await physics_frame
	await physics_frame
	var started := Time.get_ticks_msec()
	var analysis = ANALYSIS.new()
	analysis.build(root.get_world_3d().direct_space_state)
	var name := "%d %s" % [map_index, LAYOUT.map_name(map_index)]
	report.append("== MAP %s: %d nodes, %d jump steps, %d gap jumps, built in %d ms" % [name, analysis.node_count(), analysis.step_jump_edges, analysis.gap_jump_edges, Time.get_ticks_msec() - started])
	var red_start: int = analysis.nearest_node(LAYOUT.spawn_position(map_index, "red", 0))
	var blue_start: int = analysis.nearest_node(LAYOUT.spawn_position(map_index, "blue", 0))
	_check(red_start >= 0 and blue_start >= 0, "%s: spawns have ground" % name)
	if red_start < 0 or blue_start < 0:
		holder.free()
		return
	var safe: Dictionary = analysis.strongly_connected_to(red_start)
	var members: Dictionary = safe.members
	_check(members.has(blue_start), "%s: red and blue spawn are one walkable space" % name)
	# Every spawn slot must stand on safe ground.
	var bad_spawns := 0
	for team in ["red", "blue"]:
		for slot in range(8):
			var node: int = analysis.nearest_node(LAYOUT.spawn_position(map_index, team, slot))
			if node < 0 or not members.has(node):
				bad_spawns += 1
	_check(bad_spawns == 0, "%s: %d spawn slots are not on safe ground" % [name, bad_spawns])
	var pits_ok: bool = safe.pits.size() == 0
	var pit_samples: Array[String] = []
	for node: int in safe.pits:
		if pit_samples.size() < 5:
			pit_samples.append(_fmt(analysis.positions[node]))
	var dead_nodes := 0
	for node in range(analysis.node_count()):
		if not members.has(node) and not safe.pits.has(node):
			dead_nodes += 1
	report.append("  space: %d safe nodes of %d, %d drop-in pits %s, %d unreachable-from-floor nodes (tops of tall props)" % [members.size(), analysis.node_count(), safe.pits.size(), str(pit_samples), dead_nodes])
	# Pickups and objective sites.
	var lost_orbs := 0
	for orb in LAYOUT.orb_positions(map_index):
		var node: int = analysis.nearest_node(Vector3(orb.x, maxf(0.0, orb.y - 1.2), orb.z))
		var horizontal := 99.0
		if node >= 0:
			horizontal = Vector2(analysis.positions[node].x - orb.x, analysis.positions[node].z - orb.z).length()
		if node < 0 or not members.has(node) or horizontal > 1.0:
			lost_orbs += 1
			report.append("  pickup %s is not on safe ground (nearest %s)" % [_fmt(orb), _fmt(analysis.positions[node]) if node >= 0 else "none"])
	_check(lost_orbs == 0, "%s: %d pickups are out of reach" % [name, lost_orbs])
	var site_nodes := {}
	var balance_numbers := {}
	for site_id in ["A", "B"]:
		var node: int = analysis.nearest_node(LAYOUT.objective_site(map_index, site_id) + Vector3(0, 0.22, 0))
		site_nodes[site_id] = node
		_check(node >= 0 and members.has(node), "%s: objective site %s is reachable" % [name, site_id])
	# Routes between the spawns.
	var routes: Array = analysis.distinct_routes(red_start, blue_start, 3.5, 7.0, 4)
	var route_text: Array[String] = []
	for route in routes:
		route_text.append("%.0f m (%.0f%% squeezed)" % [route.cost, float(route.squeezed_share) * 100.0])
	report.append("  routes red->blue: %d distinct: %s" % [routes.size(), ", ".join(route_text)])
	# Balance: mean path length from each team's eight spawn slots to the middle and to each site.
	var centre: int = analysis.nearest_node(Vector3(0, 0.5, 0))
	var balance: Array[String] = []
	for target_name in ["centre", "A", "B"]:
		var target: int = centre if target_name == "centre" else int(site_nodes.get(target_name, -1))
		if target < 0:
			continue
		var costs: PackedFloat32Array = analysis.costs_to(target)
		var means := {}
		for team in ["red", "blue"]:
			var total := 0.0
			for slot in range(8):
				total += float(costs[analysis.nearest_node(LAYOUT.spawn_position(map_index, team, slot))])
			means[team] = total / 8.0
		balance.append("%s red %.0f / blue %.0f" % [target_name, means.red, means.blue])
		balance_numbers[target_name] = means
	report.append("  balance (mean path metres from spawn slots): " + "; ".join(balance))
	# Traffic and chokepoints.
	var member_list: Array = members.keys()
	var traffic: Dictionary = analysis.traffic_report(member_list, 30, 1000 + map_index)
	var hot_text: Array[String] = []
	for entry in traffic.hot:
		hot_text.append("%s %.0f%% (passage %.1f m wide)" % [_fmt(entry.position), float(entry.share) * 100.0, analysis.passage_half_width(entry.position) * 2.0])
	report.append("  traffic: top 5%% of cells carry %.0f%% of routes; busiest: %s" % [float(traffic.concentration) * 100.0, ", ".join(hot_text)])
	# Sightlines.
	var sight: Dictionary = analysis.sightline_report(member_list, 1500, 77 + map_index)
	report.append("  sightlines: clear view share <8 m %.0f%%, 8-16 m %.0f%%, >16 m %.0f%% (longest %.1f m)" % [float(sight.bands[0]) * 100.0, float(sight.bands[1]) * 100.0, float(sight.bands[2]) * 100.0, float(sight.longest)])
	var exposure := {}
	for team in ["red", "blue"]:
		var total := 0.0
		for slot in range(8):
			var spawn_node: int = analysis.nearest_node(LAYOUT.spawn_position(map_index, team, slot))
			total += analysis.exposure_of(analysis.positions[spawn_node], member_list, 10.0)
		exposure[team] = total / 8.0
	report.append("  spawn exposure (share of the map beyond 10 m that sees a spawn, mean of 8 slots): red %.0f%%, blue %.0f%%" % [float(exposure.red) * 100.0, float(exposure.blue) * 100.0])
	var spawn_gap: float = analysis.positions[red_start].distance_to(analysis.positions[blue_start])
	report.append("  red/blue spawn distance (slot 0): %.1f m" % spawn_gap)
	# Design targets, measured above.
	_check(pits_ok, "%s: players can drop into a pit they cannot leave" % name)
	_check(spawn_gap >= 15.0, "%s: the teams spawn only %.1f m apart" % [name, spawn_gap])
	_check(routes.size() >= 3 and float(routes[2].cost) <= float(routes[0].cost) * 2.0, "%s: fewer than three reasonable routes between the spawns" % name)
	if balance_numbers.has("centre"):
		_check(absf(float(balance_numbers.centre.red) - float(balance_numbers.centre.blue)) <= 3.0, "%s: the centre is not equally far from both teams" % name)
	if balance_numbers.has("A") and balance_numbers.has("B"):
		var red_best := minf(float(balance_numbers.A.red), float(balance_numbers.B.red))
		var blue_best := minf(float(balance_numbers.A.blue), float(balance_numbers.B.blue))
		_check(absf(red_best - blue_best) <= 3.0, "%s: nearest energy site is %.0f m for red but %.0f m for blue" % [name, red_best, blue_best])
		_check(minf(float(balance_numbers.A.blue), float(balance_numbers.B.blue)) >= 8.0, "%s: an energy site is practically inside a spawn" % name)
	_check(float(exposure.red) <= 0.6 and float(exposure.blue) <= 0.6, "%s: a spawn is visible from more than 60%% of the map" % name)
	_check(absf(float(exposure.red) - float(exposure.blue)) <= 0.15, "%s: spawn exposure differs a lot between teams" % name)
	_check(float(sight.bands[2]) <= 0.45, "%s: too many long open sightlines (%.0f%% beyond 16 m)" % [name, float(sight.bands[2]) * 100.0])
	var landmarks: Array = []
	_landmarks(arena, landmarks)
	var quadrants := [0, 0, 0, 0]
	for point: Vector3 in landmarks:
		quadrants[(1 if point.x > 0.0 else 0) + (2 if point.z > 0.0 else 0)] += 1
	report.append("  landmarks (3 m+ solid props) per quadrant NW/NE/SW/SE: %s" % str(quadrants))
	for quadrant in range(4):
		_check(quadrants[quadrant] >= 1, "%s: quadrant %d has no landmark to steer by" % [name, quadrant])
	arena.free()
	holder.free()
	await physics_frame
