extends SceneTree
## Probability-based event scheduling: random gaps, activation roll with pity, per-event cooldowns,
## player-count / map / mode eligibility, no immediate repeats, calm gap after disruptive events,
## and long-run behaviour over many simulated rounds.

const EVENTS := preload("res://scripts/meme_events.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _room(mode: String = "ffa", map_index: int = 4, round_left: float = 300.0) -> Dictionary:
	return {"mode": mode, "map_index": map_index, "round_left": round_left, "event_id": "", "event_left": 0.0,
		"event_clock": 0.0, "event_cooldowns": {}, "event_fail_streak": 0, "event_history": [], "previous_event": ""}


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115
	_test_config()
	_test_eligibility()
	_test_probability_and_gaps(rng)
	_test_simulation(rng)
	if failures.is_empty():
		print("PASS: randomized event gaps, activation probability, cooldowns, eligibility and long-run simulation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_config() -> void:
	for id in EVENTS.DEFINITIONS.keys():
		var settings: Dictionary = EVENTS.config(str(id))
		_check(float(settings.duration) > 0.0 and int(settings.weight) > 0, "%s has a duration and weight" % id)
		_check(float(settings.cooldown) >= float(settings.duration), "%s cooldown is at least its duration" % id)
	_check(float(EVENTS.config("DOUBLE_XP").cooldown) > float(EVENTS.config("PINK_SKY").cooldown), "rarer events wait longer before returning")
	_check(bool(EVENTS.config("FREEZE_FRAME").disruptive) and not bool(EVENTS.config("DUCK_PARADE").disruptive), "disruptive flags are set")


func _test_eligibility() -> void:
	var room := _room()
	_check(EVENTS.ineligible_reason("PINK_SKY", room, 3) == "", "a fresh room allows a common event")
	_check(EVENTS.ineligible_reason("SUNSHINE", room, 1) == "players", "Sunshine needs two players")
	_check(EVENTS.ineligible_reason("FREEZE_FRAME", room, 1) == "players", "Freeze Frame needs two players")
	_check(EVENTS.ineligible_reason("SUNSHINE", _room("team_deathmatch"), 3) == "mode", "Sunshine is free-for-all only")
	_check(EVENTS.ineligible_reason("LOW_GRAVITY", _room("demolition"), 3) == "mode", "no low gravity in Bomb Rush")
	_check(EVENTS.ineligible_reason("ICE_WORLD", _room("ffa", 4), 3) == "map", "no ice on the Sunken Oasis")
	_check(EVENTS.ineligible_reason("METEOR_SHOWER", _room("ffa", 0), 3) == "map", "no meteors inside the Lost Mall")
	_check(EVENTS.ineligible_reason("PINK_SKY", _room("ffa", 4, 20.0), 3) == "round_end", "an event must fit in the time left")
	room.previous_event = "PINK_SKY"
	_check(EVENTS.ineligible_reason("PINK_SKY", room, 3) == "repeat", "the same event never repeats back to back")
	room.previous_event = ""
	room.event_cooldowns = {"DUCK_PARADE": 30.0}
	_check(EVENTS.ineligible_reason("DUCK_PARADE", room, 3) == "cooldown", "an event on cooldown is not eligible")
	room.event_cooldowns = {}
	room.previous_event = "DUCK_EXE"
	_check(EVENTS.ineligible_reason("METEOR_SHOWER", room, 3) == "rarity_streak", "two rare events do not follow each other")
	_check(EVENTS.ineligible_reason("NOT_AN_EVENT", room, 3) == "unknown", "unknown ids are rejected")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var only_blocked := _room("demolition", 4, 300.0)
	for _i in range(300):
		var picked: String = EVENTS.choose_for_room(rng, only_blocked, 3)
		_check(picked != "" and EVENTS.ineligible_reason(picked, only_blocked, 3) == "", "the picker only returns eligible events (%s)" % picked)
	var none_room := _room("ffa", 4, 5.0)
	_check(EVENTS.choose_for_room(rng, none_room, 3) == "", "no event is picked when none fits")


func _test_probability_and_gaps(rng: RandomNumberGenerator) -> void:
	var room := _room()
	var base: float = EVENTS.activation_probability(room, 4)
	_check(base > 0.0 and base < 1.0, "the base activation chance is a real probability")
	room.event_fail_streak = 2
	_check(EVENTS.activation_probability(room, 4) > base, "failed rolls raise the next chance")
	room.event_fail_streak = 50
	_check(EVENTS.activation_probability(room, 4) == 1.0, "the chance is capped at 1")
	room.event_fail_streak = 0
	_check(EVENTS.activation_probability(room, 1) < base, "a lone player gets fewer events")
	var smallest := 1000.0
	var largest := 0.0
	var distinct := {}
	for _i in range(200):
		var gap: float = EVENTS.next_gap(rng, false)
		smallest = minf(smallest, gap)
		largest = maxf(largest, gap)
		distinct[snappedf(gap, 0.1)] = true
	_check(smallest >= float(EVENTS.SCHEDULE.gap_min) and largest <= float(EVENTS.SCHEDULE.gap_max), "gaps stay inside the configured range")
	_check(distinct.size() > 50, "gaps are not a fixed schedule")
	var calm_min := 1000.0
	for _i in range(100):
		calm_min = minf(calm_min, EVENTS.next_gap(rng, true))
	_check(calm_min >= float(EVENTS.SCHEDULE.gap_min) + float(EVENTS.SCHEDULE.calm_after_disruptive), "a disruptive event is followed by extra calm time")
	var first: float = EVENTS.next_gap(rng, false, true)
	_check(first >= float(EVENTS.SCHEDULE.first_min) and first <= float(EVENTS.SCHEDULE.first_max), "the first event has its own earlier window")


## Plays 300 simulated five-minute rounds at 10 ticks per second.
func _test_simulation(rng: RandomNumberGenerator) -> void:
	var alive: Array[int] = [1, 2, 3, 4]
	var starts := 0
	var counts := {}
	var violations := 0
	var gaps: Array[float] = []
	var longest_quiet := 0.0
	var rounds := 300
	for round_index in range(rounds):
		var room := _room("ffa", round_index % 7, 300.0)
		room.event_clock = EVENTS.next_gap(rng, false, true)
		var last_end := 0.0
		var clock := 0.0
		var previous := ""
		while float(room.round_left) > 0.0:
			var delta := 0.1
			room.round_left = maxf(0.0, float(room.round_left) - delta)
			clock += delta
			var had_event := str(room.event_id) != ""
			var started: bool = EVENTS.step(room, delta, rng, alive)
			if started and str(room.event_id) != "":
				if had_event:
					violations += 1 # two events at once
				starts += 1
				counts[str(room.event_id)] = int(counts.get(str(room.event_id), 0)) + 1
				if str(room.event_id) == previous:
					violations += 1
				var settings: Dictionary = EVENTS.config(str(room.event_id))
				if int(settings.min_players) > alive.size() or str(room.mode) in settings.blocked_modes or int(room.map_index) in settings.blocked_maps:
					violations += 1
				gaps.append(clock - last_end)
				longest_quiet = maxf(longest_quiet, clock - last_end)
				previous = str(room.event_id)
			elif started and str(room.event_id) == "":
				last_end = clock
	var per_round := float(starts) / float(rounds)
	_check(per_round >= 3.0 and per_round <= 12.0, "a five-minute round sees a sensible number of events (%f)" % per_round)
	_check(violations == 0, "no overlapping events, repeats or ineligible picks (%d violations)" % violations)
	_check(counts.size() >= 10, "many different events appear (%d kinds)" % counts.size())
	_check(int(counts.get("DOUBLE_XP", 0)) < int(counts.get("PINK_SKY", 1)), "legendary events are rarer than common ones")
	_check(longest_quiet < 140.0, "events never go quiet for a very long time (%f s)" % longest_quiet)
	for id in counts.keys():
		_check(int(counts[id]) < starts / 2, "%s does not dominate" % id)
