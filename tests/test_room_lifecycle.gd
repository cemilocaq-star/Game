extends SceneTree

class LifecycleNetwork extends "res://tests/online/network_under_test.gd":
	func _broadcast_snapshot(_code: String) -> void:
		# Snapshot transport is exercised by the separate real-peer integration suites.
		pass

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var net := LifecycleNetwork.new()
	root.add_child(net)

	net._rooms["EXPIRY"] = net._new_room("EXPIRY", "expired", true)
	var world := net._ensure_room_world("EXPIRY")
	net._rooms["EXPIRY"].members["expired"] = 0
	net._user_rooms["expired"] = "EXPIRY"
	net._player_joined_at_ms["expired"] = 1
	net._sessions["expired"] = {"expires": -1, "room_code": "EXPIRY"}
	net._server_process_rooms(0.0)
	check(not net._rooms.has("EXPIRY"), "expired empty room removed")
	check(not net._room_worlds.has("EXPIRY") and world.is_queued_for_deletion(), "expired physics world released")
	check(not net._player_joined_at_ms.has("expired"), "expired join timestamp released")

	var departures: Array[int] = []
	net.player_disconnected.connect(func(peer: int): departures.append(peer))
	net._client_peer_ids[12] = true
	net._client_peer_ids[13] = true
	net._client_state_cache[12] = {"display_name": "Test"}
	net._client_cache_room = "OLD"
	net._pending_jump = true
	net._forget_client_peer(12)
	net._forget_client_peer(12)
	net._clear_client_room()
	check(departures == [12, 13], "each avatar removed once")
	check(net._client_state_cache.is_empty() and net._client_cache_room.is_empty(), "room cache cleared")
	check(not net._pending_jump, "pending previous-room input cleared")

	var first = net._create_server_player(21, {})
	var second = net._create_server_player(22, {})
	net._rooms["DRAW"] = net._new_room("DRAW", "first", true)
	net._assign_user_to_room("first", 21, "DRAW")
	net._assign_user_to_room("second", 22, "DRAW")
	first.stamina = 3.0
	first._dash_left = 0.16
	first._jump_buffer_left = 0.12
	first.reload_until_ms = 1000
	first.sprinting = true
	first.respawn_at(first.global_position)
	check(first.stamina == first.MAX_STAMINA and first.reload_until_ms == 0, "respawn resets stamina and reload")
	check(first._dash_left == 0.0 and first._jump_buffer_left == 0.0 and not first.sprinting, "respawn resets movement buffers")
	net._rooms["DRAW"].round_left = 0.01
	net._rooms["DRAW"].snap_counter = 7
	net._server_process_rooms(0.02)
	check(first.match_outcome == "draw" and second.match_outcome == "draw", "tied FFA round awards a draw")
	check(net._rooms["DRAW"].snap_counter == 0, "first round-end packet includes final slow fields")
	net._rooms["FUSE"] = net._new_room("FUSE", "first", true, "demolition")
	net._rooms["FUSE"].round_left = 0.01
	net._rooms["FUSE"].bomb_planted = true
	net._rooms["FUSE"].bomb_fuse = 2.0
	net._server_process_rooms(0.02)
	check(not net._rooms["FUSE"].round_finished and net._rooms["FUSE"].round_left > 0.0, "armed bomb outlives the plant clock")
	net._server_process_rooms(2.0)
	check(net._rooms["FUSE"].round_finished and net._rooms["FUSE"].objective_winner_team == "red", "fuse detonation decides the round")
	net.free()
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("PASS: expiry cleanup, disconnect deduplication, respawn state, and tied round results")
	quit(0 if failures.is_empty() else 1)
