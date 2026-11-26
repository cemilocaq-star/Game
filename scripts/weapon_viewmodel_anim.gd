extends RefCounted
## First-person weapon presentation, kept free of scene access so it is unit-testable.
## The player owns one instance and applies the returned pose to a pivot node that sits
## *above* the weapon model, so the model's own tweens (equip, inspect, per-weapon fire tilt)
## keep working underneath this layer.
##
## Layers (all additive, all smoothed with frame-rate independent filters):
##  - look sway: the weapon lags behind camera turns and settles back;
##  - walk / sprint bob: a figure-eight keyed to distance travelled, larger and lowered when sprinting;
##  - breathing while idle, strafe lean, airborne drift and landing dip;
##  - ADS: eased blend toward the screen centre, with sway/bob/recoil damped;
##  - recoil: damped springs (kick back, muzzle rise, roll) so rapid fire stacks naturally;
##  - reload and weapon-raise poses that start and end at exactly zero offset.

const ADS_TIME := 0.18
const ADS_OFFSET := Vector3(-0.27, 0.052, 0.07)
const ADS_RECOIL_SCALE := 0.55
const SPRINT_SPEED := 9.0
const WALK_SPEED := 6.0
const SWAY_FOLLOW := 16.0
const SWAY_RELEASE := 7.0
const SWAY_ROT_GAIN := 0.012
const SWAY_POS_GAIN := 0.0016
const SWAY_MAX_ROT := deg_to_rad(3.4)
const SWAY_MAX_POS := 0.035
const SWITCH_TIME := 0.34
const SPRING_STIFFNESS := 180.0
const SPRING_ZETA := 0.55
## Peak displacement of an underdamped spring after a velocity impulse is about 0.522 * v0 / omega
## for zeta 0.55, so impulses are specified as the desired peak and converted with this gain.
const IMPULSE_GAIN := 1.92
const MAX_STEP := 1.0 / 30.0
const MAX_KICK_POS := 0.12
const MAX_KICK_ROT := deg_to_rad(14.0)


## Damped spring on a Vector3, integrated with sub-steps so a long frame cannot explode it.
class Spring extends RefCounted:
	var value := Vector3.ZERO
	var velocity := Vector3.ZERO
	var stiffness := SPRING_STIFFNESS
	var zeta := SPRING_ZETA

	func omega() -> float:
		return sqrt(stiffness)

	func impulse_peak(peak: Vector3) -> void:
		velocity += peak * omega() * IMPULSE_GAIN

	func step(delta: float) -> void:
		var remaining := minf(delta, 0.1)
		var damping := 2.0 * zeta * omega()
		while remaining > 0.0:
			var dt := minf(remaining, 1.0 / 240.0)
			velocity += (-stiffness * value - damping * velocity) * dt
			value += velocity * dt
			remaining -= dt

	func reset() -> void:
		value = Vector3.ZERO
		velocity = Vector3.ZERO


var ads := 0.0 ## linear 0..1 progress; use ads_eased() for presentation
var sprint_blend := 0.0
var slide_blend := 0.0
var move_amount := 0.0
var _sway_rot := Vector2.ZERO ## (pitch, yaw) radians
var _sway_pos := Vector2.ZERO
var _bob_phase := 0.0
var _lean := 0.0
var _air := 0.0
var _clock := 0.0
var _kick_pos := Spring.new()
var _kick_rot := Spring.new()
var reload_t := -1.0
var _reload_duration := 1.2
var switch_t := -1.0


func reset() -> void:
	ads = 0.0
	sprint_blend = 0.0
	slide_blend = 0.0
	move_amount = 0.0
	_sway_rot = Vector2.ZERO
	_sway_pos = Vector2.ZERO
	_lean = 0.0
	_air = 0.0
	_kick_pos.reset()
	_kick_rot.reset()
	reload_t = -1.0
	switch_t = -1.0


func ads_eased() -> float:
	return smoothstep(0.0, 1.0, ads)


## Weapon FOV blend for the camera: 0 = hip FOV, 1 = fully aimed.
func fov_blend() -> float:
	return ads_eased()


static func smooth_factor(rate: float, delta: float) -> float:
	return 1.0 - exp(-maxf(rate, 0.0) * maxf(delta, 0.0))


static func reload_duration(cooldown: float) -> float:
	return clampf(0.95 + cooldown * 0.9, 1.0, 2.2)


func is_reloading() -> bool:
	return reload_t >= 0.0


func is_switching() -> bool:
	return switch_t >= 0.0


func start_reload(duration: float) -> bool:
	if is_reloading() or is_switching():
		return false
	_reload_duration = maxf(0.3, duration)
	reload_t = 0.0
	return true


func cancel_reload() -> void:
	reload_t = -1.0


func start_switch() -> void:
	reload_t = -1.0
	switch_t = 0.0
	_kick_pos.reset()
	_kick_rot.reset()


## Visual recoil. `strength` is 1.0 for an average shot; heavy weapons pass more.
func fire(strength: float = 1.0, roll_sign: float = 1.0) -> void:
	var scale := clampf(strength, 0.2, 2.5) * lerpf(1.0, ADS_RECOIL_SCALE, ads_eased())
	if sprint_blend > 0.5:
		scale *= 0.8
	_kick_pos.impulse_peak(Vector3(0.0, 0.004, 0.034) * scale)
	_kick_rot.impulse_peak(Vector3(deg_to_rad(2.6), 0.0, deg_to_rad(1.8) * signf(roll_sign)) * scale)
	_kick_pos.value = _kick_pos.value.limit_length(MAX_KICK_POS)
	_kick_rot.value = _kick_rot.value.limit_length(MAX_KICK_ROT)


## A landing pushes the weapon down briefly (impact in m/s of downward speed).
func land(impact: float) -> void:
	var amount := clampf(impact / 12.0, 0.0, 1.0)
	_kick_pos.impulse_peak(Vector3(0.0, -0.03 * amount, 0.012 * amount))
	_kick_rot.impulse_peak(Vector3(deg_to_rad(-2.5) * amount, 0.0, 0.0))


## Reload pose for progress t in 0..1: lower and roll the weapon, swap the magazine with a small
## shake, return with a soft overshoot. Exactly zero at both ends.
static func reload_pose(t: float) -> Dictionary:
	var progress := clampf(t, 0.0, 1.0)
	var down := smoothstep(0.0, 0.22, progress) * (1.0 - smoothstep(0.78, 1.0, progress))
	var swap_window := smoothstep(0.30, 0.38, progress) * (1.0 - smoothstep(0.62, 0.70, progress))
	var swap := sin((progress - 0.30) / 0.40 * TAU * 2.0) * swap_window
	var slap := exp(-pow((progress - 0.64) / 0.035, 2.0)) # magazine seats
	var position_offset := Vector3(-0.045 * down, -0.11 * down - 0.012 * swap - 0.014 * slap, 0.05 * down + 0.012 * slap)
	var rotation_offset := Vector3(deg_to_rad(-26.0) * down + deg_to_rad(2.0) * swap, deg_to_rad(10.0) * down, deg_to_rad(-34.0) * down + deg_to_rad(3.0) * swap)
	return {"position": position_offset, "rotation": rotation_offset}


## Raise pose for progress t in 0..1 after changing weapon: starts low and rolled, settles with a
## small overshoot. Exactly zero at t = 1.
static func switch_pose(t: float) -> Dictionary:
	var progress := clampf(t, 0.0, 1.0)
	var back := 1.0 - progress
	var eased := back * back * (1.0 + 1.6 * progress) # fast start, soft landing
	var overshoot := sin(progress * PI) * 0.12 * back
	return {
		"position": Vector3(0.03, -0.075, 0.03) * (eased - overshoot),
		"rotation": Vector3(deg_to_rad(-34.0), deg_to_rad(-8.0), deg_to_rad(22.0)) * (eased - overshoot)
	}


## Advance one frame. `input` keys (all optional):
##  look_rate: Vector2 (yaw rad/s, pitch rad/s)  speed: horizontal m/s  vertical_speed: m/s
##  on_floor, sprinting, sliding, aiming: bool   move_input: Vector2 (x strafe, y forward)
## Returns {"position": Vector3, "rotation": Vector3 (euler radians)} relative to the rest pose.
func step(delta: float, input: Dictionary) -> Dictionary:
	delta = clampf(delta, 0.0, MAX_STEP * 3.0)
	_clock += delta
	var speed := float(input.get("speed", 0.0))
	var on_floor := bool(input.get("on_floor", true))
	var aiming := bool(input.get("aiming", false)) and not is_reloading() and not is_switching()
	var sprinting := bool(input.get("sprinting", false)) and speed > WALK_SPEED * 0.8 and on_floor and not aiming
	var sliding := bool(input.get("sliding", false)) and on_floor
	var look_rate: Vector2 = input.get("look_rate", Vector2.ZERO)
	var move_input: Vector2 = input.get("move_input", Vector2.ZERO)

	ads = move_toward(ads, 1.0 if aiming else 0.0, delta / ADS_TIME)
	var ads_k := ads_eased()
	sprint_blend = move_toward(sprint_blend, 1.0 if sprinting else 0.0, delta / 0.22)
	slide_blend = move_toward(slide_blend, 1.0 if sliding else 0.0, delta / 0.16)

	# Look sway: the weapon trails the camera; it follows quickly and settles slowly.
	var sway_scale := lerpf(1.0, 0.35, ads_k)
	var target_rot := Vector2(-look_rate.y, -look_rate.x) * SWAY_ROT_GAIN * sway_scale
	target_rot = Vector2(clampf(target_rot.x, -SWAY_MAX_ROT, SWAY_MAX_ROT), clampf(target_rot.y, -SWAY_MAX_ROT, SWAY_MAX_ROT))
	var target_pos := Vector2(look_rate.x, -look_rate.y) * SWAY_POS_GAIN * sway_scale
	target_pos = Vector2(clampf(target_pos.x, -SWAY_MAX_POS, SWAY_MAX_POS), clampf(target_pos.y, -SWAY_MAX_POS, SWAY_MAX_POS))
	var following := target_rot.length() > _sway_rot.length()
	var sway_k := smooth_factor(SWAY_FOLLOW if following else SWAY_RELEASE, delta)
	_sway_rot = _sway_rot.lerp(target_rot, sway_k)
	_sway_pos = _sway_pos.lerp(target_pos, sway_k)

	# Bob: phase follows distance travelled so it matches footsteps at any speed.
	var moving_target := clampf(speed / WALK_SPEED, 0.0, 1.5) if on_floor and not sliding else 0.0
	move_amount = lerpf(move_amount, moving_target, smooth_factor(10.0, delta))
	if on_floor and not sliding:
		_bob_phase = fposmod(_bob_phase + speed * 1.15 * delta, TAU * 4.0)
	var bob_scale := lerpf(1.0, 0.2, ads_k)
	var amp := lerpf(0.0065, 0.0165, sprint_blend) * move_amount * bob_scale
	var bob := Vector3(sin(_bob_phase) * amp * 1.1, sin(_bob_phase * 2.0) * amp * 1.25, 0.0)
	var bob_roll := sin(_bob_phase) * deg_to_rad(0.9) * move_amount * bob_scale * lerpf(1.0, 2.2, sprint_blend)

	# Breathing, strafe lean and airborne drift.
	var breath_amount := (1.0 - clampf(move_amount, 0.0, 1.0)) * lerpf(1.0, 0.45, ads_k)
	var breath := Vector3(0.0, sin(_clock * 1.7) * 0.0055, 0.0) * breath_amount
	var breath_roll := sin(_clock * 1.35) * 0.012 * breath_amount
	_lean = lerpf(_lean, clampf(move_input.x, -1.0, 1.0), smooth_factor(9.0, delta))
	var air_target := clampf(-float(input.get("vertical_speed", 0.0)) * 0.0035, -0.03, 0.03) if not on_floor else 0.0
	_air = lerpf(_air, air_target, smooth_factor(8.0, delta))

	_kick_pos.step(delta)
	_kick_rot.step(delta)
	_kick_pos.value = _kick_pos.value.limit_length(MAX_KICK_POS)
	_kick_rot.value = _kick_rot.value.limit_length(MAX_KICK_ROT)

	# Compose.
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	pos += ADS_OFFSET * ads_k
	pos += Vector3(_sway_pos.x, _sway_pos.y, 0.0) + bob + breath + Vector3(0.0, _air, 0.0)
	rot += Vector3(_sway_rot.x, _sway_rot.y, 0.0)
	rot.z += bob_roll + breath_roll - _lean * deg_to_rad(1.6) * lerpf(1.0, 0.3, ads_k)
	# Sprint carries the weapon low and angled across the body; sliding leans it hard.
	pos += Vector3(0.02, -0.06, 0.03) * sprint_blend
	rot += Vector3(deg_to_rad(-11.0), deg_to_rad(20.0), deg_to_rad(-9.0)) * sprint_blend
	pos += Vector3(0.0, -0.045, 0.02) * slide_blend
	rot += Vector3(deg_to_rad(-6.0), deg_to_rad(8.0), deg_to_rad(-14.0)) * slide_blend
	pos += _kick_pos.value
	rot += _kick_rot.value

	if reload_t >= 0.0:
		reload_t += delta / _reload_duration
		var pose := reload_pose(reload_t)
		pos += pose.position
		rot += pose.rotation
		if reload_t >= 1.0:
			reload_t = -1.0
	if switch_t >= 0.0:
		switch_t += delta / SWITCH_TIME
		var raise := switch_pose(switch_t)
		pos += raise.position
		rot += raise.rotation
		if switch_t >= 1.0:
			switch_t = -1.0
	return {"position": pos, "rotation": rot}


## Rotating about the weapon's own rest position (not the camera origin) keeps the grip steady
## when the pose has a rotation. Returns the Transform3D for a pivot node at the camera origin.
static func pivot_transform(rest: Vector3, pose: Dictionary) -> Transform3D:
	var basis := Basis.from_euler(pose.rotation, EULER_ORDER_YXZ)
	var origin: Vector3 = pose.position + rest - basis * rest
	return Transform3D(basis, origin)
