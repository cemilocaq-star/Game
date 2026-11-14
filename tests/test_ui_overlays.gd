extends SceneTree
## Covers the HUD overlays added in the UI pass: crosshair/hit marker, pause menu signals,
## persisted settings and the kill-feed trimming that used to loop forever.

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const CROSSHAIR_SCRIPT := preload("res://scripts/crosshair_overlay.gd")
const PAUSE_MENU_SCRIPT := preload("res://scripts/pause_menu.gd")
const USER_SETTINGS := preload("res://scripts/user_settings.gd")

var failures: Array[String] = []
var _resume_count := 0
var _leave_count := 0
var _last_sensitivity := -1.0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_user_settings()
	_test_crosshair()
	await _test_pause_menu()
	_test_kill_feed_trim()
	if failures.is_empty():
		print("PASS: user settings, crosshair feedback, pause menu signals and kill-feed trimming")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_user_settings() -> void:
	USER_SETTINGS.write_value("ui_overlay_test", "probe", 42)
	_assert_equal("settings round trip", int(USER_SETTINGS.read_value("ui_overlay_test", "probe", 0)), 42)
	# Writing one section must not discard another one.
	USER_SETTINGS.write_value("ui_overlay_test", "other", "kept")
	_assert_equal("settings keep earlier keys", int(USER_SETTINGS.read_value("ui_overlay_test", "probe", 0)), 42)
	var config := ConfigFile.new()
	if config.load(USER_SETTINGS.PATH) == OK:
		config.erase_section("ui_overlay_test")
		config.save(USER_SETTINGS.PATH)
	var sensitivity: float = USER_SETTINGS.look_sensitivity()
	_assert_true("look sensitivity is clamped", sensitivity >= USER_SETTINGS.MIN_LOOK_SENSITIVITY and sensitivity <= USER_SETTINGS.MAX_LOOK_SENSITIVITY)
	var volume: float = USER_SETTINGS.master_volume()
	_assert_true("master volume is within 0..1", volume >= 0.0 and volume <= 1.0)


func _test_crosshair() -> void:
	var crosshair: Control = CROSSHAIR_SCRIPT.new()
	root.add_child(crosshair)
	crosshair.call("flash_hit", false)
	_assert_true("hit marker starts", float(crosshair.get("_hit_left")) > 0.0)
	crosshair.call("flash_damage", 30.0)
	_assert_true("damage flash starts", float(crosshair.get("_damage_left")) > 0.0)
	crosshair.call("_process", 10.0)
	_assert_true("hit marker expires", float(crosshair.get("_hit_left")) == 0.0)
	_assert_true("damage flash expires", float(crosshair.get("_damage_left")) == 0.0)
	_assert_equal("crosshair ignores the mouse", crosshair.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	crosshair.queue_free()


func _test_pause_menu() -> void:
	var menu: Control = PAUSE_MENU_SCRIPT.new()
	root.add_child(menu)
	await process_frame
	menu.connect("resume_requested", func(): _resume_count += 1)
	menu.connect("leave_requested", func(): _leave_count += 1)
	menu.connect("sensitivity_changed", func(value: float): _last_sensitivity = value)
	_assert_false("pause menu starts hidden", menu.visible)
	var resume := _find_button(menu, "RESUME")
	var leave := _find_button(menu, "LEAVE MATCH")
	_assert_true("resume button exists", resume != null)
	_assert_true("leave button exists", leave != null)
	if resume != null:
		resume.pressed.emit()
	if leave != null:
		leave.pressed.emit()
	_assert_equal("resume signal", _resume_count, 1)
	_assert_equal("leave signal", _leave_count, 1)
	var slider := _find_first_slider(menu)
	_assert_true("sensitivity slider exists", slider != null)
	if slider != null:
		var original := slider.value
		slider.value = USER_SETTINGS.MAX_LOOK_SENSITIVITY
		_assert_true("sensitivity signal fires", is_equal_approx(_last_sensitivity, USER_SETTINGS.MAX_LOOK_SENSITIVITY))
		slider.value = original
	menu.queue_free()


func _test_kill_feed_trim() -> void:
	var harness := Node3D.new()
	harness.set_script(MAIN_SCRIPT)
	var container := VBoxContainer.new()
	root.add_child(container)
	harness.set("kill_feed_container", container)
	for index in range(9):
		harness.call("_on_kill_feed_received", "Killer%d" % index, "Victim%d" % index, "Aether Blaster")
	_assert_true("kill feed keeps at most five entries immediately", container.get_child_count() <= 5)
	container.queue_free()
	harness.free()


func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _find_first_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node as HSlider
	for child in node.get_children():
		var found := _find_first_slider(child)
		if found != null:
			return found
	return null


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append("%s: expected true" % label)


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append("%s: expected false" % label)
