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
var player_name := "Player"
var cosmetic_color := Color("#27D7E7")
var cosmetic_outfit := "outfit_default"
var cosmetic_accessory := "accessory_cap"
var is_admin := false
var admin_fly_enabled := false
var admin_god_mode := false
var admin_hammer_equipped := false
var _admin_hammer: Node3D

func _ready() -> void:
	_build_visuals()
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
			var friction := 7.0 if _is_sliding else 20.0
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if Input.is_action_just_pressed("dash"):
		try_dash(direction)

	move_and_slide()
	if _camera:
		var target_camera_height := 1.05 if _is_sliding else 1.55
		_camera.position.y = move_toward(_camera.position.y, target_camera_height, 5.5 * delta)

	if gyro_enabled and OS.has_feature("android"):
		var gyro := Input.get_gyroscope()
		rotate_y(-gyro.y * look_sensitivity * 70.0 * delta)
		pitch = clampf(pitch - gyro.x * look_sensitivity * 70.0 * delta, deg_to_rad(-82.0), deg_to_rad(82.0))
		_camera.rotation.x = pitch

func apply_server_slide(enabled: bool) -> void:
	_set_sliding(enabled)

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

func apply_event(event_id: String) -> void:
	event_gravity_scale = 0.55 if event_id == "LOW_GRAVITY" else 1.0
	match event_id:
		"BONK_MODE":
			event_speed_scale = 1.3
		"NPC_MODE":
			event_speed_scale = 0.78
		"ICE_WORLD":
			event_speed_scale = 0.82
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
