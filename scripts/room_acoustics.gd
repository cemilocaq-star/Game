extends RefCounted
## Room acoustics: how enclosed the listener is, and the reverb that goes with it.
##
## A shot in a closed hall rings; the same shot in the open does not. This casts rays around the
## listener (eight sideways, one up, and four diagonally up) through a `tracer` Callable like the one
## in sound_paths.gd, measures how many hit and how far away, and turns that into reverb settings.
## RoomAcousticsDriver (below) does it a few times a second in the real game and eases the SFX bus
## reverb toward the result.

const PATHS := preload("res://scripts/sound_paths.gd")
const BUSES := preload("res://scripts/audio_buses.gd")

const SIDE_RAYS := 8
const SIDE_LENGTH := 26.0
const UP_LENGTH := 14.0
const DIAGONAL_PITCH_DEG := 40.0
const MEASURE_INTERVAL := 0.2

const MAX_WET := 0.34
const OPEN_WET := 0.02
const MIN_ROOM_SIZE := 0.18
const MAX_ROOM_SIZE := 0.92
const EASE_PER_SECOND := 2.2


static func ray_directions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index in range(SIDE_RAYS):
		var angle := TAU * float(index) / float(SIDE_RAYS)
		result.append(Vector3(sin(angle), 0.0, cos(angle)))
	result.append(Vector3.UP)
	var pitch := deg_to_rad(DIAGONAL_PITCH_DEG)
	for index in range(4):
		var angle := TAU * (float(index) + 0.5) / 4.0
		result.append(Vector3(sin(angle) * cos(pitch), sin(pitch), cos(angle) * cos(pitch)))
	return result


## {"enclosure": 0..1, "mean_distance": metres to what the sideways rays hit, "ceiling": bool,
##  "open_sides": how many sideways rays hit nothing}
static func measure(origin: Vector3, tracer: Callable) -> Dictionary:
	var side_hits := 0
	var side_total := 0.0
	var ceiling := false
	var up_hits := 0
	var up_total := 0
	for direction in ray_directions():
		var is_side := absf(direction.y) < 0.01
		var length := SIDE_LENGTH if is_side else UP_LENGTH
		var hit: Dictionary = tracer.call(origin, origin + direction * length)
		var hit_something := not hit.is_empty()
		if is_side:
			if hit_something:
				side_hits += 1
				side_total += origin.distance_to(hit.position as Vector3)
		else:
			up_total += 1
			if hit_something:
				up_hits += 1
				if direction.y > 0.99:
					ceiling = true
	var side_fraction := float(side_hits) / float(SIDE_RAYS)
	var up_fraction := float(up_hits) / float(maxi(up_total, 1))
	# Walls all around make a room; a roof makes it a closed one. Open sky takes most of it away.
	var enclosure := side_fraction * (0.35 + 0.65 * up_fraction)
	return {
		"enclosure": clampf(enclosure, 0.0, 1.0),
		"mean_distance": side_total / float(side_hits) if side_hits > 0 else SIDE_LENGTH,
		"ceiling": ceiling,
		"open_sides": SIDE_RAYS - side_hits,
	}


## Reverb settings for a measurement: {"wet", "room_size", "damping"}.
static func reverb_for(measurement: Dictionary) -> Dictionary:
	var enclosure := float(measurement.enclosure)
	var distance := float(measurement.mean_distance)
	return {
		"wet": lerpf(OPEN_WET, MAX_WET, pow(enclosure, 1.4)),
		"room_size": clampf(distance / SIDE_LENGTH + 0.12, MIN_ROOM_SIZE, MAX_ROOM_SIZE),
		"damping": lerpf(0.35, 0.7, enclosure), ## a closed room soaks up the highs
	}


## One easing step from `current` toward `target` (both {"wet", "room_size", "damping"}).
static func ease_toward(current: Dictionary, target: Dictionary, delta: float) -> Dictionary:
	var amount := 1.0 - exp(-EASE_PER_SECOND * delta)
	return {
		"wet": lerpf(float(current.wet), float(target.wet), amount),
		"room_size": lerpf(float(current.room_size), float(target.room_size), amount),
		"damping": lerpf(float(current.damping), float(target.damping), amount),
	}


static func apply(reverb: AudioEffectReverb, settings: Dictionary) -> void:
	if reverb == null:
		return
	reverb.wet = float(settings.wet)
	reverb.room_size = float(settings.room_size)
	reverb.damping = float(settings.damping)

