extends SceneTree
## The dedicated server rolls weapon spread itself (the client only reports where it aims), keeps
## per-shooter bloom, and charges movement penalties from the shooter's server-side state.

const NETWORK_SCRIPT := preload("res://scripts/oxenwar_network.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var network := Node.new()
	network.set_script(NETWORK_SCRIPT)
	network.name = "OxenWarNet"
	root.add_child(network)
	var rooms: Dictionary = network.get("_rooms")
	rooms["JUNGLE"] = network.call("_new_room", "JUNGLE", "u1", true, "ffa", 5)
	# In a bare SceneTree the remote sender id is 0, so the shooter is peer 0 here. Only the shooter
	# is in the room, so no per-client effect RPCs are sent.
	var shooter = network.call("_create_server_player", 0, {}, {})
	network.call("_assign_user_to_room", "u1", 0, "JUNGLE")
	# Authentication normally records which user a peer is; do the same here.
	var peer_users: Dictionary = network.get("_peer_users")
	peer_users[0] = "u1"
	for index in range(60):
		await physics_frame
	var trackers: Dictionary = network.get("_shot_trackers")
	var last_shot: Dictionary = network.get("_last_blaster_ms")
	var forward := Vector3(0.0, 0.0, -1.0) # the shooter's facing at look_yaw 0

	_check(trackers.is_empty(), "no server tracker exists before the first shot")
	network.call("_server_blaster_fire", "aether", forward, 0, false)
	_check(shooter.shots_fired == 1, "the first shot is accepted (shots_fired %d)" % shooter.shots_fired)
	_check(trackers.has(0), "the server creates a tracker for the shooter")
	var first_bloom: float = trackers[0].bloom_deg
	_check(first_bloom > 0.0, "the shot registered bloom on the server")

	# Bypass the cooldown only, keeping the recent timestamp so the bloom has barely recovered.
	last_shot[0] = Time.get_ticks_msec() - 245
	network.call("_server_blaster_fire", "aether", forward, 0, false)
	_check(shooter.shots_fired == 2, "a shot after the cooldown is accepted")
	_check(trackers[0].bloom_deg > first_bloom * 0.9, "bloom keeps building on the server while the client holds the trigger")

	# A shot that arrives before the cooldown is dropped and does not touch bloom.
	var bloom_before: float = trackers[0].bloom_deg
	network.call("_server_blaster_fire", "aether", forward, 0, false)
	_check(shooter.shots_fired == 2, "a shot inside the cooldown is rejected")
	_check(is_equal_approx(trackers[0].bloom_deg, bloom_before), "a rejected shot adds no bloom")

	# A shot aimed behind the shooter is rejected before any spread is rolled.
	last_shot[0] = Time.get_ticks_msec() - 1000
	network.call("_server_blaster_fire", "aether", Vector3(0.0, 0.0, 1.0), 0, false)
	_check(shooter.shots_fired == 2, "aiming behind the shooter is rejected")

	# The server reads the shooter's own velocity: a sprinting shooter gets wider spread than a still one.
	var WEAPON_FEEL = load("res://scripts/weapon_feel.gd")
	var profile: Dictionary = WEAPON_FEEL.profile(0.24, 65.0)
	var tracker = WEAPON_FEEL.Tracker.new()
	var still_spread: float = tracker.spread_deg(profile, WEAPON_FEEL.movement_multiplier(0.0, true, false, false))
	var sprint_spread: float = tracker.spread_deg(profile, WEAPON_FEEL.movement_multiplier(9.0, true, false, false))
	_check(sprint_spread > still_spread, "sprinting spreads wider than standing (model sanity)")

	# Cleanup on disconnect drops the tracker.
	network.call("_on_peer_disconnected", 0)
	_check(not trackers.has(0), "the tracker is removed when the peer leaves")

	if failures.is_empty():
		print("PASS: server-authoritative spread, bloom and cooldown on the real fire path")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
