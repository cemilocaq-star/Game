extends SceneTree
## Server rooms with their own map: every room gets its own physics world, so two rooms can use
## different maps at the same time, players land on the right floor, shots and grenades only see
## their own room, and the Jungle Arena geometry stops bullets and bounces grenades.

const NETWORK_SCRIPT := preload("res://scripts/oxenwar_network.gd")
const ARENA_LAYOUT := preload("res://scripts/arena_layout.gd")
const GRENADE_PHYSICS := preload("res://scripts/grenade_physics.gd")
const JUNGLE := 5

var failures: Array[String] = []
var network: Node


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_layout_helpers()
	network = Node.new()
	network.set_script(NETWORK_SCRIPT)
	network.name = "OxenWarNet"
	root.add_child(network)
	var rooms: Dictionary = network.get("_rooms")
	rooms["JUNGLE"] = network.call("_new_room", "JUNGLE", "u1", true, "ffa", JUNGLE)
	rooms["SUNKEN"] = network.call("_new_room", "SUNKEN", "u3", true, "ffa", 4)
	_assert_equal("jungle room stores its map", int(rooms["JUNGLE"].get("map_index", -1)), JUNGLE)
	_assert_equal("other room keeps its map", int(rooms["SUNKEN"].get("map_index", -1)), 4)
	var invalid: Dictionary = network.call("_new_room", "BADMAP", "u9", true, "ffa", 99)
	_assert_equal("an invalid map falls back to the default", int(invalid.get("map_index", -1)), ARENA_LAYOUT.DEFAULT_MAP)

	var p1 = network.call("_create_server_player", 11, {}, {})
	var p2 = network.call("_create_server_player", 12, {}, {})
	var p3 = network.call("_create_server_player", 13, {}, {})
	network.call("_assign_user_to_room", "u1", 11, "JUNGLE")
	network.call("_assign_user_to_room", "u2", 12, "JUNGLE")
	network.call("_assign_user_to_room", "u3", 13, "SUNKEN")
	for i in range(90):
		await physics_frame

	_test_players_are_in_their_room_worlds(p1, p2, p3)
	_test_jungle_spawn_and_landing(p1, p2)
	_test_rooms_are_isolated()
	_test_orbs_are_reachable()
	_test_spawn_points_free()
	_test_hitscan_blocked_by_jungle_geometry()
	await _test_grenade_bounces_on_jungle_geometry()
	await _test_players_leave_and_world_is_freed(p1)

	if failures.is_empty():
		print("PASS: per-room maps, isolated physics worlds, orbs, spawns, hitscan and grenades on the Jungle Arena")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_layout_helpers() -> void:
	_assert_equal("map 5 is kept", ARENA_LAYOUT.sanitize_map(5), 5)
	_assert_equal("negative map falls back", ARENA_LAYOUT.sanitize_map(-1), ARENA_LAYOUT.DEFAULT_MAP)
	_assert_equal("too large map falls back", ARENA_LAYOUT.sanitize_map(7), ARENA_LAYOUT.DEFAULT_MAP)
	_assert_equal("jungle name", ARENA_LAYOUT.map_name(JUNGLE), "JUNGLE ARENA")
	_assert_equal("12 jungle orbs", ARENA_LAYOUT.orb_positions(JUNGLE).size(), 12)
	_assert_equal("12 default orbs", ARENA_LAYOUT.orb_positions(4).size(), 12)
	_assert_true("jungle has a floor-less base", not _box_names(JUNGLE).has("ArenaFloor"))
	_assert_true("jungle walls exist", _box_names(JUNGLE).has("NorthWall"))
	_assert_true("other maps keep the floor", _box_names(4).has("ArenaFloor"))


func _box_names(map_index: int) -> Array:
	var names := []
	for box in ARENA_LAYOUT.base_boxes(map_index):
		names.append(str(box.name))
	return names


func _test_players_are_in_their_room_worlds(p1, p2, p3) -> void:
	_assert_true("jungle player 1 sits in the jungle world", p1.get_parent() is SubViewport and str(p1.get_parent().name) == "RoomWorld_JUNGLE")
	_assert_true("jungle player 2 shares that world", p2.get_parent() == p1.get_parent())
	_assert_true("the other room has a separate world", p3.get_parent() is SubViewport and p3.get_parent() != p1.get_parent())
	_assert_true("the two worlds are different physics spaces", p1.get_world_3d().space != p3.get_world_3d().space)
	_assert_equal("jungle player swim map", int(p1.get("swim_map_index")), JUNGLE)
	_assert_equal("other player swim map", int(p3.get("swim_map_index")), 4)


func _test_jungle_spawn_and_landing(p1, p2) -> void:
	for player in [p1, p2]:
		var pos: Vector3 = player.global_position
		_assert_near("%s lands on the causeway (y %.2f)" % [player.name, pos.y], pos.y, 0.5, 0.08)
		_assert_true("%s is on the floor" % player.name, player.is_on_floor())
		_assert_true("%s is not swimming" % player.name, not bool(player.get("is_swimming")))
		_assert_true("%s is inside the arena" % player.name, absf(pos.x) < 3.0 and pos.z > 5.0 and pos.z < 9.0)


func _room_space(code: String) -> PhysicsDirectSpaceState3D:
	return network.call("_room_space", code)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var rids: Array[RID] = []
	for item in exclude:
		rids.append(item.get_rid())
	query.exclude = rids
	return space.intersect_ray(query)


func _test_rooms_are_isolated() -> void:
	var jungle := _ray(_room_space("JUNGLE"), Vector3(0, 12, -12.2), Vector3(0, -3, -12.2))
	var other := _ray(_room_space("SUNKEN"), Vector3(0, 12, -12.2), Vector3(0, -3, -12.2))
	_assert_true("jungle room sees the waterfall cliff", not jungle.is_empty() and absf(jungle.position.y - 6.0) < 0.1)
	_assert_true("the other room does not contain the waterfall cliff", other.is_empty() or other.position.y < 4.0)


func _test_orbs_are_reachable() -> void:
	var space := _room_space("JUNGLE")
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	var index := 0
	for orb in ARENA_LAYOUT.orb_positions(JUNGLE):
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, orb)
		_assert_equal("jungle orb %d is not inside a solid" % index, space.intersect_shape(query, 4).size(), 0)
		var ground := _ray(space, orb, orb + Vector3.DOWN * 3.0)
		_assert_true("jungle orb %d has ground within reach below it" % index, not ground.is_empty() and orb.y - ground.position.y <= 1.15)
		index += 1


func _test_spawn_points_free() -> void:
	var space := _room_space("JUNGLE")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	for team in ["", "red", "blue"]:
		for slot in range(8):
			var spawn: Vector3 = ARENA_LAYOUT.spawn_position(JUNGLE, team, slot)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, Vector3(spawn.x, 0.5 + 0.95, spawn.z))
			_assert_equal("jungle spawn team '%s' slot %d is free" % [team, slot], space.intersect_shape(query, 4).size(), 0)
			var ground := _ray(space, Vector3(spawn.x, 3.0, spawn.z), Vector3(spawn.x, -3.0, spawn.z))
			_assert_true("jungle spawn team '%s' slot %d stands on the causeway" % [team, slot], not ground.is_empty() and absf(ground.position.y - 0.5) < 0.12)


func _test_hitscan_blocked_by_jungle_geometry() -> void:
	var space := _room_space("JUNGLE")
	# Open river water: a shot along the river just above the bed, under the log bridge, is not blocked.
	var open := _ray(space, Vector3(0, -0.5, -9.0), Vector3(0, -0.5, 3.0))
	var blocker := "nothing" if open.is_empty() else "%s at %s" % [str(open.collider.get_parent().name if open.collider.get_parent() != null else open.collider.name), str(open.position)]
	_assert_true("a shot along the open river flies free (blocked by %s)" % blocker, open.is_empty())
	# A shot into the waterfall cliff stops at the cliff face, well before the arena wall.
	var cliff := _ray(space, Vector3(0, 3.0, -8.0), Vector3(0, 3.0, -20.0))
	_assert_true("a shot stops at the waterfall cliff", not cliff.is_empty() and cliff.position.z > -13.0)
	# A shot into the pyramid stops on the tiers.
	var pyramid := _ray(space, Vector3(-14.3, 2.5, -4.0), Vector3(-14.3, 2.5, -20.0))
	_assert_true("a shot stops at the pyramid", not pyramid.is_empty() and pyramid.position.z > -13.0)
	# A shot at a player in the same room hits that player, not a player in another room.
	var p1 = network.get("_server_players")[11]
	var p2 = network.get("_server_players")[12]
	var p3 = network.get("_server_players")[13]
	var from: Vector3 = p1.global_position + Vector3.UP * 1.0
	var to: Vector3 = p2.global_position + Vector3.UP * 1.0
	var direction := (to - from).normalized()
	var hit := _ray(space, from, from + direction * 10.0, [p1])
	_assert_true("a shot reaches the teammate body in the same room", not hit.is_empty() and hit.collider == p2)
	_assert_true("another room's player is not hit", hit.is_empty() or hit.collider != p3)


func _test_grenade_bounces_on_jungle_geometry() -> void:
	var space := _room_space("JUNGLE")
	# Dropped on the west bank (y = 0) it bounces and comes to rest on top of the ground.
	var state := {"position": Vector3(-10, 3.0, 0.0), "velocity": Vector3.ZERO}
	for i in range(240):
		state = GRENADE_PHYSICS.step(state.position, state.velocity, 1.0 / 60.0, space, [])
	_assert_true("a grenade rests on the bank (y %.2f)" % state.position.y, state.position.y > -0.01 and state.position.y < 0.4)
	_assert_true("it stays at rest", state.velocity.length() < 0.5)
	# Dropped on pyramid tier 3 it lands on the tier, not in the river.
	var tier := {"position": Vector3(-14.3, 6.0, -9.5), "velocity": Vector3.ZERO}
	for i in range(240):
		tier = GRENADE_PHYSICS.step(tier.position, tier.velocity, 1.0 / 60.0, space, [])
	_assert_true("a grenade rests on pyramid tier 3 (y %.2f)" % tier.position.y, absf(tier.position.y - 3.08) < 0.35)
	# Dropped in the river it sinks to the river bed instead of falling through the world.
	var river := {"position": Vector3(0.0, 2.0, -6.0), "velocity": Vector3.ZERO}
	for i in range(240):
		river = GRENADE_PHYSICS.step(river.position, river.velocity, 1.0 / 60.0, space, [])
	_assert_true("a grenade in the river rests on the bed (y %.2f)" % river.position.y, river.position.y > -1.3 and river.position.y < -0.9)
	# Thrown hard at the waterfall cliff it bounces back instead of passing through.
	var thrown := {"position": Vector3(0, 3.0, -8.0), "velocity": Vector3(0, 2.0, -20.0)}
	for i in range(30):
		thrown = GRENADE_PHYSICS.step(thrown.position, thrown.velocity, 1.0 / 60.0, space, [])
	_assert_true("a grenade bounces off the cliff (z %.2f)" % thrown.position.z, thrown.position.z > -13.2)
	await physics_frame


func _test_players_leave_and_world_is_freed(p1) -> void:
	network.call("_return_player_to_lobby", 11)
	_assert_true("a player who leaves goes back to the lobby", p1.get_parent() == network)
	network.call("_free_room_world", "JUNGLE")
	await process_frame
	await process_frame
	_assert_true("an empty room frees its world", network.find_child("RoomWorld_JUNGLE", false, false) == null)
	_assert_true("the other room keeps its world", network.find_child("RoomWorld_SUNKEN", false, false) != null)


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append("%s: expected true" % label)


func _assert_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s +/- %s, got %s" % [label, str(expected), str(tolerance), str(actual)])
