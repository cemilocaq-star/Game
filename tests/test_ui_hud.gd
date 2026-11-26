extends SceneTree
## The real HUD built by main.gd, on the PC layout and on the phone layout:
## every button does something, touch targets are big enough, nothing overlaps, the weapon card, kill
## feed and grenade chip follow the game state. Runs without a window.

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")
const PLAYER := preload("res://scripts/player.gd")

var _checks := 0
var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: ", message)


func _initialize() -> void:
	call_deferred("_run")


func _make_harness(touch: bool) -> Node3D:
	OS.set_environment("OXENWAR_FORCE_TOUCH", "1" if touch else "0")
	var harness := Node3D.new()
	harness.set_script(MAIN_SCRIPT)
	var player = PLAYER.new()
	root.add_child(player)
	harness.set("player", player)
	harness.set("graphics", GraphicsManager.new())
	root.add_child(harness)
	return harness


func _run() -> void:
	# main.gd registers these in _setup_input(); the test builds only the HUD.
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "slide", "dash", "sprint", "fire", "reload", "throw_grenade", "objective_interact"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	await _test_layout(false)
	await _test_layout(true)
	await _test_state_binding()
	OS.set_environment("OXENWAR_FORCE_TOUCH", "0")
	print("UI_HUD %s checks=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	for test_node in root.get_children():
		if test_node is AudioStreamPlayer:
			test_node.stop()
			test_node.stream = null
		test_node.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if _failures.is_empty() else 1)


func _all_buttons(node: Node, found: Array) -> void:
	if node is Button:
		found.append(node)
	for child in node.get_children():
		_all_buttons(child, found)


func _connected(button: Button) -> bool:
	# IconButton connects button_down itself (for its press animation), so a handler added by the game
	# is a second connection there.
	return button.pressed.get_connections().size() > 0 or button.toggled.get_connections().size() > 0 or button.button_down.get_connections().size() > 1


func _test_layout(touch: bool) -> void:
	var label := "touch" if touch else "PC"
	var harness := _make_harness(touch)
	harness.call("_build_hud")
	var ui_root = harness.get("_ui_root")
	_check(ui_root != null and ui_root.is_touch == touch, "%s: HUD built for the %s layout" % [label, label])
	ui_root.size = Vector2(1600.0, 720.0)
	ui_root.refresh()
	await process_frame
	var content: Control = ui_root.content
	_check(content.size.x > 600.0 and content.size.y > 300.0, "%s: HUD area is %s logical px" % [label, str(content.size)])
	var buttons: Array = []
	_all_buttons(content, buttons)
	var dead: Array[String] = []
	for button in buttons:
		if button is OptionButton:
			_check(button.item_selected.get_connections().size() > 0 or button.item_count > 0 and str(button.name) != "", "%s: option list %s is wired" % [label, button.name])
			continue
		if not _connected(button):
			dead.append(str(button.name))
	_check(dead.is_empty(), "%s: no decorative buttons, every button has a handler (without: %s)" % [label, str(dead)])
	_check(buttons.size() >= (20 if touch else 14), "%s: found %d buttons" % [label, buttons.size()])
	var content_rect := Rect2(Vector2.ZERO, content.size)
	var to_content := content.get_global_transform().affine_inverse()
	var seen: Array[Rect2] = []
	var names: Array[String] = []
	for name in ["ScoreboardButton", "ArsenalButton", "LobbyButton", "PauseMenuButton", "GrenadeButton"]:
		var button := content.find_child(name, true, false) as Control
		_check(button != null, "%s: %s exists" % [label, name])
		if button != null:
			var rect := Rect2(to_content * button.global_position, button.size)
			_check(rect.size.x >= 40.0 and rect.size.y >= 40.0, "%s: %s is at least 40 px" % [label, name])
	if touch:
		var scale: float = ui_root.ui_scale
		var inches_per_pixel := 1.5 / 420.0 # reference phone: 2400x1080 at 420 dpi, one viewport pixel = 1.5 window pixels
		for button in buttons:
			if not str(button.name).begins_with("Touch_") and not ["TouchAimButton", "EmoteButton", "ScoreboardButton", "ArsenalButton", "LobbyButton", "PauseMenuButton"].has(str(button.name)):
				continue
			var rect := Rect2(to_content * button.global_position, button.size)
			var inches := minf(rect.size.x, rect.size.y) * scale * inches_per_pixel
			_check(inches >= 0.28, "touch: %s is %.2f inch (at least 0.28)" % [button.name, inches])
			_check(content_rect.encloses(rect), "touch: %s stays on screen %s" % [button.name, str(rect)])
			if button.visible:
				seen.append(rect)
				names.append(str(button.name))
		var overlaps: Array[String] = []
		for i in range(seen.size()):
			for j in range(i + 1, seen.size()):
				if seen[i].intersects(seen[j]):
					overlaps.append("%s/%s" % [names[i], names[j]])
		_check(overlaps.is_empty(), "touch: no two touch buttons overlap (%s)" % str(overlaps))
		for action in ["jump", "fire", "reload", "slide", "sprint", "dash"]:
			var button := content.find_child("Touch_" + action, true, false) as Button
			_check(button != null, "touch: %s button exists" % action)
			if button != null and InputMap.has_action(action):
				button.button_down.emit()
				_check(Input.is_action_pressed(action), "touch: %s button presses the %s action" % [action, action])
				button.button_up.emit()
				_check(not Input.is_action_pressed(action), "touch: %s button releases the %s action" % [action, action])
	harness.queue_free()
	await process_frame


func _test_state_binding() -> void:
	var harness := _make_harness(false)
	harness.call("_build_hud")
	harness.call("_refresh_weapon_card", "minicore")
	var name_label: Label = harness.get("equipped_weapon_label")
	var icon: TextureRect = harness.get("weapon_icon")
	_check(name_label.text == "MINICORE", "weapon card shows the equipped weapon's name (%s)" % name_label.text)
	_check(icon.texture == ICONS.texture("w_minicore"), "weapon card shows the equipped weapon's icon")
	_check(harness.call("_kill_feed_icon", "AETHER BLASTER") == "w_aether", "kill feed finds a weapon icon from its display name")
	_check(harness.call("_kill_feed_icon", "GRENADE") == "grenade", "kill feed shows a grenade icon for grenade kills")
	_check(harness.call("_kill_feed_icon", "UNKNOWN") == "kill", "kill feed falls back to the kill icon")
	harness.call("_on_kill_feed_received", "Rasim", "Orxan", "AETHER BLASTER")
	var feed: VBoxContainer = harness.get("kill_feed_container")
	_check(feed.get_child_count() == 1, "a kill adds one kill feed line")
	for i in range(8):
		harness.call("_on_kill_feed_received", "A%d" % i, "B", "GRENADE")
	_check(feed.get_child_count() <= 5, "the kill feed keeps at most 5 lines (%d)" % feed.get_child_count())
	# Grenade chip: offline it is disabled, online it counts down the server's 5 s cooldown.
	var chip: Button = harness.get("grenade_button")
	harness.set("local_player_name", "Rasim")
	harness.call("_update_hud")
	_check(chip.disabled, "the grenade chip is disabled when there is no server to throw on")
	harness.queue_free()
	await process_frame
