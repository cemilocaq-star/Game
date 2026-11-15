extends SceneTree
## Layered weapon audio, wall occlusion and the recorded CC0 layers.

const WEAPON_AUDIO := preload("res://scripts/weapon_audio.gd")
const OCCLUSION := preload("res://scripts/sound_occlusion.gd")
const BANK := preload("res://scripts/sfx_bank.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _floats(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(wav.data.size() / 2)
	for index in range(out.size()):
		out[index] = float(wav.data.decode_s16(index * 2)) / 32768.0
	return out


func _peak(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	return peak


## Share of the signal's energy below `cutoff_hz` (one-pole low-pass).
func _low_ratio(samples: PackedFloat32Array, cutoff_hz: float) -> float:
	var alpha := 1.0 - exp(-TAU * cutoff_hz / float(WEAPON_AUDIO.SAMPLE_RATE))
	var state := 0.0
	var low := 0.0
	var total := 0.0
	for value in samples:
		state += alpha * (value - state)
		low += state * state
		total += value * value
	return low / maxf(total, 0.000001)


## Share of the energy above roughly 3 kHz (signal minus a low-passed copy).
func _high_ratio(samples: PackedFloat32Array) -> float:
	var alpha := 1.0 - exp(-TAU * 3000.0 / float(WEAPON_AUDIO.SAMPLE_RATE))
	var state := 0.0
	var high := 0.0
	var total := 0.0
	for value in samples:
		state += alpha * (value - state)
		var residue := value - state
		high += residue * residue
		total += value * value
	return high / maxf(total, 0.000001)


func _run() -> void:
	var ids: Array = WEAPON_AUDIO.weapon_ids()
	_check(ids.size() == 27, "all 27 weapons have a sound profile (%d)" % ids.size())
	for id in ids:
		var own: AudioStreamWAV = WEAPON_AUDIO.stream(str(id), "own", 0)
		var samples := _floats(own)
		var seconds := float(samples.size()) / float(WEAPON_AUDIO.SAMPLE_RATE)
		_check(seconds >= 0.25 and seconds <= 0.9, "%s own shot has body plus tail (%f s)" % [id, seconds])
		var peak := _peak(samples)
		_check(peak > 0.5 and peak <= 1.0, "%s is audible and not clipped (%f)" % [id, peak])
		var far := _floats(WEAPON_AUDIO.stream(str(id), "far", 0))
		_check(far.size() > samples.size(), "%s far shot has a longer tail" % id)
		_check(_peak(far) < peak, "%s far shot is quieter" % id)
	_check(WEAPON_AUDIO.stream("not_a_weapon", "own", 0) == WEAPON_AUDIO.stream("aether", "own", 0), "an unknown weapon falls back to the default sound")

	# Variants: different bytes, same bytes when asked again, wrapping index.
	var v0: AudioStreamWAV = WEAPON_AUDIO.stream("minicore", "own", 0)
	var v1: AudioStreamWAV = WEAPON_AUDIO.stream("minicore", "own", 1)
	var v2: AudioStreamWAV = WEAPON_AUDIO.stream("minicore", "own", 2)
	_check(v0.data != v1.data and v1.data != v2.data and v0.data != v2.data, "each weapon has three different variants")
	_check(WEAPON_AUDIO.stream("minicore", "own", 0) == v0, "variants are cached")
	_check(WEAPON_AUDIO.stream("minicore", "own", 3) == v0, "the variant index wraps")
	WEAPON_AUDIO._cache.clear()
	_check(WEAPON_AUDIO.stream("minicore", "own", 1).data == v1.data, "rendering is deterministic")

	# Layer roles: heavy weapons carry more low end, own fire has more crack than distant fire.
	var heavy := _floats(WEAPON_AUDIO.stream("thunder_drum", "own", 0))
	var light := _floats(WEAPON_AUDIO.stream("pixel_storm", "own", 0))
	_check(WEAPON_AUDIO.weight("thunder_drum") > WEAPON_AUDIO.weight("pixel_storm"), "weight ranks the deep weapon above the high one")
	_check(_low_ratio(heavy, 150.0) > _low_ratio(light, 150.0), "a heavy weapon has more sub energy than a light one")
	var own_mid := _floats(WEAPON_AUDIO.stream("aether", "own", 0))
	var far_mid := _floats(WEAPON_AUDIO.stream("aether", "far", 0))
	_check(_high_ratio(own_mid) > _high_ratio(far_mid), "own fire has more crack than distant fire")

	# Occlusion profile: more walls, darker and quieter.
	var open: Dictionary = OCCLUSION.profile(0)
	var one: Dictionary = OCCLUSION.profile(1)
	var two: Dictionary = OCCLUSION.profile(2)
	var many: Dictionary = OCCLUSION.profile(9)
	_check(float(open.cutoff_hz) >= 20000.0 and float(open.volume_db) == 0.0, "an open line is unfiltered")
	_check(float(one.cutoff_hz) < float(open.cutoff_hz) and float(two.cutoff_hz) < float(one.cutoff_hz), "each wall lowers the cutoff")
	_check(float(one.volume_db) < 0.0 and float(two.volume_db) < float(one.volume_db), "each wall lowers the volume")
	_check(many == OCCLUSION.profile(3) and float(OCCLUSION.profile(-4).cutoff_hz) == float(open.cutoff_hz), "the profile is clamped")

	# Occlusion against real collision: two walls between the listener and the source.
	for z in [-5.0, -8.0]:
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.0, 4.0, 0.6)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector3(0.0, 1.0, z)
		root.add_child(wall)
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var origin := Vector3(0.0, 1.0, 0.0)
	_check(OCCLUSION.count_blocking(space, origin, Vector3(0.0, 1.0, -3.0)) == 0, "nothing between the listener and a near source")
	_check(OCCLUSION.count_blocking(space, origin, Vector3(0.0, 1.0, -6.5)) == 1, "one wall is counted once")
	_check(OCCLUSION.count_blocking(space, origin, Vector3(0.0, 1.0, -12.0)) == 2, "two separate walls are counted twice")
	_check(OCCLUSION.count_blocking(space, origin, Vector3(20.0, 1.0, -12.0)) == 0, "a line that goes around the walls is clear")
	var speaker := AudioStreamPlayer3D.new()
	root.add_child(speaker)
	speaker.global_position = Vector3(0.0, 1.0, -12.0)
	var blocked: int = OCCLUSION.apply(speaker, origin, space, -7.0)
	_check(blocked == 2, "apply reports the walls it found")
	_check(speaker.attenuation_filter_cutoff_hz < 2000.0 and speaker.volume_db < -7.0, "apply muffles and softens the source")
	speaker.global_position = Vector3(0.0, 1.0, -3.0)
	OCCLUSION.apply(speaker, origin, space, -7.0)
	_check(speaker.attenuation_filter_cutoff_hz >= 20000.0 and is_equal_approx(speaker.volume_db, -7.0), "an open line restores the sound")

	# Recorded CC0 recordings are shipped and loadable.
	for sound_name in ["hit-light", "hit-medium", "hit-heavy", "land", "menu-move", "menu-confirm", "menu-back", "respawn", "throw"]:
		var recording: AudioStream = BANK.recorded(sound_name)
		_check(recording != null and recording.get_length() > 0.05, "recorded sound %s loads" % sound_name)
	_check(BANK.recorded("does-not-exist") == null, "a missing recording returns null instead of crashing")

	if failures.is_empty():
		print("PASS: layered weapon audio, variants, wall occlusion and recorded CC0 sounds")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
