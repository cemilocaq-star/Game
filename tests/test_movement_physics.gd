extends SceneTree
## Runtime checks for the shared movement model (CharacterMovement), the grenade bounce model
## (GrenadePhysics) and the real server player body on a real physics floor.

const GRENADE_PHYSICS := preload("res://scripts/grenade_physics.gd")
const SERVER_PLAYER_SCRIPT := preload("res://scripts/oxenwar_server_player.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_gravity()
	_test_horizontal_ground_and_air()
	_test_bounce_math()
	_test_free_flight_matches_across_frame_rates()
	await _test_grenade_on_real_floor()
	await _test_server_player_on_real_floor()

	if failures.is_empty():
		print("PASS: shared movement, grenade bounce and server player physics")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_gravity() -> void:
	var rising := CharacterMovement.apply_gravity(5.0, 18.0, 1.0, 0.1)
	_assert_near("rising uses plain gravity", rising, 5.0 - 1.8, 0.0001)
	var falling := CharacterMovement.apply_gravity(-5.0, 18.0, 1.0, 0.1)
	_assert_near("falling is snappier than rising", falling, -5.0 - 1.8 * CharacterMovement.FALL_GRAVITY_MULTIPLIER, 0.0001)
	_assert_true("falling is faster than rising", absf(falling + 5.0) > absf(rising - 5.0))
	var low_gravity := CharacterMovement.apply_gravity(0.0, 18.0, 0.55, 0.1)
	_assert_near("low gravity event scales gravity", low_gravity, -18.0 * 0.55 * 0.1, 0.0001)
	_assert_true("low gravity pulls less than normal gravity", absf(low_gravity) < absf(CharacterMovement.apply_gravity(0.0, 18.0, 1.0, 0.1)))
	var capped := CharacterMovement.apply_gravity(-44.9, 18.0, 1.0, 0.5)
	_assert_near("terminal fall speed", capped, -CharacterMovement.TERMINAL_FALL_SPEED, 0.0001)


func _test_horizontal_ground_and_air() -> void:
	var forward := Vector2(0.0, -1.0)
	var ground := CharacterMovement.step_horizontal(Vector2.ZERO, forward, 6.0, true, false, false, 0.1)
	var air := CharacterMovement.step_horizontal(Vector2.ZERO, forward, 6.0, false, false, false, 0.1)
	_assert_near("ground acceleration", ground.length(), CharacterMovement.GROUND_ACCELERATION * 0.1, 0.0001)
	_assert_near("air acceleration", air.length(), CharacterMovement.AIR_ACCELERATION * 0.1, 0.0001)
	_assert_true("air steering is weaker than ground steering", air.length() < ground.length())
	_assert_true("air steering still works", air.length() > 0.5)

	var moving := Vector2(6.0, 0.0)
	var ground_stop := CharacterMovement.step_horizontal(moving, Vector2.ZERO, 6.0, true, false, false, 0.1)
	var air_stop := CharacterMovement.step_horizontal(moving, Vector2.ZERO, 6.0, false, false, false, 0.1)
	_assert_near("ground friction", ground_stop.x, 6.0 - CharacterMovement.GROUND_FRICTION * 0.1, 0.0001)
	_assert_near("air keeps momentum", air_stop.x, 6.0 - CharacterMovement.AIR_FRICTION * 0.1, 0.0001)
	_assert_true("momentum is kept in the air", air_stop.x > ground_stop.x + 1.0)
	var ice_stop := CharacterMovement.step_horizontal(moving, Vector2.ZERO, 6.0, true, false, true, 0.1)
	_assert_near("ice friction", ice_stop.x, 6.0 - CharacterMovement.ICE_FRICTION * 0.1, 0.0001)
	var slide_stop := CharacterMovement.step_horizontal(moving, Vector2.ZERO, 6.0, true, true, false, 0.1)
	_assert_near("slide friction", slide_stop.x, 6.0 - CharacterMovement.SLIDE_FRICTION * 0.1, 0.0001)
	var slide_move := CharacterMovement.step_horizontal(Vector2.ZERO, forward, 11.0, true, true, false, 0.1)
	_assert_near("slide acceleration", slide_move.length(), CharacterMovement.SLIDE_ACCELERATION * 0.1, 0.0001)

	var reached := Vector2.ZERO
	for i in range(30):
		reached = CharacterMovement.step_horizontal(reached, forward, 6.0, true, false, false, 1.0 / 60.0)
	_assert_near("walk speed is reached and not exceeded", reached.length(), 6.0, 0.0001)


func _test_bounce_math() -> void:
	var up := Vector3.UP
	var bounced := GRENADE_PHYSICS.bounce_velocity(Vector3(6.0, -10.0, 0.0), up)
	_assert_near("bounce keeps part of the normal speed", bounced.y, 10.0 * GRENADE_PHYSICS.NORMAL_RESTITUTION, 0.0001)
	_assert_near("bounce keeps part of the tangent speed", bounced.x, 6.0 * GRENADE_PHYSICS.TANGENT_RETENTION, 0.0001)
	_assert_true("bounce reverses the normal direction", bounced.y > 0.0)
	var slow := GRENADE_PHYSICS.bounce_velocity(Vector3(0.5, -1.0, 0.0), up)
	_assert_equal("slow bounce comes to rest", slow, Vector3.ZERO)
	var wall := GRENADE_PHYSICS.bounce_velocity(Vector3(-8.0, 0.0, 2.0), Vector3.RIGHT)
	_assert_true("wall bounce sends the grenade back", wall.x > 0.0)
	_assert_near("wall bounce keeps sliding along the wall", wall.z, 2.0 * GRENADE_PHYSICS.TANGENT_RETENTION, 0.0001)


func _test_free_flight_matches_across_frame_rates() -> void:
	var launch := Vector3(8.0, 6.0, -3.0)
	var coarse := _fly(Vector3.ZERO, launch, 1.0, 1.0 / 20.0)
	var fine := _fly(Vector3.ZERO, launch, 1.0, 1.0 / 144.0)
	_assert_true("free flight is nearly independent of the frame rate (%s vs %s)" % [str(coarse), str(fine)], coarse.distance_to(fine) < 0.15)
	_assert_true("free flight moves forward", fine.x > 7.0)
	var spike := GRENADE_PHYSICS.step(Vector3.ZERO, Vector3.ZERO, 5.0, null)
	_assert_true("a long frame cannot teleport the grenade (y %.2f)" % spike.position.y, spike.position.y > -5.0)


func _fly(position: Vector3, velocity: Vector3, seconds: float, frame: float) -> Vector3:
	var elapsed := 0.0
	while elapsed < seconds - 0.00001:
		var delta := minf(frame, seconds - elapsed)
		var stepped: Dictionary = GRENADE_PHYSICS.step(position, velocity, delta, null)
		position = stepped.position
		velocity = stepped.velocity
		elapsed += delta
	return position


func _make_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(floor_body)
	return floor_body


func _test_grenade_on_real_floor() -> void:
	var floor_body := _make_floor()
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var position := Vector3(0.0, 3.0, 0.0)
	var velocity := Vector3(4.0, 0.0, 0.0)
	var bounced := false
	var lowest := 100.0
	for i in range(60 * 4):
		var stepped: Dictionary = GRENADE_PHYSICS.step(position, velocity, 1.0 / 60.0, space)
		if stepped.velocity.y > 0.5 and velocity.y < 0.0:
			bounced = true
		position = stepped.position
		velocity = stepped.velocity
		lowest = minf(lowest, position.y)
	_assert_true("grenade bounces off the floor", bounced)
	_assert_true("grenade never sinks through the floor (lowest %.3f)" % lowest, lowest > -0.05)
	_assert_true("grenade ends near the floor (y %.3f)" % position.y, position.y < 0.4)
	_assert_true("grenade skids forward before it settles (x %.2f)" % position.x, position.x > 4.0)
	_assert_true("grenade eventually rests (speed %.2f)" % velocity.length(), velocity.length() < 3.0)

	# A fast throw must not tunnel through the floor even with a long frame.
	var fast := GRENADE_PHYSICS.step(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -50.0, 0.0), 0.2, space)
	_assert_true("fast grenade does not tunnel through the floor (y %.3f)" % fast.position.y, fast.position.y > -0.05)

	# The thrower's own body is ignored when it is excluded.
	var excluded := StaticBody3D.new()
	excluded.collision_layer = 2
	var excluded_shape := CollisionShape3D.new()
	var excluded_box := BoxShape3D.new()
	excluded_box.size = Vector3(2.0, 2.0, 2.0)
	excluded_shape.shape = excluded_box
	excluded.add_child(excluded_shape)
	excluded.position = Vector3(20.0, 2.0, 0.0)
	root.add_child(excluded)
	await physics_frame
	await physics_frame
	space = root.get_world_3d().direct_space_state
	var blocked := GRENADE_PHYSICS.step(Vector3(17.0, 2.0, 0.0), Vector3(40.0, 0.0, 0.0), 0.1, space)
	var passed := GRENADE_PHYSICS.step(Vector3(17.0, 2.0, 0.0), Vector3(40.0, 0.0, 0.0), 0.1, space, [excluded.get_rid()])
	var world_only := GRENADE_PHYSICS.step(Vector3(17.0, 2.0, 0.0), Vector3(40.0, 0.0, 0.0), 0.1, space, [], 1)
	_assert_true("a body on another layer stops the server grenade", blocked.position.x < 19.5)
	_assert_true("an excluded thrower does not stop the grenade", passed.position.x > 20.5)
	_assert_true("the client visual only collides with the world layer", world_only.position.x > 20.5)
	excluded.queue_free()
	floor_body.queue_free()
	await physics_frame


func _test_server_player_on_real_floor() -> void:
	var floor_body := _make_floor()
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
	player.position = Vector3(0.0, 4.0, 0.0)
	root.add_child(player)
	await physics_frame
	_assert_near("server player uses the shared floor snap length", player.floor_snap_length, CharacterMovement.FLOOR_SNAP_LENGTH, 0.0001)

	var landed := false
	var fastest_fall := 0.0
	for i in range(60 * 3):
		await physics_frame
		fastest_fall = minf(fastest_fall, player.velocity.y)
		if player.is_on_floor():
			landed = true
			break
	_assert_true("server player lands on the floor", landed)
	_assert_true("server player stands on the floor (y %.3f)" % player.global_position.y, absf(player.global_position.y) < 0.1)
	_assert_true("fall speed never exceeds the cap (%.2f)" % fastest_fall, fastest_fall >= -CharacterMovement.TERMINAL_FALL_SPEED - 0.001)

	# Walking reaches the walk speed on the ground.
	player.set("input_vector", Vector2(0.0, -1.0))
	for i in range(45):
		await physics_frame
	var ground_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_assert_near("server player reaches walk speed", ground_speed, 6.0, 0.3)

	# A jump leaves the floor and keeps most horizontal momentum when the keys are released.
	player.set("jump_requested", true)
	await physics_frame
	await physics_frame
	_assert_true("server player leaves the floor on jump", not player.is_on_floor() and player.velocity.y > 0.0)
	player.set("input_vector", Vector2.ZERO)
	var speed_before := Vector2(player.velocity.x, player.velocity.z).length()
	for i in range(6):
		await physics_frame
	var speed_after := Vector2(player.velocity.x, player.velocity.z).length()
	_assert_true("air momentum is kept after releasing the keys (%.2f -> %.2f)" % [speed_before, speed_after], speed_after > speed_before - 0.6 and speed_after > 4.0)

	var apex := player.global_position.y
	for i in range(60):
		await physics_frame
		apex = maxf(apex, player.global_position.y)
		if player.is_on_floor():
			break
	_assert_true("jump apex is a sensible height (%.2f)" % apex, apex > 0.8 and apex < 2.0)
	_assert_true("server player lands again", player.is_on_floor())

	player.queue_free()
	floor_body.queue_free()
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
