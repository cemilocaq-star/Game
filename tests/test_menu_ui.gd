extends SceneTree
## Regression for the FPS-style main menu: START / CREATE ROOM / JOIN must never be dead buttons,
## the offline-training fallback must work without a server, and the typed server address and room
## code must survive switching tabs. Also checks that every new string exists in all four languages.

const MENU_SCRIPT := preload("res://scripts/oxenwar_menu.gd")
const I18N := preload("res://scripts/oxenwar_i18n.gd")
const USER_SETTINGS := preload("res://scripts/user_settings.gd")

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

	func update_presence() -> Dictionary:
		return {"ok": true}

	func update_profile(_data: Dictionary) -> Dictionary:
		return {"ok": true}

var failures: Array[String] = []
var requests: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var prior_host: Variant = USER_SETTINGS.read_value("network", "server_host", "")
	var backend := FakeBackend.new()
	root.add_child(backend)
	var menu := MENU_SCRIPT.new()
	root.add_child(menu)
	menu.play_requested.connect(func(identity: Dictionary): requests.append(identity))
	await menu.configure(backend, {"ok": true}, "")
	await process_frame

	var start: Button = menu.find_child("StartButton", true, false)
	var create: Button = menu.find_child("CreateRoomButton", true, false)
	var join: Button = menu.find_child("JoinRoomButton", true, false)
	var host_field: LineEdit = menu.find_child("ServerAddressField", true, false)
	var code_field: LineEdit = menu.find_child("RoomCodeField", true, false)
	_check(start != null and create != null and join != null, "play buttons exist")
	_check(host_field != null and code_field != null, "server and room-code fields exist")
	if start == null or create == null or join == null or host_field == null or code_field == null:
		_finish(menu, backend, prior_host)
		return
	_check(not start.disabled and not create.disabled and not join.disabled, "play buttons are never disabled")

	# No server address: START opens the offline training arena, rooms explain what is missing.
	host_field.text = ""
	host_field.text_changed.emit("")
	start.pressed.emit()
	_check(requests.size() == 1, "START without a server launches once")
	if requests.size() == 1:
		_check(str(requests[0].get("launch_action")) == "practice", "START without a server is offline training")
		_check(str(requests[0].get("server_host")) == "", "offline training sends no server host")
	create.pressed.emit()
	_check(requests.size() == 1, "CREATE ROOM without a server does not launch")
	_check(menu.notice_panel.visible, "CREATE ROOM without a server shows a visible hint")
	menu.notice_panel.hide()
	join.pressed.emit()
	_check(requests.size() == 1, "JOIN without a server does not launch")
	_check(menu.notice_panel.visible, "JOIN without a server shows a visible hint")

	# Malformed address blocks everything with an error instead of silently failing.
	host_field.text = "bad host"
	host_field.text_changed.emit("bad host")
	start.pressed.emit()
	_check(requests.size() == 1, "malformed address does not launch")

	# Valid address: all three actions reach the game with the chosen mode and map.
	host_field.text = "wss://example.com"
	host_field.text_changed.emit("wss://example.com")
	var demolition: Button = menu.find_child("Mode_demolition", true, false)
	var jungle: Button = menu.find_child("Map_5", true, false)
	_check(demolition != null and jungle != null, "mode card and map tile exist")
	if demolition != null and jungle != null:
		demolition.pressed.emit()
		jungle.pressed.emit()
	_check(menu.selected_game_mode == "demolition", "mode card selects Bomb Rush")
	_check(menu.selected_map_index == 5, "map tile selects Jungle Arena")
	start.pressed.emit()
	_check(requests.size() == 2 and str(requests[1].get("launch_action")) == "quick_match", "START with a server starts quick match")
	if requests.size() >= 2:
		_check(str(requests[1].get("game_mode")) == "demolition" and int(requests[1].get("map_index")) == 5, "quick match carries mode and map")
		_check(str(requests[1].get("server_host")) == "wss://example.com", "quick match carries the server host")
	create.pressed.emit()
	_check(requests.size() == 3 and str(requests[2].get("launch_action")) == "create_room", "CREATE ROOM with a server creates a room")
	code_field.text = "ab"
	code_field.text_changed.emit("ab")
	join.pressed.emit()
	_check(requests.size() == 3, "JOIN with a short code does not launch")
	code_field.text = "ab234c"
	code_field.text_changed.emit("ab234c")
	_check(code_field.text == "AB234C", "room code is upper-cased while typing")
	join.pressed.emit()
	_check(requests.size() == 4 and str(requests[3].get("launch_action")) == "join_room", "JOIN with a valid code joins")
	if requests.size() >= 4:
		_check(str(requests[3].get("room_code")) == "AB234C", "join carries the normalized room code")

	# Leaving and returning to the play tab keeps what was typed.
	menu.call("_on_tab_pressed", "play")
	await process_frame
	var rebuilt_host: LineEdit = menu.find_child("ServerAddressField", true, false)
	var rebuilt_code: LineEdit = menu.find_child("RoomCodeField", true, false)
	_check(rebuilt_host != null and rebuilt_host.text == "wss://example.com", "server address survives tab switch")
	_check(rebuilt_code != null and rebuilt_code.text == "AB234C", "room code survives tab switch")
	var rebuilt_demolition: Button = menu.find_child("Mode_demolition", true, false)
	_check(rebuilt_demolition != null, "mode cards are rebuilt")

	# Every string added by the redesign exists in all four languages.
	for locale in ["az", "en", "tr", "ru"]:
		for key in I18N.EXTRA["en"].keys():
			_check(I18N.EXTRA[locale].has(key), "missing %s string: %s" % [locale, key])
			_check(I18N.text_for(str(key), locale) != str(key), "untranslated key %s in %s" % [key, locale])

	_finish(menu, backend, prior_host)


func _finish(menu: Node, backend: Node, prior_host: Variant) -> void:
	# Do not leave the test's server address in the player's saved settings.
	if str(prior_host).is_empty():
		var config := ConfigFile.new()
		if config.load(USER_SETTINGS.PATH) == OK and config.has_section_key("network", "server_host"):
			config.erase_section_key("network", "server_host")
			config.save(USER_SETTINGS.PATH)
	else:
		USER_SETTINGS.write_value("network", "server_host", prior_host)
	menu.free()
	backend.free()
	if failures.is_empty():
		print("PASS: menu buttons, offline training fallback, server hints, tab persistence and translations")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
