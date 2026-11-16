extends SceneTree
## First-person weapon presentation: sway, bob, sprint/slide poses, ADS blend, recoil springs,
## reload and weapon-raise poses, frame-rate independence and numerical stability.

const ANIM := preload("res://scripts/weapon_viewmodel_anim.gd")
const REST := Vector3(0.27, -0.24, -0.48)
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	_test_sway()
	_test_bob_and_poses()
	_test_ads()
	_test_recoil()
	_test_reload()
	_test_switch_and_land()
	_test_pivot()
	_test_stability()
	if failures.is_empty():
		print("PASS: weapon sway, bob, ADS, recoil, reload, switch and stability")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _simulate(anim, seconds: float, dt: float, input: Dictionary) -> Dictionary:
	var pose := {"position": Vector3.ZERO, "rotation": Vector3.ZERO}
	var steps := int(round(seconds / dt))
	for index in range(steps):
		pose = anim.step(dt, input)
	return pose


func _test_sway() -> void:
	var anim = ANIM.new()
	# Turning right = negative yaw rate in this game; the weapon must trail to the left (+yaw).
	var pose := _simulate(anim, 0.4, 1.0 / 60.0, {"look_rate": Vector2(-3.0, 0.0)})
	_check(pose.rotation.y > 0.01, "turning right makes the weapon trail left (got %f)" % pose.rotation.y)
	_check(pose.position.x < -0.002, "turning right shifts the weapon left")
	var looking_up := ANIM.new()
	var up_pose := _simulate(looking_up, 0.4, 1.0 / 60.0, {"look_rate": Vector2(0.0, 2.0)})
	_check(up_pose.rotation.x < -0.01, "looking up makes the weapon trail downward")
	_check(absf(pose.rotation.y) <= ANIM.SWAY_MAX_ROT + 0.0001, "sway rotation is capped")
	var huge := ANIM.new()
	var capped := _simulate(huge, 0.5, 1.0 / 60.0, {"look_rate": Vector2(-80.0, 80.0)})
	_check(absf(capped.rotation.y) <= ANIM.SWAY_MAX_ROT + 0.0001 and absf(capped.rotation.x) <= ANIM.SWAY_MAX_ROT + 0.0001, "a flick cannot over-rotate the weapon")
	_check(absf(capped.position.x) <= ANIM.SWAY_MAX_POS + 0.0001, "sway position is capped")
	var settled := _simulate(anim, 0.7, 1.0 / 60.0, {})
	_check(absf(settled.rotation.y) < 0.002, "sway settles back after the camera stops (got %f)" % settled.rotation.y)
	# ADS damps sway.
	var hip := ANIM.new()
	var aimed := ANIM.new()
	var hip_pose := _simulate(hip, 0.5, 1.0 / 60.0, {"look_rate": Vector2(-2.0, 0.0)})
	var aim_pose := _simulate(aimed, 0.5, 1.0 / 60.0, {"look_rate": Vector2(-2.0, 0.0), "aiming": true})
	_check(absf(aim_pose.rotation.y) < absf(hip_pose.rotation.y) * 0.6, "aiming reduces sway")
	# Frame-rate independence: the same second of turning lands in nearly the same place.
	var slow_clock = ANIM.new()
	var fast_clock = ANIM.new()
	var at_30 := _simulate(slow_clock, 1.0, 1.0 / 30.0, {"look_rate": Vector2(-1.5, 0.5)})
	var at_144 := _simulate(fast_clock, 1.0, 1.0 / 144.0, {"look_rate": Vector2(-1.5, 0.5)})
	_check(absf(at_30.rotation.y - at_144.rotation.y) < 0.006, "sway is frame-rate independent (%f vs %f)" % [at_30.rotation.y, at_144.rotation.y])


## Total vertical travel of the weapon over two seconds: bob is fast motion, breathing is slow.
func _bob_extent(anim, input: Dictionary) -> float:
	_simulate(anim, 0.6, 1.0 / 60.0, input)
	var travel := 0.0
	var previous := 0.0
	for index in range(120):
		var pose: Dictionary = anim.step(1.0 / 60.0, input)
		if index > 0:
			travel += absf(pose.position.y - previous)
		previous = pose.position.y
	return travel


func _test_bob_and_poses() -> void:
	var idle := _bob_extent(ANIM.new(), {})
	var walk := _bob_extent(ANIM.new(), {"speed": 6.0, "on_floor": true})
	var sprint := _bob_extent(ANIM.new(), {"speed": 9.0, "on_floor": true, "sprinting": true})
	var aim_walk := _bob_extent(ANIM.new(), {"speed": 6.0, "on_floor": true, "aiming": true})
	var air := _bob_extent(ANIM.new(), {"speed": 6.0, "on_floor": false})
	_check(walk > idle * 1.5, "walking moves the weapon more than standing (%f vs %f)" % [walk, idle])
	_check(sprint > walk * 1.2, "sprinting moves the weapon more than walking (%f vs %f)" % [sprint, walk])
	_check(aim_walk < walk * 0.6, "aiming steadies the weapon while walking")
	_check(air < walk * 0.5, "no footstep bob while airborne")

	var sprinter = ANIM.new()
	var sprint_pose := _simulate(sprinter, 0.4, 1.0 / 60.0, {"speed": 9.0, "on_floor": true, "sprinting": true})
	_check(sprinter.sprint_blend > 0.99, "sprint pose fully blends in within 0.4 s")
	_check(sprint_pose.rotation.y > deg_to_rad(12.0), "sprinting angles the weapon across the body")
	_check(sprint_pose.position.y < -0.04, "sprinting lowers the weapon")
	var stopped := _simulate(sprinter, 0.4, 1.0 / 60.0, {})
	_check(sprinter.sprint_blend < 0.01 and absf(stopped.rotation.y) < 0.01, "the sprint pose releases when you stop")
	var no_sprint_standing = ANIM.new()
	_simulate(no_sprint_standing, 0.5, 1.0 / 60.0, {"speed": 0.0, "sprinting": true, "on_floor": true})
	_check(no_sprint_standing.sprint_blend == 0.0, "holding sprint while standing still does not lower the weapon")
	var sprint_aim = ANIM.new()
	_simulate(sprint_aim, 0.5, 1.0 / 60.0, {"speed": 9.0, "sprinting": true, "on_floor": true, "aiming": true})
	_check(sprint_aim.sprint_blend == 0.0 and sprint_aim.ads > 0.99, "aiming overrides the sprint pose")
	var slider = ANIM.new()
	var slide_pose := _simulate(slider, 0.4, 1.0 / 60.0, {"speed": 12.0, "sliding": true, "on_floor": true})
	_check(slide_pose.rotation.z < deg_to_rad(-8.0), "sliding leans the weapon")
	var lean_left = ANIM.new()
	var lean_right = ANIM.new()
	var left_pose := _simulate(lean_left, 0.5, 1.0 / 60.0, {"move_input": Vector2(-1.0, 0.0)})
	var right_pose := _simulate(lean_right, 0.5, 1.0 / 60.0, {"move_input": Vector2(1.0, 0.0)})
	_check(left_pose.rotation.z > right_pose.rotation.z + 0.02, "strafing leans the weapon opposite ways")


func _test_ads() -> void:
	var anim = ANIM.new()
	var previous := 0.0
	var monotonic := true
	var frames_to_full := -1
	for frame in range(60):
		anim.step(1.0 / 60.0, {"aiming": true})
		if anim.ads < previous - 0.000001:
			monotonic = false
		previous = anim.ads
		if frames_to_full < 0 and anim.ads >= 1.0:
			frames_to_full = frame + 1
	_check(monotonic, "ADS only increases while aiming")
	_check(frames_to_full > 0 and float(frames_to_full) / 60.0 <= ANIM.ADS_TIME + 0.02, "ADS completes within %.2f s (took %d frames)" % [ANIM.ADS_TIME, frames_to_full])
	_check(anim.ads <= 1.0 and anim.ads >= 0.0, "ADS stays inside 0..1 (no overshoot)")
	var settled := _simulate(anim, 0.3, 1.0 / 60.0, {"aiming": true})
	_check(settled.position.distance_to(ANIM.ADS_OFFSET) < 0.012, "aimed weapon sits at the centred ADS offset")
	_check(absf(anim.fov_blend() - 1.0) < 0.001, "FOV blend reaches 1")
	var half = ANIM.new()
	_simulate(half, ANIM.ADS_TIME * 0.5, 1.0 / 120.0, {"aiming": true})
	_check(half.ads_eased() > 0.4 and half.ads_eased() < 0.6, "ADS easing is symmetric around the midpoint (%f)" % half.ads_eased())
	_simulate(anim, 0.3, 1.0 / 60.0, {})
	_check(anim.ads == 0.0, "releasing aim returns to the hip")


func _peak(anim, axis_z: bool, seconds: float, dt: float) -> float:
	var peak := 0.0
	for index in range(int(seconds / dt)):
		var pose: Dictionary = anim.step(dt, {})
		peak = maxf(peak, pose.position.z if axis_z else pose.rotation.x)
	return peak


func _test_recoil() -> void:
	var anim = ANIM.new()
	anim.fire(1.0, 1.0)
	var back := _peak(anim, true, 0.5, 1.0 / 240.0)
	_check(back > 0.02 and back < 0.06, "a shot kicks the weapon back 2-6 cm (got %f)" % back)
	var settled := _simulate(anim, 0.8, 1.0 / 60.0, {})
	_check(absf(settled.position.z) < 0.004 and absf(settled.rotation.x) < deg_to_rad(0.5), "recoil recovers within about a second")
	var rise = ANIM.new()
	rise.fire(1.0, 1.0)
	_check(_peak(rise, false, 0.5, 1.0 / 240.0) > deg_to_rad(1.0), "the muzzle rises")
	var hip = ANIM.new()
	var aimed = ANIM.new()
	_simulate(aimed, 0.4, 1.0 / 60.0, {"aiming": true})
	hip.fire(1.0, 1.0)
	aimed.fire(1.0, 1.0)
	var hip_peak := _peak(hip, true, 0.4, 1.0 / 240.0)
	var aim_peak := 0.0
	for index in range(96):
		var pose: Dictionary = aimed.step(1.0 / 240.0, {"aiming": true})
		aim_peak = maxf(aim_peak, pose.position.z - ANIM.ADS_OFFSET.z)
	_check(aim_peak < hip_peak * 0.75, "aimed recoil is visually calmer (%f vs %f)" % [aim_peak, hip_peak])
	var heavy = ANIM.new()
	var light = ANIM.new()
	heavy.fire(1.8, 1.0)
	light.fire(0.5, 1.0)
	_check(_peak(heavy, true, 0.4, 1.0 / 240.0) > _peak(light, true, 0.4, 1.0 / 240.0) * 2.0, "heavier weapons kick harder")
	var rapid = ANIM.new()
	var biggest := 0.0
	for shot in range(40):
		rapid.fire(0.6, 1.0 if shot % 2 == 0 else -1.0)
		for sub in range(int(0.075 / (1.0 / 240.0))):
			var pose: Dictionary = rapid.step(1.0 / 240.0, {})
			biggest = maxf(biggest, absf(pose.position.z))
	_check(biggest < 0.14, "sustained fire stays bounded (peak %f)" % biggest)
	var left = ANIM.new()
	var right = ANIM.new()
	left.fire(1.0, -1.0)
	right.fire(1.0, 1.0)
	var roll_left := 0.0
	var roll_right := 0.0
	for index in range(60):
		roll_left += left.step(1.0 / 240.0, {}).rotation.z
		roll_right += right.step(1.0 / 240.0, {}).rotation.z
	_check(roll_left * roll_right < 0.0, "roll direction follows the sign passed in")


func _test_reload() -> void:
	var start: Dictionary = ANIM.reload_pose(0.0)
	var finish: Dictionary = ANIM.reload_pose(1.0)
	_check(start.position.length() < 0.0001 and start.rotation.length() < 0.0001, "reload pose starts at zero offset")
	_check(finish.position.length() < 0.0001 and finish.rotation.length() < 0.0001, "reload pose ends at zero offset")
	var mid: Dictionary = ANIM.reload_pose(0.5)
	_check(mid.position.y < -0.08 and mid.rotation.z < deg_to_rad(-25.0), "mid reload lowers and rolls the weapon")
	var last := ANIM.reload_pose(0.0)
	var worst_position := 0.0
	var worst_rotation := 0.0
	for frame in range(1, 101):
		var pose: Dictionary = ANIM.reload_pose(float(frame) / 100.0)
		worst_position = maxf(worst_position, pose.position.distance_to(last.position))
		worst_rotation = maxf(worst_rotation, pose.rotation.distance_to(last.rotation))
		last = pose
	_check(worst_position < 0.03, "reload pose has no position pops (largest step %f per 1%%)" % worst_position)
	_check(worst_rotation < deg_to_rad(12.0), "reload pose has no rotation pops")

	var anim = ANIM.new()
	_check(anim.start_reload(ANIM.reload_duration(0.24)), "reload starts")
	_check(not anim.start_reload(1.0), "a second reload cannot start while one runs")
	_check(anim.is_reloading(), "reload state is exposed")
	_simulate(anim, ANIM.reload_duration(0.24) + 0.2, 1.0 / 60.0, {})
	_check(not anim.is_reloading(), "reload finishes by itself")
	var rest := _simulate(anim, 0.2, 1.0 / 60.0, {})
	_check(rest.position.length() < 0.012, "the weapon is back at rest after reloading")
	var aiming_reload = ANIM.new()
	_simulate(aiming_reload, 0.4, 1.0 / 60.0, {"aiming": true})
	aiming_reload.start_reload(1.2)
	_simulate(aiming_reload, 0.3, 1.0 / 60.0, {"aiming": true})
	_check(aiming_reload.ads < 0.05, "reloading drops out of ADS")
	aiming_reload.cancel_reload()
	_check(not aiming_reload.is_reloading(), "reload can be cancelled")
	_check(ANIM.reload_duration(0.075) >= 1.0 and ANIM.reload_duration(5.0) <= 2.2, "reload duration stays in range")
	_check(ANIM.reload_duration(1.25) > ANIM.reload_duration(0.075), "slow heavy weapons reload longer")


func _test_switch_and_land() -> void:
	var begin: Dictionary = ANIM.switch_pose(0.0)
	var end: Dictionary = ANIM.switch_pose(1.0)
	_check(begin.position.y < -0.05 and begin.rotation.x < deg_to_rad(-25.0), "a new weapon starts raised from below")
	_check(end.position.length() < 0.0001 and end.rotation.length() < 0.0001, "switch pose ends at zero offset")
	var anim = ANIM.new()
	anim.start_reload(1.2)
	anim.start_switch()
	_check(anim.is_switching() and not anim.is_reloading(), "switching cancels a reload")
	_check(not anim.start_reload(1.0), "cannot reload mid-switch")
	_simulate(anim, ANIM.SWITCH_TIME + 0.05, 1.0 / 60.0, {})
	_check(not anim.is_switching(), "switch finishes by itself")
	var landing = ANIM.new()
	landing.land(12.0)
	var low := 0.0
	for index in range(60):
		low = minf(low, landing.step(1.0 / 240.0, {}).position.y)
	_check(low < -0.01, "landing dips the weapon (got %f)" % low)
	var soft = ANIM.new()
	soft.land(1.0)
	var soft_low := 0.0
	for index in range(60):
		soft_low = minf(soft_low, soft.step(1.0 / 240.0, {}).position.y)
	_check(soft_low > low * 0.5, "soft landings barely move it")


func _test_pivot() -> void:
	var no_rotation := {"position": Vector3(0.01, -0.02, 0.03), "rotation": Vector3.ZERO}
	var transform: Transform3D = ANIM.pivot_transform(REST, no_rotation)
	_check(transform.origin.distance_to(no_rotation.position) < 0.0001, "no rotation: pivot is a plain offset")
	var rotated := {"position": Vector3(0.0, 0.05, 0.0), "rotation": Vector3(deg_to_rad(-30.0), deg_to_rad(20.0), deg_to_rad(15.0))}
	var pivoted: Transform3D = ANIM.pivot_transform(REST, rotated)
	_check((pivoted * REST).distance_to(REST + rotated.position) < 0.0001, "the weapon's rest point stays put under rotation (grip does not swing)")
	_check(not is_nan(pivoted.basis.x.x), "pivot basis is valid")


func _test_stability() -> void:
	var anim = ANIM.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var finite := true
	var bounded := true
	for frame in range(6000):
		var dt := rng.randf_range(0.0, 0.2)
		if frame % 7 == 0:
			anim.fire(rng.randf_range(0.0, 3.0), rng.randf_range(-1.0, 1.0))
		if frame % 211 == 0:
			anim.start_reload(rng.randf_range(0.5, 2.0))
		if frame % 397 == 0:
			anim.start_switch()
		if frame % 53 == 0:
			anim.land(rng.randf_range(0.0, 30.0))
		var pose: Dictionary = anim.step(dt, {
			"look_rate": Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-60.0, 60.0)),
			"speed": rng.randf_range(0.0, 14.0), "vertical_speed": rng.randf_range(-30.0, 30.0),
			"on_floor": rng.randf() > 0.3, "sprinting": rng.randf() > 0.5, "sliding": rng.randf() > 0.8,
			"aiming": rng.randf() > 0.5, "move_input": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		})
		if not (is_finite(pose.position.x) and is_finite(pose.position.y) and is_finite(pose.position.z) and is_finite(pose.rotation.x) and is_finite(pose.rotation.y) and is_finite(pose.rotation.z)):
			finite = false
		if pose.position.length() > 0.8 or pose.rotation.length() > 2.5:
			bounded = false
	_check(finite, "viewmodel pose stays finite under random abuse")
	_check(bounded, "viewmodel pose stays bounded under random abuse")
