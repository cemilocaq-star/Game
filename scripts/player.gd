extends CharacterBody3D
class_name ArcadePlayer

const CharacterVisuals = preload("res://scripts/character_visuals.gd")
const CharacterMotionRig = preload("res://scripts/character_motion_rig.gd")
const ARCADE_WEAPON_VISUALS = preload("res://scripts/arcade_weapon_visuals.gd")

const ARCADE_WEAPON_LOCAL := {
	"aether": {"name":"AETHER BLASTER", "cooldown":0.24, "range":65.0, "color":Color("#8CEEFF")},
	"minicore": {"name":"MINICORE", "cooldown":0.09, "range":46.0, "color":Color("#FF9B54")},
	"hand_cannon": {"name":"NOVA HAND CANNON", "cooldown":0.68, "range":58.0, "color":Color("#F2D36D")},
	"pulse_carbine": {"name":"PULSE CARBINE", "cooldown":0.18, "range":62.0, "color":Color("#76E6C5")},
	"star_piercer": {"name":"STAR PIERCER", "cooldown":1.05, "range":92.0, "color":Color("#C6A0FF")},
	"duck_launcher": {"name":"DUCK LAUNCHER", "cooldown":0.62, "range":42.0, "color":Color("#FFE56B")},
	"banana_boomerang": {"name":"BANANA BOOMERANG", "cooldown":0.42, "range":38.0, "color":Color("#E7F26C")},
	"confetti_cannon": {"name":"CONFETTI CANNON", "cooldown":0.11, "range":34.0, "color":Color("#FF83C8")},
	"prism_scepter": {"name":"PRISM SCEPTER", "cooldown":0.32, "range":72.0, "color":Color("#E98BFF")},
	"vortex_orbiter": {"name":"VORTEX ORBITER", "cooldown":0.15, "range":52.0, "color":Color("#7A9DFF")},
	"comet_bow": {"name":"COMET BOW", "cooldown":0.90, "range":88.0, "color":Color("#F7A8FF")},
	"bubble_burst": {"name":"BUBBLE BURST", "cooldown":0.25, "range":36.0, "color":Color("#8EEAFF")},
	"glitch_ray": {"name":"GLITCH RAY", "cooldown":0.13, "range":60.0, "color":Color("#B6FF63")},
	"meteor_mallet": {"name":"METEOR MALLET", "cooldown":0.70, "range":30.0, "color":Color("#FF815D")},
	"frost_wand": {"name":"FROST WAND", "cooldown":0.28, "range":58.0, "color":Color("#8FCFFF")},
	"solar_lance": {"name":"SOLAR LANCE", "cooldown":0.98, "range":86.0, "color":Color("#FFD46A")},
	"slime_slinger": {"name":"SLIME SLINGER", "cooldown":0.36, "range":44.0, "color":Color("#B9F56E")},
	"pixel_storm": {"name":"PIXEL STORM", "cooldown":0.08, "range":40.0, "color":Color("#80F6DB")},
	"thunder_drum": {"name":"THUNDER DRUM", "cooldown":0.40, "range":55.0, "color":Color("#7DC8FF")},
	"moon_disc": {"name":"MOON DISC", "cooldown":0.52, "range":68.0, "color":Color("#BCC7FF")},
	"jellyfish_staff": {"name":"JELLYFISH STAFF", "cooldown":0.30, "range":50.0, "color":Color("#D39BFF")},
	"portal_popper": {"name":"PORTAL POPPER", "cooldown":0.64, "range":62.0, "color":Color("#9C72FF")},
	"rubber_chicken": {"name":"RUBBER CHICKEN", "cooldown":0.48, "range":32.0, "color":Color("#FFB56C")}
}

signal collected(points: int)

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.0
const SLIDE_SPEED := 11.0
const JUMP_VELOCITY := 7.0
const DASH_SPEED := 15.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.0
const MAX_STAMINA := 100.0
const GRAVITY := 18.0
const JUMP_BUFFER_TIME := 0.14
const COYOTE_TIME := 0.12
const SLIDE_DURATION := 0.7
const SLIDE_STAMINA_COST := 12.0

var look_sensitivity := 0.0022
var pitch := 0.0
var stamina := MAX_STAMINA
var health := 100.0
var is_dead := false
var respawn_left := 0.0
var dash_cooldown := 0.0
var dash_left := 0.0
var slide_left := 0.0
var event_gravity_scale := 1.0
var event_speed_scale := 1.0
var score := 0
var gyro_enabled := true
var _dash_direction := Vector3.ZERO
var _camera: Camera3D
var _body_mesh: MeshInstance3D
var _collider: CollisionShape3D
var _capsule: CapsuleShape3D
var _jump_buffer_left := 0.0
var _coyote_left := 0.0
var _is_sliding := false
var _footstep_player: AudioStreamPlayer3D
var _footstep_distance := 0.0
var _footstep_streams: Dictionary = {}
var player_name := "Player"
var cosmetic_color := Color("#27D7E7")
var cosmetic_outfit := "outfit_default"
var cosmetic_accessory := "accessory_cap"
var is_admin := false
var admin_fly_enabled := false
var admin_god_mode := false
var admin_hammer_equipped := false
var _admin_hammer: Node3D
var _blaster_audio: AudioStreamPlayer3D
var _blaster_model: Node3D
var _blaster_cooldown := 0.0
var _blaster_recoil := 0.0
var _weapon_inspect_tween: Tween
var _weapon_idle_clock := 0.0
var selected_weapon_id := "aether"
var arsenal_open := false
var active_emote := ""
var _emote_clock := 0.0
var _emote_music: AudioStreamPlayer
var _emote_base_rotation := Vector3.ZERO
var _swimwear_root: Node3D
var _character_detail_root: Node3D
var _motion_rig: Node3D
var _motion_clock := 0.0
var is_swimming := false

func _ready() -> void:
	_build_visuals()
	_setup_footstep_audio()
	_setup_blaster()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_visuals() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.38
	_capsule.height = 1.8
	_collider = CollisionShape3D.new()
	_collider.shape = _capsule
	_collider.position.y = 0.9
	add_child(_collider)

	_body_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = 1.8
	_body_mesh.mesh = body
	var suit_color := cosmetic_color
	if cosmetic_outfit == "outfit_iron_vanguard":
		suit_color = Color("#A92332")
	elif cosmetic_outfit == "outfit_web_sentinel":
		suit_color = Color("#B52D3D")
	_body_mesh.material_override = _material(suit_color)
	if cosmetic_outfit == "outfit_neon":
		var neon_material := _material(cosmetic_color)
		neon_material.emission_enabled = true
		neon_material.emission = cosmetic_color
		neon_material.emission_energy_multiplier = 0.45
		_body_mesh.material_override = neon_material
	elif cosmetic_outfit == "outfit_runner":
		_body_mesh.scale = Vector3(0.94, 1.0, 0.94)
	if cosmetic_outfit != "outfit_iron_vanguard" and cosmetic_outfit != "outfit_web_sentinel":
		_add_selected_accessory()
	_body_mesh.position.y = 0.9
	add_child(_body_mesh)
	_build_swimwear()
	_character_detail_root = CharacterVisuals.build(_body_mesh, cosmetic_outfit, cosmetic_color)
	_motion_rig = CharacterMotionRig.build(_body_mesh, suit_color)
	if cosmetic_outfit == "outfit_iron_vanguard" or cosmetic_outfit == "outfit_web_sentinel":
		_add_hero_skin_details()

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.55, 0)
	_camera.current = true
	_camera.fov = 86.0
	add_child(_camera)

	var halo_scene: PackedScene = load("res://assets/CosmicHalo_Cosmetic.glb")
	if halo_scene:
		var halo := halo_scene.instantiate()
		halo.scale = Vector3.ONE * 0.003
		halo.position = Vector3(0, 2.0, 0)
		add_child(halo)


func _add_hero_skin_details() -> void:
	# Original hero-inspired silhouettes; no copied movie/game meshes or logos.
	var iron := cosmetic_outfit == "outfit_iron_vanguard"
	var primary := Color("#A92332") if iron else Color("#B52D3D")
	var secondary := Color("#D9B45B") if iron else Color("#183D78")
	var glow := Color("#66EFFF") if iron else Color("#E34A62")
	var armor := _blaster_material(secondary, 0.55)
	var accent := _blaster_material(glow, 0.25, true)
	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.48, 0.42, 0.16)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 0.05, -0.34)
	chest.material_override = armor
	_body_mesh.add_child(chest)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.105 if iron else 0.075
	core_mesh.height = 0.10 if iron else 0.08
	core.mesh = core_mesh
	core.position = Vector3(0, 0.08, -0.435)
	core.material_override = accent
	_body_mesh.add_child(core)
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.19
		shoulder_mesh.height = 0.25
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(side * 0.32, 0.43, 0)
		shoulder.material_override = armor
		_body_mesh.add_child(shoulder)
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.31
	helmet_mesh.height = 0.42
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0, 0.72, 0)
	helmet.material_override = _material(primary, 0.42)
	_body_mesh.add_child(helmet)
	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.34, 0.09, 0.055)
	visor.mesh = visor_mesh
	visor.position = Vector3(0, 0.73, -0.285)
	visor.material_override = accent
	_body_mesh.add_child(visor)
	if not iron:
		for side in [-1.0, 1.0]:
			var web_line := MeshInstance3D.new()
			var line_mesh := BoxMesh.new()
			line_mesh.size = Vector3(0.025, 0.48, 0.018)
			web_line.mesh = line_mesh
			web_line.position = Vector3(side * 0.12, 0.05, -0.432)
			web_line.material_override = _material(Color("#DDEBFF"))
			_body_mesh.add_child(web_line)

func _add_selected_accessory() -> void:
	var accessory_root := Node3D.new()
	accessory_root.name = "FreeCosmeticAccessory"
	accessory_root.position.y = 1.72
	add_child(accessory_root)
	if cosmetic_accessory == "accessory_cap":
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.24
		cap_mesh.height = 0.18
		cap.mesh = cap_mesh
		cap.position.y = 0.08
		cap.material_override = _material(cosmetic_color.lightened(0.25))
		accessory_root.add_child(cap)
		var brim := MeshInstance3D.new()
		var brim_mesh := CylinderMesh.new()
		brim_mesh.top_radius = 0.22
		brim_mesh.bottom_radius = 0.22
		brim_mesh.height = 0.035
		brim.mesh = brim_mesh
		brim.position = Vector3(0, 0.015, -0.12)
		brim.material_override = _material(cosmetic_color.darkened(0.2))
		accessory_root.add_child(brim)
	elif cosmetic_accessory == "accessory_headphones":
		for side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var ear_mesh := SphereMesh.new()
			ear_mesh.radius = 0.105
			ear_mesh.height = 0.22
			ear.mesh = ear_mesh
			ear.position = Vector3(side * 0.31, -0.02, 0)
			ear.material_override = _material(cosmetic_color)
			accessory_root.add_child(ear)


func _build_swimwear() -> void:
	_swimwear_root = Node3D.new()
	_swimwear_root.name = "BeachSwimwear"
	_swimwear_root.visible = false
	_body_mesh.add_child(_swimwear_root)
	var shirt := MeshInstance3D.new()
	shirt.name = "BeachShirt"
	var shirt_mesh := BoxMesh.new()
	shirt_mesh.size = Vector3(0.66, 0.56, 0.44)
	shirt.mesh = shirt_mesh
	shirt.position.y = 0.18
	shirt.material_override = _material(Color("#16A6C8"))
	_swimwear_root.add_child(shirt)
	var shorts := MeshInstance3D.new()
	shorts.name = "SwimShorts"
	var shorts_mesh := BoxMesh.new()
	shorts_mesh.size = Vector3(0.68, 0.34, 0.46)
	shorts.mesh = shorts_mesh
	shorts.position.y = -0.30
	shorts.material_override = _material(Color("#FFB347"))
	_swimwear_root.add_child(shorts)
	var glasses := Node3D.new()
	glasses.name = "Sunglasses"
	glasses.position = Vector3(0.0, 0.62, -0.34)
	_swimwear_root.add_child(glasses)
	for side in [-1.0, 1.0]:
		var lens := MeshInstance3D.new()
		var lens_mesh := BoxMesh.new()
		lens_mesh.size = Vector3(0.22, 0.12, 0.055)
		lens.mesh = lens_mesh
		lens.position.x = side * 0.13
		lens.material_override = _material(Color("#172638"))
		glasses.add_child(lens)
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.10, 0.035, 0.05)
	bridge.mesh = bridge_mesh
	bridge.material_override = _material(Color("#F4D36B"))
	glasses.add_child(bridge)

func set_swimming(enabled: bool) -> void:
	is_swimming = enabled
	if is_instance_valid(_swimwear_root):
		_swimwear_root.visible = enabled
	if is_instance_valid(_character_detail_root):
		_character_detail_root.visible = not enabled

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("emote_griddy"):
		play_emote("griddy")
	elif Input.is_action_just_pressed("emote_goofy"):
		play_emote("goofy")
	_motion_clock += delta
	if active_emote != "":
		_emote_clock += delta
		_update_emote_visual()
	elif is_instance_valid(_body_mesh):
		var movement_speed := Vector2(velocity.x, velocity.z).length()
		var moving := movement_speed > 0.35 and is_on_floor() and not _is_sliding
		_body_mesh.position.y = 0.9 + (absf(sin(_motion_clock * 10.0)) * 0.035 if moving else sin(_motion_clock * 1.8) * 0.012)
	CharacterMotionRig.animate(_motion_rig, _motion_clock, Vector2(velocity.x, velocity.z).length(), is_on_floor(), _is_sliding, active_emote, delta)
	_blaster_cooldown = maxf(0.0, _blaster_cooldown - delta)
	_blaster_recoil = move_toward(_blaster_recoil, 0.0, delta * 1.35)
	_weapon_idle_clock += delta
	if is_instance_valid(_blaster_model):
		_blaster_model.position.z = -0.48 + _blaster_recoil
		if _weapon_inspect_tween == null or not _weapon_inspect_tween.is_running():
			_blaster_model.rotation.z = sin(_weapon_idle_clock * 1.35) * 0.012
			_blaster_model.position.y = -0.24 + sin(_weapon_idle_clock * 1.7) * 0.006
	if Input.is_action_pressed("fire") and _blaster_cooldown <= 0.0 and not arsenal_open:
		_fire_blaster()

func play_emote(emote_id: String) -> void:
	if emote_id not in ["griddy", "goofy"]:
		return
	if active_emote == emote_id:
		stop_emote()
		return
	active_emote = emote_id
	_emote_clock = 0.0
	if is_instance_valid(_emote_music):
		_emote_music.stop()
	if emote_id == "griddy":
		_start_emote_music()
	var net := get_parent().get_node_or_null("OxenWarNet")
	if is_instance_valid(net) and net.is_authenticated:
		net.request_emote(emote_id)

func stop_emote() -> void:
	active_emote = ""
	_emote_clock = 0.0
	if is_instance_valid(_body_mesh):
		_body_mesh.rotation = Vector3.ZERO
		_body_mesh.position.y = 0.9
	if is_instance_valid(_emote_music):
		_emote_music.stop()

func apply_remote_emote(emote_id: String) -> void:
	if emote_id == active_emote:
		return
	active_emote = emote_id if emote_id in ["griddy", "goofy"] else ""
	_emote_clock = 0.0

func _update_emote_visual() -> void:
	if not is_instance_valid(_body_mesh):
		return
	var phase := _emote_clock * (TAU * (2.0 if active_emote == "griddy" else 1.35))
	var bounce := absf(sin(phase)) * (0.12 if active_emote == "griddy" else 0.08)
	_body_mesh.position.y = 0.9 + bounce
	_body_mesh.rotation.z = sin(phase) * (0.24 if active_emote == "griddy" else 0.34)
	_body_mesh.rotation.x = sin(phase * 0.5) * 0.12

func _start_emote_music() -> void:
	if not is_instance_valid(_emote_music):
		_emote_music = AudioStreamPlayer.new()
		_emote_music.name = "OriginalGriddyBeat"
		_emote_music.volume_db = -13.0
		add_child(_emote_music)
	_emote_music.stream = _make_emote_music()
	_emote_music.play()

func _make_emote_music() -> AudioStreamWAV:
	# Original, locally synthesized short dance beat; no sampled or copyrighted track.
	const sample_rate := 22050
	const beat_count := 4
	const beat_seconds := 0.32
	var sample_count := int(sample_rate * beat_count * beat_seconds)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / sample_rate
		var beat_phase := fposmod(t, beat_seconds)
		var beat_index := int(floor(t / beat_seconds))
		var kick_env := exp(-beat_phase * 18.0)
		var kick := sin(TAU * (78.0 - 28.0 * beat_phase) * beat_phase) * kick_env
		var hat_env := exp(-beat_phase * 75.0)
		var hat := sin(TAU * 7200.0 * t) * hat_env * 0.12
		var clap_phase := fposmod(t, beat_seconds * 2.0)
		var clap := (sin(TAU * 190.0 * t) + sin(TAU * 310.0 * t) * 0.4) * exp(-clap_phase * 24.0) * (0.22 if beat_index % 2 == 1 else 0.0)
		var bass := sin(TAU * [110.0, 110.0, 146.8, 98.0][beat_index % 4] * t) * 0.12
		var sample := clampf((kick * 0.55 + hat + clap + bass) * 0.65, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_count
	return stream

func set_arsenal_open(open: bool) -> void:
	arsenal_open = open
	if open:
		Input.action_release("fire")

func set_selected_weapon(weapon_id: String) -> void:
	if not ARCADE_WEAPON_LOCAL.has(weapon_id) or selected_weapon_id == weapon_id:
		return
	selected_weapon_id = weapon_id
	_blaster_cooldown = 0.0
	_setup_blaster()
	_blaster_recoil = 0.035
	if is_instance_valid(_blaster_model):
		var target_position := Vector3(0.27, -0.24, -0.48)
		_blaster_model.position = target_position + Vector3(0.0, -0.09, 0.08)
		var equip_tween := create_tween()
		equip_tween.set_parallel(true)
		equip_tween.tween_property(_blaster_model, "position", target_position, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		equip_tween.tween_property(_blaster_model, "rotation", Vector3.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_blaster_audio):
		_blaster_audio.stream = _make_weapon_stream(weapon_id)

func _setup_blaster() -> void:
	if not is_instance_valid(_camera):
		return
	if is_instance_valid(_blaster_model):
		_blaster_model.queue_free()
	var weapon_data: Dictionary = ARCADE_WEAPON_LOCAL.get(selected_weapon_id, ARCADE_WEAPON_LOCAL["aether"])
	var weapon_color: Color = weapon_data.get("color", Color("#8CEEFF"))
	_blaster_model = ARCADE_WEAPON_VISUALS.build_weapon(selected_weapon_id, weapon_color)
	_blaster_model.position = Vector3(0.27, -0.24, -0.48)
	_camera.add_child(_blaster_model)
	if not is_instance_valid(_blaster_audio):
		_blaster_audio = AudioStreamPlayer3D.new()
		_blaster_audio.name = "ArcadeWeaponAudio"
		_blaster_audio.volume_db = -7.0
		_blaster_audio.max_distance = 42.0
		_blaster_audio.unit_size = 9.0
		_blaster_audio.stream = _make_weapon_stream(selected_weapon_id)
		_camera.add_child(_blaster_audio)

func _blaster_material(color: Color, metallic_value: float, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = 0.28
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material

func _make_weapon_stream(weapon_id: String) -> AudioStreamWAV:
	# Original synthetic arcade tones; all samples are generated locally.
	const sample_rate := 22050
	const duration := 0.17
	var profiles := {
		"aether":[260.0, 105.0, 520.0, 0.22],
		"minicore":[520.0, 190.0, 880.0, 0.14],
		"hand_cannon":[145.0, 55.0, 290.0, 0.30],
		"pulse_carbine":[340.0, 125.0, 680.0, 0.18],
		"star_piercer":[780.0, 620.0, 1560.0, 0.08],
		"duck_launcher":[210.0, 80.0, 430.0, 0.34],
		"banana_boomerang":[430.0, 260.0, 860.0, 0.20],
		"confetti_cannon":[690.0, 410.0, 1380.0, 0.12],
		"prism_scepter":[610.0, 180.0, 1220.0, 0.24],
		"vortex_orbiter":[190.0, 150.0, 570.0, 0.28],
		"comet_bow":[390.0, 300.0, 1170.0, 0.10],
		"bubble_burst":[310.0, 220.0, 930.0, 0.32],
		"glitch_ray":[880.0, 510.0, 1760.0, 0.16],
		"meteor_mallet":[115.0, 35.0, 230.0, 0.38],
		"frost_wand":[560.0, 360.0, 1120.0, 0.12],
		"solar_lance":[470.0, 90.0, 1410.0, 0.26],
		"slime_slinger":[175.0, 95.0, 350.0, 0.36],
		"pixel_storm":[960.0, 240.0, 1920.0, 0.10],
		"thunder_drum":[95.0, 28.0, 190.0, 0.42],
		"moon_disc":[270.0, 210.0, 810.0, 0.18],
		"jellyfish_staff":[720.0, 440.0, 1440.0, 0.20],
		"portal_popper":[225.0, 420.0, 900.0, 0.24],
		"rubber_chicken":[390.0, 720.0, 1170.0, 0.42]
	}
	var profile: Array = profiles.get(weapon_id, profiles["aether"])
	var base_frequency := float(profile[0])
	var sweep_amount := float(profile[1])
	var overtone_frequency := float(profile[2])
	var overtone_mix := float(profile[3])
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var progress := float(i) / float(count)
		var envelope := pow(maxf(0.0, 1.0 - progress), 2.15)
		var fundamental := sin(TAU * (base_frequency - sweep_amount * t / duration) * t)
		var overtone := sin(TAU * overtone_frequency * t) * overtone_mix
		var wobble := sin(TAU * (base_frequency * 0.5) * t) * 0.08
		var sample := clampf((fundamental * (0.72 - overtone_mix * 0.35) + overtone + wobble) * envelope * 0.72, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func inspect_weapon() -> void:
	if not is_instance_valid(_blaster_model) or arsenal_open or is_dead:
		return
	if _weapon_inspect_tween != null and _weapon_inspect_tween.is_running():
		return
	_weapon_inspect_tween = create_tween()
	_weapon_inspect_tween.set_trans(Tween.TRANS_SINE)
	_weapon_inspect_tween.set_ease(Tween.EASE_IN_OUT)
	_weapon_inspect_tween.set_parallel(true)
	_weapon_inspect_tween.tween_property(_blaster_model, "rotation", Vector3(deg_to_rad(-24.0), deg_to_rad(32.0), deg_to_rad(18.0)), 0.28)
	_weapon_inspect_tween.tween_property(_blaster_model, "position", Vector3(0.20, -0.16, -0.42), 0.28)
	_weapon_inspect_tween.tween_property(_blaster_model, "scale", Vector3.ONE * 1.08, 0.28)
	_weapon_inspect_tween.chain().tween_interval(0.18)
	_weapon_inspect_tween.set_parallel(true)
	_weapon_inspect_tween.tween_property(_blaster_model, "rotation", Vector3.ZERO, 0.30)
	_weapon_inspect_tween.tween_property(_blaster_model, "position", Vector3(0.27, -0.24, -0.48), 0.30)
	_weapon_inspect_tween.tween_property(_blaster_model, "scale", Vector3.ONE, 0.30)


func _fire_blaster() -> void:
	if not is_instance_valid(_camera) or _blaster_cooldown > 0.0:
		return
	_blaster_cooldown = float(ARCADE_WEAPON_LOCAL.get(selected_weapon_id, ARCADE_WEAPON_LOCAL["aether"]).get("cooldown", 0.24))
	_blaster_recoil = 0.055
	var origin := _camera.global_position
	var direction := -_camera.global_basis.z.normalized()
	var weapon_data: Dictionary = ARCADE_WEAPON_LOCAL.get(selected_weapon_id, ARCADE_WEAPON_LOCAL["aether"])
	var endpoint := origin + direction * float(weapon_data.get("range", 65.0))
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position
	var net := get_parent().get_node_or_null("OxenWarNet")
	var online_fire := is_instance_valid(net) and net.is_authenticated
	if online_fire:
		net.request_blaster_fire(selected_weapon_id, direction)
	else:
		_show_blaster_beam(origin, endpoint)
	if is_instance_valid(_blaster_audio):
				_blaster_audio.pitch_scale = randf_range(0.985, 1.015)
		_blaster_audio.play()
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.065
	flash_mesh.height = 0.13
	flash.mesh = flash_mesh
	var weapon_color: Color = ARCADE_WEAPON_LOCAL.get(selected_weapon_id, ARCADE_WEAPON_LOCAL["aether"]).get("color", Color("#9AF7FF"))
	flash.material_override = _blaster_material(weapon_color, 0.0, true)
	flash.position = Vector3(0.0, 0.0, -0.48)
	_camera.add_child(flash)
	get_tree().create_timer(0.055).timeout.connect(flash.queue_free)

func _show_blaster_beam(origin: Vector3, endpoint: Vector3) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "AetherPulseTrail"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 1.0)
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	var beam_color: Color = ARCADE_WEAPON_LOCAL.get(selected_weapon_id, ARCADE_WEAPON_LOCAL["aether"]).get("color", Color("#35EFFF"))
	material.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.92)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = beam_color
	material.emission_energy_multiplier = 2.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = material
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	scene.add_child(beam)
	beam.global_position = (origin + endpoint) * 0.5
	var up := Vector3.RIGHT if absf((endpoint - origin).normalized().dot(Vector3.UP)) > 0.97 else Vector3.UP
	beam.look_at(endpoint, up)
	beam.scale.z = maxf(0.05, origin.distance_to(endpoint))
	get_tree().create_timer(0.085).timeout.connect(beam.queue_free)

func _physics_process(delta: float) -> void:
	if admin_fly_enabled:
		var fly_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var fly_forward := -global_transform.basis.z
		var fly_right := global_transform.basis.x
		var fly_direction := (fly_right * fly_input.x + fly_forward * -fly_input.y).normalized()
		var vertical := float(Input.is_action_pressed("jump")) - float(Input.is_action_pressed("slide"))
		velocity = fly_direction * 14.0 + Vector3.UP * vertical * 10.0
		move_and_slide()
		return
	if event_speed_scale <= 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_left = maxf(0.0, dash_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if is_on_floor():
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
		velocity.y -= GRAVITY * event_gravity_scale * delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = JUMP_BUFFER_TIME

	if Input.is_action_just_pressed("slide") and is_on_floor() and stamina >= SLIDE_STAMINA_COST and not _is_sliding:
		_set_sliding(true)
		slide_left = SLIDE_DURATION
		stamina -= SLIDE_STAMINA_COST

	if _is_sliding:
		slide_left = maxf(0.0, slide_left - delta)
		if slide_left <= 0.0 or Input.is_action_just_pressed("jump"):
			_set_sliding(false)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and stamina >= 8.0:
		_set_sliding(false)
		velocity.y = JUMP_VELOCITY
		stamina -= 8.0
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var direction := (right * input_vector.x + forward * -input_vector.y).normalized()

	if dash_left > 0.0:
		_set_sliding(false)
		velocity.x = _dash_direction.x * DASH_SPEED * event_speed_scale
		velocity.z = _dash_direction.z * DASH_SPEED * event_speed_scale
	else:
		var target_speed := WALK_SPEED
		if _is_sliding:
			target_speed = SLIDE_SPEED
			stamina = maxf(0.0, stamina - 5.0 * delta)
		elif Input.is_action_pressed("sprint") and stamina > 0.0:
			target_speed = SPRINT_SPEED
			stamina = maxf(0.0, stamina - 15.0 * delta)
		else:
			stamina = minf(MAX_STAMINA, stamina + 20.0 * delta)

		target_speed *= event_speed_scale
		if direction.length() > 0.01:
			var acceleration := 34.0 if _is_sliding else 28.0
			velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
		else:
			var friction := 3.5 if active_event_ice() else (7.0 if _is_sliding else 20.0)
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if Input.is_action_just_pressed("dash"):
		try_dash(direction)

	move_and_slide()
	set_swimming(global_position.x >= -16.0 and global_position.x <= -8.0 and global_position.z >= -13.0 and global_position.z <= -5.0 and global_position.y <= 3.5)
	_update_footsteps(delta)
	if _camera:
		var target_camera_height := 1.05 if _is_sliding else 1.55
		_camera.position.y = move_toward(_camera.position.y, target_camera_height, 5.5 * delta)

	if gyro_enabled and OS.has_feature("android"):
		var gyro := Input.get_gyroscope()
		rotate_y(-gyro.y * look_sensitivity * 70.0 * delta)
		pitch = clampf(pitch - gyro.x * look_sensitivity * 70.0 * delta, deg_to_rad(-82.0), deg_to_rad(82.0))
		_camera.rotation.x = pitch

func _setup_footstep_audio() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "SurfaceFootstepAudio"
	_footstep_player.volume_db = -9.0
	_footstep_player.max_distance = 24.0
	_footstep_player.unit_size = 8.0
	add_child(_footstep_player)

func _update_footsteps(delta: float) -> void:
	if not is_instance_valid(_footstep_player):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or _is_sliding or horizontal_speed < 1.25:
		_footstep_distance = 0.0
		return
	_footstep_distance += horizontal_speed * delta
	var step_distance := 2.05 if horizontal_speed > WALK_SPEED + 0.5 else 1.55
	if _footstep_distance >= step_distance:
		_footstep_distance = 0.0
		_play_surface_footstep()

func _play_surface_footstep() -> void:
	var surface := _detect_footstep_surface()
	if not _footstep_streams.has(surface):
		_footstep_streams[surface] = _make_footstep_stream(surface)
	_footstep_player.stream = _footstep_streams[surface] as AudioStreamWAV
	_footstep_player.pitch_scale = randf_range(0.92, 1.08)
	_footstep_player.play()

func _detect_footstep_surface() -> String:
	var origin := global_position + Vector3.UP * 0.25
	var target := global_position - Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "stone"
	var collider: Object = hit.get("collider")
	var surface_hint := ""
	if collider is CollisionObject3D:
		surface_hint = str(collider.get_meta("surface_type", ""))
		if surface_hint.is_empty():
			for group_name in collider.get_groups():
				if str(group_name).begins_with("surface_"):
					surface_hint = str(group_name).trim_prefix("surface_")
					break
	if surface_hint.is_empty() and collider is Node:
		surface_hint = str(collider.name)
	surface_hint = surface_hint.to_lower()
	if "grass" in surface_hint or "foliage" in surface_hint or "leaf" in surface_hint:
		return "grass"
	if "metal" in surface_hint or "steel" in surface_hint:
		return "metal"
	if "wood" in surface_hint or "plank" in surface_hint:
		return "wood"
	if "ice" in surface_hint or "snow" in surface_hint:
		return "ice"
	if "sand" in surface_hint or "dirt" in surface_hint or "soil" in surface_hint:
		return "dirt"
	return "stone"

func _make_footstep_stream(surface: String) -> AudioStreamWAV:
	# Original synthesized foley: distinct tonal/noise profiles, generated locally.
	const sample_rate := 22050
	const duration := 0.105
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var frequency := 430.0
	var noise_mix := 0.28
	var amplitude := 0.52
	match surface:
		"grass":
			frequency = 180.0
			noise_mix = 0.78
			amplitude = 0.34
		"metal":
			frequency = 920.0
			noise_mix = 0.18
			amplitude = 0.48
		"wood":
			frequency = 270.0
			noise_mix = 0.24
			amplitude = 0.48
		"ice":
			frequency = 1080.0
			noise_mix = 0.52
			amplitude = 0.30
		"dirt":
			frequency = 220.0
			noise_mix = 0.88
			amplitude = 0.30
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var envelope := pow(maxf(0.0, 1.0 - float(i) / float(sample_count)), 2.2)
		var tone := sin(TAU * frequency * t) * (1.0 - noise_mix)
		var noise := rng.randf_range(-1.0, 1.0) * noise_mix
		var transient := rng.randf_range(-1.0, 1.0) * 0.24 if i < int(sample_rate * 0.009) else 0.0
		var sample := clampf((tone + noise + transient) * envelope * amplitude, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func apply_server_slide(enabled: bool) -> void:
	_set_sliding(enabled)
	if is_instance_valid(_camera):
		_camera.position.y = 1.05 if enabled else 1.55

func _set_sliding(enabled: bool) -> void:
	if _is_sliding == enabled:
		return
	_is_sliding = enabled
	if not is_instance_valid(_capsule) or not is_instance_valid(_collider) or not is_instance_valid(_body_mesh):
		return
	if enabled:
		_capsule.height = 1.0
		_collider.position.y = 0.5
		_body_mesh.scale.y = 0.56
		_body_mesh.position.y = 0.5
	else:
		_capsule.height = 1.8
		_collider.position.y = 0.9
		_body_mesh.scale.y = 1.0
		_body_mesh.position.y = 0.9

func try_dash(direction: Vector3 = Vector3.ZERO) -> void:
	if dash_cooldown > 0.0 or stamina < 20.0:
		return
	_set_sliding(false)
	_dash_direction = direction.normalized() if direction.length() > 0.1 else -global_transform.basis.z
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()
	dash_left = DASH_TIME
	dash_cooldown = DASH_COOLDOWN
	stamina -= 20.0

func set_admin_fly(enabled: bool) -> void:
	if not is_admin:
		return
	admin_fly_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO

func toggle_admin_hammer() -> void:
	if not is_admin:
		return
	admin_hammer_equipped = not admin_hammer_equipped
	if admin_hammer_equipped:
		_admin_hammer = Node3D.new()
		_admin_hammer.name = "AdminThorHammer"
		_admin_hammer.position = Vector3(0.48, -0.42, -0.82)
		_admin_hammer.rotation_degrees = Vector3(0, 0, -24)
		var handle := MeshInstance3D.new()
		var handle_mesh := CylinderMesh.new()
		handle_mesh.top_radius = 0.055
		handle_mesh.bottom_radius = 0.075
		handle_mesh.height = 0.9
		handle.mesh = handle_mesh
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.72, 0.55, 0.27)
		gold.metallic = 0.8
		handle.material_override = gold
		_admin_hammer.add_child(handle)
		var head := MeshInstance3D.new()
		var head_mesh := BoxMesh.new()
		head_mesh.size = Vector3(0.72, 0.36, 0.42)
		head.mesh = head_mesh
		head.position.y = 0.42
		var silver := StandardMaterial3D.new()
		silver.albedo_color = Color(0.55, 0.72, 0.86)
		silver.metallic = 0.95
		silver.roughness = 0.2
		head.material_override = silver
		_admin_hammer.add_child(head)
		_camera.add_child(_admin_hammer)
	else:
		if is_instance_valid(_admin_hammer):
			_admin_hammer.queue_free()
		_admin_hammer = null

func add_score(points: int) -> void:
	score += points
	collected.emit(points)

func active_event_ice() -> bool:
	return event_speed_scale == 0.82

func apply_event(event_id: String) -> void:
	event_gravity_scale = 0.55 if event_id == "LOW_GRAVITY" else 1.0
	match event_id:
		"BONK_MODE":
			event_speed_scale = 1.3
		"NPC_MODE":
			event_speed_scale = 0.78
		"ICE_WORLD":
			event_speed_scale = 0.82
		"FREEZE_FRAME":
			event_speed_scale = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
		_:
			event_speed_scale = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative)
	elif event is InputEventScreenDrag:
		var viewport_size := get_viewport().get_visible_rect().size
		if event.position.x > viewport_size.x * 0.38:
			_apply_look(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _apply_look(relative: Vector2) -> void:
	rotate_y(-relative.x * look_sensitivity)
	pitch = clampf(pitch - relative.y * look_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))
	_camera.rotation.x = pitch

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	return material
