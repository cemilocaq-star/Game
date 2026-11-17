extends Node3D
## Client-only visualization. The room snapshot supplies every gameplay decision.
const CHARACTER := preload("res://scripts/character_visuals.gd")
const RIG := preload("res://scripts/character_motion_rig.gd")
const AUDIO_BUSES := preload("res://scripts/audio_buses.gd")
var _avatar := Node3D.new()
var _rig: Node3D
var _destination := Vector3.ZERO
var _clock := 0.0
var _warning := 3.0
var _impact := false
var _clouds := Node3D.new()
var _light := DirectionalLight3D.new()
var _caption := Label3D.new()
var _thunder := AudioStreamPlayer3D.new()


func _ready() -> void:
	add_child(_avatar)
	add_child(_clouds)
	var torso := MeshInstance3D.new()
	var jersey := CapsuleMesh.new()
	jersey.radius = 0.35
	jersey.height = 0.78
	torso.mesh = jersey
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#632AAD")
	torso.material_override = material
	_avatar.add_child(torso)
	CHARACTER.build(torso, "outfit_default", Color("#E4A52D"))
	_rig = RIG.build(torso, Color("#632AAD"))
	var number := Label3D.new()
	number.text = "23"
	number.position = Vector3(0, 0.05, -0.38)
	number.rotation.y = PI
	number.font_size = 72
	number.pixel_size = 0.003
	torso.add_child(number)
	var ball := MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.16
	ball_mesh.height = 0.32
	ball.mesh = ball_mesh
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color("#E47828")
	ball.material_override = orange
	ball.position = Vector3(0.45, -0.15, -0.24)
	torso.add_child(ball)
	for i in range(8):
		var cloud := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radial_segments = 10
		shape.rings = 5
		cloud.mesh = shape
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("#192239")
		cloud.material_override = dark
		cloud.scale = Vector3(9.0, 2.2, 5.5)
		cloud.position = Vector3(cos(i * TAU / 8.0) * 14.0, 17.0, sin(i * TAU / 8.0) * 11.0)
		_clouds.add_child(cloud)
	_light.rotation_degrees = Vector3(-65, -20, 0)
	_light.light_color = Color("#9BC9FF")
	add_child(_light)
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.position.y = 1.8
	_caption.font_size = 72
	_caption.pixel_size = 0.008
	_avatar.add_child(_caption)
	_thunder.stream = _make_thunder()
	_thunder.max_distance = 65.0
	_thunder.unit_size = 14.0
	_thunder.volume_db = -13.0
	_thunder.bus = AUDIO_BUSES.bus_or_master(AUDIO_BUSES.SFX)
	_avatar.add_child(_thunder)


func sync_state(state: Dictionary) -> void:
	if _destination == Vector3.ZERO:
		_avatar.position = state.actor
	_destination = state.actor
	_warning = float(state.warning)
	_impact = bool(state.impact)
	_caption.text = "SLAM!" if _impact else (str(ceili(_warning)) if _warning > 0.0 else "INCOMING")


func _process(delta: float) -> void:
	_clock += delta
	_clouds.rotation.y += delta * 0.07
	_light.light_energy = 0.20 + (1.2 if fmod(_clock, 2.6) < 0.08 else 0.0)
	if fmod(_clock, 2.6) < 0.08 and not _thunder.playing:
		_thunder.play()
	var motion := _destination - _avatar.position
	if Vector2(motion.x, motion.z).length() > 0.02:
		_avatar.rotation.y = atan2(-motion.x, -motion.z)
	_avatar.position = _avatar.position.lerp(_destination, minf(1.0, delta * 14.0))
	RIG.animate(_rig, _clock, 7.0 if _warning <= 0.0 and not _impact else 0.0, true, false, "", delta)


func _make_thunder() -> AudioStreamWAV:
	var samples := PackedByteArray()
	const RATE := 16000
	samples.resize(RATE)
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 23
	var noise := 0.0
	for i in range(RATE / 2):
		var time := float(i) / RATE
		noise = lerpf(noise, seeded.randf_range(-1.0, 1.0), 0.08)
		var value := (noise * 0.8 + sin(TAU * 41.0 * time) * 0.4) * exp(-8.0 * time)
		samples.encode_s16(i * 2, int(value * 25000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	return stream
