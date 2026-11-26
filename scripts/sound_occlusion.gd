extends RefCounted
## Sound occlusion: gunfire from another room is muffled and quieter, like the "sound paths" in
## big shooters but approximated with a straight ray. The number of separate solid surfaces on the
## line from the listener to the source (up to 3) picks a low-pass cutoff and a volume cut. Godot's
## AudioStreamPlayer3D attenuation filter does the actual low-pass.

const CLEAR_CUTOFF_HZ := 20500.0
const MAX_COUNTED := 3
const CUTOFF_HZ := [20500.0, 2400.0, 1200.0, 700.0]
const VOLUME_DB := [0.0, -4.0, -8.0, -12.0]


## {"cutoff_hz": float, "volume_db": float} for this many blocking surfaces.
static func profile(blocked_surfaces: int) -> Dictionary:
	var index := clampi(blocked_surfaces, 0, MAX_COUNTED)
	return {"cutoff_hz": float(CUTOFF_HZ[index]), "volume_db": float(VOLUME_DB[index])}


## Counts separate solid surfaces between two points by re-casting past each hit.
static func count_blocking(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID] = [], collision_mask: int = 1) -> int:
	var count := 0
	var start := from
	var direction := to - from
	var total := direction.length()
	if total < 0.01:
		return 0
	direction = direction / total
	for _step in range(MAX_COUNTED):
		var query := PhysicsRayQueryParameters3D.create(start, to)
		query.exclude = exclude
		query.collision_mask = collision_mask
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		count += 1
		start = hit.position + direction * 0.1
		if (to - start).dot(direction) <= 0.1:
			break
	return count


## Muffles a positional player according to what stands between it and the listener.
static func apply(audio: AudioStreamPlayer3D, listener: Vector3, space: PhysicsDirectSpaceState3D, base_volume_db: float, exclude: Array[RID] = []) -> int:
	if audio == null or space == null:
		return 0
	var blocked := count_blocking(space, listener, audio.global_position, exclude)
	var settings := profile(blocked)
	audio.attenuation_filter_cutoff_hz = float(settings.cutoff_hz)
	audio.attenuation_filter_db = -24.0 if blocked > 0 else 0.0
	audio.volume_db = base_volume_db + float(settings.volume_db)
	return blocked
