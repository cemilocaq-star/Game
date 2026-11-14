extends SceneTree
const EVENTS := preload("res://scripts/meme_events.gd")
const NETWORK := preload("res://scripts/oxenwar_network.gd")
const FX := preload("res://scripts/sunshine_fx.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var sunshine := 0
	for i in range(4000):
		if EVENTS.choose(rng, "", "ffa", 3) == EVENTS.SUNSHINE:
			sunshine += 1
		var competitive := EVENTS.choose(rng, "PINK_SKY", "demolition", 3)
		if competitive in ["PINK_SKY", "SUNSHINE", "REVERSE_PANIC"]:
			push_error("Ineligible event selected")
			quit(1)
			return
	var room := {"mode": "ffa", "event_id": "", "event_left": 0.0, "event_clock": 0.1, "round_left": 100.0}
	var alive: Array[int] = [2, 3]
	var ok := sunshine > 0 and sunshine < 65
	ok = EVENTS.step(room, 0.1, rng, alive) and ok
	ok = room.event_serial == 1 and room.event_warning == 3.0 and ok
	ok = EVENTS.step(room, 20.0, rng, alive) and room.event_id == "" and room.event_clock == 20.0 and ok
	ok = not EVENTS.step(room, 19.0, rng, alive) and ok
	ok = EVENTS.track(Vector3.ZERO, Vector3(100, 0, 0), 0.1).is_equal_approx(Vector3(2.4, 0, 0)) and ok
	var fx := FX.new()
	root.add_child(fx)
	fx.sync_state({"actor": Vector3(0, 14, 0), "warning": 3.0, "impact": false})
	ok = fx.get("_caption").text == "3" and ok
	fx.sync_state({"actor": Vector3(1, 1, 1), "warning": 0.0, "impact": true})
	ok = fx.get("_caption").text == "SLAM!" and ok
	fx.free()
	ok = await _test_room_chase() and ok
	if ok:
		print("PASS: event weights, eligibility, cooldown, speed cap and Sunshine snapshot presentation")
	else:
		push_error("Event policy or presentation regression")
	quit(0 if ok else 1)


func _test_room_chase() -> bool:
	var network := NETWORK.new()
	root.add_child(network)
	var rooms: Dictionary = network.get("_rooms")
	var room: Dictionary = network.call("_new_room", "SUN", "a", true, "ffa", 4)
	rooms["SUN"] = room
	var target = network.call("_create_server_player", 11, {}, {})
	network.call("_assign_user_to_room", "a", 11, "SUN")
	target.set_physics_process(false)
	target.global_position = Vector3(0, 6, 0)
	await physics_frame
	room.event_id = EVENTS.SUNSHINE
	room.event_left = 15.0
	room.event_serial = 1
	room.event_target = 11
	room.event_warning = 3.0
	room.event_actor_ready = false
	room.event_impact = false
	network.call("_server_step_meme_event", "SUN", room, 0.0)
	for tick in range(180):
		network.call("_server_step_meme_event", "SUN", room, 1.0 / 60.0)
	var ok: bool = not target.is_dead and target.deaths == 0 and room.event_actor.is_equal_approx(Vector3(0, 14, 0))
	target.global_position.x = 1.2
	for tick in range(60):
		network.call("_server_step_meme_event", "SUN", room, 1.0 / 60.0)
	ok = ok and target.is_dead and target.deaths == 1 and room.event_impact
	var visible: Dictionary = network.call("_meme_snapshot", room)
	ok = ok and visible.impact and visible.target == 11
	target.respawn_at(Vector3(0, 6, 0))
	network.call("_server_step_meme_event", "SUN", room, 1.0 / 60.0)
	ok = ok and not target.is_dead and target.deaths == 1
	room.event_impact = false
	room.event_target = 999
	network.call("_server_step_meme_event", "SUN", room, 1.0 / 60.0)
	ok = ok and room.event_id.is_empty() and network.call("_meme_snapshot", room).is_empty()
	network.free()
	return ok
