extends SceneTree
## Plays-by-numbers report for every real map, measured on the real collision.

const ANALYSIS := preload("res://scripts/map_flow_analysis.gd")
const LAYOUT := preload("res://scripts/arena_layout.gd")
const SITES := {"A": Vector3(-9.0, 0.0, -8.0), "B": Vector3(9.0, 0.0, 8.0)}
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
	for site_id in SITES:
		var node: int = analysis.nearest_node(SITES[site_id] + Vector3(0, 0.22, 0))
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
	var spawn_gap := analysis.positions[red_start].distance_to(analysis.positions[blue_start])
	report.append("  red/blue spawn distance (slot 0): %.1f m" % spawn_gap)
	arena.free()
	holder.free()
	await physics_frame
