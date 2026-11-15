extends RefCounted
## Original, locally synthesized interface and feedback sounds (no third-party audio, nothing
## copied from any game). They follow what competitive shooters document for feedback audio:
## short, high-contrast cues that stay readable over gunfire - a bright tick for a hit, a rising
## two-note ding plus low thump for a kill, a low thud for damage taken, a slow double-thump
## heartbeat when health is low, accelerating beeps for a bomb and soft ticks for a countdown.

const SAMPLE_RATE := 22050
const IDS := ["ui_hover", "ui_click", "hit", "kill", "damage", "heartbeat", "beep", "tick"]

static var _cache: Dictionary = {}


static func stream(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		_cache[id] = _build(id)
	return _cache[id]


static func _build(id: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match id:
		"ui_hover":
			samples = _burst(0.04, 2200.0, 2000.0, 0.0, 6.0, 1)
			_scale(samples, 0.35)
		"ui_click":
			samples = _burst(0.05, 900.0, 1500.0, 0.05, 5.0, 2)
			_mix(samples, _burst(0.05, 1500.0, 1900.0, 0.0, 6.0, 3), 0.03, 0.8)
		"hit":
			samples = _burst(0.06, 2400.0, 1800.0, 0.35, 7.0, 4)
			_mix(samples, _burst(0.05, 160.0, 90.0, 0.2, 8.0, 5), 0.0, 0.55)
		"kill":
			samples = _burst(0.22, 880.0, 880.0, 0.0, 5.0, 6, 0.3)
			_mix(samples, _burst(0.26, 1320.0, 1320.0, 0.0, 5.0, 7, 0.3), 0.09, 1.0)
			_mix(samples, _burst(0.12, 110.0, 60.0, 0.3, 6.0, 8), 0.0, 0.6)
		"damage":
			samples = _burst(0.16, 120.0, 55.0, 0.45, 5.0, 9)
			_mix(samples, _burst(0.05, 700.0, 400.0, 0.7, 10.0, 10), 0.0, 0.4)
		"heartbeat":
			samples = _burst(0.14, 62.0, 40.0, 0.1, 5.0, 11)
			_mix(samples, _burst(0.12, 55.0, 38.0, 0.1, 6.0, 12), 0.26, 0.8)
		"beep":
			samples = _burst(0.09, 1040.0, 1040.0, 0.0, 3.0, 13, 0.2)
		"tick":
			samples = _burst(0.05, 700.0, 700.0, 0.08, 7.0, 14)
		_:
			samples = _burst(0.05, 800.0, 800.0, 0.0, 6.0, 15)
	_normalize(samples, 0.9)
	return _wav(samples)


## One decaying tone (optionally noisy, optionally with a second harmonic) with a 2 ms attack.
static func _burst(duration: float, freq_start: float, freq_end: float, noise_mix: float, decay: float, seed_value: int, harmonic: float = 0.0) -> PackedFloat32Array:
	var count := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase := 0.0
	for index in range(count):
		var t := float(index) / float(maxi(1, count - 1))
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var envelope := exp(-decay * t) * minf(1.0, float(index) / (0.002 * float(SAMPLE_RATE)))
		var tone := sin(phase) + harmonic * sin(phase * 2.0)
		var noise := rng.randf() * 2.0 - 1.0
		out[index] = (tone * (1.0 - noise_mix) + noise * noise_mix) * envelope
	return out


static func _mix(target: PackedFloat32Array, source: PackedFloat32Array, offset_seconds: float, gain: float) -> void:
	var offset := int(offset_seconds * SAMPLE_RATE)
	var needed := offset + source.size()
	if target.size() < needed:
		target.resize(needed)
	for index in range(source.size()):
		target[offset + index] += source[index] * gain


static func _scale(samples: PackedFloat32Array, gain: float) -> void:
	for index in range(samples.size()):
		samples[index] *= gain


static func _normalize(samples: PackedFloat32Array, peak: float) -> void:
	var loudest := 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	if loudest > 0.0001:
		_scale(samples, peak / loudest)


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


## Plays an interface sound from anywhere in the tree (used by menu buttons).
static func play_ui(from: Node, id: String, volume_db: float = -10.0) -> void:
	if from == null or not from.is_inside_tree():
		return
	var host := from.get_tree().root
	var player := host.get_node_or_null("UiSfx") as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "UiSfx"
		host.add_child(player)
	player.stream = stream(id)
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.97, 1.03)
	player.play()
