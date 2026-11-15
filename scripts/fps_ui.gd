extends RefCounted
## Shared building blocks for the FPS-style OxenWar menu: palette, angled buttons, selectable
## cards, section headers and an animated backdrop. The look follows the common competitive
## shooter lobby layout (top navigation bar, mode list on the left, character in the middle,
## map picker and one large START button on the right) without copying any game's assets.

const BG := Color("#060A11")
const BG_TOP := Color("#0C1828")
const PANEL := Color("#0D1722")
const PANEL_ALT := Color("#13233A")
const EDGE := Color("#22364C")
const ACCENT := Color("#25D7C2")
const ACCENT_HOT := Color("#5CF0DD")
const DANGER := Color("#FF4D5E")
const GOLD := Color("#FFC36B")
const TEXT := Color("#EAF4FF")
const MUTED := Color("#8DA2B6")
const DARK_TEXT := Color("#04131D")
## Angled (parallelogram) buttons: StyleBoxFlat.skew shifts the shape to the right with height.
const SKEW := Vector2(0.16, 0.0)


## Slowly drifting diagonal light bars on a dark gradient, plus a soft glow behind the hero model.
class MenuBackdrop extends Control:
	var _time := 0.0
	var glow_center := Vector2(0.5, 0.58)

	func _init() -> void:
		name = "MenuBackdropArt"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		var top := Color("#0E1D31")
		var bottom := Color("#05080E")
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([top, top, bottom, bottom])
		)
		var accent := Color("#25D7C2")
		# Soft glow behind the character: stacked translucent discs.
		var center := Vector2(w * glow_center.x, h * glow_center.y)
		var radius := minf(w, h) * 0.5
		for ring in range(6):
			var factor := 1.0 - float(ring) * 0.15
			draw_circle(center, radius * factor, Color(accent.r, accent.g, accent.b, 0.018))
		# Drifting diagonal bars.
		var lean := h * 0.45
		var span := w + 360.0
		for index in range(7):
			var x0 := fposmod(float(index) * span / 7.0 + _time * 16.0, span) - 220.0
			var bar_w := 70.0 + float(index % 3) * 46.0
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(x0, 0), Vector2(x0 + bar_w, 0),
					Vector2(x0 + bar_w - lean, h), Vector2(x0 - lean, h)
				]),
				Color(accent.r, accent.g, accent.b, 0.045)
			)
		# Dark vignette on the left and right edges so the panels stay readable.
		var edge_w := w * 0.16
		var shade := Color(0, 0, 0, 0.5)
		var clear := Color(0, 0, 0, 0.0)
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(edge_w, 0), Vector2(edge_w, h), Vector2(0, h)]),
			PackedColorArray([shade, clear, clear, shade])
		)
		draw_polygon(
			PackedVector2Array([Vector2(w - edge_w, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - edge_w, h)]),
			PackedColorArray([clear, shade, shade, clear])
		)


const SFX_BANK := preload("res://scripts/sfx_bank.gd")


## Soft hover tick and click on a menu control (once per control).
static func attach_sounds(control: BaseButton) -> void:
	if control.has_meta("sfx_attached"):
		return
	control.set_meta("sfx_attached", true)
	control.mouse_entered.connect(func(): if not control.disabled: SFX_BANK.play_ui(control, "ui_hover"))
	control.pressed.connect(func(): SFX_BANK.play_ui(control, "ui_click"))


static func flat_box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, skew: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	box.skew = skew
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func _focus_box(skew: Vector2) -> StyleBoxFlat:
	var box := flat_box(Color.TRANSPARENT, Color.WHITE, 2, skew)
	box.draw_center = false
	return box


static func _apply_button_states(b: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, disabled: StyleBoxFlat, skew: Vector2) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", _focus_box(skew))


## kind: "primary" (filled accent), "danger", "secondary" (dark with edge) or "ghost" (text only).
static func button(text: String, kind: String = "secondary", height: float = 48.0, font_size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = height
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_size)
	var skew := SKEW
	match kind:
		"primary", "danger":
			var base := ACCENT if kind == "primary" else DANGER
			var normal := flat_box(base, Color.TRANSPARENT, 0, skew)
			normal.shadow_color = Color(base.r, base.g, base.b, 0.35)
			normal.shadow_size = 10
			var hover := flat_box(base.lightened(0.22), Color.TRANSPARENT, 0, skew)
			hover.shadow_color = Color(base.r, base.g, base.b, 0.55)
			hover.shadow_size = 16
			var pressed := flat_box(base.darkened(0.2), Color.TRANSPARENT, 0, skew)
			var disabled := flat_box(Color("#1A2736"), Color.TRANSPARENT, 0, skew)
			_apply_button_states(b, normal, hover, pressed, disabled, skew)
			for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(color_name, DARK_TEXT if kind == "primary" else Color.WHITE)
		"ghost":
			skew = Vector2.ZERO
			var normal := flat_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, skew)
			var hover := flat_box(Color(1, 1, 1, 0.07), Color.TRANSPARENT, 0, skew)
			var pressed := flat_box(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, skew)
			_apply_button_states(b, normal, hover, pressed, normal, skew)
			b.add_theme_color_override("font_color", MUTED)
			b.add_theme_color_override("font_hover_color", TEXT)
			b.add_theme_color_override("font_pressed_color", TEXT)
		_:
			var normal := flat_box(PANEL_ALT, EDGE, 1, skew)
			var hover := flat_box(Color("#1B3250"), ACCENT, 1, skew)
			var pressed := flat_box(Color("#0F2A33"), ACCENT, 1, skew)
			var disabled := flat_box(Color("#0F1925"), Color("#1A2736"), 1, skew)
			_apply_button_states(b, normal, hover, pressed, disabled, skew)
			b.add_theme_color_override("font_color", TEXT)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#5E7284"))
	attach_sounds(b)
	return b


## Top-bar navigation tab: plain text with an accent underline while active.
static func nav_button(text: String, active: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 18)
	var normal := flat_box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.10) if active else Color.TRANSPARENT)
	normal.border_width_bottom = 3
	normal.border_color = ACCENT if active else Color.TRANSPARENT
	var hover := flat_box(Color(1, 1, 1, 0.06))
	hover.border_width_bottom = 3
	hover.border_color = ACCENT if active else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", _focus_box(Vector2.ZERO))
	var font := TEXT if active else MUTED
	b.add_theme_color_override("font_color", font)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	attach_sounds(b)
	return b


## Re-styles a selectable card (game mode or map). Selected cards get a bright left bar and tint.
static func style_card(b: Button, accent: Color, selected: bool) -> void:
	attach_sounds(b)
	var normal := flat_box(Color(accent.r, accent.g, accent.b, 0.20) if selected else Color(PANEL.r, PANEL.g, PANEL.b, 0.92), accent if selected else EDGE, 2 if selected else 1)
	normal.border_width_left = 7
	var hover := flat_box(Color(accent.r, accent.g, accent.b, 0.28), accent, 2)
	hover.border_width_left = 7
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", _focus_box(Vector2.ZERO))


static func panel_style(alpha: float = 0.9) -> StyleBoxFlat:
	var box := flat_box(Color(PANEL.r, PANEL.g, PANEL.b, alpha), EDGE, 1)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box


static func input_style(focused: bool = false) -> StyleBoxFlat:
	var box := flat_box(Color("#08121D"), ACCENT if focused else EDGE, 2 if focused else 1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box


## Small round status light (green/amber/red) that does not depend on font glyphs.
static func status_dot(color: Color) -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", box)
	return dot


static func set_status_dot(dot: Panel, color: Color) -> void:
	if not is_instance_valid(dot):
		return
	var box := dot.get_theme_stylebox("panel") as StyleBoxFlat
	if box != null:
		box.bg_color = color


## "▌ TITLE" style header used above each column.
static func section_header(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(4, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)
	return row
