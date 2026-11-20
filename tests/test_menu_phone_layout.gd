extends SceneTree
## The main menu on a phone: it is scaled for the device (1.0 on PC, larger on touch), the top bar fits
## the narrower logical screen, tab buttons and the main action buttons are comfortable touch targets,
## and every tab can be opened. Runs without a window.

const MENU_SCRIPT := preload("res://scripts/oxenwar_menu.gd")

class FakeBackend extends Node:
	var user_id := "test-user"
	var access_token := "test-token"

	func get_profile() -> Dictionary:
		return {
			"username": "TestPlayer", "display_name": "Test Player", "locale": "en",
			"avatar_color_id": "color_cyan", "outfit_id": "outfit_default", "accessory_id": "accessory_cap"
		}

	func get_role() -> String:
		return "player"

	func get_cosmetics() -> Dictionary:
		return {"inventory": [], "catalog": []}

	func find_server() -> Dictionary:
		return {"ok": false, "none": true, "message": "No online server was found."}

	func update_presence() -> Dictionary:
		return {"ok": true}

	func update_profile(_data: Dictionary) -> Dictionary:
		return {"ok": true}

	func get_player_stats() -> Dictionary:
		return {"ok": true, "data": {"total_score": 0, "total_xp": 0, "matches_played": 0, "total_kills": 0, "total_deaths": 0}}

	func get_weapon_mastery() -> Dictionary:
		return {"ok": true, "data": {"blaster_xp": 0, "grenade_xp": 0}}

	func get_friend_requests() -> Dictionary:
		return {"ok": true, "data": []}

	func get_friends() -> Dictionary:
		return {"ok": true, "data": []}

	func get_friend_presence(_friend_ids: PackedStringArray) -> Dictionary:
		return {"ok": true, "data": []}

var _checks := 0
var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: ", message)


func _initialize() -> void:
	call_deferred("_run")


func _make_menu(touch: bool) -> CanvasLayer:
	OS.set_environment("OXENWAR_FORCE_TOUCH", "1" if touch else "0")
	var backend := FakeBackend.new()
	root.add_child(backend)
	var menu: CanvasLayer = MENU_SCRIPT.new()
	root.add_child(menu)
	await menu.configure(backend, {"ok": true}, "")
	await process_frame
	await process_frame
	return menu


func _all_buttons(node: Node, found: Array) -> void:
	if node is Button:
		found.append(node)
	for child in node.get_children():
		_all_buttons(child, found)


func _run() -> void:
	await _test_layout(false)
	await _test_layout(true)
	OS.set_environment("OXENWAR_FORCE_TOUCH", "0")
	print("MENU_PHONE_LAYOUT %s checks=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	await process_frame
	await process_frame
	for channel in root.get_children():
		if channel is AudioStreamPlayer:
			channel.stop()
			channel.stream = null
			channel.queue_free()
	await create_timer(0.15).timeout
	quit(0 if _failures.is_empty() else 1)


func _test_layout(touch: bool) -> void:
	var tag := "touch" if touch else "pc"
	var menu: CanvasLayer = await _make_menu(touch)
	var scaled: Control = menu.get("scaled_root")
	_check(scaled != null, "%s: the menu has a scaled root" % tag)
	if scaled == null:
		menu.queue_free()
		return
	var scale: float = scaled.ui_scale
	if touch:
		_check(scale > 1.2, "touch: the menu is scaled up (%.2f)" % scale)
	else:
		_check(is_equal_approx(scale, 1.0), "pc: the menu is not scaled (%.2f)" % scale)
	var area: Vector2 = scaled.content.size
	var menu_root: Control = menu.find_child("MenuRoot", true, false)
	_check(menu_root != null and menu_root.size.is_equal_approx(area), "%s: MenuRoot fills the scaled area %s" % [tag, str(area)])

	var top_bar: Control = menu.find_child("TopBar", true, false)
	_check(top_bar != null, "%s: the top bar exists" % tag)
	if top_bar != null:
		var needed := top_bar.get_combined_minimum_size().x
		_check(needed <= area.x - 56.0, "%s: the top bar (%.0f px) fits the %.0f px wide screen" % [tag, needed, area.x])

	var inches_per_pixel := 1.5 / 420.0 # reference phone: 2400x1080 at 420 dpi, one viewport pixel = 1.5 window pixels
	var nav_buttons := []
	for tab in ["play", "stats", "friends", "character"]:
		var nav := menu.find_child("Nav_" + tab, true, false)
		_check(nav != null, "%s: tab %s exists" % [tag, tab])
		if nav != null:
			nav_buttons.append(nav)
	if touch:
		for nav in nav_buttons:
			var inches := (nav as Control).custom_minimum_size.y * scale * inches_per_pixel
			_check(inches >= 0.28, "touch: tab %s is %.2f inch tall (at least 0.28)" % [nav.name, inches])

	# Every tab opens without an error and keeps the menu usable.
	for tab in ["stats", "friends", "character", "play"]:
		var nav := menu.find_child("Nav_" + tab, true, false) as Button
		if nav != null:
			nav.pressed.emit()
			await process_frame
			await process_frame
			_check(menu.get("active_tab") == tab, "%s: tab %s opens" % [tag, tab])
			var tab_content: Control = menu.get("content")
			if tab_content != null:
				var wide := tab_content.get_combined_minimum_size().x
				_check(wide <= area.x - 56.0, "%s: the %s tab (%.0f px) fits the %.0f px wide screen" % [tag, tab, wide, area.x])

	if touch:
		var buttons := []
		_all_buttons(menu, buttons)
		var small := []
		for button in buttons:
			var control := button as Control
			if not control.is_visible_in_tree() or control.size.y < 1.0:
				continue
			var height := maxf(control.size.y, control.custom_minimum_size.y)
			if height * scale * inches_per_pixel < 0.26:
				small.append("%s (%s, %.0f px)" % [control.name, (button as Button).text, height])
		_check(small.is_empty(), "touch: every visible button is at least 0.26 inch tall, too small: %s" % str(small))
	menu.queue_free()
	await process_frame
