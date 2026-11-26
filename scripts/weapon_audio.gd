extends RefCounted
## Layered, original weapon sounds (all synthesized locally; no recordings, nothing copied).
## Layers follow the documented approach for shooters: a bright CRACK transient, a tonal BODY
## that gives each weapon its identity, a SUB thump that grows with weapon weight, a small
## MECHANICAL clack after the shot, and a TAIL of low-passed noise. Layers are offset by a few
## milliseconds so transients do not stack, and each weapon has several VARIANTS (different
## noise, plus or minus 3 percent pitch, different layer offsets) so repeated shots do not
## sound identical. The "far" perspective is what other players hear: body only (softened) plus
## a longer tail, with no crack, sub or clack (simplified non-player fire).

const SAMPLE_RATE := 32000
const VARIANTS := 3
const OWN := "own"
const FAR := "far"
const LAYER_OFFSETS_MS := [0.0, 1.5, 3.0]

## [base frequency, sweep amount, overtone frequency, overtone mix] per weapon.
const BODY := {
	"aether": [260.0, 105.0, 520.0, 0.22],
	"minicore": [520.0, 190.0, 880.0, 0.14],
	"hand_cannon": [145.0, 55.0, 290.0, 0.30],
	"pulse_carbine": [340.0, 125.0, 680.0, 0.18],
	"star_piercer": [780.0, 620.0, 1560.0, 0.08],
	"duck_launcher": [210.0, 80.0, 430.0, 0.34],
	"banana_boomerang": [430.0, 260.0, 860.0, 0.20],
	"confetti_cannon": [690.0, 410.0, 1380.0, 0.12],
	"prism_scepter": [610.0, 180.0, 1220.0, 0.24],
	"vortex_orbiter": [190.0, 150.0, 570.0, 0.28],
	"comet_bow": [390.0, 300.0, 1170.0, 0.10],
	"bubble_burst": [310.0, 220.0, 930.0, 0.32],
	"glitch_ray": [880.0, 510.0, 1760.0, 0.16],
	"meteor_mallet": [115.0, 35.0, 230.0, 0.38],
	"frost_wand": [560.0, 360.0, 1120.0, 0.12],
	"solar_lance": [470.0, 90.0, 1410.0, 0.26],
	"slime_slinger": [175.0, 95.0, 350.0, 0.36],
	"pixel_storm": [960.0, 240.0, 1920.0, 0.10],
	"thunder_drum": [95.0, 28.0, 190.0, 0.42],
	"moon_disc": [270.0, 210.0, 810.0, 0.18],
	"jellyfish_staff": [720.0, 440.0, 1440.0, 0.20],
	"portal_popper": [225.0, 420.0, 900.0, 0.24],
	"rubber_chicken": [390.0, 720.0, 1170.0, 0.42],
	"ranger_rifle": [305.0, 95.0, 610.0, 0.18],
	"heavy_sidearm": [155.0, 48.0, 310.0, 0.28],
	"longshot": [820.0, 540.0, 1640.0, 0.09],
	"rotary_arc": [175.0, 34.0, 525.0, 0.25],
}

static var _cache: Dictionary = {}


static func weapon_ids() -> Array:
	return BODY.keys()


## How heavy a weapon sounds, 0 (light/high) to 1 (deep).
static func weight(weapon_id: String) -> float:
	var profile: Array = BODY.get(weapon_id, BODY["aether"])
	return clampf((230.0 - float(profile[0])) / 170.0, 0.0, 1.0)


static func stream(weapon_id: String, perspective: String = OWN, variant: int = 0) -> AudioStreamWAV:
	var id := weapon_id if BODY.has(weapon_id) else "aether"
	var index := posmod(variant, VARIANTS)
	var key := "%s|%s|%d" % [id, perspective, index]
	if not _cache.has(key):
		_cache[key] = _render(id, perspective, index)
	return _cache[key]


## Builds every own-perspective variant ahead of time so the first shots do not hitch.
static func prewarm(weapon_id: String) -> void:
	for index in range(VARIANTS):
		stream(weapon_id, OWN, index)


static func _render(weapon_id: String, perspective: String, variant: int) -> AudioStreamWAV:
	var profile: Array = BODY[weapon_id]
	var base := float(profile[0])
	var sweep := float(profile[1])
	var overtone_frequency := float(profile[2])
	var overtone_mix := float(profile[3])
	var heavy := weight(weapon_id)
	var far := perspective == FAR
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(weapon_id) + variant * 7919 + (104729 if far else 0)
	var jitter := 1.0 + (rng.randf() - 0.5) * 0.06
	var offset := float(LAYER_OFFSETS_MS[variant]) / 1000.0
	var tail_seconds := lerpf(0.22, 0.5, heavy) * (1.5 if far else 1.0)
	var out := PackedFloat32Array()

	# BODY: the weapon's tonal identity (fundamental sweep + overtone).
	var body := PackedFloat32Array()
	var body_seconds := 0.17
	body.resize(int(SAMPLE_RATE * body_seconds))
	for i in range(body.size()):
		var t := float(i) / float(SAMPLE_RATE)
		var progress := float(i) / float(body.size())
		var envelope := pow(maxf(0.0, 1.0 - progress), 2.15)
		var fundamental := sin(TAU * (base * jitter - sweep * t / body_seconds) * t)
		var overtone := sin(TAU * overtone_frequency * jitter * t) * overtone_mix
		var wobble := sin(TAU * (base * 0.5) * t) * 0.08
		body[i] = (fundamental * (0.72 - overtone_mix * 0.35) + overtone + wobble) * envelope * 0.72
	if far:
		_lowpass(body, 1800.0)
		_scale(body, 0.85)
	_mix(out, body, offset, 1.0)

	# TAIL: low-passed noise, longer for heavy weapons and for distant fire.
	var tail := PackedFloat32Array()
	tail.resize(int(SAMPLE_RATE * tail_seconds))
	for i in range(tail.size()):
		var progress := float(i) / float(tail.size())
		tail[i] = (rng.randf() * 2.0 - 1.0) * exp(-5.0 * progress)
	_lowpass(tail, lerpf(2500.0, 900.0, heavy) * (0.5 if far else 1.0))
	_mix(out, tail, 0.03 + offset, (0.45 if far else 0.30) * (1.0 + heavy * 0.4) * 2.2)

	if not far:
		# CRACK: differentiated noise, a few milliseconds of bright transient.
		var crack := PackedFloat32Array()
		crack.resize(int(SAMPLE_RATE * 0.014))
		var last_noise := 0.0
		for i in range(crack.size()):
			var noise := rng.randf() * 2.0 - 1.0
			var t := float(i) / float(SAMPLE_RATE)
			crack[i] = (noise - last_noise) * 0.5 * exp(-t / 0.004)
			last_noise = noise
		_mix(out, crack, 0.0, 0.55 * (1.0 - 0.5 * heavy))
		# SUB: deep thump that grows with weapon weight.
		var sub := PackedFloat32Array()
		sub.resize(int(SAMPLE_RATE * 0.16))
		var sub_start := lerpf(90.0, 55.0, heavy)
		var sub_phase := 0.0
		for i in range(sub.size()):
			var progress := float(i) / float(sub.size())
			sub_phase += TAU * lerpf(sub_start, 40.0, progress) / float(SAMPLE_RATE)
			sub[i] = sin(sub_phase) * exp(-4.5 * progress)
		_mix(out, sub, offset, 0.25 + 0.55 * heavy)
		# MECHANICS: a small clack just after the shot (action cycling).
		var clack := PackedFloat32Array()
		clack.resize(int(SAMPLE_RATE * 0.008))
		for i in range(clack.size()):
			var progress := float(i) / float(clack.size())
			clack[i] = (rng.randf() * 2.0 - 1.0) * exp(-6.0 * progress) * sin(TAU * 1700.0 * float(i) / float(SAMPLE_RATE) + 1.0)
		_mix(out, clack, 0.05 + offset, 0.18)

	_normalize(out, 0.7 if far else 0.88)
	return _wav(out)


static func _mix(target: PackedFloat32Array, source: PackedFloat32Array, offset_seconds: float, gain: float) -> void:
	var start := int(offset_seconds * SAMPLE_RATE)
	var needed := start + source.size()
	if target.size() < needed:
		target.resize(needed)
	for i in range(source.size()):
		target[start + i] += source[i] * gain


static func _scale(samples: PackedFloat32Array, gain: float) -> void:
	for i in range(samples.size()):
		samples[i] *= gain


static func _lowpass(samples: PackedFloat32Array, cutoff_hz: float) -> void:
	var alpha := 1.0 - exp(-TAU * cutoff_hz / float(SAMPLE_RATE))
	var state := 0.0
	for i in range(samples.size()):
		state += alpha * (samples[i] - state)
		samples[i] = state


static func _normalize(samples: PackedFloat32Array, peak: float) -> void:
	var loudest := 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	if loudest > 0.0001:
		_scale(samples, peak / loudest)


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
