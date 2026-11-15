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
	var first: float = tracker.spread_deg(fast, 0.0, true, false, false)
	for shot in range(12):
		tracker.fire(fast, false)
	var sustained: float = tracker.spread_deg(fast, 0.0, true, false, false)
	_check(sustained > first, "sustained fire blooms the spread")
	_check(sustained <= WEAPON_FEEL.MAX_SPREAD_DEG, "spread is capped")
	for frame in range(60):
		tracker.step(1.0 / 60.0)
	_check(tracker.spread_deg(fast, 0.0, true, false, false) <= first + 0.001, "bloom recovers when you stop firing")

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

	if failures.is_empty():
		print("PASS: weapon spread, bloom, recoil kick and recovery")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
