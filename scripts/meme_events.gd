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
	if not before.is_empty():
		room.event_left = maxf(0.0, float(room.event_left) - delta)
		if room.event_left <= 0.0:
			cancel(room)
			return true
	elif not alive.is_empty() and float(room.round_left) > 18.0:
		room.event_clock = maxf(0.0, float(room.event_clock) - delta)
		if room.event_clock <= 0.0:
			var id := choose(rng, str(room.get("previous_event", "")), str(room.mode), alive.size())
			room.event_id = id
			room.event_left = DEFINITIONS[id][1]
			room.event_serial = int(room.get("event_serial", 0)) + 1
			room.event_target = alive[rng.randi_range(0, alive.size() - 1)] if id == SUNSHINE else 0
			room.event_warning = WARNING
			room.event_actor = Vector3.ZERO
			room.event_actor_ready = false
			room.event_impact = false
			return true
	return false


static func cancel(room: Dictionary) -> void:
	room.previous_event = room.event_id
	room.event_id = ""
	room.event_left = 0.0
	room.event_clock = 20.0
	room.event_target = 0
	room.event_actor_ready = false


static func count_down(room: Dictionary, delta: float) -> float:
	var warning := float(room.event_warning)
	room.event_warning = maxf(0.0, warning - delta)
	return maxf(0.0, delta - warning)


static func track(from: Vector3, to: Vector3, delta: float) -> Vector3:
	return from.move_toward(to, 24.0 * delta)
