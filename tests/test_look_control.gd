extends SceneTree
## Touch look, gyro and aiming-down-sights: the maths, the saved settings, the player wiring, the
## pause menu rows and the on-screen AIM button. Everything that can run without a device.

const LOOK := preload("res://scripts/look_control.gd")
const SETTINGS := preload("res://scripts/user_settings.gd")
const PLAYER := preload("res://scripts/player.gd")
const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
const MAIN_SCRIPT := preload("res://scripts/main.gd")

const SENS := 0.0022
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _near(a: float, b: float, tolerance: float = 0.0001) -> bool:
	return absf(a - b) <= tolerance


func _run() -> void:
	_test_device_scale()
	_test_touch_gain()
	_test_ads_scale()
	_test_touch_turn()
	_test_gyro()
	_test_settings()
	await _test_player()
	await _test_pause_menu()
	await _test_aim_button()
	if failures.is_empty():
		print("PASS: touch look, gyro, ADS and acceleration (maths, settings, player, pause menu, AIM button)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_device_scale() -> void:
	var phone: float = LOOK.device_scale(420.0, Vector2(2400.0, 1080.0))
	_check(_near(phone, 1.0, 0.03), "the reference phone is 1.0 (%f)" % phone)
	_check(LOOK.device_scale(0.0, Vector2(2400.0, 1080.0)) == 1.0, "unknown density changes nothing")
	_check(LOOK.device_scale(420.0, Vector2.ZERO) == 1.0, "an unknown window changes nothing")
	var tablet: float = LOOK.device_scale(264.0, Vector2(2560.0, 1600.0))
	_check(tablet > 1.2 and tablet <= LOOK.MAX_DEVICE_SCALE, "a big low-density tablet turns more per pixel (%f)" % tablet)
	_check(LOOK.device_scale(1.0, Vector2(2560.0, 1600.0)) == 1.0, "a density below 1 dpi is treated as unknown")
	_check(LOOK.device_scale(900.0, Vector2(1280.0, 720.0)) == LOOK.MIN_DEVICE_SCALE, "extremes are clamped low")
	_check(LOOK.device_scale(100.0, Vector2(2560.0, 1600.0)) == LOOK.MAX_DEVICE_SCALE, "extremes are clamped high")
	# The same physical swipe turns the same on two devices (inside the clamp range).
	var other: float = LOOK.device_scale(320.0, Vector2(1920.0, 1200.0))
	var phone_px := 1.0 / (1.5 / 420.0) # one inch in viewport pixels
	var other_px := 1.0 / (1.5 / 320.0)
	_check(_near(phone_px * phone, other_px * other, 3.0), "one inch of swipe turns the same on both (%f vs %f)" % [phone_px * phone, other_px * other])


func _test_touch_gain() -> void:
	_check(LOOK.touch_gain(5000.0, 0.0) == 1.0, "acceleration 0 never changes the gain")
	_check(LOOK.touch_gain(100.0, 1.0) == 1.0, "slow swipes keep full precision")
	_check(_near(LOOK.touch_gain(2500.0, 1.0), 1.0 + LOOK.ACCEL_MAX_BONUS), "a fast swipe at full acceleration gets the full bonus")
	_check(_near(LOOK.touch_gain(99999.0, 1.0), 1.0 + LOOK.ACCEL_MAX_BONUS), "the bonus is capped")
	var previous := 1.0
	var steady := true
	for speed in range(0, 3000, 50):
		var gain: float = LOOK.touch_gain(float(speed), 0.6)
		if gain < previous - 0.000001:
			steady = false
		previous = gain
	_check(steady, "gain never falls as the swipe gets faster")
	_check(LOOK.touch_gain(-2500.0, 1.0) == LOOK.touch_gain(2500.0, 1.0), "direction does not matter")
	_check(LOOK.touch_gain(1000.0, 0.5) < LOOK.touch_gain(1000.0, 1.0), "more acceleration, more gain")
	_check(LOOK.touch_gain(1000.0, 5.0) == LOOK.touch_gain(1000.0, 1.0), "the setting is clamped")


func _test_ads_scale() -> void:
	_check(LOOK.ads_scale(0.7, 0.0) == 1.0, "no change at the hip")
	_check(_near(LOOK.ads_scale(0.7, 1.0), 0.7), "fully zoomed uses the setting")
	_check(LOOK.ads_scale(0.7, 0.5) > 0.7 and LOOK.ads_scale(0.7, 0.5) < 1.0, "it eases in with the zoom")
	_check(_near(LOOK.ads_scale(0.01, 1.0), LOOK.MIN_ADS_SENSITIVITY, 0.000001), "the setting cannot freeze the view")
	_check(LOOK.ads_scale(3.0, 1.0) == 1.0, "ADS never speeds the view up")
	_check(LOOK.ads_scale(0.7, 4.0) == LOOK.ads_scale(0.7, 1.0), "the blend is clamped")


func _test_touch_turn() -> void:
	# Defaults on the reference phone give exactly the old `relative * look_sensitivity`.
	var turn: Vector2 = LOOK.touch_turn(Vector2(10.0, -4.0), 0.0, SENS, 1.0, 0.0, 1.0, 1.0)
	_check(_near(turn.x, -10.0 * SENS, 0.000001) and _near(turn.y, 4.0 * SENS, 0.000001), "defaults reproduce the original touch look")
	_check(LOOK.touch_turn(Vector2(10.0, 0.0), 0.0, SENS, 1.0, 0.0, 1.0, 1.0).x < 0.0, "dragging right turns right (negative yaw)")
	_check(LOOK.touch_turn(Vector2(0.0, 10.0), 0.0, SENS, 1.0, 0.0, 1.0, 1.0).y < 0.0, "dragging down looks down")
	var base: float = absf(LOOK.touch_turn(Vector2(10.0, 0.0), 0.0, SENS, 1.0, 0.0, 1.0, 1.0).x)
	_check(_near(absf(LOOK.touch_turn(Vector2(10.0, 0.0), 0.0, SENS, 2.0, 0.0, 1.0, 1.0).x), base * 2.0, 0.000001), "touch sensitivity scales linearly")
	_check(absf(LOOK.touch_turn(Vector2(10.0, 0.0), 0.0, SENS, 99.0, 0.0, 1.0, 1.0).x) <= base * LOOK.MAX_TOUCH_SENSITIVITY + 0.000001, "touch sensitivity is clamped")
	_check(absf(LOOK.touch_turn(Vector2(10.0, 0.0), 2500.0, SENS, 1.0, 1.0, 1.0, 1.0).x) > base * 2.4, "a fast swipe with acceleration turns much further")
	_check(_near(absf(LOOK.touch_turn(Vector2(10.0, 0.0), 0.0, SENS, 1.0, 0.0, 1.0, 0.5).x), base * 0.5, 0.000001), "the ADS factor scales the turn")
	_check(LOOK.touch_turn(Vector2.ZERO, 900.0, SENS, 1.0, 1.0, 1.0, 1.0) == Vector2.ZERO, "no movement, no turn")


func _test_gyro() -> void:
	_check(LOOK.gyro_filter(0.0) == 0.0 and LOOK.gyro_filter(LOOK.GYRO_DEADZONE * 0.9) == 0.0, "sensor noise is removed")
	_check(LOOK.gyro_filter(-LOOK.GYRO_DEADZONE * 0.9) == 0.0, "noise either way")
	_check(_near(LOOK.gyro_filter(1.0), 1.0 - LOOK.GYRO_DEADZONE), "a real turn loses only the deadzone")
	_check(_near(LOOK.gyro_filter(-1.0), -(1.0 - LOOK.GYRO_DEADZONE)), "and keeps its sign")
	_check(LOOK.gyro_filter(LOOK.GYRO_DEADZONE + 0.001) < 0.002, "it eases in from the edge of the deadzone")
	_check(LOOK.gyro_filter(LOOK.GYRO_MAX_RATE + 1.0) == 0.0, "a glitch spike is ignored")
	_check(LOOK.gyro_filter(NAN) == 0.0 and LOOK.gyro_filter(INF) == 0.0, "bad readings are ignored")
	var dt := 1.0 / 60.0
	var turn: Vector2 = LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), dt, SENS, 1.0, 1.0)
	_check(_near(turn.x, -(1.0 - LOOK.GYRO_DEADZONE) * SENS * 70.0 * dt, 0.000001), "yaw follows the original formula (%f)" % turn.x)
	_check(_near(turn.y, -(0.5 - LOOK.GYRO_DEADZONE) * SENS * 70.0 * dt, 0.000001), "pitch follows the original formula")
	_check(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), dt, SENS, 1.0, 1.0, true, false).x == -turn.x, "invert yaw flips only yaw")
	_check(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), dt, SENS, 1.0, 1.0, true, false).y == turn.y, "and leaves pitch")
	_check(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), dt, SENS, 1.0, 1.0, false, true).y == -turn.y, "invert pitch flips only pitch")
	_check(_near(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), dt, SENS, 2.0, 1.0).x, turn.x * 2.0, 0.000001), "gyro sensitivity scales linearly")
	_check(_near(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), dt, SENS, 1.0, 0.5).x, turn.x * 0.5, 0.000001), "ADS slows the gyro too")
	_check(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), 0.0, SENS, 1.0, 1.0) == Vector2.ZERO, "no time, no turn")
	_check(LOOK.gyro_turn(Vector3(0.5, 1.0, 0.0), -1.0, SENS, 1.0, 1.0) == Vector2.ZERO, "negative time, no turn")
	_check(LOOK.gyro_turn(Vector3(0.01, -0.01, 0.9), dt, SENS, 1.0, 1.0) == Vector2.ZERO, "a phone held still, rolling a little, does not drift the view")
	# A full second of a 90 degree/s turn at gyro sensitivity 1/0.154: one-to-one with the hand.
	var one_to_one := Vector2.ZERO
	for frame in range(60):
		one_to_one += LOOK.gyro_turn(Vector3(0.0, deg_to_rad(90.0), 0.0), dt, SENS, 1.0 / (SENS * LOOK.GYRO_BASE_GAIN), 1.0)
	_check(absf(rad_to_deg(one_to_one.x)) > 85.0 and absf(rad_to_deg(one_to_one.x)) <= 90.0, "at 1:1 a 90 degree/s turn turns the view about 90 degrees (%f)" % rad_to_deg(one_to_one.x))


func _test_settings() -> void:
	DirAccess.remove_absolute(SETTINGS.PATH)
	_check(SETTINGS.touch_sensitivity() == 1.0 and SETTINGS.touch_acceleration() == 0.0, "touch defaults keep the original feel")
	_check(_near(SETTINGS.ads_sensitivity(), LOOK.DEFAULT_ADS_SENSITIVITY) and SETTINGS.gyro_enabled(), "ADS default and gyro on by default")
	_check(SETTINGS.gyro_sensitivity() == 1.0 and not SETTINGS.gyro_invert_yaw() and not SETTINGS.gyro_invert_pitch(), "gyro defaults keep the original feel")
	SETTINGS.write_value("input", "touch_sensitivity", 99.0)
	SETTINGS.write_value("input", "touch_acceleration", -3.0)
	SETTINGS.write_value("input", "ads_sensitivity", 0.0)
	SETTINGS.write_value("input", "gyro_sensitivity", 0.0)
	SETTINGS.write_value("input", "gyro_enabled", false)
	SETTINGS.write_value("input", "gyro_invert_yaw", true)
	_check(SETTINGS.touch_sensitivity() == LOOK.MAX_TOUCH_SENSITIVITY, "saved values are clamped (touch)")
	_check(SETTINGS.touch_acceleration() == 0.0, "saved values are clamped (acceleration)")
	_check(SETTINGS.ads_sensitivity() == LOOK.MIN_ADS_SENSITIVITY, "saved values are clamped (ADS)")
	_check(SETTINGS.gyro_sensitivity() == LOOK.MIN_GYRO_SENSITIVITY, "saved values are clamped (gyro)")
	_check(not SETTINGS.gyro_enabled() and SETTINGS.gyro_invert_yaw(), "switches round-trip")
	_check(_near(SETTINGS.look_sensitivity(), SETTINGS.DEFAULT_LOOK_SENSITIVITY), "the look sensitivity section is untouched")
	DirAccess.remove_absolute(SETTINGS.PATH)


func _test_player() -> void:
	DirAccess.remove_absolute(SETTINGS.PATH)
	var player = PLAYER.new()
	root.add_child(player)
	await process_frame
	await process_frame
	player.set("_intro_left", 0.0)
	player.look_sensitivity = SENS
	player.load_input_settings()
	_check(player.gyro_enabled and player.touch_sensitivity == 1.0 and player.device_look_scale == 1.0, "a player loads the defaults (device scale 1.0 off a touch device)")

	# Touch drag.
	var yaw_before: float = player.rotation.y
	player.apply_touch_drag(Vector2(100.0, 0.0), 0.0)
	_check(_near(player.rotation.y - yaw_before, -100.0 * SENS, 0.0001), "a touch drag turns the player like the mouse did (%f)" % (player.rotation.y - yaw_before))
	player.pitch = 0.0
	player.apply_touch_drag(Vector2(0.0, -50.0), 0.0)
	_check(_near(player.pitch, 50.0 * SENS, 0.0001) and _near(player.get("_camera").rotation.x, player.pitch), "dragging up looks up and moves the camera")
	player.apply_touch_drag(Vector2(0.0, -100000.0), 0.0)
	_check(_near(player.pitch, deg_to_rad(82.0), 0.0001), "pitch stops at 82 degrees up")
	player.apply_touch_drag(Vector2(0.0, 100000.0), 0.0)
	_check(_near(player.pitch, deg_to_rad(-82.0), 0.0001), "and at 82 degrees down")
	player.pitch = 0.0
	player.ui_blocked = true
	var frozen: float = player.rotation.y
	player.apply_touch_drag(Vector2(100.0, 50.0), 0.0)
	player.apply_gyro(Vector3(2.0, 2.0, 0.0), 0.05)
	player._apply_look(Vector2(50.0, 50.0))
	_check(player.rotation.y == frozen and player.pitch == 0.0, "no look while a menu is open")
	player.ui_blocked = false

	# Gyro.
	var gyro_before: float = player.rotation.y
	player.apply_gyro(Vector3(0.0, 1.0, 0.0), 0.05)
	_check(player.rotation.y != gyro_before, "gyro turns the view")
	player.gyro_enabled = false
	gyro_before = player.rotation.y
	player.apply_gyro(Vector3(0.0, 1.0, 0.0), 0.05)
	_check(player.rotation.y == gyro_before, "gyro off means no turn")
	player.gyro_enabled = true
	player.is_dead = true
	player.apply_gyro(Vector3(0.0, 1.0, 0.0), 0.05)
	_check(player.rotation.y == gyro_before, "no gyro look while defeated")
	player.is_dead = false

	# ADS: the same swipe turns less while zoomed in.
	var view_anim = player.get("_view_anim")
	player.ads_sensitivity = 0.5
	view_anim.ads = 0.0
	var hip_before: float = player.rotation.y
	player.apply_touch_drag(Vector2(100.0, 0.0), 0.0)
	var hip_turn: float = absf(player.rotation.y - hip_before)
	view_anim.ads = 1.0
	var ads_before: float = player.rotation.y
	player.apply_touch_drag(Vector2(100.0, 0.0), 0.0)
	var ads_turn: float = absf(player.rotation.y - ads_before)
	_check(_near(ads_turn, hip_turn * 0.5, 0.0001), "zoomed in, the same swipe turns half as far (%f vs %f)" % [ads_turn, hip_turn])
	ads_before = player.rotation.y
	player._apply_look(Vector2(100.0, 0.0))
	_check(_near(absf(player.rotation.y - ads_before), hip_turn * 0.5, 0.0001), "the mouse gets the same ADS slow-down")
	ads_before = player.rotation.y
	player.apply_gyro(Vector3(0.0, 1.0, 0.0), 0.05)
	var gyro_ads: float = absf(player.rotation.y - ads_before)
	view_anim.ads = 0.0
	ads_before = player.rotation.y
	player.apply_gyro(Vector3(0.0, 1.0, 0.0), 0.05)
	_check(_near(gyro_ads, absf(player.rotation.y - ads_before) * 0.5, 0.0001), "and so does the gyro")

	# The AIM toggle.
	player.set_touch_aim(true)
	_check(player.get("_aim_held") and player._weapon_aim_allowed(), "the AIM button starts aiming")
	player.set_touch_aim(false)
	_check(not player.get("_aim_held"), "and stops it")
	player.is_dead = true
	player.set_touch_aim(true)
	_check(not player.get("_aim_held"), "a defeated player cannot aim")
	player.is_dead = false

	# Saved settings reach the player.
	SETTINGS.write_value("input", "touch_sensitivity", 1.5)
	SETTINGS.write_value("input", "gyro_enabled", false)
	SETTINGS.write_value("input", "gyro_invert_pitch", true)
	player.load_input_settings()
	_check(player.touch_sensitivity == 1.5 and not player.gyro_enabled and player.gyro_invert_pitch, "load_input_settings picks up the saved values")
	DirAccess.remove_absolute(SETTINGS.PATH)
	player.queue_free()


func _test_pause_menu() -> void:
	DirAccess.remove_absolute(SETTINGS.PATH)
	var menu := PAUSE_MENU.new()
	root.add_child(menu)
	await process_frame
	var ads_slider := menu.find_child("Slider_ads_sensitivity", true, false) as HSlider
	_check(ads_slider != null, "the pause menu has an ADS slider")
	_check(menu.find_child("Slider_touch_sensitivity", true, false) == null, "touch rows are hidden off a touch device")
	var emitted := [0]
	menu.input_settings_changed.connect(func(): emitted[0] += 1)
	if ads_slider != null:
		ads_slider.value = 0.5
		_check(_near(SETTINGS.ads_sensitivity(), 0.5), "moving the ADS slider saves the setting")
		_check(emitted[0] >= 1, "and tells the game")

	var column := VBoxContainer.new()
	root.add_child(column)
	menu.call("_add_input_rows", column, true)
	for key in ["ads_sensitivity", "touch_sensitivity", "touch_acceleration", "gyro_sensitivity"]:
		_check(column.find_child("Slider_" + key, true, false) != null, "a touch device gets the %s slider" % key)
	var checks := column.find_children("*", "CheckBox", true, false)
	_check(checks.size() == 3, "gyro on/off plus two invert switches (%d)" % checks.size())
	if checks.size() == 3:
		(checks[0] as CheckBox).button_pressed = false
		_check(not SETTINGS.gyro_enabled(), "the gyro switch saves")
		(checks[1] as CheckBox).button_pressed = true
		_check(SETTINGS.gyro_invert_yaw(), "the invert switch saves")
	var touch_slider := column.find_child("Slider_touch_acceleration", true, false) as HSlider
	if touch_slider != null:
		touch_slider.value = 0.4
		_check(_near(SETTINGS.touch_acceleration(), 0.4), "the acceleration slider saves")
	DirAccess.remove_absolute(SETTINGS.PATH)
	menu.queue_free()
	column.queue_free()


func _test_aim_button() -> void:
	var harness := Node3D.new()
	harness.set_script(MAIN_SCRIPT)
	var player = PLAYER.new()
	root.add_child(player)
	await process_frame
	harness.set("player", player)
	var controls := Control.new()
	root.add_child(controls)
	harness.call("_build_touch_controls", controls)
	var button := controls.find_child("TouchAimButton", true, false) as Button
	_check(button != null and button.toggle_mode, "the touch controls have a toggle AIM button")
	if button != null:
		button.button_pressed = true
		_check(player.get("_aim_held"), "pressing AIM aims")
		harness.call("_release_all_touch_actions")
		_check(not button.button_pressed and not player.get("_aim_held"), "closing a menu releases AIM")
		button.button_pressed = true
		button.button_pressed = false
		_check(not player.get("_aim_held"), "pressing AIM again stops aiming")
		var overlap := false
		for other in controls.get_children():
			if other != button and other is Button and Rect2((other as Button).position, (other as Button).size).intersects(Rect2(button.position, button.size)):
				overlap = true
		_check(not overlap, "the AIM button does not sit on another button")
	player.queue_free()
	harness.free()
	controls.queue_free()
