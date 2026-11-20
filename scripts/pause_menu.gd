extends Control
## In-game pause/settings overlay: resume, look sensitivity, master volume, controls help
## and leaving the match. It only changes client-side settings; the server keeps running
## the player's authoritative state while this is open.
##
## Built from the shared UI foundation (theme, icons, plates, scaled root), so it has the same look as
## the HUD and is scaled for the device: on a phone every button is at least the comfortable touch size.
## RESUME and LEAVE MATCH are pinned above and below the scrolling settings, so a small landscape
## screen never hides them.

signal resume_requested
signal leave_requested
signal sensitivity_changed(value: float)
signal input_settings_changed

const AUDIO_BUSES := preload("res://scripts/audio_buses.gd")
const USER_SETTINGS := preload("res://scripts/user_settings.gd")
const LOOK := preload("res://scripts/look_control.gd")
const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")
const PLATE := preload("res://scripts/ui/hud_plate.gd")
const BUTTON := preload("res://scripts/ui/icon_button.gd")
const SCALED_ROOT := preload("res://scripts/ui/scaled_root.gd")

const CARD_WIDTH := 560.0
const CARD_MARGIN := 24.0

const CONTROLS_TEXT := """WASD / left stick: move      Space: jump      Shift: sprint
Ctrl: slide      Q: dash      Mouse / right-side drag: look
Left click / FIRE: shoot      G: grenade      E / R: next / previous weapon
V: arsenal      H: inspect weapon      T: reload / recharge
Tab: scoreboard      F: plant / defuse
C / VIEW: first / third person camera
B N M J: emotes      Esc / Back: this menu"""

var _ui_root: Control
var _card: Control
var _margin: MarginContainer
var _header: Control
var _touch_target: float = 44.0
## Below this visible height (logical px) the title row is dropped so the settings keep room to scroll.
const COMPACT_HEIGHT := 520.0


func _ready() -> void:
	theme = THEME.make_theme()
	name = "PauseMenu"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 60
	_build()


func _build() -> void:
	_ui_root = SCALED_ROOT.new()
	add_child(_ui_root)
	var content: Control = _ui_root.content
	_touch_target = maxf(48.0, float(_ui_root.touch_target))

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.02, 0.05, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(dim)

	_card = Control.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(_card)

	var plate: Control = PLATE.new()
	plate.name = "Plate"
	plate.fill = THEME.PANEL_DEEP
	plate.edge = THEME.ACCENT
	plate.accent = THEME.ACCENT
	plate.cut = 14.0
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_child(plate)

	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(CARD_MARGIN))
	margin.add_theme_constant_override("margin_right", int(CARD_MARGIN))
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_card.add_child(margin)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", THEME.SPACE_M)
	margin.add_child(frame)

	_header = _build_header()
	frame.add_child(_header)

	var resume := _action_button("RESUME", "play", THEME.ACCENT)
	resume.name = "ResumeButton"
	resume.pressed.connect(func(): resume_requested.emit())
	frame.add_child(resume)

	# Phones in landscape only give ~720 px of height: the settings scroll, the two buttons stay.
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", THEME.SPACE_S)
	scroll.add_child(column)

	column.add_child(_section("LOOK SENSITIVITY", "aim"))
	var sensitivity_slider := _add_slider_row(column, "look_sensitivity", USER_SETTINGS.MIN_LOOK_SENSITIVITY, USER_SETTINGS.MAX_LOOK_SENSITIVITY, 0.0001, USER_SETTINGS.look_sensitivity(), "", 1.0, true)
	sensitivity_slider.value_changed.connect(func(value: float):
		USER_SETTINGS.write_value("input", "look_sensitivity", value)
		sensitivity_changed.emit(value)
	)

	_add_input_rows(column, bool(_ui_root.is_touch))

	column.add_child(_section("MASTER VOLUME", "sound"))
	var volume_slider := _add_slider_row(column, "master_volume", 0.0, 1.0, 0.05, USER_SETTINGS.master_volume(), "%d%%", 100.0, false, "audio")
	volume_slider.value_changed.connect(func(value: float):
		USER_SETTINGS.apply_master_volume(value)
		USER_SETTINGS.write_value("audio", "master_volume", value)
	)

	AUDIO_BUSES.ensure()
	for bus_name in AUDIO_BUSES.ALL:
		column.add_child(_section(str(bus_name).to_upper() + " VOLUME", "sound"))
		var key := "volume_" + str(bus_name).to_lower()
		var slider := _add_slider_row(column, key, 0.0, 1.0, 0.05, USER_SETTINGS.bus_volume(bus_name), "%d%%", 100.0, false, "audio")
		var captured_bus := str(bus_name)
		var captured_key := key
		slider.value_changed.connect(func(value: float):
			USER_SETTINGS.write_value("audio", captured_key, value)
			USER_SETTINGS.apply_bus_volume(captured_bus, value))

	column.add_child(_section("CONTROLS", "info"))
	var help := Label.new()
	help.name = "ControlsHelp"
	help.text = CONTROLS_TEXT
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", THEME.SIZE_S)
	help.add_theme_color_override("font_color", THEME.MUTED)
	column.add_child(help)

	var leave := _action_button("LEAVE MATCH", "leave", THEME.DANGER)
	leave.name = "LeaveButton"
	leave.pressed.connect(func(): leave_requested.emit())
	frame.add_child(leave)

	_ui_root.layout_changed.connect(func(_size: Vector2, _scale: float): _fit_card())
	_fit_card()


## Sizes the card to the visible area: a fixed width on a wide screen, nearly the full height on a phone.
func _fit_card() -> void:
	if _card == null or _ui_root == null:
		return
	var area: Vector2 = _ui_root.content.size
	if area.x < 1.0 or area.y < 1.0:
		area = get_viewport_rect().size
	var compact := area.y < COMPACT_HEIGHT
	_header.visible = not compact
	var pad := 10 if compact else 16
	_margin.add_theme_constant_override("margin_top", pad)
	_margin.add_theme_constant_override("margin_bottom", pad)
	var width := minf(CARD_WIDTH, maxf(area.x - 32.0, 260.0))
	var height := clampf(area.y - 32.0, 240.0, 640.0)
	_card.size = Vector2(width, height)
	_card.position = ((area - _card.size) * 0.5).round()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", THEME.SPACE_M)
	row.add_child(ICONS.make("menu", 34.0, THEME.ACCENT))
	var title := Label.new()
	title.text = "PAUSED"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", THEME.font("bold"))
	title.add_theme_font_size_override("font_size", THEME.SIZE_XL)
	title.add_theme_color_override("font_color", THEME.INK)
	row.add_child(title)
	return row


## A full-width plate button: icon on the left, label next to it. The label is also the Button text.
func _action_button(label_text: String, icon: String, tint: Color) -> Button:
	var button: Button = BUTTON.new()
	button.text = label_text
	button.icon_name = icon
	button.tint = tint
	button.custom_minimum_size = Vector2(0.0, maxf(52.0, _touch_target))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


## Aiming-down-sights sensitivity for everyone; touch and gyro rows only on touch devices.
func _add_input_rows(column: VBoxContainer, touch_device: bool) -> void:
	column.add_child(_section("AIMING DOWN SIGHTS (x of normal)", "aim"))
	_add_slider_row(column, "ads_sensitivity", LOOK.MIN_ADS_SENSITIVITY, 1.0, 0.01, USER_SETTINGS.ads_sensitivity(), "%.2fx")
	if not touch_device:
		return
	column.add_child(_section("TOUCH LOOK SPEED", "view"))
	_add_slider_row(column, "touch_sensitivity", LOOK.MIN_TOUCH_SENSITIVITY, LOOK.MAX_TOUCH_SENSITIVITY, 0.05, USER_SETTINGS.touch_sensitivity(), "%.2fx")
	column.add_child(_section("TOUCH ACCELERATION (faster swipes turn further)", "dash"))
	_add_slider_row(column, "touch_acceleration", 0.0, 1.0, 0.05, USER_SETTINGS.touch_acceleration(), "%d%%", 100.0)
	column.add_child(_section("GYRO", "rotate"))
	var gyro_check := CheckBox.new()
	gyro_check.text = "GYRO AIMING"
	gyro_check.button_pressed = USER_SETTINGS.gyro_enabled()
	gyro_check.custom_minimum_size = Vector2(0.0, _touch_target)
	gyro_check.toggled.connect(func(on: bool):
		USER_SETTINGS.write_value("input", "gyro_enabled", on)
		input_settings_changed.emit()
	)
	column.add_child(gyro_check)
	_add_slider_row(column, "gyro_sensitivity", LOOK.MIN_GYRO_SENSITIVITY, LOOK.MAX_GYRO_SENSITIVITY, 0.05, USER_SETTINGS.gyro_sensitivity(), "%.2fx")
	var calibrate := Button.new()
	calibrate.name = "CalibrateGyro"
	calibrate.text = "CALIBRATE GYRO • HOLD STILL"
	calibrate.custom_minimum_size.y = _touch_target
	calibrate.disabled = not OS.has_feature("android")
	calibrate.tooltip_text = "Available on an Android device with a gyroscope."
	calibrate.pressed.connect(func():
		calibrate.disabled = true
		calibrate.text = "HOLD STILL…"
		var samples := Vector3.ZERO
		for index in range(30):
			await get_tree().process_frame
			if not is_inside_tree():
				return
			samples += Input.get_gyroscope()
		var bias := samples / 30.0
		if bias.is_finite() and bias.length() < 0.2:
			USER_SETTINGS.write_value("input", "gyro_bias", bias)
			input_settings_changed.emit()
			calibrate.text = "GYRO CALIBRATED"
		else:
			calibrate.text = "TOO MUCH MOVEMENT • RETRY"
		calibrate.disabled = false
	)
	column.add_child(calibrate)

	for entry in [["gyro_invert_yaw", "INVERT GYRO LEFT / RIGHT", USER_SETTINGS.gyro_invert_yaw()], ["gyro_invert_pitch", "INVERT GYRO UP / DOWN", USER_SETTINGS.gyro_invert_pitch()]]:
		var invert := CheckBox.new()
		invert.text = str(entry[1])
		invert.button_pressed = bool(entry[2])
		invert.custom_minimum_size = Vector2(0.0, _touch_target)
		var key := str(entry[0])
		invert.toggled.connect(func(on: bool):
			USER_SETTINGS.write_value("input", key, on)
			input_settings_changed.emit()
		)
		column.add_child(invert)


## One labelled slider: the value is saved when it moves, `input_settings_changed` tells the game.
## `friendly` shows the look sensitivity as a multiple of the default; `section_name` is the settings
## section the key is saved in.
func _add_slider_row(column: VBoxContainer, key: String, min_value: float, max_value: float, step: float, value: float, format: String, display_scale: float = 1.0, friendly: bool = false, section_name: String = "input") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", THEME.SPACE_M)
	column.add_child(row)
	var slider := HSlider.new()
	slider.name = "Slider_" + key
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0.0, maxf(32.0, _touch_target * 0.8))
	row.add_child(slider)
	var label := Label.new()
	label.custom_minimum_size = Vector2(64.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", THEME.font("bold"))
	label.add_theme_color_override("font_color", THEME.ACCENT)
	label.text = _sensitivity_text(value) if friendly else format % (value * display_scale)
	row.add_child(label)
	slider.value_changed.connect(func(new_value: float):
		label.text = _sensitivity_text(new_value) if friendly else format % (new_value * display_scale)
		if section_name == "input" and not friendly:
			USER_SETTINGS.write_value("input", key, new_value)
			input_settings_changed.emit()
		elif section_name != "input":
			USER_SETTINGS.write_value(section_name, key, new_value)
	)
	return slider


func _sensitivity_text(value: float) -> String:
	# Shown as a friendly multiple of the default (1.00x = original feel).
	return "%.2fx" % (value / USER_SETTINGS.DEFAULT_LOOK_SENSITIVITY)


## A small icon and an uppercase caption above a group of settings.
func _section(text_value: String, icon: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", THEME.SPACE_S)
	row.add_child(ICONS.make(icon, 18.0, THEME.ACCENT_DIM))
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", THEME.font("bold"))
	label.add_theme_font_size_override("font_size", THEME.SIZE_S)
	label.add_theme_color_override("font_color", THEME.MUTED)
	row.add_child(label)
	return row
