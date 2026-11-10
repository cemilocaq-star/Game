extends SceneTree
## Runtime checks for room creation invariants and game-mode normalization.

const NETWORK_SCRIPT := preload("res://scripts/oxenwar_network.gd")
const ROOM_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var network := Node.new()
	network.set_script(NETWORK_SCRIPT)
	var rng: RandomNumberGenerator = network.get("_rng")
	rng.randomize()

	_assert_equal("free-for-all mode", str(network.call("_sanitize_mode", "ffa")), "ffa")
	_assert_equal("team deathmatch mode", str(network.call("_sanitize_mode", "team_deathmatch")), "team_deathmatch")
	_assert_equal("king of the hill mode", str(network.call("_sanitize_mode", "king_of_the_hill")), "king_of_the_hill")
	_assert_equal("unknown mode falls back safely", str(network.call("_sanitize_mode", "admin_mode")), "ffa")

	var room: Dictionary = network.call("_new_room", "AB234C", "owner-1", false, "team_deathmatch")
	_assert_equal("room code preserved", str(room.get("code", "")), "AB234C")
	_assert_equal("room owner assigned", str(room.get("owner_uid", "")), "owner-1")
	_assert_equal("private room flag", bool(room.get("is_public", true)), false)
	_assert_equal("room mode normalized", str(room.get("mode", "")), "team_deathmatch")
	_assert_equal("room capacity", int(room.get("max_players", 0)), 8)
	var members: Dictionary = room.get("members", {})
	_assert_equal("new room starts empty", members.size(), 0)
	_assert_equal("new round is active", bool(room.get("round_finished", true)), false)
	_assert_equal("new room round timer", float(room.get("round_left", 0.0)), 300.0)
	_assert_equal("new room event starts empty", str(room.get("event_id", "x")), "")

	var available: Dictionary = room.get("orb_available", {})
	_assert_equal("all room collectibles initially available", available.size(), 12)
	for index in range(12):
		_assert_equal("collectible %d initially available" % index, bool(available.get(index, false)), true)

	var network_source_file := FileAccess.open("res://scripts/oxenwar_network.gd", FileAccess.READ)
	_assert_true("network source readable", network_source_file != null)
	var network_source := network_source_file.get_as_text() if network_source_file != null else ""
	var auth_start := network_source.find("func _server_authenticate")
	var auth_end := network_source.find("\nfunc _redeem_game_ticket", auth_start)
	var auth_body := network_source.substr(auth_start, auth_end - auth_start) if auth_start >= 0 and auth_end > auth_start else ""
	_assert_true("auth reports reconnect restoration", auth_body.contains("can_restore)"))
	_assert_true("successful reconnect consumes its grace-period reservation", auth_body.contains("_sessions.erase(user_id)"))
	_assert_true("reconnect reservation is consumed before expiry processing can run", auth_body.find("_sessions.erase(user_id)") > auth_body.find("room.members[user_id] = peer_id"))
	_assert_false("auth does not create a phantom quick-match room", auth_body.contains("_server_quick_match_for_peer"))
	for required_state in [
		'"team_id": str(_server_players[peer_id].team_id)',
		'"kill_streak": int(_server_players[peer_id].kill_streak)',
		'"best_kill_streak": int(_server_players[peer_id].best_kill_streak)',
		'"stamina": float(_server_players[peer_id].stamina)',
		'"damage_received": float(_server_players[peer_id].damage_received)',
		'"secret_404_found": bool(_server_players[peer_id].secret_404_found)',
		'"emote_id": str(_server_players[peer_id].emote_id)',
		'"is_swimming": bool(_server_players[peer_id].is_swimming)'
	]:
		_assert_true("reconnect saves " + required_state, network_source.contains(required_state))
	for required_restore in [
		'player.team_id = restored_team if restored_team in ["red", "blue"] else ""',
		'player.kill_streak = maxi(0, int(restored.get("kill_streak", 0)))',
		'player.stamina = clampf(float(restored.get("stamina", 100.0)), 0.0, 100.0)',
		'player.secret_404_found = bool(restored.get("secret_404_found", false))',
		'player.is_swimming = bool(restored.get("is_swimming", false))'
	]:
		_assert_true("reconnect restores " + required_restore, network_source.contains(required_restore))

	var generated: Dictionary = {}
	for index in range(64):
		var code := str(network.call("_generate_room_code"))
		_assert_equal("generated room code length %d" % index, code.length(), 6)
		for char_index in range(code.length()):
			_assert_true("generated room code character %d/%d" % [index, char_index], ROOM_CODE_ALPHABET.contains(code.substr(char_index, 1)))
		_assert_false("room code uniqueness %d" % index, generated.has(code))
		generated[code] = true
		var rooms: Dictionary = network.get("_rooms")
		rooms[code] = {}
		network.set("_rooms", rooms)

	network.free()
	if failures.is_empty():
		print("PASS: matchmaking mode normalization, private room defaults, round state, collectible initialization and unique room-code generation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append("%s: expected true" % label)


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append("%s: expected false" % label)
