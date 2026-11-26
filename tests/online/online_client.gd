extends SceneTree
## One client of the online test. Run with `-- --role=A` (the shooter) or `-- --role=B` (the target).
## Connects to a real dedicated server over UDP with the real network script, quick-matches into the
## same room as the other client, and checks what the server and the other client really do:
## authentication, room, movement and reconciliation, server-side hit validation, fire-rate limit,
## kills, respawn, and cleanup when a player leaves. Prints ONLINE_RESULT <role> PASS|FAIL.

const NET := preload("res://tests/online/network_under_test.gd")
const STUB := preload("res://tests/online/stub_player.gd")
const ARENA := preload("res://scripts/arena_layout.gd")
const MAP := 4
const AETHER_DAMAGE := 34.0

var role := "A"
var net
var stub
var _yaw := 0.0
var _stub_placed := false
var _room_code := ""
var _local: Dictionary = {}
var _others: Dictionary = {} # peer id -> latest state
var _other_peer := -1
var _other_track: Array = [] # positions of the other player over time
var _health_trace: Array = [] # my own health as the server reports it
var _saw_dead := false
var _saw_respawn := false
var _fx: Array = [] # shooter peer id of every shot effect I received
var _kill_feed: Array = []
var _disconnected: Array = []
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("ONLINE_FAIL %s: %s" % [role, message])


func _note(message: String) -> void:
	print("ONLINE_NOTE %s: %s" % [role, message])


func _wait_until(condition: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _finish() -> void:
	if net != null and net.multiplayer.multiplayer_peer != null:
		net.multiplayer.multiplayer_peer.close()
	if _failures.is_empty():
		print("ONLINE_RESULT %s PASS checks=%d" % [role, _checks])
		quit(0)
	else:
		print("ONLINE_RESULT %s FAIL failures=%d" % [role, _failures.size()])
		quit(1)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "slide", "dash", "sprint"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	# Hard stop so a stuck test fails instead of hanging.
	get_root().get_tree().create_timer(75.0).timeout.connect(func():
		_check(false, "the whole test finished inside 75 seconds")
		_finish())

	net = NET.new()
	net.name = "OxenWarNetwork"
	root.add_child(net)
	ARENA.build_collision(root, MAP) # the world my predicted player walks in
	stub = STUB.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	stub.add_child(collider)
	stub.collision_layer = 2
	stub.collision_mask = 1
	root.add_child(stub)
	stub.global_position = Vector3(0.0, 1.5, 6.0)
	net.set_local_player(stub, "Test" + role, Color.CYAN)

	net.local_state_received.connect(_on_local_state)
	net.player_state_received.connect(_on_other_state)
	net.room_state_changed.connect(func(state: Dictionary):
		if not str(state.get("code", "")).is_empty():
			_room_code = str(state.code))
	net.blaster_fx_received.connect(func(shooter: int, _origin: Vector3, _endpoint: Vector3, _weapon: String): _fx.append(shooter))
	net.kill_feed_received.connect(func(killer: String, victim: String, weapon: String): _kill_feed.append([killer, victim, weapon]))
	net.player_disconnected.connect(func(peer: int): _disconnected.append(peer))
	process_frame.connect(_tick)

	net._last_host = "127.0.0.1"
	net._game_ticket = "TESTTICKET-%s-%s" % [role, "x".repeat(40)]
	net._connect_now()

	_check(await _wait_until(func(): return net.is_authenticated, 10.0), "authenticated against the server with a ticket")
	if not net.is_authenticated:
		_finish()
		return
	net.request_quick_match("ffa", MAP)
	_check(await _wait_until(func(): return not _room_code.is_empty(), 6.0), "joined a room")
	_check(await _wait_until(func(): return not _local.is_empty(), 6.0), "received authoritative snapshots")
	_check(await _wait_until(func(): return _other_peer != -1, 25.0), "the other player appeared in my snapshots")
	_note("room %s, other peer %d, spawn %s" % [_room_code, _other_peer, str(_local.get("position"))])
	if _other_peer == -1 or _local.is_empty():
		_finish()
		return
	if role == "A":
		await _run_shooter()
	else:
		await _run_target()
	_finish()


func _tick() -> void:
	if stub == null:
		return
	stub.input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	stub.look_yaw = _yaw
	stub.rotation.y = _yaw


func _on_local_state(state: Dictionary) -> void:
	_local = state
	if not _stub_placed and state.get("position") is Vector3:
		stub.global_position = state.position
		stub.velocity = Vector3.ZERO
		_stub_placed = true
	net.reconcile_local_player(state)
	var health := float(state.get("health", 100.0))
	if _health_trace.is_empty() or not is_equal_approx(float(_health_trace[-1]), health):
		_health_trace.append(health)
	if bool(state.get("dead", false)):
		_saw_dead = true
	elif _saw_dead:
		_saw_respawn = true


func _on_other_state(peer: int, state: Dictionary) -> void:
	_others[peer] = state
	_other_peer = peer
	if state.get("position") is Vector3:
		_other_track.append(state.position)


## Yaw that makes the server's view_forward point from `from` toward `to` (horizontally).
func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var flat := to - from
	return atan2(-flat.x, -flat.z)


func _other_position() -> Vector3:
	return (_others[_other_peer].get("position", Vector3.ZERO)) as Vector3


## Turns to face the other player, waits for the server to learn the yaw, returns the aim direction.
func _face_other() -> Vector3:
	var mine: Vector3 = _local.position
	_yaw = _yaw_toward(mine, _other_position())
	await _wait(0.25)
	mine = _local.position
	return ((_other_position() + Vector3.UP * 0.9) - (mine + Vector3.UP * 1.45)).normalized()


func _run_shooter() -> void:
	# 1. Movement: walk left for a second. The server decides how far that is, and my predicted copy
	# of the same movement stays in agreement with it (reconciliation).
	var start: Vector3 = _local.position
	Input.action_press("move_left")
	await _wait(1.0)
	Input.action_release("move_left")
	await _wait(0.8)
	var travelled := (_local.position as Vector3).distance_to(start)
	_check(travelled > 3.0 and travelled < 8.5, "walking for a second moved me %.2f m on the server (3 to 8.5 expected)" % travelled)
	_check((_local.position as Vector3).x < start.x - 2.5, "and in the direction I pressed")
	var disagreement := (stub.global_position as Vector3).distance_to(_local.position as Vector3)
	_check(disagreement < 0.6, "my predicted position stays within 0.6 m of the server's (%.2f m)" % disagreement)

	# 2. Fire rate: ten shots in one frame must not become ten shots.
	var aim := await _face_other()
	var before := _fx.size()
	for shot in range(10):
		net.request_blaster_fire("aether", aim, false)
	await _wait(0.7)
	var accepted := _fx.size() - before
	_check(accepted >= 1 and accepted <= 2, "ten shots in one frame became %d (server cooldown, 1 to 2 expected)" % accepted)

	# 3. The server refuses shots it cannot believe.
	before = _fx.size()
	net.request_blaster_fire("aether", -aim, false)
	await _wait(0.5)
	_check(_fx.size() == before, "a shot aimed behind the player's own facing is ignored")
	before = _fx.size()
	net.request_blaster_fire("minicore", aim, false)
	await _wait(0.5)
	_check(_fx.size() == before, "a shot with a weapon that is not equipped is ignored")
	before = _fx.size()
	net.request_blaster_fire("aether", Vector3(aim.x * 0.1, 1.0, aim.z * 0.1).normalized(), false)
	await _wait(0.5)
	_check(_fx.size() == before, "a shot straight up is ignored")

	# 4. Kill the other player with real shots; the server validates every hit.
	var shots := 0
	while shots < 16 and _kill_feed.is_empty():
		aim = await _face_other()
		net.request_blaster_fire("aether", aim, false)
		shots += 1
		await _wait(0.34)
	_check(not _kill_feed.is_empty(), "the other player was killed within 16 shots (%d fired)" % shots)
	if not _kill_feed.is_empty():
		_check(str(_kill_feed[0][0]) == "TestA" and str(_kill_feed[0][1]) == "TestB", "the kill feed names the killer and the victim (%s)" % str(_kill_feed[0]))
	await _wait(0.5)
	_check(int(_local.get("kills", 0)) == 1, "the server counts exactly one kill for me (%d)" % int(_local.get("kills", 0)))
	_check(bool(_others[_other_peer].get("dead", false)), "the other player is dead on the server")
	_check(int(_others[_other_peer].get("deaths", 0)) == 1, "and has exactly one death")

	# 5. Shooting a dead player does not kill them again.
	for extra in range(2):
		net.request_blaster_fire("aether", aim, false)
		await _wait(0.34)
	await _wait(0.3)
	_check(int(_local.get("kills", 0)) == 1, "shots at a dead player do not add kills")

	# 6. The other player respawns with full health.
	await _wait_until(func(): return not bool(_others[_other_peer].get("dead", true)), 8.0)
	_check(not bool(_others[_other_peer].get("dead", true)) and float(_others[_other_peer].get("health", 0.0)) >= 100.0, "the victim respawned with full health")
	_note("shots fired %d, own health trace %s" % [shots, str(_health_trace)])


func _run_target() -> void:
	# Stand still until the shooter leaves, recording what the server says about me and about them.
	_check(await _wait_until(func(): return _disconnected.has(_other_peer), 60.0), "the shooter's disconnect was reported to me")
	var start: Vector3 = _other_track[0] if _other_track.size() > 0 else Vector3.ZERO
	var farthest := 0.0
	for position in _other_track:
		farthest = maxf(farthest, (position as Vector3).distance_to(start))
	_check(farthest > 3.0, "I saw the other player walk %.2f m through the snapshots" % farthest)
	var steady := true
	for index in range(1, _other_track.size()):
		if (_other_track[index] as Vector3).distance_to(_other_track[index - 1] as Vector3) > 1.5:
			steady = false
	_check(steady, "their snapshots never jumped more than 1.5 m between two updates")
	_check(not _health_trace.is_empty() and is_equal_approx(float(_health_trace[0]), 100.0), "I started at 100 health")
	var damage_steps_ok := true
	for index in range(1, _health_trace.size()):
		var drop := float(_health_trace[index - 1]) - float(_health_trace[index])
		if drop > 0.0 and not (is_equal_approx(drop, AETHER_DAMAGE) or float(_health_trace[index]) <= 0.0):
			damage_steps_ok = false
	_check(damage_steps_ok, "every damage step was exactly one Aether hit (%s)" % str(_health_trace))
	_check(_saw_dead, "the server reported me dead")
	_check(_saw_respawn, "and later alive again")
	_check(_fx.size() >= 3, "I received the shot effects of the fight (%d)" % _fx.size())
	_check(not _kill_feed.is_empty() and str(_kill_feed[0][1]) == "TestB", "I received the kill feed with me as the victim")
	_check(_disconnected.has(_other_peer), "peer cleanup reached me")
