extends SceneTree
## Guest entry: a name and one button, no account. The guest reaches the play screen, can START, CREATE
## ROOM and JOIN with a code, the request says it is a guest, and there are no account tabs.

const MENU_SCRIPT := preload("res://scripts/oxenwar_menu.gd")
const I18N := preload("res://scripts/oxenwar_i18n.gd")
const USER_SETTINGS := preload("res://scripts/user_settings.gd")

class SignedOutBackend extends Node:
	var user_id := ""
	var access_token := ""
	var calls: Array[String] = []

	func get_profile() -> Dictionary:
		calls.append("get_profile")
		return {}

	func find_server() -> Dictionary:
		calls.append("find_server")
		return {"ok": false}

	func update_presence() -> Dictionary:
		calls.append("update_presence")
		return {"ok": true}

	func update_profile(_data: Dictionary) -> Dictionary:
		calls.append("update_profile")
		return {"ok": true}

	func sign_out() -> void:
		calls.append("sign_out")

var failures: Array[String] = []
var requests: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var prior_name: Variant = USER_SETTINGS.read_value("guest", "name", "")
	var backend := SignedOutBackend.new()
	root.add_child(backend)
	var menu := MENU_SCRIPT.new()
	root.add_child(menu)
	menu.play_requested.connect(func(identity: Dictionary): requests.append(identity))
	await menu.configure(backend, {"ok": false}, "")
	await process_frame

	_check(not menu.authenticated, "signed-out menu starts on the sign-in screen")
	var guest_field: LineEdit = menu.find_child("GuestNameField", true, false)
	var guest_button: Button = menu.find_child("GuestPlayButton", true, false)
	_check(guest_field != null and guest_button != null, "guest name field and button exist on the sign-in screen")
	_check(menu.find_child("AuthScroll", true, false) != null, "sign-in screen scrolls on a small screen")
	if guest_field == null or guest_button == null:
		_finish(menu, backend, prior_name)
		return
	guest_field.text = "Ali"
	guest_button.pressed.emit()
	await process_frame
	_check(menu.authenticated and menu.is_guest, "guest button signs in as a guest")
	_check(str(menu.profile.get("display_name", "")) == "Ali", "guest profile carries the typed name")
	_check(menu.find_child("MainNav", true, false) == null, "guest has no account tabs")
	_check(menu.find_child("StartButton", true, false) != null, "guest sees the play screen")
	_check(not backend.calls.has("update_presence") and not backend.calls.has("get_profile"), "guest never touches the account (presence, profile); the public server lookup is allowed")

	var create: Button = menu.find_child("CreateRoomButton", true, false)
	var join: Button = menu.find_child("JoinRoomButton", true, false)
	var code_field: LineEdit = menu.find_child("RoomCodeField", true, false)
	_check(create != null and join != null and code_field != null, "guest can create or join a room")
	if create != null and join != null and code_field != null:
		create.pressed.emit()
		_check(requests.size() == 1 and str(requests[0].get("launch_action")) == "create_room", "guest CREATE ROOM launches")
		_check(bool(requests[0].get("guest", false)) and str(requests[0].get("display_name")) == "Ali", "request is marked as a guest with the name")
		code_field.text = "ab234c"
		code_field.text_changed.emit("ab234c")
		join.pressed.emit()
		_check(requests.size() == 2 and str(requests[1].get("room_code")) == "AB234C", "guest JOIN carries only the room code")
		_check(str(requests[1].get("server_host")) == "", "no server address is typed")

	# Signing out of a guest session returns to the sign-in screen without touching the account backend.
	var sign_out: Button = menu.find_child("SignOutButton", true, false)
	_check(sign_out != null, "guest has a way back to the sign-in screen")
	if sign_out != null:
		sign_out.pressed.emit()
		await process_frame
		await process_frame
		_check(not menu.authenticated and not menu.is_guest, "leaving guest mode shows sign-in again")
		_check(not backend.calls.has("sign_out"), "leaving guest mode does not call sign_out")

	for locale in ["az", "en", "tr", "ru"]:
		for key in ["guest_play", "guest_hint", "guest_name", "guest_badge", "guest_sign_in", "server_lan_online"]:
			_check(I18N.text_for(key, locale) != key, "untranslated %s in %s" % [key, locale])
	_finish(menu, backend, prior_name)


func _finish(menu: Node, backend: Node, prior_name: Variant) -> void:
	var config := ConfigFile.new()
	if config.load(USER_SETTINGS.PATH) == OK:
		if str(prior_name).is_empty():
			if config.has_section_key("guest", "name"):
				config.erase_section_key("guest", "name")
		else:
			config.set_value("guest", "name", prior_name)
		config.save(USER_SETTINGS.PATH)
	menu.free()
	backend.free()
	if failures.is_empty():
		print("PASS: guest menu entry")
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
			print("FAIL: ", failure)
		await process_frame
		await process_frame
		quit(1)
