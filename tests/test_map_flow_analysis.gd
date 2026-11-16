extends SceneTree
## The map flow analyser itself, on a tiny synthetic world whose answers are known.

const ANALYSIS := preload("res://scripts/map_flow_analysis.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _box(parent: Node, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


func _world(wall_gap_north: bool, wall_gap_south: bool, with_extras: bool) -> Node3D:
	var holder := Node3D.new()
	root.add_child(holder)
	_box(holder, Vector3(40, 0.8, 30), Vector3(0, -0.4, 0))
	# A wall across the middle (x = 0) with an optional gap at each end.
	var north_end := -10.0 if wall_gap_north else -14.2
	var south_end := 10.0 if wall_gap_south else 14.2
	_box(holder, Vector3(1.0, 3.0, south_end - north_end), Vector3(0, 1.5, (south_end + north_end) * 0.5))
	if with_extras:
		_box(holder, Vector3(4, 1.0, 4), Vector3(-10, 0.5, 5)) # climbable: 1.0 m step
		_box(holder, Vector3(4, 2.0, 4), Vector3(10, 1.0, 5)) # too high to jump onto
		_box(holder, Vector3(4, 0.3, 4), Vector3(-10, 1.35, -5)) # low ceiling: no headroom under it
	return holder


func _run() -> void:
	await physics_frame
	await physics_frame
	await _test_detour_and_routes()
	await _test_extras()
	await _test_gap_width()
	await _test_pit()
	await _test_gap_jumps()
	if failures.is_empty():
		print("PASS: map flow analyser (detours, routes, steps, headroom, gap width, pits, sightlines)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _analyse(holder: Node3D):
	await physics_frame
	await physics_frame
	var analysis = ANALYSIS.new()
	analysis.build(root.get_world_3d().direct_space_state)
	return analysis


func _test_detour_and_routes() -> void:
	var holder := _world(true, true, false)
	var analysis = await _analyse(holder)
	var a: int = analysis.nearest_node(Vector3(-8, 0, 0))
	var b: int = analysis.nearest_node(Vector3(8, 0, 0))
	_check(a >= 0 and b >= 0, "nodes exist on both sides of the wall")
	var path: Array[int] = analysis.path_between(a, b)
	_check(not path.is_empty(), "the wall can be walked around")
	var crossed_far := false
	for node in path:
		if absf(analysis.positions[node].z) > 9.5:
			crossed_far = true
	_check(crossed_far, "the path detours through a gap at the wall's end")
	_check(analysis.path_cost(path) > 25.0, "the detour is long (%f)" % analysis.path_cost(path))
	var routes: Array = analysis.distinct_routes(a, b, 3.5, 4.0, 4)
	_check(routes.size() >= 2, "both gaps count as separate routes (%d)" % routes.size())
	var members: Dictionary = analysis.strongly_connected_to(a).members
	_check(members.has(b), "both sides of the wall are one walkable space")
	_check(not analysis.has_line_of_sight(analysis.positions[a], analysis.positions[b]), "the wall blocks the line of sight")
	var east_a: int = analysis.nearest_node(Vector3(5, 0, -2))
	_check(analysis.has_line_of_sight(analysis.positions[b], analysis.positions[east_a]), "open floor is visible")
	holder.free()
	await physics_frame
	var sealed := _world(false, true, false)
	var one_way = await _analyse(sealed)
	var c: int = one_way.nearest_node(Vector3(-8, 0, 0))
	var d: int = one_way.nearest_node(Vector3(8, 0, 0))
	var one_routes: Array = one_way.distinct_routes(c, d, 3.5, 4.0, 4)
	_check(one_routes.size() == 1, "a single gap is a single route (%d)" % one_routes.size())
	sealed.free()
	await physics_frame


func _test_extras() -> void:
	var holder := _world(true, true, true)
	var analysis = await _analyse(holder)
	var start: int = analysis.nearest_node(Vector3(-8, 0, 8))
	var members: Dictionary = analysis.strongly_connected_to(start).members
	var step_top: int = analysis.nearest_node(Vector3(-10, 1.0, 5))
	_check(analysis.positions[step_top].y > 0.9 and members.has(step_top), "a 1.0 m block can be jumped onto and left again")
	var high_top: int = analysis.nearest_node(Vector3(10, 2.0, 5))
	_check(analysis.positions[high_top].y > 1.9 and not members.has(high_top), "a 2.0 m block cannot be reached from the floor")
	var under_ceiling: int = analysis.nearest_node(Vector3(-10, 0.0, -5))
	var floor_under := false
	for node in analysis.cells.get(Vector2i(int(floor((-10.0 + analysis.HALF_X) / analysis.CELL)), int(floor((-5.0 + analysis.HALF_Z) / analysis.CELL))), []):
		if absf(analysis.positions[node].y) < 0.05:
			floor_under = true
	_check(not floor_under, "no standing room under a 1.35 m ceiling (nearest node %d)" % under_ceiling)
	holder.free()
	await physics_frame


func _test_gap_width() -> void:
	# Two wall pieces leaving a 0.4 m slot (too tight) and a second pair leaving 1.4 m.
	var holder := Node3D.new()
	root.add_child(holder)
	_box(holder, Vector3(40, 0.8, 30), Vector3(0, -0.4, 0))
	_box(holder, Vector3(1.0, 3.0, 11.7), Vector3(0, 1.5, -8.15)) # z -14..-2.3
	_box(holder, Vector3(1.0, 3.0, 11.0), Vector3(0, 1.5, 8.5)) # z 3..14  -> gap z -2.3..3.0? narrowed below
	_box(holder, Vector3(1.0, 3.0, 4.1), Vector3(0, 1.5, -0.25)) # z -2.3..1.8 closes most of it
	var analysis = await _analyse(holder)
	var a: int = analysis.nearest_node(Vector3(-8, 0, 0))
	var b: int = analysis.nearest_node(Vector3(8, 0, 0))
	var path: Array[int] = analysis.path_between(a, b)
	_check(not path.is_empty(), "a 1.2 m gap (z 1.8..3.0) lets a player through")
	var squeezed := false
	for node in path:
		if absf(analysis.positions[node].x) < 0.7 and analysis.positions[node].z < 1.9:
			squeezed = true
	_check(not squeezed, "the path avoids the closed part of the wall")
	holder.free()
	await physics_frame
	var narrow := Node3D.new()
	root.add_child(narrow)
	_box(narrow, Vector3(40, 0.8, 30), Vector3(0, -0.4, 0))
	_box(narrow, Vector3(1.0, 3.0, 14.2), Vector3(0, 1.5, -7.1)) # z -14.2..0
	_box(narrow, Vector3(1.0, 3.0, 14.2 - 0.4), Vector3(0, 1.5, 0.4 + (14.2 - 0.4) * 0.5)) # z 0.4..14.2
	var tight = await _analyse(narrow)
	var c: int = tight.nearest_node(Vector3(-8, 0, 0))
	var d: int = tight.nearest_node(Vector3(8, 0, 0))
	_check(tight.path_between(c, d).is_empty(), "a 0.4 m slot is too narrow to walk through")
	narrow.free()
	await physics_frame


func _test_pit() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	_box(holder, Vector3(6, 0.8, 30), Vector3(-15, -0.4, 0)) # x -18..-12
	_box(holder, Vector3(26, 0.8, 30), Vector3(5, -0.4, 0)) # x -8..18
	_box(holder, Vector3(4, 0.8, 4), Vector3(-10, -0.4, -12)) # north of the hole
	_box(holder, Vector3(4, 0.8, 20), Vector3(-10, -0.4, 4)) # z -6..14, south of the hole
	_box(holder, Vector3(4, 0.4, 4), Vector3(-10, -2.4, -8)) # pit bottom, top at y = -2.2
	var analysis = await _analyse(holder)
	var start: int = analysis.nearest_node(Vector3(0, 0, 0))
	var result: Dictionary = analysis.strongly_connected_to(start)
	var pit_node: int = analysis.nearest_node(Vector3(-10, -2.2, -8))
	_check(analysis.positions[pit_node].y < -2.0, "the pit floor is sampled")
	_check(result.pits.has(pit_node), "dropping into the pit is possible but climbing out is not")
	_check(not result.members.has(pit_node), "pit nodes are not part of the safe space")
	holder.free()


func _gap_world(gap: float, east_top: float) -> Node3D:
	var holder := Node3D.new()
	root.add_child(holder)
	var half := gap * 0.5
	var west_width := 18.0 - half
	_box(holder, Vector3(west_width, 0.8, 30), Vector3(-(half + west_width * 0.5), -0.4, 0))
	_box(holder, Vector3(west_width, 0.8 + east_top, 30), Vector3(half + west_width * 0.5, east_top - (0.8 + east_top) * 0.5, 0))
	return holder


func _test_gap_jumps() -> void:
	var near := _gap_world(4.0, 0.0)
	var analysis = await _analyse(near)
	var a: int = analysis.nearest_node(Vector3(-8, 0, 0))
	var b: int = analysis.nearest_node(Vector3(8, 0, 0))
	_check(not analysis.path_between(a, b).is_empty() and not analysis.path_between(b, a).is_empty(), "a 4 m gap can be jumped both ways")
	_check(analysis.gap_jump_edges > 0, "gap jumps are counted")
	near.free()
	await physics_frame
	var wide := _gap_world(9.0, 0.0)
	var blocked = await _analyse(wide)
	var c: int = blocked.nearest_node(Vector3(-8, 0, 0))
	var d: int = blocked.nearest_node(Vector3(8, 0, 0))
	_check(blocked.path_between(c, d).is_empty(), "a 9 m gap cannot be jumped")
	wide.free()
	await physics_frame
	var raised := _gap_world(3.0, 1.0)
	var ledge = await _analyse(raised)
	var e: int = ledge.nearest_node(Vector3(-8, 0, 0))
	var f: int = ledge.nearest_node(Vector3(8, 1.0, 0))
	_check(not ledge.path_between(e, f).is_empty(), "a 3 m gap onto a 1.0 m higher ledge can be jumped")
	_check(not ledge.path_between(f, e).is_empty(), "and the drop back down works")
	raised.free()
	await physics_frame
	_check(absf(ANALYSIS.jump_reach(0.0) - 5.83) < 0.1, "jump reach on level ground is about 5.8 m (%f)" % ANALYSIS.jump_reach(0.0))
	_check(ANALYSIS.jump_reach(1.2) < ANALYSIS.jump_reach(0.0), "landing higher shortens the jump")
	_check(ANALYSIS.jump_reach(2.0) == 0.0, "a ledge above the jump apex cannot be reached")
