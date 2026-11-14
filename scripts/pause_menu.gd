extends Control
## In-game pause/settings overlay: resume, look sensitivity, master volume, controls help
## and leaving the match. It only changes client-side settings; the server keeps running
## the player's authoritative state while this is open.

signal resume_requested
signal leave_requested
signal sensitivity_changed(value: float)

const USER_SETTINGS := preload("res://scripts/user_settings.gd")
const ACCENT := Color("#25D7C2")
const MUTED := Color("#91A5B8")

const CONTROLS_TEXT := """WASD / left stick: move      Space: jump      Shift: sprint
Ctrl: slide      Q: dash      Mouse / right-side drag: look
Left click / FIRE: shoot      G: grenade      E / R: next / previous weapon
V: arsenal      H: inspect weapon      Tab: scoreboard      F: plant / defuse
B N M J: emotes      Esc / Back: this menu"""

func _ready() -> void:
	name = "PauseMenu"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 60
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.065, 0.105, 0.98)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	# Phones in landscape only give ~720 px of height: let the content scroll if it must.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 360)
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT)
	column.add_child(title)

	var resume := _button("RESUME")
	resume.pressed.connect(func(): resume_requested.emit())
	column.add_child(resume)

	column.add_child(_section_label("LOOK SENSITIVITY"))
	var sensitivity_row := HBoxContainer.new()
	column.add_child(sensitivity_row)
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = USER_SETTINGS.MIN_LOOK_SENSITIVITY
	sensitivity_slider.max_value = USER_SETTINGS.MAX_LOOK_SENSITIVITY
	sensitivity_slider.step = 0.0001
	sensitivity_slider.value = USER_SETTINGS.look_sensitivity()
	sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity_slider.custom_minimum_size = Vector2(0, 32)
	sensitivity_row.add_child(sensitivity_slider)
	var sensitivity_value := Label.new()
	sensitivity_value.custom_minimum_size = Vector2(56, 0)
	sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sensitivity_value.text = _sensitivity_text(sensitivity_slider.value)
	sensitivity_row.add_child(sensitivity_value)
	sensitivity_slider.value_changed.connect(func(value: float):
		sensitivity_value.text = _sensitivity_text(value)
		USER_SETTINGS.write_value("input", "look_sensitivity", value)
		sensitivity_changed.emit(value)
	)

	column.add_child(_section_label("MASTER VOLUME"))
	var volume_row := HBoxContainer.new()
	column.add_child(volume_row)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = USER_SETTINGS.master_volume()
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.custom_minimum_size = Vector2(0, 32)
	volume_row.add_child(volume_slider)
	var volume_value := Label.new()
	volume_value.custom_minimum_size = Vector2(56, 0)
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_value.text = "%d%%" % int(round(volume_slider.value * 100.0))
	volume_row.add_child(volume_value)
	volume_slider.value_changed.connect(func(value: float):
		volume_value.text = "%d%%" % int(round(value * 100.0))
		USER_SETTINGS.write_value("audio", "master_volume", value)
		USER_SETTINGS.apply_master_volume(value)
	)

	column.add_child(_section_label("CONTROLS"))
	var help := Label.new()
	help.text = CONTROLS_TEXT
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color("#C9DAE8"))
	column.add_child(help)

	var leave := _button("LEAVE MATCH")
	leave.add_theme_color_override("font_color", Color("#FF8A93"))
	leave.pressed.connect(func(): leave_requested.emit())
	column.add_child(leave)

func _sensitivity_text(value: float) -> String:
	# Shown as a friendly multiple of the default (1.00x = original feel).
	return "%.2fx" % (value / USER_SETTINGS.DEFAULT_LOOK_SENSITIVITY)

func _section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 46)
	return button
