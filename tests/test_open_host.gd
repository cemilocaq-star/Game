extends SceneTree
## "Create room with no server": the OxenWar server runs inside this process (lan_host.gd) with its own
## MultiplayerAPI, and the game's network node connects to it as a guest on the default API, exactly like a
## client of any other server. Checks guest login, room creation, snapshots, and that a room code is listed.

const LAN_HOST := preload("res://scripts/lan_host.gd")
const NET := preload("res://scripts/oxenwar_network.gd")

var failures: Array[String] = []
var _room_code := ""
var _local_states := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)


func _wait_until(condition: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		print("FAIL: test took longer than 40 seconds")
		quit(1))
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var host := LAN_HOST.new()
	host.name = "OxenWarLanHost"
	main.add_child(host)
	_check(host.start(), "the server starts inside the game process")
	if not host.running:
		quit(1)
		return
	_check(host.server.open_mode and host.server.is_dedicated_server, "the hosted server is an open dedicated server")

	var net := NET.new()
	net.name = "OxenWarNet"
	main.add_child(net)
	net.room_state_changed.connect(func(state: Dictionary):
		if not str(state.get("code", "")).is_empty():
			_room_code = str(state.code))
	net.local_state_received.connect(func(_state: Dictionary): _local_states += 1)
	net.connect_as_guest("127.0.0.1", "Ali-the-Guest")
	_check(await _wait_until(func(): return net.is_authenticated, 10.0), "a guest joins with only a name")
	_check(net.local_player_name == "AlitheGuest", "the guest name is cleaned (no dashes) and sent to the server")
	if net.is_authenticated:
		net.request_create_room(true, "ffa", 4)
		_check(await _wait_until(func(): return not _room_code.is_empty(), 8.0), "the guest creates a room")
		_check(await _wait_until(func(): return _local_states >= 3, 8.0), "the guest receives authoritative snapshots")
		_check(host.room_codes().has(_room_code), "the hosted server lists the new room code")
		_check(host.server._server_players.size() == 1, "the server simulates the guest player")
		_check(net.multiplayer != host.server.multiplayer, "client and hosted server use different multiplayer APIs")
		# Guests are never written to an account.
		var guest_ok: bool = await host.server._persist_result_values("guest-abc", "", 10, 5, [], 1, 0, 0.0, 0, 0, 5, "win", 0, 0)
		_check(guest_ok, "guest results are skipped, not sent to Supabase")
	if net.multiplayer.multiplayer_peer != null:
		net.multiplayer.multiplayer_peer.close()
	if failures.is_empty():
		print("PASS: in-process hosted room with a guest client (room %s)" % _room_code)
		quit(0)
	else:
		quit(1)
