extends RefCounted
## Third-person weapon holding for the shared character rig (local player in third person and every
## replicated avatar). Three pieces:
##  - measure(): the weapon's own bounds, grip and foregrip, read from its built model;
##  - hold_targets(): where each glove must be so the weapon clears the torso and points forward;
##  - solve_arm(): numeric inverse kinematics for the rig's shoulder + elbow hinge arm;
##  - place_mount(): keeps the weapon level, with its grip inside the glove, whatever the arm does.
## The limb maths mirrors CharacterMotionRig.build exactly, so tests can verify the fit by forward kinematics.

const CHARACTER_VISUALS := preload("res://scripts/character_visuals.gd")

const UPPER_ARM := 0.385 ## shoulder pivot -> elbow pivot
const GLOVE_LOCAL := Vector3(0.0, -0.355, -0.02) ## glove centre in the elbow pivot's frame
const WEAPON_SCALE := 0.58
const SHOULDER_Y := CHARACTER_VISUALS.TROLL_SHOULDER_Y
const SHOULDER_X := CHARACTER_VISUALS.TROLL_SHOULDER_X
const TORSO_RADIUS := CHARACTER_VISUALS.TROLL_BODY_RADIUS
const ARM_X_LIMITS := Vector2(-1.2, 2.7)
const ARM_Z_LIMITS := Vector2(-1.1, 1.1)
const ELBOW_LIMITS := Vector2(0.0, 2.4)
const TWO_HAND_LENGTH := 0.42 ## scaled weapon length (m) from which the off hand supports it
const REACH_MARGIN := 0.97

static var _info_cache: Dictionary = {}


static func forearm_length() -> float:
	return GLOVE_LOCAL.length()


static func max_reach() -> float:
	return UPPER_ARM + forearm_length()


## Glove position relative to the shoulder pivot for the given joint angles (radians).
static func hand_position(arm_x: float, arm_z: float, elbow_x: float) -> Vector3:
	var arm := Basis.from_euler(Vector3(arm_x, 0.0, arm_z), EULER_ORDER_YXZ)
	var elbow := Basis.from_euler(Vector3(elbow_x, 0.0, 0.0), EULER_ORDER_YXZ)
	return arm * (Vector3(0.0, -UPPER_ARM, 0.0) + elbow * GLOVE_LOCAL)


## Joint angles that put the glove on `target` (relative to the shoulder). Targets beyond reach are
## pulled onto the reachable sphere. Returns {"arm_x", "arm_z", "elbow_x", "error"}.
static func solve_arm(target: Vector3) -> Dictionary:
	var reach := max_reach() * REACH_MARGIN
	var minimum := absf(UPPER_ARM - forearm_length()) + 0.03
	var distance := clampf(target.length(), minimum, reach)
	var goal := target.normalized() * distance if target.length() > 0.0001 else Vector3(0.0, -distance, 0.0)
	# Analytic start: aim the arm at the goal and bend the elbow by the law of cosines.
	var direction := goal.normalized()
	var arm_z := asin(clampf(direction.x, -0.99, 0.99))
	var arm_x := atan2(-direction.z, -direction.y)
	var l1 := UPPER_ARM
	var l2 := forearm_length()
	var interior := acos(clampf((l1 * l1 + l2 * l2 - distance * distance) / (2.0 * l1 * l2), -1.0, 1.0))
	var elbow_x := PI - interior
	var params := Vector3(arm_x, arm_z, elbow_x)
	for iteration in range(10):
		params = _clamp_params(params)
		var error := goal - hand_position(params.x, params.y, params.z)
		if error.length() < 0.002:
			break
		# Damped least squares with a numeric Jacobian (three joints, three coordinates).
		var columns: Array[Vector3] = []
		for axis in range(3):
			var probe := params
			probe[axis] += 0.0005
			columns.append((hand_position(probe.x, probe.y, probe.z) - hand_position(params.x, params.y, params.z)) / 0.0005)
		var damping := 0.0004
		var normal := Basis(
			Vector3(columns[0].dot(columns[0]) + damping, columns[0].dot(columns[1]), columns[0].dot(columns[2])),
			Vector3(columns[1].dot(columns[0]), columns[1].dot(columns[1]) + damping, columns[1].dot(columns[2])),
			Vector3(columns[2].dot(columns[0]), columns[2].dot(columns[1]), columns[2].dot(columns[2]) + damping)
		)
		var rhs := Vector3(columns[0].dot(error), columns[1].dot(error), columns[2].dot(error))
		params += normal.inverse() * rhs
	params = _clamp_params(params)
	var final_error := target.distance_to(hand_position(params.x, params.y, params.z))
	return {"arm_x": params.x, "arm_z": params.y, "elbow_x": params.z, "error": final_error}


static func _clamp_params(params: Vector3) -> Vector3:
	return Vector3(
		clampf(params.x, ARM_X_LIMITS.x, ARM_X_LIMITS.y),
		clampf(params.y, ARM_Z_LIMITS.x, ARM_Z_LIMITS.y),
		clampf(params.z, ELBOW_LIMITS.x, ELBOW_LIMITS.y)
	)


## Bounds and grip points of a built weapon model, in the model's own space (unscaled).
## Cached per weapon id because the geometry never changes, only the tint.
static func measure(weapon: Node3D, weapon_id: String = "") -> Dictionary:
	if not weapon_id.is_empty() and _info_cache.has(weapon_id):
		return _info_cache[weapon_id]
	var holder := {"aabb": AABB(), "has_bounds": false, "grip": Vector3.ZERO, "has_grip": false}
	_collect(weapon, Transform3D.IDENTITY, holder)
	var bounds: AABB = holder["aabb"]
	var grip_point: Vector3 = holder["grip"]
	if not bool(holder["has_bounds"]):
		bounds = AABB(Vector3(-0.1, -0.1, -0.3), Vector3(0.2, 0.2, 0.4))
	if not bool(holder["has_grip"]):
		grip_point = Vector3(0.0, bounds.position.y + bounds.size.y * 0.25, bounds.end.z - bounds.size.z * 0.25)
	var muzzle_z := bounds.position.z
	# The off hand grips the underside, a third of the way from the grip to the muzzle (and never
	# further than the arms can comfortably reach).
	var forward_span := minf(maxf(0.0, grip_point.z - muzzle_z) * 0.34, 0.16 / WEAPON_SCALE)
	var foregrip := Vector3(0.0, minf(grip_point.y + 0.05, bounds.position.y + bounds.size.y * 0.3), grip_point.z - forward_span)
	var info := {
		"aabb": bounds,
		"grip": grip_point,
		"foregrip": foregrip,
		"length": bounds.size.z * WEAPON_SCALE,
		"rear": maxf(0.0, bounds.end.z - grip_point.z) * WEAPON_SCALE,
		"two_handed": bounds.size.z * WEAPON_SCALE >= TWO_HAND_LENGTH
	}
	if not weapon_id.is_empty():
		_info_cache[weapon_id] = info
	return info


static func _collect(node: Node, transform: Transform3D, holder: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child3d := child as Node3D
		var child_transform := transform * child3d.transform
		if child3d is MeshInstance3D and (child3d as MeshInstance3D).mesh != null:
			var box: AABB = child_transform * (child3d as MeshInstance3D).mesh.get_aabb()
			if bool(holder["has_bounds"]):
				holder["aabb"] = (holder["aabb"] as AABB).merge(box)
			else:
				holder["aabb"] = box
				holder["has_bounds"] = true
		if not bool(holder["has_grip"]) and child3d.name.to_lower().contains("grip"):
			holder["grip"] = child_transform.origin
			holder["has_grip"] = true
		_collect(child3d, child_transform, holder)


## Glove targets in the rig's space (relative to the rig origin, which is the body centre):
## {"right": Vector3, "left": Vector3 or null}. `aim_pitch` tilts the weapon up (+) or down (-).
static func hold_targets(info: Dictionary, aim_pitch: float, bob: float = 0.0) -> Dictionary:
	var pitch := clampf(aim_pitch, -1.15, 1.15)
	# The grip sits far enough ahead that the stock or handle behind it stays outside the torso.
	var forward := clampf(TORSO_RADIUS + float(info.get("rear", 0.0)) + 0.10, 0.46, 0.60)
	var pivot := Vector3(0.0, SHOULDER_Y, 0.0)
	var base := Vector3(0.10, SHOULDER_Y - 0.17 + bob, -forward)
	var weapon_basis := Basis(Vector3.RIGHT, pitch)
	var right := pivot + Basis(Vector3.RIGHT, pitch * 0.55) * (base - pivot)
	var result := {"right": right, "left": null}
	if bool(info.get("two_handed", false)):
		var offset: Vector3 = ((info.foregrip as Vector3) - (info.grip as Vector3)) * WEAPON_SCALE
		result["left"] = right + weapon_basis * offset
	return result


## Keeps the mounted weapon level with the body (plus aim pitch and a recoil tilt) and puts its
## grip point on the glove centre. `elbow` is the right ElbowPivot, `rig` the rig root.
static func place_mount(mount: Node3D, elbow: Node3D, rig: Node3D, info: Dictionary, aim_pitch: float, kick: float = 0.0) -> void:
	if not (is_instance_valid(mount) and is_instance_valid(elbow) and is_instance_valid(rig)):
		return
	if not elbow.is_inside_tree() or not rig.is_inside_tree():
		return
	var rig_basis := rig.global_transform.basis.orthonormalized()
	var elbow_basis := elbow.global_transform.basis.orthonormalized()
	var desired := rig_basis * Basis(Vector3.RIGHT, clampf(aim_pitch, -1.15, 1.15) + kick * 0.16)
	var local_basis := elbow_basis.inverse() * desired
	var grip: Vector3 = info.get("grip", Vector3.ZERO)
	var recoil_back := Vector3(0.0, 0.0, kick * 0.055)
	mount.transform = Transform3D(local_basis.scaled(Vector3.ONE * WEAPON_SCALE), GLOVE_LOCAL - local_basis * (grip * WEAPON_SCALE) + local_basis * recoil_back)


static func clear_cache() -> void:
	_info_cache.clear()
