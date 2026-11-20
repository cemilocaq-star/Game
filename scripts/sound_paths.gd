extends RefCounted
## Sound paths: how a sound reaches the listener when the straight line is blocked.
##
## A sound behind one wall is muffled (SoundOcclusion). But a sound around a corner or past an open
## door is not "behind a wall" for the ear: it arrives through the opening, quieter because the way
## is longer, duller because it bends, and from the direction of the opening. This looks for a
## one-bend path around the obstacle and, if there is one, tells the caller to place the sound at an
## apparent position that sits along the bend direction at the full path length. The 3D player's own
## distance attenuation and panning then do the rest. With no way around, it falls back to the wall
## muffling profile from SoundOcclusion.
##
## Geometry comes through a `tracer` Callable (from: Vector3, to: Vector3) -> Dictionary, which
## returns {} when the line is clear or {"position": Vector3} for the first thing it hits. That keeps
## the logic testable without a physics world; physics_tracer() builds one for the real game.

const OCCLUSION := preload("res://scripts/sound_occlusion.gd")

const CLEAR_CUTOFF_HZ := 20500.0
const DETOUR_OFFSETS := [0.8, 1.6, 2.6, 4.0, 6.0, 8.5, 12.0] ## metres sideways from where the line hits
const PULL_BACK := 0.35 ## the bend point sits this far before the obstacle so it is not inside it
const MAX_PATH_RATIO := 2.0 ## a way around that is more than twice the direct distance does not count
const MAX_EXTRA_METRES := 45.0
const DIFFRACTED_CUTOFF_NEAR := 9000.0 ## a gentle bend (an open door) keeps most of the brightness
const DIFFRACTED_CUTOFF_FAR := 1800.0 ## a sharp turn takes the highs away
const DIFFRACTED_DB_NEAR := -1.5
const DIFFRACTED_DB_FAR := -6.5
const FULL_BEND_DEGREES := 120.0
const MIN_DISTANCE := 0.05


## Builds a tracer that casts against a physics world.
static func physics_tracer(space: PhysicsDirectSpaceState3D, exclude: Array[RID] = [], collision_mask: int = 1) -> Callable:
	return func(from: Vector3, to: Vector3) -> Dictionary:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		query.collision_mask = collision_mask
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		return {"position": hit.position}


## Separate solid surfaces on the line (up to SoundOcclusion.MAX_COUNTED), by casting past each hit.
static func count_surfaces(tracer: Callable, from: Vector3, to: Vector3) -> int:
	var total := from.distance_to(to)
	if total < MIN_DISTANCE:
		return 0
	var direction := (to - from) / total
	var start := from
	var count := 0
	for _step in range(OCCLUSION.MAX_COUNTED):
		var hit: Dictionary = tracer.call(start, to)
		if hit.is_empty():
			break
		count += 1
		start = (hit.position as Vector3) + direction * 0.1
		if (to - start).dot(direction) <= 0.1:
			break
	return count


## The result for a sound at `source` heard from `listener`:
## {"kind": "direct" | "diffracted" | "blocked", "surfaces": int, "path_length": float,
##  "apparent_position": Vector3, "cutoff_hz": float, "volume_db": float, "bend_degrees": float}
static func resolve(listener: Vector3, source: Vector3, tracer: Callable) -> Dictionary:
	var direct := listener.distance_to(source)
	var result := {
		"kind": "direct", "surfaces": 0, "path_length": direct, "apparent_position": source,
		"cutoff_hz": CLEAR_CUTOFF_HZ, "volume_db": 0.0, "bend_degrees": 0.0,
	}
	if direct < MIN_DISTANCE:
		return result
	var first_hit: Dictionary = tracer.call(listener, source)
	if first_hit.is_empty():
		return result

	var surfaces := count_surfaces(tracer, listener, source)
	var profile: Dictionary = OCCLUSION.profile(surfaces)
	result.kind = "blocked"
	result.surfaces = surfaces
	result.cutoff_hz = float(profile.cutoff_hz)
	result.volume_db = float(profile.volume_db)

	# A way around only makes sense past a single obstacle; several walls in a row are a closed room.
	if surfaces > 1:
		return result
	var detour := _best_detour(listener, source, first_hit.position as Vector3, tracer)
	if detour.is_empty():
		return result
	var bend_point: Vector3 = detour.point
	var path_length: float = detour.length
	var bend := rad_to_deg((bend_point - listener).angle_to(source - bend_point))
	var amount := clampf(bend / FULL_BEND_DEGREES, 0.0, 1.0)
	result.kind = "diffracted"
	result.path_length = path_length
	result.apparent_position = listener + (bend_point - listener).normalized() * path_length
	result.cutoff_hz = lerpf(DIFFRACTED_CUTOFF_NEAR, DIFFRACTED_CUTOFF_FAR, amount)
	result.volume_db = lerpf(DIFFRACTED_DB_NEAR, DIFFRACTED_DB_FAR, amount)
	result.bend_degrees = bend
	return result


static func _best_detour(listener: Vector3, source: Vector3, hit_point: Vector3, tracer: Callable) -> Dictionary:
	var direct := listener.distance_to(source)
	var direction := (source - listener) / direct
	var side := direction.cross(Vector3.UP)
	if side.length() < 0.2:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var best := {}
	var best_length := minf(direct * MAX_PATH_RATIO, direct + MAX_EXTRA_METRES)
	for offset in DETOUR_OFFSETS:
		for sign_value in [-1.0, 1.0]:
			var candidate: Vector3 = hit_point - direction * PULL_BACK + side * float(sign_value) * float(offset)
			var length := listener.distance_to(candidate) + candidate.distance_to(source)
			if length >= best_length:
				continue
			if not (tracer.call(listener, candidate) as Dictionary).is_empty():
				continue
			if not (tracer.call(candidate, source) as Dictionary).is_empty():
				continue
			best = {"point": candidate, "length": length}
			best_length = length
	return best


## Applies a resolved path to a positional player: where it seems to be, how bright, how loud.
## Returns the resolved dictionary. `base_position` is the sound's real position.
static func apply(audio: AudioStreamPlayer3D, resolved: Dictionary, base_position: Vector3, base_volume_db: float) -> void:
	if audio == null:
		return
	audio.global_position = resolved.apparent_position if resolved.kind == "diffracted" else base_position
	audio.attenuation_filter_cutoff_hz = float(resolved.cutoff_hz)
	audio.attenuation_filter_db = 0.0 if resolved.kind == "direct" else -24.0
	audio.volume_db = base_volume_db + float(resolved.volume_db)
