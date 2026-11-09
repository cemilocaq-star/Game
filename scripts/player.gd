extends CharacterBody3D
class_name ArcadePlayer

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
	_body_mesh.material_override = _material(cosmetic_color)
	if cosmetic_outfit == "outfit_neon":
		var neon_material := _material(cosmetic_color)
		neon_material.emission_enabled = true
		neon_material.emission = cosmetic_color
		neon_material.emission_energy_multiplier = 0.45
		_body_mesh.material_override = neon_material
	elif cosmetic_outfit == "outfit_runner":
		_body_mesh.scale = Vector3(0.94, 1.0, 0.94)
	_add_selected_accessory()
	_body_mesh.position.y = 0.9
	add_child(_body_mesh)

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


func _process(delta: float) -> void:
	_blaster_cooldown = maxf(0.0, _blaster_cooldown - delta)
	if Input.is_action_just_pressed("fire") and _blaster_cooldown <= 0.0:
		_fire_blaster()

func _setup_blaster() -> void:
	if not is_instance_valid(_camera):
		return
	_blaster_model = Node3D.new()
	_blaster_model.name = "AetherBlaster"
	_blaster_model.position = Vector3(0.27, -0.24, -0.48)
	_camera.add_child(_blaster_model)
	var core := MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.16, 0.18, 0.62)
	core.mesh = core_mesh
	core.material_override = _blaster_material(Color("#26384E"), 0.35)
	_blaster_model.add_child(core)
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.12, 0.07, 0.36)
	top.mesh = top_mesh
	top.position = Vector3(0.0, 0.12, -0.04)
	top.material_override = _blaster_material(Color("#3C5B78"), 0.5)
	_blaster_model.add_child(top)
	var emitter := MeshInstance3D.new()
	var emitter_mesh := CylinderMesh.new()
	emitter_mesh.top_radius = 0.075
	emitter_mesh.bottom_radius = 0.095
	emitter_mesh.height = 0.18
	emitter.mesh = emitter_mesh
	emitter.rotation_degrees.x = 90.0
	emitter.position.z = -0.37
	emitter.material_override = _blaster_material(Color("#31E8FF"), 0.2, true)
	_blaster_model.add_child(emitter)
	var cell := MeshInstance3D.new()
	var cell_mesh := SphereMesh.new()
	cell_mesh.radius = 0.085
	cell_mesh.height = 0.18
	cell.mesh = cell_mesh
	cell.position = Vector3(0.105, -0.015, 0.02)
	cell.material_override = _blaster_material(Color("#9C7BFF"), 0.25, true)
	_blaster_model.add_child(cell)
	_blaster_audio = AudioStreamPlayer3D.new()
	_blaster_audio.name = "AetherPulseAudio"
	_blaster_audio.volume_db = -7.0
	_blaster_audio.max_distance = 42.0
	_blaster_audio.unit_size = 9.0
	_blaster_audio.stream = _make_blaster_stream()
	_blaster_model.add_child(_blaster_audio)

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

func _make_blaster_stream() -> AudioStreamWAV:
	# Original synthetic sci-fi pulse; not a recording or imitation of a real firearm.
	const sample_rate := 22050
	const duration := 0.19
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var envelope := pow(maxf(0.0, 1.0 - float(i) / float(count)), 2.0)
		var sweep := sin(TAU * (260.0 - 105.0 * t / duration) * t)
		var overtone := sin(TAU * 520.0 * t) * 0.22
		var sample := clampf((sweep * 0.58 + overtone) * envelope * 0.72, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _fire_blaster() -> void:
	if not is_instance_valid(_camera) or _blaster_cooldown > 0.0:
		return
	_blaster_cooldown = 0.24
	var origin := _camera.global_position
	var direction := -_camera.global_basis.z.normalized()
	var endpoint := origin + direction * 65.0
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position
	_show_blaster_beam(origin, endpoint)
	if is_instance_valid(_blaster_audio):
		_blaster_audio.pitch_scale = randf_range(0.96, 1.04)
		_blaster_audio.play()
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.065
	flash_mesh.height = 0.13
	flash.mesh = flash_mesh
	flash.material_override = _blaster_material(Color("#9AF7FF"), 0.0, true)
	flash.position = Vector3(0.0, 0.0, -0.48)
	_camera.add_child(flash)
	get_tree().create_timer(0.055).timeout.connect(flash.queue_free)
	var net := get_parent().get_node_or_null("OxenWarNet")
	if is_instance_valid(net) and net.is_authenticated:
		net.request_blaster_fire(direction)

func _show_blaster_beam(origin: Vector3, endpoint: Vector3) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "AetherPulseTrail"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 1.0)
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.9, 1.0, 0.92)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color("#35EFFF")
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
