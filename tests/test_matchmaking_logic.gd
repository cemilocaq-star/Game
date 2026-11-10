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
