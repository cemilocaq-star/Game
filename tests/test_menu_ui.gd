extends SceneTree
## Regression for the FPS-style main menu: START / CREATE ROOM / JOIN must never be dead buttons,
## the server is found automatically (JOIN needs only a room code), rooms explain when no server is
## online, and the typed room code and optional custom address must survive switching tabs. Also checks that every new string exists in all four languages.

const MENU_SCRIPT := preload("res://scripts/oxenwar_menu.gd")
const I18N := preload("res://scripts/oxenwar_i18n.gd")
const USER_SETTINGS := preload("res://scripts/user_settings.gd")

class FakeBackend extends Node:
	var user_id := "test-user"
	var access_token := "test-token"
	var server_online := false

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
		if server_online:
			return {"ok": true, "host": "wss://auto.example", "stale": false, "player_count": 3, "max_players": 32}
		return {"ok": false, "none": true, "message": "No online server was found."}

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
	host_field.text = ""
	host_field.text_changed.emit("")

	# No server is online: START opens the offline training arena (main resolves it), rooms explain why not.
	_check(menu.auto_server_state == "none", "lookup with no registered server reports none")
	start.pressed.emit()
	_check(requests.size() == 1, "START with no server online still launches")
	if requests.size() == 1:
		_check(str(requests[0].get("launch_action")) == "quick_match", "START requests a quick match")
		_check(str(requests[0].get("server_host")) == "", "no server address is needed or sent")
	# CREATE ROOM and JOIN are not blocked either: the game itself looks for a server (LAN, hosted) and
	# CREATE ROOM hosts the room on this device when nothing else exists.
	create.pressed.emit()
	_check(requests.size() == 2 and str(requests[1].get("launch_action")) == "create_room", "CREATE ROOM with no server online still launches (hosts here)")
	code_field.text = "AB234C"
	code_field.text_changed.emit("AB234C")
	join.pressed.emit()
	_check(requests.size() == 3 and str(requests[2].get("launch_action")) == "join_room", "JOIN with a code launches (the game finds the host on the network)")
	_check(str(requests[2].get("room_code")) == "AB234C", "JOIN carries the room code")
	_check(not bool(requests[2].get("guest", true)), "a signed-in player is not a guest")
	var base := requests.size()

	# A server comes online: the address is never typed. START, CREATE ROOM and JOIN (room code only) all launch.
	backend.server_online = true
	menu.call("_on_tab_pressed", "play")
	await process_frame
	start = menu.find_child("StartButton", true, false)
	create = menu.find_child("CreateRoomButton", true, false)
	join = menu.find_child("JoinRoomButton", true, false)
	host_field = menu.find_child("ServerAddressField", true, false)
	code_field = menu.find_child("RoomCodeField", true, false)
	_check(menu.auto_server_state == "online", "lookup finds the registered server")
	_check(not host_field.visible, "server address box is hidden by default (advanced option)")
	var demolition: Button = menu.find_child("Mode_demolition", true, false)
	var jungle: Button = menu.find_child("Map_5", true, false)
	_check(demolition != null and jungle != null, "mode card and map tile exist")
	if demolition != null and jungle != null:
		demolition.pressed.emit()
		jungle.pressed.emit()
	_check(menu.selected_game_mode == "demolition", "mode card selects Bomb Rush")
	_check(menu.selected_map_index == 5, "map tile selects Jungle Arena")
	start.pressed.emit()
	_check(requests.size() == base + 1 and str(requests[base].get("launch_action")) == "quick_match", "START with a server online starts quick match")
	if requests.size() >= base + 1:
		_check(str(requests[base].get("game_mode")) == "demolition" and int(requests[base].get("map_index")) == 5, "quick match carries mode and map")
		_check(str(requests[base].get("server_host")) == "", "server is resolved automatically, no host sent")
	create.pressed.emit()
	_check(requests.size() == base + 2 and str(requests[base + 1].get("launch_action")) == "create_room", "CREATE ROOM creates a room")
	code_field.text = "ab"
	code_field.text_changed.emit("ab")
	join.pressed.emit()
	_check(requests.size() == base + 2, "JOIN with a short code does not launch")
	code_field.text = "xjhwe2"
	code_field.text_changed.emit("xjhwe2")
	_check(code_field.text == "XJHWE2", "room code is upper-cased while typing")
	join.pressed.emit()
	_check(requests.size() == base + 3 and str(requests[base + 2].get("launch_action")) == "join_room", "JOIN with only a room code joins")
	if requests.size() >= base + 3:
		_check(str(requests[base + 2].get("room_code")) == "XJHWE2", "join carries the normalized room code")
		_check(str(requests[base + 2].get("server_host")) == "", "join needs no server address")

	# Advanced: a custom server address still works, and a malformed one is rejected with an error.
	host_field.text = "bad host"
	host_field.text_changed.emit("bad host")
	start.pressed.emit()
	_check(requests.size() == base + 3, "malformed custom address does not launch")
	host_field.text = "wss://example.com"
	host_field.text_changed.emit("wss://example.com")
	start.pressed.emit()
	_check(requests.size() == base + 4 and str(requests[base + 3].get("server_host")) == "wss://example.com", "custom server address is sent")

	# Leaving and returning to the play tab keeps what was typed.
	menu.call("_on_tab_pressed", "play")
	await process_frame
	var rebuilt_host: LineEdit = menu.find_child("ServerAddressField", true, false)
	var rebuilt_code: LineEdit = menu.find_child("RoomCodeField", true, false)
	_check(rebuilt_host != null and rebuilt_host.text == "wss://example.com", "custom address survives tab switch")
	_check(rebuilt_host != null and rebuilt_host.visible, "custom address box stays open when an address is set")
	_check(rebuilt_code != null and rebuilt_code.text == "XJHWE2", "room code survives tab switch")
	_check(menu.find_child("Mode_demolition", true, false) != null, "mode cards are rebuilt")

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
		await process_frame
		await process_frame
		for channel in root.get_children():
			if channel is AudioStreamPlayer:
				channel.stop()
				channel.stream = null
				channel.queue_free()
		await create_timer(0.15).timeout
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		await process_frame
		await process_frame
		for channel in root.get_children():
			if channel is AudioStreamPlayer:
				channel.stop()
				channel.stream = null
				channel.queue_free()
		await create_timer(0.15).timeout
		quit(1)
