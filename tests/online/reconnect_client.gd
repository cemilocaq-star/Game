extends "res://tests/online/online_client.gd"
## Tests a real transport reconnect inside the production grace reservation.
## Identity redemption is a fixture; HTTPS ticket renewal remains an external test.
func _run() -> void:
	role = "RECONNECT"
	root.get_tree().create_timer(30.0).timeout.connect(func():
		_check(false,"reconnect test completed inside 30s")
		_finish())
	for action in ["move_left","move_right","move_forward","move_back","jump","sprint","slide","dash"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	net = NET.new()
	net.name = "OxenWarNetwork"
	root.add_child(net)
	stub = STUB.new()
	root.add_child(stub)
	net.set_local_player(stub,"Reconnect fixture",Color.CYAN)
	net.local_state_received.connect(func(value: Dictionary):_local = value)
	net.room_state_changed.connect(func(value: Dictionary):_room_code = str(value.get("code","")))
	net._last_host = "127.0.0.1"
	net._game_ticket = "TESTTICKET-reconnect-%s" % "x".repeat(40)
	net._connect_now()
	_check(await _wait_until(func():return net.is_authenticated,6.0),"initial fixture authentication")
	if not net.is_authenticated:_finish();return
	net.request_quick_match("ffa",4)
	_check(await _wait_until(func():return not _room_code.is_empty(),4.0),"initial room joined")
	net.request_select_weapon("longshot")
	_check(await _wait_until(func():return str(_local.get("equipped_weapon_id","")) == "longshot",4.0),"server accepted selected weapon")
	await _wait(0.8)
	var original_room := _room_code
	var original_peer: int = net.multiplayer.get_unique_id()
	net.multiplayer.multiplayer_peer.disconnect_peer(1)
	await _wait(0.8)
	net.multiplayer.multiplayer_peer.close()
	net.multiplayer.multiplayer_peer = null
	net.is_authenticated = false
	_room_code = ""
	_local = {}
	net._connect_now()
	_check(await _wait_until(func():return net.is_authenticated,6.0),"reconnected fixture identity")
	_check(net.session_restored_on_auth,"server restored grace reservation")
	_check(await _wait_until(func():return _room_code == original_room,4.0),"same room restored without quick matching")
	_check(net.multiplayer.get_unique_id() != original_peer,"reconnect uses a new network peer")
	_check(await _wait_until(func():return str(_local.get("equipped_weapon_id","")) == "longshot",4.0),"equipped weapon restored from server reservation")
	_check(float(_local.get("reload_left",0.0)) == 0.0,"transient reload state reset")
	_finish()
