extends RefCounted
## Policy and deterministic transitions for the existing server room loop.
const SUNSHINE := "SUNSHINE"
const WARNING := 3.0
const DEFINITIONS := {
	"DUCK_PARADE": [20, 12.0, "Common"],
	"PINK_SKY": [20, 12.0, "Common"],
	"CONFETTI_STORM": [20, 12.0, "Common"],
	"LOW_GRAVITY": [16, 12.0, "Common"],
	"GOLDEN_ORB_RUSH": [10, 12.0, "Uncommon"],
	"BONK_MODE": [9, 9.0, "Uncommon"],
	"NPC_MODE": [8, 9.0, "Uncommon"],
	"ICE_WORLD": [7, 10.0, "Uncommon"],
	"BIG_HEAD": [7, 10.0, "Uncommon"],
	"DUCK_EXE": [4, 10.0, "Rare"],
	"METEOR_SHOWER": [4, 10.0, "Rare"],
	"FREEZE_FRAME": [3, 5.0, "Rare"],
	"REVERSE_PANIC": [3, 7.0, "Rare"],
	"DOUBLE_XP": [2, 10.0, "Legendary"],
	SUNSHINE: [1, 15.0, "Secret"],
}


## Probability-based scheduling (replaces the old fixed 20 s clock). Every value is per room.
##  - a random gap between events, longer after a disruptive one;
##  - when the gap ends an activation roll decides whether an event starts now; a failed roll
##    retries soon and each failure raises the next chance (pity), so events never stall for long;
##  - the event itself is a weighted pick among the events that are eligible right now.
const SCHEDULE := {
	"first_min": 12.0, "first_max": 28.0,
	"gap_min": 16.0, "gap_max": 38.0,
	"retry_min": 4.0, "retry_max": 9.0,
	"calm_after_disruptive": 12.0,
	"base_probability": 0.75, "pity_bonus": 0.12, "solo_factor": 0.6,
	"end_margin": 6.0,
}
## Seconds before the same event may start again in the same room (counted from its start).
const RARITY_COOLDOWN := {"Common": 45.0, "Uncommon": 75.0, "Rare": 120.0, "Legendary": 180.0, "Secret": 240.0}
## Per-event overrides: min_players, disruptive (changes movement/vision/control), blocked_maps
## (indices of ARENA_LAYOUT.MAP_NAMES), blocked_modes, cooldown.
const CONFIG := {
	"LOW_GRAVITY": {"disruptive": true, "blocked_modes": ["demolition"]},
	"BONK_MODE": {"disruptive": true, "blocked_modes": ["demolition"]},
	"NPC_MODE": {"disruptive": true},
	"ICE_WORLD": {"disruptive": true, "blocked_modes": ["demolition"], "blocked_maps": [4]},
	"DUCK_EXE": {"disruptive": true},
	"METEOR_SHOWER": {"disruptive": true, "blocked_maps": [0]},
	"FREEZE_FRAME": {"disruptive": true, "min_players": 2, "blocked_modes": ["demolition"]},
	"REVERSE_PANIC": {"disruptive": true, "blocked_modes": ["demolition"]},
	"SUNSHINE": {"disruptive": true, "min_players": 2, "blocked_modes": ["demolition", "team_deathmatch", "king_of_the_hill"]},
}


static func config(id: String) -> Dictionary:
	var definition: Array = DEFINITIONS.get(id, [0, 10.0, "Common"])
	var override: Dictionary = CONFIG.get(id, {})
	return {
		"weight": int(definition[0]), "duration": float(definition[1]), "rarity": str(definition[2]),
		"cooldown": float(override.get("cooldown", RARITY_COOLDOWN.get(str(definition[2]), 60.0))),
		"min_players": int(override.get("min_players", 1)),
		"disruptive": bool(override.get("disruptive", false)),
		"blocked_maps": override.get("blocked_maps", []),
		"blocked_modes": override.get("blocked_modes", []),
	}


## Why an event cannot start right now ("" = it can). Used by the picker and by tests.
static func ineligible_reason(id: String, room: Dictionary, players: int) -> String:
	if not DEFINITIONS.has(id):
		return "unknown"
	var settings := config(id)
	if id == str(room.get("previous_event", "")):
		return "repeat"
	if float(room.get("event_cooldowns", {}).get(id, 0.0)) > 0.0:
		return "cooldown"
	if players < int(settings.min_players):
		return "players"
	if str(room.get("mode", "ffa")) in settings.blocked_modes:
		return "mode"
	if int(room.get("map_index", -1)) in settings.blocked_maps:
		return "map"
	if room.has("round_left") and float(room.round_left) < float(settings.duration) + WARNING + float(SCHEDULE.end_margin):
		return "round_end"
	var previous := str(room.get("previous_event", ""))
	if DEFINITIONS.has(previous) and str(settings.rarity) != "Common" and str(settings.rarity) != "Uncommon" and str(config(previous).rarity) == str(settings.rarity):
		return "rarity_streak"
	return ""


static func choose_for_room(rng: RandomNumberGenerator, room: Dictionary, players: int) -> String:
	var running := 0
	var cumulative: Array = []
	for id: String in DEFINITIONS:
		if ineligible_reason(id, room, players).is_empty():
			running += int(config(id).weight)
			cumulative.append([id, running])
	if running <= 0:
		return ""
	var roll := rng.randi_range(1, running)
	for entry: Array in cumulative:
		if roll <= int(entry[1]):
			return str(entry[0])
	return ""


## Chance that an event starts when its gap ends. Rises after every failed roll.
static func activation_probability(room: Dictionary, players: int) -> float:
	var value := float(SCHEDULE.base_probability) + float(SCHEDULE.pity_bonus) * float(int(room.get("event_fail_streak", 0)))
	if players < 2:
		value *= float(SCHEDULE.solo_factor)
	return clampf(value, 0.0, 1.0)


static func next_gap(rng: RandomNumberGenerator, after_disruptive: bool = false, first: bool = false) -> float:
	if first:
		return rng.randf_range(float(SCHEDULE.first_min), float(SCHEDULE.first_max))
	var gap := rng.randf_range(float(SCHEDULE.gap_min), float(SCHEDULE.gap_max))
	return gap + (float(SCHEDULE.calm_after_disruptive) if after_disruptive else 0.0)


static func _tick_cooldowns(room: Dictionary, delta: float) -> void:
	var cooldowns: Dictionary = room.get("event_cooldowns", {})
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	room.event_cooldowns = cooldowns

static func choose(rng: RandomNumberGenerator, previous: String, mode: String, players: int) -> String:
	var eligible: Dictionary = {}
	var total := 0
	for id: String in DEFINITIONS:
		if id == previous or (id == SUNSHINE and (mode != "ffa" or players < 2)):
			continue
		if mode == "demolition" and id in ["FREEZE_FRAME", "REVERSE_PANIC", "BONK_MODE", "LOW_GRAVITY", "ICE_WORLD"]:
			continue
		total += int(DEFINITIONS[id][0])
		eligible[id] = total
	var roll := rng.randi_range(1, total)
	for id: String in eligible:
		if roll <= int(eligible[id]):
			return id
	return ""


static func step(room: Dictionary, delta: float, rng: RandomNumberGenerator, alive: Array[int]) -> bool:
	var before := str(room.event_id)
	_tick_cooldowns(room, delta)
	if not before.is_empty():
		room.event_left = maxf(0.0, float(room.event_left) - delta)
		if room.event_left <= 0.0:
			cancel(room, rng)
			return true
	elif not alive.is_empty() and float(room.round_left) > 18.0:
		room.event_clock = maxf(0.0, float(room.event_clock) - delta)
		if room.event_clock <= 0.0:
			if rng.randf() > activation_probability(room, alive.size()):
				room.event_fail_streak = int(room.get("event_fail_streak", 0)) + 1
				room.event_clock = rng.randf_range(float(SCHEDULE.retry_min), float(SCHEDULE.retry_max))
				return false
			var id := choose_for_room(rng, room, alive.size())
			if id.is_empty():
				room.event_clock = rng.randf_range(float(SCHEDULE.retry_min), float(SCHEDULE.retry_max))
				return false
			var settings := config(id)
			room.event_fail_streak = 0
			room.event_id = id
			room.event_left = float(settings.duration)
			room.event_serial = int(room.get("event_serial", 0)) + 1
			room.event_target = alive[rng.randi_range(0, alive.size() - 1)] if id == SUNSHINE else 0
			room.event_warning = WARNING
			room.event_actor = Vector3.ZERO
			room.event_actor_ready = false
			room.event_impact = false
			var cooldowns: Dictionary = room.get("event_cooldowns", {})
			cooldowns[id] = float(settings.cooldown) + float(settings.duration)
			room.event_cooldowns = cooldowns
			var history: Array = room.get("event_history", [])
			history.append(id)
			room.event_history = history.slice(maxi(0, history.size() - 8))
			return true
	return false


static func cancel(room: Dictionary, rng: RandomNumberGenerator = null) -> void:
	var ended := str(room.get("event_id", ""))
	if not ended.is_empty():
		room.previous_event = ended
	room.event_id = ""
	room.event_left = 0.0
	var disruptive := not ended.is_empty() and bool(config(ended).disruptive)
	room.event_clock = next_gap(rng, disruptive) if rng != null else float(SCHEDULE.gap_min)
	room.event_target = 0
	room.event_actor_ready = false


static func count_down(room: Dictionary, delta: float) -> float:
	var warning := float(room.event_warning)
	room.event_warning = maxf(0.0, warning - delta)
	return maxf(0.0, delta - warning)


static func track(from: Vector3, to: Vector3, delta: float) -> Vector3:
	return from.move_toward(to, 24.0 * delta)
