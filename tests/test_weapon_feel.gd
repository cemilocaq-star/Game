extends SceneTree
## Weapon feel: spread by movement state, bloom while firing, recoil kick and recovery.

const WEAPON_FEEL := preload("res://scripts/weapon_feel.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var slow: Dictionary = WEAPON_FEEL.profile(0.68, 58.0) # hand cannon
	var fast: Dictionary = WEAPON_FEEL.profile(0.075, 48.0) # rotary arc
	var sniper: Dictionary = WEAPON_FEEL.profile(1.25, 100.0) # longshot
	_check(float(slow.kick_pitch_deg) > float(fast.kick_pitch_deg), "heavy slow weapons kick harder per shot")
	_check(float(fast.base_spread_deg) > float(slow.base_spread_deg), "rapid-fire weapons are less accurate")
	_check(float(sniper.base_spread_deg) < float(slow.base_spread_deg), "long-range rifles are tightest while standing")

	_check(WEAPON_FEEL.movement_multiplier(0.0, true, false, false) == 1.0, "standing still is the baseline")
	_check(WEAPON_FEEL.movement_multiplier(6.0, true, false, false) > 1.0, "walking costs accuracy")
	_check(WEAPON_FEEL.movement_multiplier(9.0, true, false, false) > WEAPON_FEEL.movement_multiplier(6.0, true, false, false), "sprinting costs more")
	_check(WEAPON_FEEL.movement_multiplier(0.0, false, false, false) > WEAPON_FEEL.movement_multiplier(9.0, true, false, false), "being airborne costs the most")
	_check(WEAPON_FEEL.movement_multiplier(0.0, true, false, true) < 1.0, "aiming tightens the spread")

	var tracker = WEAPON_FEEL.Tracker.new()
	var first: float = tracker.spread_deg(fast, 1.0)
	for shot in range(12):
		tracker.fire(fast, false)
	var sustained: float = tracker.spread_deg(fast, 1.0)
	_check(sustained > first, "sustained fire blooms the spread")
	_check(sustained <= WEAPON_FEEL.MAX_SPREAD_DEG, "spread is capped")
	for frame in range(60):
		tracker.step(1.0 / 60.0)
	_check(tracker.spread_deg(fast, 1.0) <= first + 0.001, "bloom recovers when you stop firing")

	# Recoil: kick goes up, then part of it is pulled back down after a short pause.
	tracker.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kick: Dictionary = tracker.fire(slow, false, 1.0, rng)
	_check(float(kick.pitch) > 0.0, "the camera kicks up")
	_check(tracker.step(0.05) == 0.0, "no recovery right after a shot")
	var recovered := 0.0
	for frame in range(120):
		recovered += tracker.step(1.0 / 60.0)
	_check(recovered > 0.0 and recovered <= float(kick.pitch), "part of the kick is returned afterwards")
	var scaled: Dictionary = tracker.fire(slow, false, 0.0, rng)
	_check(float(scaled.pitch) == 0.0 and float(scaled.yaw) == 0.0, "recoil scale 0 (accessibility) removes the camera kick")
	var aimed: Dictionary = tracker.fire(slow, true, 1.0, rng)
	_check(float(aimed.pitch) < float(kick.pitch), "aiming reduces the kick")

	# Spread stays inside its cone and is deterministic with a seeded generator.
	var forward := Vector3(0, 0, -1)
	var widest := 0.0
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 99
	for index in range(400):
		var shot: Vector3 = WEAPON_FEEL.apply_spread(forward, 2.0, seeded)
		_check(is_equal_approx(shot.length(), 1.0), "a spread direction stays a unit vector")
		widest = maxf(widest, rad_to_deg(forward.angle_to(shot)))
	_check(widest <= 2.0001, "spread never leaves its cone (widest %f deg)" % widest)
	_check(widest > 0.5, "spread actually varies")
	_check(WEAPON_FEEL.apply_spread(forward, 0.0, seeded) == forward, "zero spread is exact")
	_check(WEAPON_FEEL.apply_spread(Vector3.UP, 1.5, seeded).angle_to(Vector3.UP) <= deg_to_rad(1.5) + 0.0001, "straight up works too")

	# Server-authoritative shot: spread comes from the server's tracker and movement, never the client.
	var server_tracker = WEAPON_FEEL.Tracker.new()
	var server_rng := RandomNumberGenerator.new()
	server_rng.seed = 7
	var standing: Dictionary = WEAPON_FEEL.authoritative_shot(forward, server_tracker, fast, 0.0, true, false, false, server_rng)
	_check(is_equal_approx(float(standing.spread_deg), float(fast.base_spread_deg)), "first standing shot uses the base spread only")
	_check(forward.angle_to(standing.direction) <= deg_to_rad(float(standing.spread_deg)) + 0.0001, "server shot stays inside the server's cone")
	_check(server_tracker.bloom_deg > 0.0, "an authoritative shot registers bloom")
	var after_one: float = server_tracker.bloom_deg
	var second: Dictionary = WEAPON_FEEL.authoritative_shot(forward, server_tracker, fast, 0.0, true, false, false, server_rng)
	_check(float(second.spread_deg) > float(standing.spread_deg), "sustained fire widens the server's spread")
	_check(server_tracker.bloom_deg > after_one, "bloom keeps growing while firing")
	var running_tracker = WEAPON_FEEL.Tracker.new()
	var running: Dictionary = WEAPON_FEEL.authoritative_shot(forward, running_tracker, fast, 9.0, true, false, false, server_rng)
	_check(float(running.spread_deg) > float(standing.spread_deg), "the server charges the sprint penalty from its own velocity")
	var airborne_tracker = WEAPON_FEEL.Tracker.new()
	var airborne: Dictionary = WEAPON_FEEL.authoritative_shot(forward, airborne_tracker, fast, 0.0, false, false, false, server_rng)
	_check(float(airborne.spread_deg) > float(running.spread_deg), "the server charges the airborne penalty")
	var aimed_tracker = WEAPON_FEEL.Tracker.new()
	var aimed_shot: Dictionary = WEAPON_FEEL.authoritative_shot(forward, aimed_tracker, fast, 0.0, true, false, true, server_rng)
	_check(float(aimed_shot.spread_deg) < float(standing.spread_deg), "aiming tightens the server's spread")
	# Bloom recovers with elapsed time, exactly as the client's tracker does.
	server_tracker.step(2.0)
	_check(is_zero_approx(server_tracker.bloom_deg), "bloom recovers after a pause")
	# Same seed, same inputs, same shot: the server model is reproducible for tests.
	var tracker_a = WEAPON_FEEL.Tracker.new()
	var tracker_b = WEAPON_FEEL.Tracker.new()
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 5
	rng_b.seed = 5
	var shot_a: Dictionary = WEAPON_FEEL.authoritative_shot(forward, tracker_a, slow, 6.0, true, false, false, rng_a)
	var shot_b: Dictionary = WEAPON_FEEL.authoritative_shot(forward, tracker_b, slow, 6.0, true, false, false, rng_b)
	_check(shot_a.direction == shot_b.direction, "authoritative shots are reproducible with a seed")

	if failures.is_empty():
		print("PASS: weapon spread, bloom, recoil kick and recovery, server-authoritative shot")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
