extends Control
## Fills the screen and holds a `content` control that is scaled for this device (see ui_platform.gd),
## so one layout works on a 27 inch monitor and on a phone. Everything inside `content` is laid out in
## logical pixels; `content.size` is the visible area in those pixels. Anchor children to `content`.

const PLATFORM := preload("res://scripts/ui/ui_platform.gd")

signal layout_changed(content_size: Vector2, ui_scale: float)

var content: Control
var ui_scale: float = 1.0
var is_touch: bool = false
var touch_target: float = 44.0
var _forced_profile: Dictionary = {}


func _init() -> void:
	name = "ScaledRoot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)


func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


## Uses a fixed platform profile (tests, or a "force touch layout" preview) instead of the real device.
func force_profile(profile: Dictionary) -> void:
	_forced_profile = profile
	refresh()


func refresh() -> void:
	var profile := _forced_profile if not _forced_profile.is_empty() else PLATFORM.current()
	is_touch = bool(profile.touch)
	ui_scale = float(profile.scale)
	touch_target = float(profile.target)
	var visible := size
	if visible.x < 1.0 or visible.y < 1.0:
		visible = get_viewport_rect().size
	content.scale = Vector2(ui_scale, ui_scale)
	content.position = Vector2.ZERO
	content.size = visible / ui_scale
	layout_changed.emit(content.size, ui_scale)
