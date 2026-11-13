class_name CharacterMovement
extends RefCounted
## Movement model shared by the authoritative server body (oxenwar_server_player.gd) and the
## local player (player.gd), so ground, air and fall behavior cannot drift apart.

const GROUND_ACCELERATION := 28.0
const SLIDE_ACCELERATION := 34.0
## Steering in the air is softer than on the ground, but it is no longer zero friction vs. instant stop.
const AIR_ACCELERATION := 16.0

const GROUND_FRICTION := 20.0
const SLIDE_FRICTION := 7.0
const ICE_FRICTION := 3.5
## Releasing the keys in mid-air keeps most of the momentum instead of stopping dead.
const AIR_FRICTION := 4.0

## Falling is a little snappier than rising, which makes jumps feel less floaty.
const FALL_GRAVITY_MULTIPLIER := 1.3
## Caps the fall speed so a long drop cannot tunnel through thin floors.
const TERMINAL_FALL_SPEED := 45.0
## Lets the body stay glued to stairs and slopes when walking down them.
const FLOOR_SNAP_LENGTH := 0.3


## Next vertical velocity under gravity. `gravity_scale` is the event scale (for example low gravity).
static func apply_gravity(vertical_velocity: float, gravity: float, gravity_scale: float, delta: float) -> float:
	var multiplier := FALL_GRAVITY_MULTIPLIER if vertical_velocity < 0.0 else 1.0
	return maxf(vertical_velocity - gravity * gravity_scale * multiplier * delta, -TERMINAL_FALL_SPEED)


## Next horizontal velocity (x, z as a Vector2). `direction` is the wished world direction on the
## ground plane; a zero direction means no input.
static func step_horizontal(current: Vector2, direction: Vector2, target_speed: float, on_floor: bool, sliding: bool, ice: bool, delta: float) -> Vector2:
	if direction.length() > 0.01:
		var acceleration := GROUND_ACCELERATION if on_floor else AIR_ACCELERATION
		if sliding:
			acceleration = SLIDE_ACCELERATION
		return Vector2(
			move_toward(current.x, direction.x * target_speed, acceleration * delta),
			move_toward(current.y, direction.y * target_speed, acceleration * delta)
		)
	var friction := GROUND_FRICTION
	if not on_floor:
		friction = AIR_FRICTION
	elif ice:
		friction = ICE_FRICTION
	elif sliding:
		friction = SLIDE_FRICTION
	return Vector2(
		move_toward(current.x, 0.0, friction * delta),
		move_toward(current.y, 0.0, friction * delta)
	)
