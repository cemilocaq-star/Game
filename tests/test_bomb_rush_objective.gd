extends SceneTree
## Runtime checks for the Bomb Rush (demolition) plant / defuse state machine.
## Drives the real server-side `_server_step_objective` with stand-in players, so the
## timings, range checks and win conditions are exercised instead of only grepped.

const NETWORK_SCRIPT := preload("res://scripts/oxenwar_network.gd")
const SITE_A := Vector3(-8.0, 1.5, -8.0)
const SITE_B := Vector3(8.0, 1.5, 8.0)
const STEP := 0.1

var failures: Array[String] = []
var network: Node


class FakePlayer extends RefCounted:
	var team_id := ""
	var is_dead := false
	var global_position := Vector3.ZERO

	func _init(team: String, position: Vector3) -> void:
		team_id = team
		global_position = position


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	network = Node.new()
	network.set_script(NETWORK_SCRIPT)

	_test_new_room_defaults()
	_test_plant_site_a()
	_test_plant_site_b()
	_test_plant_interrupted_by_leaving_range()
	_test_plant_interrupted_by_death()
	_test_blue_cannot_plant()
	_test_detonation_after_fuse()
	_test_defuse_wins_for_blue()
	_test_defuse_requires_range_and_blue()
	_test_defuse_loses_race_against_fuse()
	_test_red_eliminated()
	_test_blue_eliminated_before_plant()
	_test_blue_elimination_after_plant_does_not_end_round()
	_test_finished_round_and_other_modes_are_ignored()

	network.free()
	if failures.is_empty():
		print("PASS: Bomb Rush plant/defuse timing, range checks, detonation, elimination and mode guards")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


## Builds a demolition room with the given peer -> player mapping (peer ids 1..n).
func _make_room(players: Array, mode: String = "demolition") -> Dictionary:
	var room: Dictionary = network.call("_new_room", "BR234C", "owner-1", false, mode)
	var server_players := {}
	var members := {}
	for index in range(players.size()):
		var peer_id := index + 1
		server_players[peer_id] = players[index]
		members["user-%d" % peer_id] = peer_id
	room.members = members
	network.set("_server_players", server_players)
	return room


func _step(room: Dictionary, seconds: float) -> Dictionary:
	var remaining := seconds
	while remaining > 0.0001:
		var delta := minf(STEP, remaining)
		room = network.call("_server_step_objective", "BR234C", room, delta)
		remaining -= delta
	return room


## Mimics `_server_objective_interact` having accepted a request for `peer_id`.
func _begin(room: Dictionary, peer_id: int, action: String) -> Dictionary:
	room.objective_interactor = peer_id
	room.objective_action = action
	room.objective_progress = 0.0
	return room


func _test_new_room_defaults() -> void:
	var room := _make_room([])
	_assert_equal("demolition round limit", float(room.get("round_left", 0.0)), 180.0)
	_assert_equal("core not planted at start", bool(room.get("bomb_planted", true)), false)
	_assert_equal("no winner at start", str(room.get("objective_winner_team", "x")), "")
	_assert_equal("round not finished at start", bool(room.get("round_finished", true)), false)


func _test_plant_site_a() -> void:
	var room := _make_room([FakePlayer.new("red", SITE_A + Vector3(1, 0, 0)), FakePlayer.new("blue", Vector3(20, 0, 20))])
	room = _begin(room, 1, "plant_a")
	room = _step(room, 2.5)
	_assert_false("site A: not planted after 2.5s", bool(room.bomb_planted))
	_assert_true("site A: progress accumulating", float(room.objective_progress) > 2.0)
	room = _step(room, 0.65)
	_assert_true("site A: planted after 3s hold", bool(room.bomb_planted))
	_assert_equal("site A: site label", str(room.bomb_site), "A")
	_assert_equal("site A: position", room.bomb_position, SITE_A)
	_assert_near("site A: fuse starts at 35s", float(room.bomb_fuse), 35.0, 0.5)
	_assert_true("site A: result text", str(room.objective_result).contains("SITE A"))
	_assert_equal("site A: interaction cleared", int(room.objective_interactor), 0)
	_assert_equal("site A: no winner yet", str(room.objective_winner_team), "")


func _test_plant_site_b() -> void:
	var room := _make_room([FakePlayer.new("red", SITE_B), FakePlayer.new("blue", Vector3(-20, 0, -20))])
	room = _begin(room, 1, "plant_b")
	room = _step(room, 3.1)
	_assert_true("site B: planted", bool(room.bomb_planted))
	_assert_equal("site B: site label", str(room.bomb_site), "B")
	_assert_equal("site B: position", room.bomb_position, SITE_B)


func _test_plant_interrupted_by_leaving_range() -> void:
	var red := FakePlayer.new("red", SITE_A)
	var room := _make_room([red, FakePlayer.new("blue", Vector3(20, 0, 20))])
	room = _begin(room, 1, "plant_a")
	room = _step(room, 1.5)
	red.global_position = SITE_A + Vector3(6, 0, 0)
	room = _step(room, 0.2)
	_assert_equal("leaving range resets progress", float(room.objective_progress), 0.0)
	_assert_equal("leaving range clears interactor", int(room.objective_interactor), 0)
	room = _step(room, 5.0)
	_assert_false("no plant after leaving range", bool(room.bomb_planted))


func _test_plant_interrupted_by_death() -> void:
	var red := FakePlayer.new("red", SITE_A)
	# A second living attacker keeps the "attackers eliminated" rule from ending the round first.
	var room := _make_room([red, FakePlayer.new("blue", Vector3(20, 0, 20)), FakePlayer.new("red", Vector3(30, 0, 30))])
	room = _begin(room, 1, "plant_a")
	room = _step(room, 1.0)
	red.is_dead = true
	room = _step(room, 0.2)
	_assert_equal("death clears interactor", int(room.objective_interactor), 0)
	_assert_equal("death resets progress", float(room.objective_progress), 0.0)
	_assert_false("dead planter does not plant", bool(room.bomb_planted))


func _test_blue_cannot_plant() -> void:
	var room := _make_room([FakePlayer.new("blue", SITE_A), FakePlayer.new("red", Vector3(20, 0, 20))])
	room = _begin(room, 1, "plant_a")
	room = _step(room, 4.0)
	_assert_false("defender cannot plant", bool(room.bomb_planted))
	_assert_equal("defender plant attempt is cleared", int(room.objective_interactor), 0)


func _planted_room(players: Array, site: Vector3 = SITE_A, label: String = "A") -> Dictionary:
	var room := _make_room(players)
	room.bomb_planted = true
	room.bomb_site = label
	room.bomb_position = site
	room.bomb_fuse = 35.0
	return room


func _test_detonation_after_fuse() -> void:
	var room := _planted_room([FakePlayer.new("red", Vector3(30, 0, 30)), FakePlayer.new("blue", Vector3(-30, 0, -30))])
	room = _step(room, 34.0)
	_assert_true("core still armed at 34s", bool(room.bomb_planted))
	_assert_equal("no winner at 34s", str(room.objective_winner_team), "")
	room = _step(room, 1.2)
	_assert_equal("attackers win on detonation", str(room.objective_winner_team), "red")
	_assert_false("core cleared after detonation", bool(room.bomb_planted))
	_assert_equal("detonation result text", str(room.objective_result), "CORE DETONATED")
	_assert_equal("round timer zeroed on detonation", float(room.round_left), 0.0)


func _test_defuse_wins_for_blue() -> void:
	var room := _planted_room([FakePlayer.new("red", Vector3(30, 0, 30)), FakePlayer.new("blue", SITE_A + Vector3(0, 0, 1))])
	room = _begin(room, 2, "defuse")
	room = _step(room, 2.5)
	_assert_true("core still armed after 2.5s of defusing", bool(room.bomb_planted))
	_assert_equal("no winner before the 3s defuse completes", str(room.objective_winner_team), "")
	_assert_true("fuse keeps running during the defuse", float(room.bomb_fuse) < 33.0)
	room = _step(room, 0.65)
	_assert_equal("defenders win by defusing", str(room.objective_winner_team), "blue")
	_assert_false("core cleared after defuse", bool(room.bomb_planted))
	_assert_equal("defuse result text", str(room.objective_result), "ENERGY CORE DEFUSED")
	_assert_equal("round timer zeroed on defuse", float(room.round_left), 0.0)
	_assert_equal("defuse interaction cleared", int(room.objective_interactor), 0)


func _test_defuse_requires_range_and_blue() -> void:
	var blue := FakePlayer.new("blue", SITE_A)
	var room := _planted_room([FakePlayer.new("red", Vector3(30, 0, 30)), blue])
	room = _begin(room, 2, "defuse")
	room = _step(room, 1.5)
	blue.global_position = SITE_A + Vector3(6, 0, 0)
	room = _step(room, 0.2)
	_assert_equal("leaving range resets defuse progress", float(room.objective_progress), 0.0)
	_assert_equal("leaving range clears defuse interactor", int(room.objective_interactor), 0)
	room = _step(room, 5.0)
	_assert_equal("no defuse win after leaving range", str(room.objective_winner_team), "")
	_assert_true("core stays armed after a broken defuse", bool(room.bomb_planted))

	var dying_blue := FakePlayer.new("blue", SITE_A)
	room = _planted_room([FakePlayer.new("red", Vector3(30, 0, 30)), dying_blue])
	room = _begin(room, 2, "defuse")
	room = _step(room, 1.0)
	dying_blue.is_dead = true
	room = _step(room, 0.2)
	_assert_equal("death clears defuse interactor", int(room.objective_interactor), 0)
	room = _step(room, 5.0)
	_assert_equal("dead defender cannot finish a defuse", str(room.objective_winner_team), "")

	var red_in_range := FakePlayer.new("red", SITE_A)
	room = _planted_room([red_in_range, FakePlayer.new("blue", Vector3(30, 0, 30))])
	room = _begin(room, 1, "defuse")
	room = _step(room, 4.0)
	_assert_equal("attacker cannot defuse", str(room.objective_winner_team), "")
	_assert_true("core stays armed against an attacker defuse", bool(room.bomb_planted))

	room = _planted_room([FakePlayer.new("red", SITE_A), FakePlayer.new("blue", Vector3(30, 0, 30))])
	room = _begin(room, 1, "plant_a")
	room = _step(room, 5.0)
	_assert_true("armed core cannot be planted again", bool(room.bomb_planted))
	_assert_true("fuse still counting down after a re-plant attempt", float(room.bomb_fuse) < 31.0)


func _test_defuse_loses_race_against_fuse() -> void:
	var room := _planted_room([FakePlayer.new("red", Vector3(30, 0, 30)), FakePlayer.new("blue", SITE_A)])
	room.bomb_fuse = 2.0
	room = _begin(room, 2, "defuse")
	room = _step(room, 2.5)
	_assert_equal("detonation beats a defuse that needs more time", str(room.objective_winner_team), "red")
	_assert_equal("detonation result wins the race", str(room.objective_result), "CORE DETONATED")


func _test_red_eliminated() -> void:
	var red := FakePlayer.new("red", Vector3(30, 0, 30))
	var room := _make_room([red, FakePlayer.new("blue", Vector3(-30, 0, -30))])
	red.is_dead = true
	room = _step(room, 0.2)
	_assert_equal("defenders win when attackers are eliminated", str(room.objective_winner_team), "blue")
	_assert_equal("attackers eliminated text", str(room.objective_result), "ATTACKERS ELIMINATED")
	_assert_equal("round timer zeroed on elimination", float(room.round_left), 0.0)


func _test_blue_eliminated_before_plant() -> void:
	var blue := FakePlayer.new("blue", Vector3(-30, 0, -30))
	var room := _make_room([FakePlayer.new("red", Vector3(30, 0, 30)), blue])
	blue.is_dead = true
	room = _step(room, 0.2)
	_assert_equal("attackers win when defenders are eliminated pre-plant", str(room.objective_winner_team), "red")
	_assert_equal("defenders eliminated text", str(room.objective_result), "DEFENDERS ELIMINATED")


func _test_blue_elimination_after_plant_does_not_end_round() -> void:
	var blue := FakePlayer.new("blue", Vector3(-30, 0, -30))
	var room := _planted_room([FakePlayer.new("red", Vector3(30, 0, 30)), blue])
	blue.is_dead = true
	room = _step(room, 5.0)
	_assert_equal("planted core keeps the round open after defenders die", str(room.objective_winner_team), "")
	_assert_true("core still armed", bool(room.bomb_planted))
	room = _step(room, 31.0)
	_assert_equal("detonation still resolves the round", str(room.objective_winner_team), "red")


func _test_finished_round_and_other_modes_are_ignored() -> void:
	var finished := _make_room([FakePlayer.new("red", SITE_A), FakePlayer.new("blue", Vector3(20, 0, 20))])
	finished.round_finished = true
	finished = _begin(finished, 1, "plant_a")
	finished = _step(finished, 4.0)
	_assert_false("finished round cannot be planted", bool(finished.bomb_planted))

	var other := _make_room([FakePlayer.new("red", SITE_A), FakePlayer.new("blue", Vector3(20, 0, 20))], "team_deathmatch")
	other = _begin(other, 1, "plant_a")
	other = _step(other, 4.0)
	_assert_false("non-demolition mode ignores objectives", bool(other.bomb_planted))
	_assert_equal("non-demolition mode has no objective winner", str(other.objective_winner_team), "")


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append("%s: expected true" % label)


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append("%s: expected false" % label)


func _assert_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s +/- %s, got %s" % [label, str(expected), str(tolerance), str(actual)])
