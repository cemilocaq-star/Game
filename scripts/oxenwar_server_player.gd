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

var input_vector := Vector2.ZERO
var look_yaw := 0.0
var jump_requested := false
var sprinting := false
var sliding := false
var dash_requested := false
var stamina := MAX_STAMINA
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
var _collider: CollisionShape3D
var _capsule: CapsuleShape3D
var _was_sliding := false

func _ready() -> void:
	_collider = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(_collider):
		_capsule = _collider.shape as CapsuleShape3D

func _physics_process(delta: float) -> void:
	rotation.y = look_yaw
	_set_sliding(sliding)
	_dash_left = maxf(0.0, _dash_left - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * gravity_scale * delta
	if jump_requested and is_on_floor() and stamina >= 8.0:
		velocity.y = JUMP_VELOCITY
		stamina -= 8.0
	jump_requested = false

	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var direction := local_direction.rotated(Vector3.UP, look_yaw).normalized()
	if dash_requested and _dash_cooldown <= 0.0 and stamina >= 20.0:
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
		var target_speed := SLIDE_SPEED if sliding else (SPRINT_SPEED if sprinting and stamina > 0.0 else WALK_SPEED)
		target_speed *= speed_scale
		if direction.length() > 0.01:
			velocity.x = move_toward(velocity.x, direction.x * target_speed, 30.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * target_speed, 30.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		if sliding:
			stamina = maxf(0.0, stamina - 5.0 * delta)
		elif sprinting and stamina > 0.0:
			stamina = maxf(0.0, stamina - 15.0 * delta)
		else:
			stamina = minf(MAX_STAMINA, stamina + 20.0 * delta)
	move_and_slide()

func _set_sliding(enabled: bool) -> void:
	if _was_sliding == enabled or not is_instance_valid(_collider) or not is_instance_valid(_capsule):
		return
	_was_sliding = enabled
	_capsule.height = 1.0 if enabled else 1.8
	_collider.position.y = 0.5 if enabled else 0.9

func apply_event(next_event: String) -> void:
	event_id = next_event
	gravity_scale = 0.55 if next_event == "LOW_GRAVITY" else 1.0
	match next_event:
		"BONK_MODE": speed_scale = 1.3
		"NPC_MODE": speed_scale = 0.78
		"ICE_WORLD": speed_scale = 0.82
		_: speed_scale = 1.0
