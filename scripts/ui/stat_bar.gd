extends Control
## An icon, a segmented bar and a number. When the value drops, the lost part stays visible as a pale
## trail for a moment and then drains, so damage is readable at a glance (the same idea as the health
## bars of Apex Legends and Valorant). When the value is low the bar pulses.

const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")

@export var icon_name: String = "health":
	set(value):
		icon_name = value
		_icon = ICONS.texture(value)
		queue_redraw()
@export var bar_color: Color = THEME.OK:
	set(value):
		bar_color = value
		queue_redraw()
@export var maximum: float = 100.0:
	set(value):
		maximum = maxf(value, 1.0)
		queue_redraw()
@export var segments: int = 10
@export var show_number: bool = true
@export var low_fraction: float = 0.3

var value: float = 100.0
var _trail: float = 100.0
var _trail_hold: float = 0.0
var _pulse: float = 0.0
var _icon: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190.0, 26.0)
	_icon = ICONS.texture(icon_name)


func set_value(new_value: float) -> void:
	var clamped := clampf(new_value, 0.0, maximum)
	if clamped < value - 0.01:
		_trail = maxf(_trail, value)
		_trail_hold = 0.45
	elif clamped > value:
		_trail = maxf(_trail, clamped) if _trail > clamped else clamped
	value = clamped
	queue_redraw()
	set_process(true)


func fraction() -> float:
	return value / maximum


func _process(delta: float) -> void:
	var busy := false
	if _trail > value:
		busy = true
		if _trail_hold > 0.0:
			_trail_hold -= delta
		else:
			_trail = maxf(value, _trail - maximum * 0.9 * delta)
		queue_redraw()
	if fraction() <= low_fraction and value > 0.0:
		busy = true
		_pulse += delta * 6.0
		queue_redraw()
	elif _pulse != 0.0:
		_pulse = 0.0
		queue_redraw()
	if not busy:
		set_process(false)


func _draw() -> void:
	var icon_box := size.y
	var low := fraction() <= low_fraction
	var color := bar_color
	if low:
		color = bar_color.lerp(THEME.DANGER, 0.7 + 0.3 * sin(_pulse))
	if _icon != null:
		draw_texture_rect(_icon, Rect2(0.0, 0.0, icon_box, icon_box), false, color if low else bar_color)
	var number_width := 0.0
	var font := THEME.font("bold")
	var number_size := int(size.y * 0.78)
	if show_number:
		number_width = font.get_string_size("000", HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x + 6.0
	var bar_x := icon_box + 6.0
	var bar_w := maxf(size.x - bar_x - number_width, 10.0)
	var bar_h := maxf(size.y * 0.36, 6.0)
	var bar_y := (size.y - bar_h) * 0.5
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.0, 0.0, 0.0, 0.55))
	var trail_w := bar_w * clampf(_trail / maximum, 0.0, 1.0)
	var fill_w := bar_w * clampf(value / maximum, 0.0, 1.0)
	if trail_w > fill_w:
		draw_rect(Rect2(bar_x + fill_w, bar_y, trail_w - fill_w, bar_h), Color(1.0, 0.92, 0.85, 0.75))
	if fill_w > 0.0:
		draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), color)
		draw_rect(Rect2(bar_x, bar_y, fill_w, maxf(bar_h * 0.35, 1.0)), Color(1.0, 1.0, 1.0, 0.22))
	# Segment gaps drawn over the bar give it the cut-up look.
	var count := maxi(segments, 1)
	for index in range(1, count):
		var x := bar_x + bar_w * float(index) / float(count)
		draw_line(Vector2(x, bar_y), Vector2(x, bar_y + bar_h), Color(0.0, 0.0, 0.0, 0.85), 2.0)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(THEME.ACCENT_DIM.r, THEME.ACCENT_DIM.g, THEME.ACCENT_DIM.b, 0.7), false, 1.0)
	if show_number:
		var text := str(int(ceil(value)))
		draw_string(font, Vector2(bar_x + bar_w + 6.0, (size.y + font.get_ascent(number_size) - font.get_descent(number_size)) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, number_width, number_size, THEME.INK if not low else THEME.DANGER)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
