extends RefCounted
## Look control maths for touch drag, gyro and aiming down sights (ADS). Pure functions, no nodes,
## so every number can be tested without a device.
##
## With every setting at its default the result is the same as before this file existed:
## touch drag on a reference phone is `relative * look_sensitivity`, and the gyro gain is
## `look_sensitivity * 70`. What is new is that devices differ (screen size and density), that fast
## swipes can turn further, that zooming in slows the look down, and that the gyro has a deadzone
## and a spike limit.

## Viewport size the project is designed for (project.godot, stretch mode canvas_items, aspect expand).
const BASE_VIEWPORT := Vector2(1280.0, 720.0)
## Physical inches one viewport pixel covers on a typical 2400x1080, 420 dpi phone held in landscape.
## Touch look is scaled so a finger swipe of a given physical length turns the view the same amount
## on a small phone and on a tablet.
const REFERENCE_INCHES_PER_PIXEL := 0.00357
const MIN_DEVICE_SCALE := 0.6
const MAX_DEVICE_SCALE := 1.6

const ACCEL_START_SPEED := 250.0 ## viewport pixels per second: below this there is no acceleration
const ACCEL_FULL_SPEED := 2500.0
const ACCEL_MAX_BONUS := 1.5 ## at full acceleration setting and full speed the turn is 2.5x

const MIN_TOUCH_SENSITIVITY := 0.4
const MAX_TOUCH_SENSITIVITY := 2.5
const DEFAULT_TOUCH_SENSITIVITY := 1.0
const DEFAULT_TOUCH_ACCELERATION := 0.0
const MIN_ADS_SENSITIVITY := 0.3
const DEFAULT_ADS_SENSITIVITY := 0.72 ## about the narrowing of the view from 86 to 68 degrees FOV

const GYRO_BASE_GAIN := 70.0 ## the original gain: look_sensitivity * 70
const MIN_GYRO_SENSITIVITY := 0.2
const MAX_GYRO_SENSITIVITY := 8.0 ## 1:1 with the hand needs about 6.5 at the default look sensitivity
const DEFAULT_GYRO_SENSITIVITY := 1.0
const GYRO_DEADZONE := 0.02 ## rad/s, about 1.1 deg/s: below this the sensor is only noise
const GYRO_MAX_RATE := 12.0 ## rad/s: a reading above this is a glitch or a thrown phone


## How much of a viewport pixel a finger covers on this device, compared with the reference phone.
## `window_size` is the real window in pixels, `dpi` the screen density (0 or less when unknown).
static func device_scale(dpi: float, window_size: Vector2) -> float:
	if dpi <= 1.0 or window_size.x < 1.0 or window_size.y < 1.0:
		return 1.0
	var view_scale := minf(window_size.x / BASE_VIEWPORT.x, window_size.y / BASE_VIEWPORT.y)
	var inches_per_pixel := view_scale / dpi
	return clampf(inches_per_pixel / REFERENCE_INCHES_PER_PIXEL, MIN_DEVICE_SCALE, MAX_DEVICE_SCALE)


## Gain for a finger moving at `speed` viewport pixels per second. 1.0 for slow, precise movements.
static func touch_gain(speed: float, acceleration: float) -> float:
	var amount := clampf((absf(speed) - ACCEL_START_SPEED) / (ACCEL_FULL_SPEED - ACCEL_START_SPEED), 0.0, 1.0)
	amount = amount * amount * (3.0 - 2.0 * amount) ## smoothstep, so there is no kink in the response
	return 1.0 + clampf(acceleration, 0.0, 1.0) * ACCEL_MAX_BONUS * amount


## Look slows down as the view zooms in. `ads_blend` is 0 at the hip and 1 fully zoomed, so the
## change eases in with the zoom instead of snapping.
static func ads_scale(ads_sensitivity: float, ads_blend: float) -> float:
	return lerpf(1.0, clampf(ads_sensitivity, MIN_ADS_SENSITIVITY, 1.0), clampf(ads_blend, 0.0, 1.0))


## Radians to turn for a finger drag: Vector2(yaw, pitch) with the sign of the mouse path
## (dragging right turns right, dragging down looks down).
static func touch_turn(relative: Vector2, speed: float, look_sensitivity: float, touch_sensitivity: float, acceleration: float, device: float, ads: float) -> Vector2:
	var gain := look_sensitivity * clampf(touch_sensitivity, MIN_TOUCH_SENSITIVITY, MAX_TOUCH_SENSITIVITY) * device * touch_gain(speed, acceleration) * ads
	return Vector2(-relative.x, -relative.y) * gain


## A gyro rate with the noise floor removed. The rate eases in from the edge of the deadzone, so a
## hand that is slowly starting to turn does not feel a step.
static func gyro_filter(rate: float) -> float:
	if is_nan(rate) or is_inf(rate):
		return 0.0
	var magnitude := absf(rate)
	if magnitude > GYRO_MAX_RATE:
		return 0.0
	return signf(rate) * maxf(0.0, magnitude - GYRO_DEADZONE)


## Radians to turn for one frame of gyro: Vector2(yaw, pitch) in the same convention as touch_turn.
## `rate` is Input.get_gyroscope(): x pitches, y yaws (Godot gives it in screen axes). The signs match
## the original code; the invert flags flip an axis for a device or a preference that disagrees.
static func gyro_turn(rate: Vector3, delta: float, look_sensitivity: float, gyro_sensitivity: float, ads: float, invert_yaw: bool = false, invert_pitch: bool = false) -> Vector2:
	var gain := look_sensitivity * GYRO_BASE_GAIN * clampf(gyro_sensitivity, MIN_GYRO_SENSITIVITY, MAX_GYRO_SENSITIVITY) * ads * maxf(delta, 0.0)
	var yaw := -gyro_filter(rate.y) * gain
	var pitch := -gyro_filter(rate.x) * gain
	return Vector2(-yaw if invert_yaw else yaw, -pitch if invert_pitch else pitch)
