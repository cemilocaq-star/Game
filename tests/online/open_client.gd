extends SceneTree
## One guest of the open-server test. `-- --role=A --out=<file>` creates a room and writes its code to the
## file; `-- --role=B --in=<file>` waits for the code, finds the server by that room code through LAN
## discovery (no address is given), joins it and checks that A and B see each other.
## Talks to a real `--server --open` process started without any secret. Prints OPEN_RESULT <role> PASS|FAIL.

const NET := preload("res://scripts/oxenwar_network.gd")
const LAN := preload("res://scripts/lan_discovery.gd")

var role := "A"
var file_path := ""
var net
var failures: Array[String] = []
var _room_code := ""
var _others: Dictionary = {}
var _local := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("OPEN_FAIL %s: %s" % [role, message])


func _wait_until(condition: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _finish() -> void:
	if net != null and net.multiplayer.multiplayer_peer != null:
		net.multiplayer.multiplayer_peer.close()
	if failures.is_empty():
		print("OPEN_RESULT %s PASS" % role)
		quit(0)
	else:
		print("OPEN_RESULT %s FAIL failures=%d" % [role, failures.size()])
		quit(1)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--file="):
			file_path = arg.trim_prefix("--file=")
	create_timer(50.0).timeout.connect(func():
		_check(false, "finished inside 50 seconds")
		_finish())
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	net = NET.new()
	net.name = "OxenWarNet"
	main.add_child(net)
	net.room_state_changed.connect(func(state: Dictionary):
		if not str(state.get("code", "")).is_empty():
			_room_code = str(state.code))
	net.local_state_received.connect(func(_state: Dictionary): _local += 1)
	net.player_state_received.connect(func(peer: int, state: Dictionary): _others[peer] = state)

	var wanted := ""
	if role == "B":
		_check(await _wait_until(func(): return FileAccess.file_exists(file_path), 25.0), "A published a room code")
		if FileAccess.file_exists(file_path):
			wanted = FileAccess.get_file_as_string(file_path).strip_edges()
	var servers: Array = await LAN.scan(self, 4.0, LAN.PORT, wanted)
	_check(not servers.is_empty(), "LAN discovery finds the open server with no address typed")
	if servers.is_empty():
		_finish()
		return
	var target: Dictionary = servers[0]
	if not wanted.is_empty():
		target = LAN.find_room(servers, wanted)
		_check(not target.is_empty(), "the server is found by the room code alone")
		if target.is_empty():
			_finish()
			return
	net.connect_as_guest(LAN.address_of(target), "Guest" + role)
	_check(await _wait_until(func(): return net.is_authenticated, 10.0), "joined as a guest, no ticket or account")
	if not net.is_authenticated:
		_finish()
		return
	if role == "A":
		net.request_create_room(true, "ffa", 4)
		_check(await _wait_until(func(): return not _room_code.is_empty(), 8.0), "created a room")
		var out := FileAccess.open(file_path, FileAccess.WRITE)
		out.store_string(_room_code)
		out.close()
		print("OPEN_NOTE A: room %s" % _room_code)
	else:
		net.request_join_room(wanted)
		_check(await _wait_until(func(): return _room_code == wanted, 8.0), "joined the room by its code")
	_check(await _wait_until(func(): return _local >= 3, 8.0), "receives snapshots")
	_check(await _wait_until(func(): return _others.size() >= 1, 15.0), "sees the other guest in the room")
	if role == "A":
		# Stay until B has seen us, so B's check cannot fail because A left first.
		await create_timer(6.0).timeout
	else:
		await create_timer(1.0).timeout
	_finish()
