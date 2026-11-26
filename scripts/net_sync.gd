extends RefCounted
## Pure netcode helpers shared by the client and the dedicated server (no scene access, so they
## are unit-testable). The techniques follow what the big competitive shooters document:
##  - snapshot interpolation: render other players ~100 ms in the past between two snapshots
##    (Source engine default), extrapolating only briefly when a snapshot is late;
##  - lag compensation: the server rewinds enemy positions to what the shooter saw, but never by
##    more than MAX_REWIND_MS (Overwatch clamps near 220 ms so high ping cannot dominate);
##  - reconciliation: the client predicts its own movement, so the server position is compared with
##    where the client was *at that input* and only real disagreement is corrected, smoothly.

const INTERP_DELAY_MS := 100
const MAX_EXTRAPOLATION_MS := 100
const MAX_REWIND_MS := 220
const HISTORY_MS := 1000
const TELEPORT_DISTANCE := 8.0
const RECONCILE_DEADZONE := 0.35
const RECONCILE_SNAP_DISTANCE := 3.0
const RECONCILE_NUDGE := 0.35
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.8
const PLAYER_HEIGHT_SLIDING := 1.0


## Time-ordered samples of (time_ms, position, yaw) for one remote player.
class SnapshotBuffer extends RefCounted:
	var times: Array[int] = []
	var positions: Array[Vector3] = []
	var yaws: Array[float] = []
	var max_samples := 32

	func clear() -> void:
		times.clear()
		positions.clear()
		yaws.clear()

	func size() -> int:
		return times.size()

	func push(time_ms: int, position_value: Vector3, yaw_value: float) -> void:
		if not times.is_empty():
			if time_ms <= times[times.size() - 1]:
				return
			# A respawn or teleport must not slide across the map.
			if positions[positions.size() - 1].distance_to(position_value) > TELEPORT_DISTANCE:
				clear()
		times.append(time_ms)
		positions.append(position_value)
		yaws.append(yaw_value)
		while times.size() > max_samples:
			times.remove_at(0)
			positions.remove_at(0)
			yaws.remove_at(0)

	## Returns {"position": Vector3, "yaw": float, "extrapolated": bool, "valid": bool}.
	func sample(render_time_ms: int) -> Dictionary:
		if times.is_empty():
			return {"valid": false, "position": Vector3.ZERO, "yaw": 0.0, "extrapolated": false}
		var last := times.size() - 1
		if times.size() == 1 or render_time_ms <= times[0]:
			return {"valid": true, "position": positions[0], "yaw": yaws[0], "extrapolated": false}
		if render_time_ms >= times[last]:
			# Snapshot is late: continue along the last known velocity for a short while only.
			var gap := render_time_ms - times[last]
			var span := maxf(1.0, float(times[last] - times[last - 1]))
			var velocity := (positions[last] - positions[last - 1]) / span
			var capped := mini(gap, MAX_EXTRAPOLATION_MS)
			return {"valid": true, "position": positions[last] + velocity * float(capped), "yaw": yaws[last], "extrapolated": true}
		for index in range(last):
			if render_time_ms >= times[index] and render_time_ms <= times[index + 1]:
				var length := float(times[index + 1] - times[index])
				var weight := clampf(float(render_time_ms - times[index]) / maxf(1.0, length), 0.0, 1.0)
				return {
					"valid": true,
					"position": positions[index].lerp(positions[index + 1], weight),
					"yaw": lerp_angle(yaws[index], yaws[index + 1], weight),
					"extrapolated": false
				}
		return {"valid": true, "position": positions[last], "yaw": yaws[last], "extrapolated": false}


## Recent positions of one player, used for lag compensation (server) and reconciliation (client).
class PositionHistory extends RefCounted:
	var times: Array[int] = []
	var positions: Array[Vector3] = []
	var heights: Array[float] = []

	func record(time_ms: int, position_value: Vector3, height: float = PLAYER_HEIGHT) -> void:
		if not times.is_empty() and time_ms <= times[times.size() - 1]:
			return
		times.append(time_ms)
		positions.append(position_value)
		heights.append(height)
		while times.size() > 1 and time_ms - times[0] > HISTORY_MS:
			times.remove_at(0)
			positions.remove_at(0)
			heights.remove_at(0)

	func size() -> int:
		return times.size()

	## Interpolated position at time_ms, or null when there is no history that old/new.
	func position_at(time_ms: int) -> Variant:
		if times.is_empty():
			return null
		if time_ms <= times[0]:
			return positions[0]
		var last := times.size() - 1
		if time_ms >= times[last]:
			return positions[last]
		for index in range(last):
			if time_ms >= times[index] and time_ms <= times[index + 1]:
				var weight := clampf(float(time_ms - times[index]) / maxf(1.0, float(times[index + 1] - times[index])), 0.0, 1.0)
				return positions[index].lerp(positions[index + 1], weight)
		return positions[last]

	func height_at(time_ms: int, fallback: float = PLAYER_HEIGHT) -> float:
		if times.is_empty():
			return fallback
		var chosen := heights[0]
		for index in range(times.size()):
			if times[index] <= time_ms:
				chosen = heights[index]
			else:
				break
		return chosen


## How far back (ms) the server rewinds enemies for a shot: half the round trip plus the
## interpolation delay the shooter's screen was behind, clamped so high ping stays fair.
static func rewind_ms(round_trip_ms: float, interp_delay_ms: int = INTERP_DELAY_MS) -> int:
	if not is_finite(round_trip_ms):
		return 0
	return clampi(int(round(maxf(0.0, round_trip_ms) * 0.5)) + interp_delay_ms, 0, MAX_REWIND_MS)


## Clamps a client-reported view delay to the allowed rewind window (never trust the client).
static func clamp_rewind(value_ms: int) -> int:
	return clampi(value_ms, 0, MAX_REWIND_MS)


## Distance along the ray (origin, unit direction) where it first touches a vertical capsule
## standing on `base` (feet), or -1.0 when it misses within max_distance.
static func ray_capsule_distance(origin: Vector3, direction: Vector3, max_distance: float, base: Vector3, radius: float = PLAYER_RADIUS, height: float = PLAYER_HEIGHT) -> float:
	var seg_a := base + Vector3.UP * radius
	var seg_b := base + Vector3.UP * maxf(radius, height - radius)
	# Closest points between the ray segment P(s)=origin+direction*s and the capsule axis Q(t).
	var d1 := direction * max_distance
	var d2 := seg_b - seg_a
	var r := origin - seg_a
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 0.000001:
		return -1.0
	if e <= 0.000001:
		t = 0.0
		s = clampf(-d1.dot(r) / a, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		var b := d1.dot(d2)
		var denom := a * e - b * b
		if denom > 0.000001:
			s = clampf((b * f - c * e) / denom, 0.0, 1.0)
		t = (b * s + f) / e
		if t < 0.0:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((b - c) / a, 0.0, 1.0)
	var closest_ray := origin + d1 * s
	var closest_axis := seg_a + d2 * t
	var gap := closest_ray.distance_to(closest_axis)
	if gap > radius:
		return -1.0
	# Pull back from the closest approach to the point where the ray enters the capsule.
	var entry := maxf(0.0, s * max_distance - sqrt(maxf(0.0, radius * radius - gap * gap)))
	return entry


## Compares the server's position with where the client predicted it to be at the same moment.
## Returns {"action": "none"|"nudge"|"snap", "position": Vector3 (new local position)}.
static func reconcile(server_position: Vector3, reference_position: Vector3, current_position: Vector3, dead: bool = false) -> Dictionary:
	if dead:
		return {"action": "snap", "position": server_position}
	var error := server_position - reference_position
	var distance := error.length()
	if distance >= RECONCILE_SNAP_DISTANCE:
		return {"action": "snap", "position": server_position}
	if distance <= RECONCILE_DEADZONE:
		return {"action": "none", "position": current_position}
	# Only the part beyond the dead-zone is corrected, spread across several snapshots.
	var excess := error.normalized() * (distance - RECONCILE_DEADZONE)
	return {"action": "nudge", "position": current_position + excess * RECONCILE_NUDGE}
