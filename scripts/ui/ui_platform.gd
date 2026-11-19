extends RefCounted
## PC and Android need different sizes. A pixel is a very different physical size on a 27 inch
## monitor and on a 6 inch phone, so sizes are worked out from the real screen density.
##
## The interface is laid out in "logical pixels". On a touch device the whole interface is scaled up so
## that text is readable and every touch target is at least TOUCH_TARGET_INCHES (about 7.6 mm, the
## 48 dp Android guideline) across. On a PC the scale is 1.

const BASE_VIEWPORT := Vector2(1280.0, 720.0) ## project.godot, stretch mode canvas_items, aspect expand
const TOUCH_TARGET_INCHES := 0.30
const TEXT_INCHES_PER_LOGICAL_PIXEL := 0.0057 ## aim: one logical pixel is about this big on a touch device
const MIN_SCALE := 1.0
const MAX_SCALE := 1.8
const MAX_TARGET_PIXELS := 120.0


## OXENWAR_FORCE_TOUCH=1 previews the phone layout on a PC (screenshots, layout checks).
static func forced_touch() -> bool:
	return OS.get_environment("OXENWAR_FORCE_TOUCH") == "1"


static func is_touch() -> bool:
	return forced_touch() or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


## Inches covered by one viewport pixel for a window of `window_size` pixels at `dpi`.
static func inches_per_pixel(dpi: float, window_size: Vector2) -> float:
	if dpi <= 1.0 or window_size.x < 1.0 or window_size.y < 1.0:
		return 0.0
	var view_scale := minf(window_size.x / BASE_VIEWPORT.x, window_size.y / BASE_VIEWPORT.y)
	return view_scale / dpi


## The scale for the whole interface. 1.0 on PC; on touch it grows as the screen gets denser/smaller.
static func ui_scale(touch: bool, dpi: float, window_size: Vector2) -> float:
	if not touch:
		return 1.0
	var inches := inches_per_pixel(dpi, window_size)
	if inches <= 0.0:
		return 1.4
	return clampf(TEXT_INCHES_PER_LOGICAL_PIXEL / inches, MIN_SCALE, MAX_SCALE)


## The smallest logical size of something that is tapped: `base` on PC, at least 0.30 inch on touch.
static func touch_target(base: float, touch: bool, dpi: float, window_size: Vector2) -> float:
	if not touch:
		return base
	var inches := inches_per_pixel(dpi, window_size)
	if inches <= 0.0:
		return maxf(base, 56.0)
	var scale := ui_scale(true, dpi, window_size)
	return clampf(maxf(base, TOUCH_TARGET_INCHES / (inches * scale)), base, MAX_TARGET_PIXELS)


## The profile of the screen the game is running on right now.
static func current() -> Dictionary:
	var touch := is_touch()
	var dpi := float(DisplayServer.screen_get_dpi())
	var window := Vector2(DisplayServer.window_get_size())
	if forced_touch():
		# A reference phone: 2400x1080 at 420 dpi.
		dpi = 420.0
		window = Vector2(2400.0, 1080.0)
	return {
		"touch": touch, "dpi": dpi, "window": window,
		"scale": ui_scale(touch, dpi, window), "target": touch_target(44.0, touch, dpi, window),
	}
