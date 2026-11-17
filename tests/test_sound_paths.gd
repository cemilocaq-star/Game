extends SceneTree
## Sound paths on synthetic geometry (vertical walls given as segments on the floor plane), so the
## logic is checked without a physics world, plus one run against real physics bodies.

const PATHS := preload("res://scripts/sound_paths.gd")
const OCCLUSION := preload("res://scripts/sound_occlusion.gd")
const WORLD_AUDIO := preload("res://scripts/world_audio.gd")
const COMBAT_FX := preload("res://scripts/combat_fx.gd")
const SFX_BANK := preload("res://scripts/sfx_bank.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## Tracer over wall segments [[Vector2 a, Vector2 b], ...] in (x, z). Heights are ignored.
func _tracer(walls: Array) -> Callable:
	return func(from: Vector3, to: Vector3) -> Dictionary:
		var best_t := 2.0
		var p := Vector2(from.x, from.z)
		var r := Vector2(to.x - from.x, to.z - from.z)
		for wall in walls:
			var q: Vector2 = wall[0]
			var s: Vector2 = (wall[1] as Vector2) - q
			var denominator := r.cross(s)
			if absf(denominator) < 0.000001:
				continue
			var t := (q - p).cross(s) / denominator
			var u := (q - p).cross(r) / denominator
			if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0 and t < best_t:
				best_t = t
		if best_t > 1.0:
			return {}
		return {"position": from.lerp(to, best_t)}


func _wall(x0: float, x1: float, z: float) -> Array:
	return [Vector2(x0, z), Vector2(x1, z)]


func _run() -> void:
	var listener := Vector3(0.0, 1.5, -10.0)
	var source := Vector3(0.0, 1.5, 10.0)

	# 1. Clear line: untouched sound.
	var clear: Dictionary = PATHS.resolve(listener, source, _tracer([]))
	_check(clear.kind == "direct", "an open line is a direct path")
	_check(is_equal_approx(float(clear.path_length), 20.0), "a direct path is as long as the distance")
	_check((clear.apparent_position as Vector3).is_equal_approx(source), "a direct sound stays where it is")
	_check(float(clear.cutoff_hz) >= 20000.0 and is_zero_approx(float(clear.volume_db)), "a direct sound is not filtered or quieted")

	# 2. A wall with an open end: heard around the end of the wall, longer, duller, from that side.
	var short_wall: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-5.0, 5.0, 0.0)]))
	_check(short_wall.kind == "diffracted", "a sound past the end of a wall bends around it (%s)" % short_wall.kind)
	_check(float(short_wall.path_length) > 20.0 and float(short_wall.path_length) < 40.0, "the way around is longer than the direct line (%.1f m)" % float(short_wall.path_length))
	_check(float(short_wall.cutoff_hz) < 20000.0 and float(short_wall.cutoff_hz) > 1500.0, "a bent sound is duller but not smothered (%.0f Hz)" % float(short_wall.cutoff_hz))
	_check(float(short_wall.volume_db) < 0.0, "a bent sound loses level")
	_check(absf(float((short_wall.apparent_position as Vector3).x)) > 2.0, "the sound seems to come from beside the wall, not through it")
	_check(is_equal_approx((short_wall.apparent_position as Vector3).distance_to(listener), float(short_wall.path_length)), "the apparent position is exactly one path length away (distance fall-off carries the detour)")

	# 3. An open door in a long wall: only a small bend, brighter than a sharp corner.
	var door: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-100.0, 2.5, 0.0), _wall(4.0, 100.0, 0.0)]))
	_check(door.kind == "diffracted", "a sound through a doorway is heard through it (%s)" % door.kind)
	var toward_door: Vector3 = ((door.apparent_position as Vector3) - listener).normalized()
	var door_direction := (Vector3(3.2, 1.5, 0.0) - listener).normalized()
	_check(toward_door.angle_to(door_direction) < deg_to_rad(12.0), "the sound arrives from the direction of the door (%.1f deg off)" % rad_to_deg(toward_door.angle_to(door_direction)))
	_check(float(door.cutoff_hz) > float(short_wall.cutoff_hz) - 1.0 or float(door.bend_degrees) < float(short_wall.bend_degrees), "a gentle bend keeps at least as much brightness as a sharp one")

	# 4. A closed wall: muffled by the wall instead.
	var closed: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-100.0, 100.0, 0.0)]))
	var one_wall: Dictionary = OCCLUSION.profile(1)
	_check(closed.kind == "blocked" and int(closed.surfaces) == 1, "a long solid wall blocks the sound (%s, %d)" % [closed.kind, int(closed.surfaces)])
	_check(is_equal_approx(float(closed.cutoff_hz), float(one_wall.cutoff_hz)) and is_equal_approx(float(closed.volume_db), float(one_wall.volume_db)), "a blocked sound uses the one-wall muffling profile")
	_check((closed.apparent_position as Vector3).is_equal_approx(source), "a blocked sound stays where it is")

	# 5. Two walls in a row (a closed room): muffled more, and no way around is tried.
	var two: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-100.0, 100.0, -3.0), _wall(-100.0, 100.0, 4.0)]))
	_check(two.kind == "blocked" and int(two.surfaces) == 2, "two walls count as two surfaces (%d)" % int(two.surfaces))
	_check(float(two.cutoff_hz) < float(closed.cutoff_hz) and float(two.volume_db) < float(closed.volume_db), "two walls muffle more than one")
	var short_two: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-5.0, 5.0, -3.0), _wall(-5.0, 5.0, 4.0)]))
	_check(short_two.kind == "blocked", "no detour is attempted past two obstacles")

	# 6. A way around that is far too long does not count.
	var far_gap: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-100.0, 40.0, 0.0)]))
	_check(far_gap.kind == "blocked", "a gap 40 m away is not a way around for a 20 m sound (%s)" % far_gap.kind)

	# 7. A sharper bend dulls the sound more.
	var near_listener := Vector3(0.0, 1.5, -1.5)
	var near_source := Vector3(0.0, 1.5, 1.5)
	var sharp: Dictionary = PATHS.resolve(near_listener, near_source, _tracer([_wall(-1.0, 1.0, 0.0)]))
	var wide: Dictionary = PATHS.resolve(listener, source, _tracer([_wall(-8.0, 8.0, 0.0)]))
	if sharp.kind == "diffracted" and wide.kind == "diffracted":
		_check(float(sharp.bend_degrees) > float(wide.bend_degrees), "hugging a wall bends the sound more than standing back (%.0f vs %.0f deg)" % [float(sharp.bend_degrees), float(wide.bend_degrees)])
		_check(float(sharp.cutoff_hz) < float(wide.cutoff_hz), "the sharper bend is duller")
		_check(float(sharp.volume_db) < float(wide.volume_db), "the sharper bend is quieter")
	else:
		_check(false, "both the close and the wide wall should have a way around (%s / %s)" % [sharp.kind, wide.kind])

	# 8. Edge cases: same point, vertical line.
	var same: Dictionary = PATHS.resolve(listener, listener, _tracer([_wall(-100.0, 100.0, 0.0)]))
	_check(same.kind == "direct", "a sound at the listener is direct")
	var above: Dictionary = PATHS.resolve(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 20.0, 0.0), _tracer([]))
	_check(above.kind == "direct" and is_equal_approx(float(above.path_length), 20.0), "a vertical clear line works")
	var finite := true
	for result in [clear, short_wall, door, closed, two, far_gap, sharp, wide, same, above]:
		var position_value: Vector3 = result.apparent_position
		finite = finite and is_finite(position_value.x) and is_finite(position_value.y) and is_finite(position_value.z) and is_finite(float(result.cutoff_hz)) and is_finite(float(result.volume_db))
	_check(finite, "all results are finite")

	# 9. Surface counting.
	_check(PATHS.count_surfaces(_tracer([]), listener, source) == 0, "no walls, no surfaces")
	_check(PATHS.count_surfaces(_tracer([_wall(-9.0, 9.0, -6.0), _wall(-9.0, 9.0, -2.0), _wall(-9.0, 9.0, 2.0), _wall(-9.0, 9.0, 6.0)]), listener, source) == OCCLUSION.MAX_COUNTED, "surface counting stops at the cap")

	# 10. Real physics: the same logic against static bodies, and applying the result to a player.
	await _test_physics()

	if failures.is_empty():
		print("PASS: sound paths (direct, around a wall end, through a door, blocked, closed rooms, limits, physics)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_physics() -> void:
	var world := Node3D.new()
	root.add_child(world)
	# One wall 10 m wide at z = 0 with open space to either side.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 6.0, 1.0)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = Vector3(0.0, 3.0, 0.0)
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var tracer: Callable = PATHS.physics_tracer(space)
	var listener := Vector3(0.0, 1.5, -10.0)
	var source := Vector3(0.0, 1.5, 10.0)
	var around: Dictionary = PATHS.resolve(listener, source, tracer)
	_check(around.kind == "diffracted", "physics: a sound past a 10 m wall bends around it (%s)" % around.kind)
	_check(absf(float((around.apparent_position as Vector3).x)) > 2.0, "physics: it seems to come from beside the wall")
	var clear: Dictionary = PATHS.resolve(Vector3(12.0, 1.5, -10.0), Vector3(12.0, 1.5, 10.0), tracer)
	_check(clear.kind == "direct", "physics: a line clear of the wall is direct")

	var audio := AudioStreamPlayer3D.new()
	world.add_child(audio)
	PATHS.apply(audio, around, source, -7.0)
	_check(audio.global_position.is_equal_approx(around.apparent_position), "apply moves a bent sound to its apparent position")
	_check(audio.attenuation_filter_cutoff_hz < 20000.0 and audio.volume_db < -7.0, "apply filters and lowers a bent sound")
	PATHS.apply(audio, clear, source, -7.0)
	_check(audio.global_position.is_equal_approx(source) and is_equal_approx(audio.volume_db, -7.0), "apply leaves a direct sound alone")

	# WorldAudio: the one-shot helper used for gunfire, explosions and footsteps.
	var stream := SFX_BANK.stream("hit")
	var bent_sound: AudioStreamPlayer3D = WORLD_AUDIO.play_at(world, stream, source, -7.0, 42.0, 9.0, listener, [], 1.0, "TestBent")
	_check(bent_sound != null and str(bent_sound.get_meta("sound_path")) == "diffracted", "WorldAudio bends a sound around the wall")
	var open_sound: AudioStreamPlayer3D = WORLD_AUDIO.play_at(world, stream, Vector3(12.0, 1.5, 10.0), -7.0, 42.0, 9.0, Vector3(12.0, 1.5, -10.0), [], 1.0, "TestOpen")
	_check(open_sound != null and str(open_sound.get_meta("sound_path")) == "direct", "WorldAudio leaves an open sound direct")
	_check(WORLD_AUDIO.play_at(world, stream, Vector3(0.0, 1.5, 100.0), -7.0, 42.0, 9.0, listener, [], 1.0, "TestFar") == null, "a sound beyond its range is not started")
	_check(WORLD_AUDIO.play_at(world, null, source, -7.0, 42.0, 9.0, listener) == null, "no stream, no sound")
	_check(is_equal_approx(bent_sound.pitch_scale, 1.0) and bent_sound.name == "TestBent", "WorldAudio applies the name and pitch it was given")

	# A grenade blast is audible, and goes through the same path logic.
	var before := world.get_child_count()
	COMBAT_FX.grenade_explosion(world, Vector3(0.0, 0.5, 6.0))
	var blast_audio := world.get_node_or_null("GrenadeExplosionAudio") as AudioStreamPlayer3D
	_check(world.get_child_count() > before, "a grenade explosion adds effects")
	_check(blast_audio != null, "a grenade explosion makes a sound")
	if blast_audio != null:
		var blast_seconds := float(blast_audio.stream.get_length())
		_check(blast_seconds > 0.6 and blast_seconds <= 0.9, "the blast lasts under a second (%.2f s)" % blast_seconds)
	_check(SFX_BANK.stream("explosion").get_length() > SFX_BANK.stream("kill").get_length(), "the explosion is the longest sound in the bank")
