extends CharacterBody3D
## Server-owned movement body. Clients submit input only; this node owns physics.

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.0
const SLIDE_SPEED := 11.0
const JUMP_VELOCITY := 7.0
const DASH_SPEED := 15.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.0
const GRAVITY := 18.0
const MAX_STAMINA := 100.0
const MAX_HEALTH := 100.0
const RESPAWN_SECONDS := 4.0
const JUMP_BUFFER_TIME := 0.14
const COYOTE_TIME := 0.12
const SLIDE_DURATION := 0.7
const SLIDE_STAMINA_COST := 12.0

var input_vector := Vector2.ZERO
var look_yaw := 0.0
var jump_requested := false
var sprinting := false
var sliding := false
var slide_requested := false
var dash_requested := false
var stamina := MAX_STAMINA
var health := MAX_HEALTH
var is_dead := false
var respawn_left := 0.0
var score := 0
var xp := 0
var match_xp := 0
var collection_counts: Dictionary = {}
var secret_404_found := false
var event_id := ""
var speed_scale := 1.0
var gravity_scale := 1.0
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector3.ZERO
var _slide_left := 0.0
var _jump_buffer_left := 0.0
var _coyote_left := 0.0
var _collider: CollisionShape3D
var _capsule: CapsuleShape3D
var _was_sliding := false
var sliding_active := false

func _ready() -> void:
	_collider = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(_collider):
		_capsule = _collider.shape as CapsuleShape3D

func _physics_process(delta: float) -> void:
	rotation.y = look_yaw
	if is_dead:
		input_vector = Vector2.ZERO
		velocity = Vector3.ZERO
		jump_requested = false
		dash_requested = false
		slide_requested = false
		sprinting = false
		return
	if event_id == "FREEZE_FRAME":
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_dash_left = maxf(0.0, _dash_left - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if is_on_floor():
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
		velocity.y -= GRAVITY * gravity_scale * delta

	if jump_requested:
		_jump_buffer_left = JUMP_BUFFER_TIME
	jump_requested = false

	if slide_requested and is_on_floor() and stamina >= SLIDE_STAMINA_COST and not _was_sliding:
		_set_sliding(true)
		_slide_left = SLIDE_DURATION
		stamina -= SLIDE_STAMINA_COST
	slide_requested = false
	if _was_sliding:
		_slide_left = maxf(0.0, _slide_left - delta)
		if _slide_left <= 0.0 or _jump_buffer_left > 0.0:
			_set_sliding(false)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and stamina >= 8.0:
		_set_sliding(false)
		velocity.y = JUMP_VELOCITY
		stamina -= 8.0
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var direction := local_direction.rotated(Vector3.UP, look_yaw).normalized()
	if dash_requested and _dash_cooldown <= 0.0 and stamina >= 20.0:
		_set_sliding(false)
		_dash_direction = direction if direction.length() > 0.1 else -global_basis.z
		_dash_direction.y = 0.0
		_dash_direction = _dash_direction.normalized()
		_dash_left = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		stamina -= 20.0
	dash_requested = false

	if _dash_left > 0.0:
		velocity.x = _dash_direction.x * DASH_SPEED * speed_scale
		velocity.z = _dash_direction.z * DASH_SPEED * speed_scale
	else:
		var target_speed := SLIDE_SPEED if _was_sliding else (SPRINT_SPEED if sprinting and stamina > 0.0 else WALK_SPEED)
		target_speed *= speed_scale
		if direction.length() > 0.01:
			var acceleration := 34.0 if _was_sliding else 28.0
			velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
		else:
			var friction := 3.5 if event_id == "ICE_WORLD" else (7.0 if _was_sliding else 20.0)
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if _was_sliding:
			stamina = maxf(0.0, stamina - 5.0 * delta)
		elif sprinting and stamina > 0.0:
			stamina = maxf(0.0, stamina - 15.0 * delta)
		else:
			stamina = minf(MAX_STAMINA, stamina + 20.0 * delta)
	move_and_slide()

func apply_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		is_dead = true
		respawn_left = RESPAWN_SECONDS
		input_vector = Vector2.ZERO
		velocity = Vector3.ZERO
		sprinting = false
		dash_requested = false
		slide_requested = false
		_set_sliding(false)
		return true
	return false

func respawn_at(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	is_dead = false
	respawn_left = 0.0
	stamina = MAX_STAMINA
	input_vector = Vector2.ZERO
	jump_requested = false
	dash_requested = false
	slide_requested = false
	_set_sliding(false)

func _set_sliding(enabled: bool) -> void:
	if _was_sliding == enabled or not is_instance_valid(_collider) or not is_instance_valid(_capsule):
		return
	_was_sliding = enabled
	sliding_active = enabled
	_capsule.height = 1.0 if enabled else 1.8
	_collider.position.y = 0.5 if enabled else 0.9

func apply_event(next_event: String) -> void:
	event_id = next_event
	gravity_scale = 0.55 if next_event == "LOW_GRAVITY" else 1.0
	match next_event:
		"BONK_MODE": speed_scale = 1.3
		"NPC_MODE": speed_scale = 0.78
		"ICE_WORLD": speed_scale = 0.82
		"FREEZE_FRAME":
			speed_scale = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
		_: speed_scale = 1.0
