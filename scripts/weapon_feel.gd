extends RefCounted
## Weapon feel model: hybrid recoil (a kick per shot) + spread that depends on how you move and
## grows while you keep firing (bloom). This is the approach the big shooters document: first
## shot accurate, sustained fire climbs, moving/jumping hurts accuracy, aiming tightens it, and
## slow heavy weapons kick once and hard while rapid-fire weapons kick a little and bloom more.
## Pure functions + one small state object, so it is unit-testable.

const MAX_SPREAD_DEG := 4.0
const MAX_BLOOM_DEG := 1.6
const BLOOM_RECOVERY_PER_SECOND := 2.4
const RECOIL_IDLE_BEFORE_RECOVERY := 0.14
const RECOIL_RECOVERY_RAD_PER_SECOND := 0.25
const RECOIL_RETURN_FRACTION := 0.7


## Per-weapon numbers derived from its fire rate (cooldown in seconds) and range.
static func profile(cooldown: float, weapon_range: float = 60.0) -> Dictionary:
	var fast := clampf(1.0 - cooldown / 0.35, 0.0, 1.0)
	var precise := clampf((weapon_range - 60.0) / 40.0, 0.0, 1.0) # long-range rifles are tighter when standing
	return {
		"kick_pitch_deg": lerpf(1.5, 0.55, fast),
		"kick_yaw_deg": lerpf(0.2, 0.45, fast),
		"base_spread_deg": lerpf(0.12, 0.55, fast) * lerpf(1.0, 0.25, precise),
		"bloom_per_shot_deg": lerpf(0.05, 0.12, fast)
	}


## Accuracy multiplier from the movement state (1.0 = standing still, hip fire).
static func movement_multiplier(horizontal_speed: float, grounded: bool, sliding: bool, aiming: bool) -> float:
	var multiplier := 1.0
	if not grounded:
		multiplier = 2.4
	elif sliding:
		multiplier = 1.3
	elif horizontal_speed > 7.5:
		multiplier = 1.9
	elif horizontal_speed > 0.5:
		multiplier = 1.35
	if aiming:
		multiplier *= 0.55
	return multiplier


## Random direction inside a cone of `spread_deg` around `direction` (uniform over the disc).
static func apply_spread(direction: Vector3, spread_deg: float, rng: RandomNumberGenerator = null) -> Vector3:
	var unit := direction.normalized()
	if spread_deg <= 0.0001 or unit.length() < 0.5:
		return unit
	var roll_a := rng.randf() if rng != null else randf()
	var roll_b := rng.randf() if rng != null else randf()
	var angle := deg_to_rad(spread_deg) * sqrt(roll_a)
	var azimuth := roll_b * TAU
	var helper := Vector3.UP if absf(unit.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := unit.cross(helper).normalized()
	var up := right.cross(unit).normalized()
	return (unit + (right * cos(azimuth) + up * sin(azimuth)) * tan(angle)).normalized()


## The shot the dedicated server fires. The client only reports where it aimed; the server rolls the
## spread itself from its own tracker and the shooter's server-side movement, so a modified client
## cannot shoot tighter than the rules allow (and cannot pick a lucky roll). Uses the same functions
## as the client's own prediction, in the same order: spread first, then the shot registers bloom.
## Returns {"direction": Vector3, "spread_deg": float}.
static func authoritative_shot(aim_direction: Vector3, tracker, weapon_profile: Dictionary, horizontal_speed: float, grounded: bool, sliding: bool, aiming: bool, rng: RandomNumberGenerator = null) -> Dictionary:
	var spread := float(tracker.spread_deg(weapon_profile, movement_multiplier(horizontal_speed, grounded, sliding, aiming)))
	var direction := apply_spread(aim_direction, spread, rng)
	tracker.fire(weapon_profile, aiming, 0.0, rng)
	return {"direction": direction, "spread_deg": spread}


## Mutable per-player state: current bloom and the camera kick that can still be recovered.
class Tracker extends RefCounted:
	var bloom_deg := 0.0
	var recoverable_pitch := 0.0
	var idle_time := 0.0

	func reset() -> void:
		bloom_deg = 0.0
		recoverable_pitch = 0.0
		idle_time = 0.0

	## `accuracy_multiplier` comes from WeaponFeel.movement_multiplier (inner classes cannot call the outer statics).
	func spread_deg(weapon_profile: Dictionary, accuracy_multiplier: float) -> float:
		var base: float = float(weapon_profile.get("base_spread_deg", 0.2)) + bloom_deg
		return minf(MAX_SPREAD_DEG, base * accuracy_multiplier)

	## Registers a shot; returns the camera kick {"pitch": rad up, "yaw": rad (random side)}.
	func fire(weapon_profile: Dictionary, aiming: bool, recoil_scale: float = 1.0, rng: RandomNumberGenerator = null) -> Dictionary:
		var aim_factor := 0.7 if aiming else 1.0
		var pitch_kick := deg_to_rad(float(weapon_profile.get("kick_pitch_deg", 1.0))) * aim_factor * recoil_scale
		var side := (rng.randf() if rng != null else randf()) * 2.0 - 1.0
		var yaw_kick := deg_to_rad(float(weapon_profile.get("kick_yaw_deg", 0.3))) * aim_factor * recoil_scale * side
		bloom_deg = minf(MAX_BLOOM_DEG, bloom_deg + float(weapon_profile.get("bloom_per_shot_deg", 0.08)))
		recoverable_pitch += pitch_kick
		idle_time = 0.0
		return {"pitch": pitch_kick, "yaw": yaw_kick}

	## Call every frame. Returns how many radians the camera pitch should be pulled back down.
	func step(delta: float) -> float:
		idle_time += delta
		bloom_deg = maxf(0.0, bloom_deg - BLOOM_RECOVERY_PER_SECOND * delta)
		if idle_time < RECOIL_IDLE_BEFORE_RECOVERY or recoverable_pitch <= 0.0:
			return 0.0
		var amount := minf(recoverable_pitch, RECOIL_RECOVERY_RAD_PER_SECOND * delta)
		recoverable_pitch -= amount
		return amount * RECOIL_RETURN_FRACTION
