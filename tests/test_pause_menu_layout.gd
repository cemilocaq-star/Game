extends SceneTree
## The pause menu built from the UI foundation, on the PC layout and on the phone layout:
## the card fits the screen, RESUME and LEAVE MATCH stay visible above and below the scrolling
## settings, nothing overlaps, touch targets are big enough, and the signals and saved settings still work.
## Runs without a window.

const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
const SETTINGS := preload("res://scripts/user_settings.gd")

var _checks := 0
var _failures: Array[String] = []
var _resume_count := 0
var _leave_count := 0
var _last_sensitivity := -1.0


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: ", message)


func _initialize() -> void:
	call_deferred("_run")


func _make_menu(touch: bool) -> Control:
	OS.set_environment("OXENWAR_FORCE_TOUCH", "1" if touch else "0")
	DirAccess.remove_absolute(SETTINGS.PATH)
	var menu: Control = PAUSE_MENU.new()
	root.add_child(menu)
	menu.visible = true
	return menu


func _run() -> void:
	await _test_layout(false)
	await _test_layout(true)
	await _test_behaviour()
	OS.set_environment("OXENWAR_FORCE_TOUCH", "0")
	DirAccess.remove_absolute(SETTINGS.PATH)
	print("PAUSE_MENU_LAYOUT %s checks=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_layout(touch: bool) -> void:
	var tag := "touch" if touch else "pc"
	var menu := _make_menu(touch)
	await process_frame
	await process_frame
	var ui_root: Control = menu.get("_ui_root")
	var card: Control = menu.find_child("Card", true, false)
	var resume: Control = menu.find_child("ResumeButton", true, false)
	var leave: Control = menu.find_child("LeaveButton", true, false)
	var scroll: Control = menu.find_child("SettingsScroll", true, false)
	_check(ui_root != null and card != null and resume != null and leave != null and scroll != null, "%s: card, both buttons and the settings scroll exist" % tag)
	if card == null or resume == null or leave == null or scroll == null:
		menu.queue_free()
		return
	_check(ui_root.is_touch == touch, "%s: the layout profile matches the device (%s)" % [tag, str(ui_root.is_touch)])

	# Everything is measured in logical pixels, inside the scaled content area.
	var area := Rect2(Vector2.ZERO, ui_root.content.size)
	var card_rect := Rect2(card.position, card.size)
	_check(area.encloses(card_rect), "%s: the card %s fits the screen %s" % [tag, str(card_rect), str(area)])
	var card_global := card.get_global_rect()
	for control in [resume, leave, scroll]:
		var rect: Rect2 = (control as Control).get_global_rect()
		_check(card_global.grow(1.0).encloses(rect), "%s: %s stays inside the card" % [tag, control.name])
	var resume_rect: Rect2 = resume.get_global_rect()
	var scroll_rect: Rect2 = scroll.get_global_rect()
	var leave_rect: Rect2 = leave.get_global_rect()
	_check(resume_rect.end.y <= scroll_rect.position.y + 0.5, "%s: RESUME is above the settings" % tag)
	_check(scroll_rect.end.y <= leave_rect.position.y + 0.5, "%s: LEAVE MATCH is below the settings" % tag)
	_check(scroll_rect.size.y >= 120.0, "%s: the settings keep a usable height (%.0f)" % [tag, scroll_rect.size.y])

	var scale: float = ui_root.ui_scale
	var inches_per_pixel := 1.5 / 420.0 # reference phone: 2400x1080 at 420 dpi, one viewport pixel = 1.5 window pixels
	if touch:
		for control in [resume, leave]:
			var inches := (control as Control).size.y * scale * inches_per_pixel
			_check(inches >= 0.28, "touch: %s is %.2f inch tall (at least 0.28)" % [control.name, inches])
		for slider in menu.find_children("Slider_*", "HSlider", true, false):
			var inches := (slider as Control).custom_minimum_size.y * scale * inches_per_pixel
			_check(inches >= 0.2, "touch: %s is %.2f inch tall (at least 0.2)" % [slider.name, inches])
		for check in menu.find_children("*", "CheckBox", true, false):
			var inches := (check as Control).custom_minimum_size.y * scale * inches_per_pixel
			_check(inches >= 0.28, "touch: switch '%s' is %.2f inch tall (at least 0.28)" % [(check as CheckBox).text, inches])
		_check(menu.find_child("Slider_touch_sensitivity", true, false) != null, "touch: the touch look slider is shown")
	else:
		_check(resume.size.y >= 48.0, "pc: RESUME is at least 48 px tall")
		_check(menu.find_child("Slider_touch_sensitivity", true, false) == null, "pc: touch rows are hidden")
	_check(menu.find_child("Slider_look_sensitivity", true, false) != null, "%s: the look sensitivity slider exists" % tag)
	_check(menu.find_child("Slider_master_volume", true, false) != null, "%s: the volume slider exists" % tag)

	# A smaller window (a phone in landscape): the card shrinks, the two buttons stay on screen.
	ui_root.content.size = Vector2(640.0, 330.0)
	ui_root.layout_changed.emit(ui_root.content.size, scale)
	await process_frame
	var small_area := Rect2(Vector2.ZERO, ui_root.content.size)
	_check(small_area.encloses(Rect2(card.position, card.size)), "%s: on a 640x330 screen the card still fits" % tag)
	var small_scroll: Rect2 = scroll.get_global_rect()
	_check(small_scroll.size.y >= 40.0, "%s: on a 640x330 screen the settings still get a strip to scroll in (%.0f)" % [tag, small_scroll.size.y])
	menu.queue_free()
	await process_frame


func _test_behaviour() -> void:
	var menu := _make_menu(false)
	await process_frame
	menu.connect("resume_requested", func(): _resume_count += 1)
	menu.connect("leave_requested", func(): _leave_count += 1)
	menu.connect("sensitivity_changed", func(value: float): _last_sensitivity = value)
	var emitted := [0]
	menu.connect("input_settings_changed", func(): emitted[0] += 1)
	(menu.find_child("ResumeButton", true, false) as Button).pressed.emit()
	(menu.find_child("LeaveButton", true, false) as Button).pressed.emit()
	_check(_resume_count == 1 and _leave_count == 1, "RESUME and LEAVE MATCH emit their signals once")

	var look := menu.find_child("Slider_look_sensitivity", true, false) as HSlider
	look.value = SETTINGS.MAX_LOOK_SENSITIVITY
	_check(is_equal_approx(_last_sensitivity, SETTINGS.MAX_LOOK_SENSITIVITY), "the look slider tells the game")
	_check(is_equal_approx(SETTINGS.look_sensitivity(), SETTINGS.MAX_LOOK_SENSITIVITY), "and saves the look sensitivity")
	_check(emitted[0] == 0, "a look change is not an input-settings change")

	var ads := menu.find_child("Slider_ads_sensitivity", true, false) as HSlider
	ads.value = 0.5
	_check(is_equal_approx(SETTINGS.ads_sensitivity(), 0.5) and emitted[0] == 1, "the ADS slider saves and tells the game")

	var volume := menu.find_child("Slider_master_volume", true, false) as HSlider
	volume.value = 0.4
	_check(is_equal_approx(SETTINGS.master_volume(), 0.4), "the volume slider saves the master volume")
	_check(emitted[0] == 1, "a volume change is not an input-settings change")
	menu.queue_free()
	await process_frame
