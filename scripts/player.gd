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
	_body_mesh.material_override = _material(Color(0.12, 0.78, 0.68))
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

func _physics_process(delta: float) -> void:
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
		velocity.x = _dash_direction.x * DASH_SPEED
		velocity.z = _dash_direction.z * DASH_SPEED
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

func add_score(points: int) -> void:
	score += points
	collected.emit(points)

func apply_event(event_id: String) -> void:
	event_gravity_scale = 0.55 if event_id == "LOW_GRAVITY" else 1.0

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
