extends RefCounted
## Shared defaults for menus and match overlays. Per-screen semantic colors can override them.

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("#E3EDF5"))
	theme.set_color("font_color", "Button", Color("#E3EDF5"))
	theme.set_color("font_hover_color", "Button", Color("#FFFFFF"))
	theme.set_color("font_pressed_color", "Button", Color("#FFFFFF"))
	theme.set_color("font_disabled_color", "Button", Color("#879FB2"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {
			"normal": Color("#17283B"), "hover": Color("#224258"),
			"pressed": Color("#166561"), "disabled": Color("#111D2B"),
			"focus": Color.TRANSPARENT
		}[state]
		style.border_color = Color("#4CE0D1") if state == "focus" else Color("#315469")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		for control in ["Button", "OptionButton"]:
			theme.set_stylebox(state, control, style)
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	return theme
