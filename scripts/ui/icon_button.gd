extends Button
## The one button of the game: a chamfered plate with a tinted icon, an optional short label under or
## beside it, a key hint chip (PC) and a cooldown sweep. It is a real Button, so `pressed`, `button_down`,
## `button_up`, `disabled` and keyboard focus all work; it only changes how it looks.
##
## `hold_mode` makes it report press/release instead of a click, for touch controls that must stay
## active while a finger is on them (move, jump, fire, aim). Touch controls use `touch_pressed` so the
## state follows the finger even when the finger slides off the plate.

const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")

signal touch_pressed_changed(is_pressed: bool)

@export var icon_name: String = "":
	set(value):
		icon_name = value
		_icon_texture = ICONS.texture(value) if not value.is_empty() else null
		queue_redraw()
@export var caption: String = "":
	set(value):
		caption = value
		queue_redraw()
@export var key_hint: String = "":
	set(value):
		key_hint = value
		queue_redraw()
@export var tint: Color = THEME.ACCENT:
	set(value):
		tint = value
		queue_redraw()
## 0 = ready, 1 = just used. The plate sweeps back to ready as this falls.
var cooldown: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, 1.0)
		if not is_equal_approx(clamped, cooldown):
			cooldown = clamped
			queue_redraw()
## A latched state (a toggle that is on, the current selection).
var selected: bool = false:
	set(value):
		if value != selected:
			selected = value
			queue_redraw()
## Small dot at the corner: a status (connection state, new item).
var badge: Color = Color.TRANSPARENT:
	set(value):
		badge = value
		queue_redraw()
var hold_mode: bool = false
var touch_down: bool = false

var _icon_texture: Texture2D
var _hover: float = 0.0
var _press: float = 0.0
var _tween: Tween


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(44.0, 44.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mouse_entered.connect(func(): _animate(1.0, _press))
	mouse_exited.connect(func(): _animate(0.0, 0.0))
	button_down.connect(func():
		_animate(_hover, 1.0)
		_set_touch(true))
	button_up.connect(func():
		_animate(_hover, 0.0)
		_set_touch(false))


func _set_touch(value: bool) -> void:
	if touch_down != value:
		touch_down = value
		touch_pressed_changed.emit(value)


## Forces the released state (a screen closed, the pause menu opened): no stuck touch controls.
func release() -> void:
	_set_touch(false)
	_animate(0.0, 0.0)


func _animate(hover_to: float, press_to: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_hover = hover_to
		_press = press_to
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float): _hover = v; queue_redraw(), _hover, hover_to, 0.12)
	_tween.tween_method(func(v: float): _press = v; queue_redraw(), _press, press_to, 0.08)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var dim := 0.4 if disabled else 1.0
	var inner := rect.grow(-_press * 1.5)
	var base_fill := THEME.PANEL.lerp(THEME.PANEL_HOVER, _hover)
	if selected:
		base_fill = base_fill.lerp(Color(THEME.ACCENT.r, THEME.ACCENT.g, THEME.ACCENT.b, 0.3), 0.8)
	if _press > 0.01:
		base_fill = base_fill.lerp(Color(tint.r, tint.g, tint.b, 0.45), _press * 0.7)
	var points := THEME.chamfer_points(inner, minf(THEME.CHAMFER, size.y * 0.25))
	draw_colored_polygon(points, Color(base_fill.r, base_fill.g, base_fill.b, base_fill.a * dim))
	if cooldown > 0.001:
		_draw_cooldown(inner)
	var edge_color := tint.lerp(Color.WHITE, _hover * 0.3) if (selected or _hover > 0.01) else THEME.ACCENT_DIM
	edge_color.a = (1.0 if (selected or _hover > 0.01) else 0.8) * dim
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, edge_color, 2.0 if selected else 1.5, true)

	var has_caption := not caption.is_empty() or not text.is_empty()
	var label := caption if not caption.is_empty() else text
	var font := THEME.font("bold")
	var font_size := THEME.SIZE_S if size.y >= 56.0 else THEME.SIZE_XS
	var icon_box := minf(size.x, size.y) * (0.56 if has_caption else 0.62)
	var icon_color := tint if not disabled else THEME.FAINT
	icon_color = icon_color.lerp(Color.WHITE, _hover * 0.35 + _press * 0.2)
	if has_caption and size.x >= size.y * 1.6 and _icon_texture != null:
		# Wide button: icon on the left, label to the right.
		var box := minf(size.y * 0.6, 40.0)
		var pad := (size.y - box) * 0.5 + 4.0
		draw_texture_rect(_icon_texture, Rect2(pad, (size.y - box) * 0.5, box, box), false, icon_color)
		var text_x := pad + box + 8.0
		var text_pos := Vector2(text_x, (size.y + font.get_ascent(font_size + 2) - font.get_descent(font_size + 2)) * 0.5)
		draw_string(font, text_pos, label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - 8.0, font_size + 2, Color(THEME.INK.r, THEME.INK.g, THEME.INK.b, dim))
	elif _icon_texture != null:
		var label_height := float(font_size) + 4.0 if has_caption else 0.0
		var top := (size.y - icon_box - label_height) * 0.5
		draw_texture_rect(_icon_texture, Rect2((size.x - icon_box) * 0.5, top, icon_box, icon_box), false, icon_color)
		if has_caption:
			var y := top + icon_box + font.get_ascent(font_size) + 1.0
			draw_string(font, Vector2(0.0, y), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(THEME.MUTED.r, THEME.MUTED.g, THEME.MUTED.b, dim))
	elif has_caption:
		var fs := font_size + 4
		draw_string(font, Vector2(0.0, (size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(THEME.INK.r, THEME.INK.g, THEME.INK.b, dim))

	if not key_hint.is_empty():
		var chip_font := THEME.font("bold")
		var chip_size := 12
		var chip_w := chip_font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, chip_size).x + 10.0
		var chip := Rect2(size.x - chip_w - 3.0, 3.0, chip_w, 17.0)
		draw_rect(chip, Color(0.0, 0.0, 0.0, 0.55 * dim))
		draw_rect(chip, Color(THEME.MUTED.r, THEME.MUTED.g, THEME.MUTED.b, 0.7 * dim), false, 1.0)
		draw_string(chip_font, Vector2(chip.position.x, chip.position.y + 13.0), key_hint, HORIZONTAL_ALIGNMENT_CENTER, chip_w, chip_size, THEME.INK)
	if badge.a > 0.01:
		draw_circle(Vector2(size.x - 9.0, size.y - 9.0), 5.0, Color(0.0, 0.0, 0.0, 0.7))
		draw_circle(Vector2(size.x - 9.0, size.y - 9.0), 3.6, badge)


## Cooldown: a darkened fill that shrinks from the top as the ability comes back.
func _draw_cooldown(rect: Rect2) -> void:
	var height := rect.size.y * cooldown
	var shade := Rect2(rect.position.x, rect.position.y + rect.size.y - height, rect.size.x, height)
	draw_rect(shade, Color(0.0, 0.0, 0.0, 0.5))
	draw_line(shade.position, shade.position + Vector2(shade.size.x, 0.0), Color(THEME.WARM.r, THEME.WARM.g, THEME.WARM.b, 0.9), 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED:
		queue_redraw()
