extends SceneTree
## Runtime checks for the Jungle Arena (map 5): geometry heights, spawn safety, real walking up
## the ramps and out of the river with the server player body, and the per-map swim zone.

const SERVER_PLAYER_SCRIPT := preload("res://scripts/oxenwar_server_player.gd")
const JUNGLE := 5

var failures: Array[String] = []
var world: Node3D


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_swim_zone_function()
	var holder := Node3D.new()
	root.add_child(holder)
	world = MapWorldBuilder.build(holder, JUNGLE)
	await physics_frame
	await physics_frame
	_test_structure()
	_test_node_budget()
	_test_heights()
	_test_ramp_surfaces()
	_test_spawn_points_are_free()
	await _test_walk_up_pyramid_ramp()
	await _test_walk_up_treehouse_ramp()
	await _test_climb_out_of_river()
	await _test_spawn_landing_and_swim_flag()

	if failures.is_empty():
		print("PASS: Jungle Arena structure, heights, spawn safety, ramps, river exits and swim zone")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_swim_zone_function() -> void:
	_assert_true("river is the jungle swim zone", MapWorldBuilder.in_swim_zone(JUNGLE, Vector3(0.0, -1.1, 0.0)))
	_assert_true("river banks are not swim zone", not MapWorldBuilder.in_swim_zone(JUNGLE, Vector3(-6.0, 0.0, 0.0)))
	_assert_true("standing on the causeway is not swimming", not MapWorldBuilder.in_swim_zone(JUNGLE, Vector3(0.0, 0.5, 6.1)))
	_assert_true("objective site A is not swim zone in the jungle", not MapWorldBuilder.in_swim_zone(JUNGLE, Vector3(-9.0, 0.22, -8.0)))
	_assert_true("original beach pool still works on other maps", MapWorldBuilder.in_swim_zone(4, Vector3(-12.0, 0.0, -9.0)))
	_assert_true("original beach pool ignores far positions", not MapWorldBuilder.in_swim_zone(4, Vector3(5.0, 0.0, 5.0)))


func _test_structure() -> void:
	var required := [
		"JungleFloorWest", "JungleFloorEast", "JungleRiverBed", "JungleRiverWater", "JungleWaterfallCliff",
		"JungleWaterfallRibbon", "JungleWaterfallBasin", "JungleLogBridge", "JungleSpawnCauseway",
		"JunglePyramidTier1", "JunglePyramidTier2", "JunglePyramidTier3", "JunglePyramidRamp",
		"JungleRuinsTier1", "JungleRuinsTier2", "JungleRuinsTier3", "JungleRuinsRamp",
		"JungleTreehouse_A_Platform", "JungleTreehouse_B_Platform", "JungleTreehouseRamp_A", "JungleTreehouseRamp_B",
		"JungleRopeBridge_A", "JungleRopeBridge_B", "JungleBlueFlagBase", "JungleRedFlagBase",
		"ObjectiveSite_A_Pad", "ObjectiveSite_B_Pad"
	]
	for node_name in required:
		_assert_true("%s exists" % node_name, world.find_child(node_name, true, false) != null)
	# A duplicate name makes Godot rename the node to "@Type@N". Unnamed labels are renamed that way
	# on purpose, so only named nodes (everything but Label3D) are checked.
	var renamed := 0
	for node in world.get_children():
		if node is Label3D:
			continue
		if str(node.name).contains("@"):
			renamed += 1
			failures.append("duplicate or invalid node name: %s" % str(node.name))
	_assert_equal("no duplicate node names", renamed, 0)


## Phone budget: counts what the renderer has to draw. The limits are generous guard rails against
## the map growing unnoticed; real frame rate on a phone still has to be measured on a device.
func _test_node_budget() -> void:
	var nodes := 0
	var meshes := 0
	var bodies := 0
	var lights := 0
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		nodes += 1
		if node is MeshInstance3D:
			meshes += 1
		if node is StaticBody3D:
			bodies += 1
		if node is Light3D:
			lights += 1
		for child in node.get_children():
			stack.append(child)
	print("Jungle Arena budget: %d nodes, %d meshes, %d static bodies, %d lights" % [nodes, meshes, bodies, lights])
	_assert_true("node count stays below 900 (%d)" % nodes, nodes < 900)
	_assert_true("mesh count stays below 700 (%d)" % meshes, meshes < 700)
	_assert_true("static body count stays below 400 (%d)" % bodies, bodies < 400)
	_assert_true("no extra lights on the map (%d)" % lights, lights <= 4)


func _ground_y(x: float, z: float) -> float:
	var space := root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 12.0, z), Vector3(x, -5.0, z))
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -999.0
	return hit.position.y


func _test_heights() -> void:
	var cases := [
		["river bed", 0.0, 0.0, -1.2],
		["west bank", -10.0, 0.0, 0.0],
		["east bank", 10.0, 0.0, 0.0],
		["spawn causeway", 0.0, 6.1, 0.5],
		["log bridge deck", 0.0, -2.4, 0.5],
		["waterfall cliff top", 0.0, -12.2, 6.0],
		["pyramid tier 1", -16.5, -12.0, 1.0],
		["pyramid tier 2", -14.3, -7.5, 2.0],
		["pyramid tier 3", -14.3, -9.5, 3.0],
		["ruins tier 1", 16.5, 12.0, 1.0],
		["ruins tier 2", 14.3, 7.5, 2.0],
		["ruins tier 3", 14.3, 9.5, 3.0],
		["treehouse A", -7.1, -11.85, 3.0],
		["treehouse B", 7.1, 11.85, 3.0],
		["rope bridge A", -11.3, -10.4, 3.0],
		["rope bridge B", 11.3, 10.4, 3.0],
		["objective pad A", -9.0, -8.0, 0.22],
		["objective pad B", 9.0, 8.0, 0.22],
	]
	for entry in cases:
		var label: String = entry[0]
		var actual := _ground_y(float(entry[1]), float(entry[2]))
		_assert_near("%s height" % label, actual, float(entry[3]), 0.06)


## Points along each ramp must lie on the straight line between its ends, and no ramp may be steeper
## than the 45 degree floor angle the characters can walk.
func _test_ramp_surfaces() -> void:
	var ramps := [
		["pyramid ramp", Vector3(-14.3, 0.0, -2.3), Vector3(-14.3, 1.0, -6.3)],
		["ruins ramp", Vector3(14.3, 0.0, 2.3), Vector3(14.3, 1.0, 6.3)],
		["treehouse ramp A", Vector3(-5.5, 0.0, -5.0), Vector3(-5.5, 3.0, -9.9)],
		["treehouse ramp B", Vector3(5.5, 0.0, 5.0), Vector3(5.5, 3.0, 9.9)],
		["river exit west", Vector3(-0.7, -1.2, 1.5), Vector3(-2.4, 0.0, 1.5)],
		["river exit east", Vector3(0.7, -1.2, 10.5), Vector3(2.4, 0.0, 10.5)],
		["causeway north ramp", Vector3(3.3, 0.0, 2.2), Vector3(3.3, 0.5, 4.0)],
		["log bridge ramp", Vector3(-5.8, 0.0, -2.4), Vector3(-3.7, 0.5, -2.4)],
	]
	for ramp in ramps:
		var label: String = ramp[0]
		var bottom: Vector3 = ramp[1]
		var top: Vector3 = ramp[2]
		var run := Vector2(top.x - bottom.x, top.z - bottom.z).length()
		var angle := rad_to_deg(atan2(top.y - bottom.y, run))
		_assert_true("%s slope is walkable (%.1f deg)" % [label, angle], angle <= 40.0)
		for t in [0.25, 0.5, 0.75]:
			var point := bottom.lerp(top, t)
			_assert_near("%s surface at %.0f%%" % [label, t * 100.0], _ground_y(point.x, point.z), point.y, 0.12)


func _test_spawn_points_are_free() -> void:
	var space := root.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	for x in [-2.4, -0.8, 0.8, 2.4]:
		for z in [6.0, 7.6]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.5 + 0.9 + 0.05, z))
			var hits := space.intersect_shape(query, 4)
			_assert_equal("spawn (%.1f, %.1f) is free" % [x, z], hits.size(), 0)
			_assert_near("spawn (%.1f, %.1f) lands on the causeway" % [x, z], _ground_y(x, z), 0.5, 0.06)


func _make_player(position: Vector3, yaw: float = 0.0) -> CharacterBody3D:
	var player := CharacterBody3D.new()
	player.set_script(SERVER_PLAYER_SCRIPT)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = position
	root.add_child(player)
	player.set("look_yaw", yaw)
	return player


func _walk(player: CharacterBody3D, frames: int) -> void:
	player.set("input_vector", Vector2(0.0, -1.0))
	for i in range(frames):
		await physics_frame
	player.set("input_vector", Vector2.ZERO)


func _test_walk_up_pyramid_ramp() -> void:
	var player := _make_player(Vector3(-14.3, 0.05, -1.0), 0.0)
	await _walk(player, 120)
	_assert_true("walking north climbs the pyramid ramp (y %.2f)" % player.global_position.y, absf(player.global_position.y - 1.0) < 0.08)
	_assert_true("player ends on the first tier (z %.2f)" % player.global_position.z, player.global_position.z < -6.4 and player.global_position.z > -8.0)
	player.queue_free()
	await physics_frame


func _test_walk_up_treehouse_ramp() -> void:
	var player := _make_player(Vector3(-5.5, 0.05, -3.6), 0.0)
	await _walk(player, 200)
	_assert_true("walking north climbs to the treehouse (y %.2f)" % player.global_position.y, absf(player.global_position.y - 3.0) < 0.1)
	_assert_true("player is on the treehouse platform (z %.2f)" % player.global_position.z, player.global_position.z < -10.0 and player.global_position.z > -13.8)
	player.queue_free()
	await physics_frame


func _test_climb_out_of_river() -> void:
	# Yaw 90 degrees makes "forward" point west, toward the exit ramp at z = 1.5.
	var player := _make_player(Vector3(-0.2, -1.1, 1.5), PI * 0.5)
	await _walk(player, 120)
	_assert_true("a swimmer climbs out on the west bank (x %.2f, y %.2f)" % [player.global_position.x, player.global_position.y], player.global_position.x < -2.5 and absf(player.global_position.y) < 0.08)
	player.queue_free()
	await physics_frame


func _test_spawn_landing_and_swim_flag() -> void:
	var player := _make_player(Vector3(0.0, 1.5, 6.0), 0.0)
	player.set("swim_map_index", JUNGLE)
	for i in range(60):
		await physics_frame
	_assert_true("spawn lands on the causeway (y %.2f)" % player.global_position.y, absf(player.global_position.y - 0.5) < 0.08 and player.is_on_floor())
	_assert_true("a player on the causeway is not swimming", not bool(player.get("is_swimming")))
	player.global_position = Vector3(0.0, -1.1, 0.0)
	player.velocity = Vector3.ZERO
	for i in range(10):
		await physics_frame
	_assert_true("a player in the river is swimming (y %.2f)" % player.global_position.y, bool(player.get("is_swimming")))
	player.queue_free()
	await physics_frame


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append("%s: expected true" % label)


func _assert_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s +/- %s, got %s" % [label, str(expected), str(tolerance), str(actual)])
