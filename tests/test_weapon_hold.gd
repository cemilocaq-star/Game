extends SceneTree
## Third-person weapon holding: arm IK accuracy, grip glued to the glove, weapon pointing forward,
## no clipping into the torso for any of the 27 weapons, local third person and remote avatars.

const HOLD := preload("res://scripts/weapon_hold.gd")
const RIG := preload("res://scripts/character_motion_rig.gd")
const VISUALS := preload("res://scripts/arcade_weapon_visuals.gd")
const PLAYER := preload("res://scripts/player.gd")
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const CLEARANCE := 0.02 ## metres the weapon must keep from the torso cylinder
var failures: Array[String] = []
var report: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	_test_ik()
	_test_measure_all_weapons()
	for outfit in ["outfit_default", "outfit_ghost_ops"]:
		_test_rig(outfit)
	await _test_local_player()
	_test_remote()
	for line in report:
		print(line)
	if failures.is_empty():
		print("PASS: third-person weapon holding (IK, grip fit, clearance, local and remote)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_ik() -> void:
	var worst := 0.0
	var count := 0
	for x in [-0.5, -0.4, -0.3, -0.2, -0.1, 0.0, 0.1, 0.2, 0.3, 0.4, 0.5]:
		for y in [-0.3, -0.2, -0.1, 0.0, 0.1, 0.15]:
			for z in [-0.65, -0.55, -0.45, -0.4]:
				var target := Vector3(x, y, z)
				if target.length() > HOLD.max_reach() * 0.96 or target.length() < 0.4:
					continue
				var solved: Dictionary = HOLD.solve_arm(target)
				var reached: Vector3 = HOLD.hand_position(solved.arm_x, solved.arm_z, solved.elbow_x)
				worst = maxf(worst, reached.distance_to(target))
				count += 1
				_check(solved.arm_x >= HOLD.ARM_X_LIMITS.x - 0.0001 and solved.arm_x <= HOLD.ARM_X_LIMITS.y + 0.0001, "arm_x inside limits for %s" % str(target))
				_check(solved.elbow_x >= HOLD.ELBOW_LIMITS.x - 0.0001 and solved.elbow_x <= HOLD.ELBOW_LIMITS.y + 0.0001, "elbow inside limits for %s" % str(target))
	report.append("IK: %d reachable targets, worst error %.4f m" % [count, worst])
	_check(count > 20, "enough IK targets were sampled (%d)" % count)
	_check(worst < 0.015, "IK reaches reachable targets within 1.5 cm (worst %f)" % worst)
	var far: Dictionary = HOLD.solve_arm(Vector3(0.0, 0.0, -3.0))
	var far_hand: Vector3 = HOLD.hand_position(far.arm_x, far.arm_z, far.elbow_x)
	_check(is_finite(far_hand.x) and far_hand.length() <= HOLD.max_reach() + 0.001, "unreachable targets stay on the reachable sphere")
	var zero: Dictionary = HOLD.solve_arm(Vector3.ZERO)
	_check(is_finite(float(zero.arm_x)) and is_finite(float(zero.elbow_x)), "a target at the shoulder does not blow up")


func _test_measure_all_weapons() -> void:
	for weapon_id: String in PLAYER.ARCADE_WEAPON_LOCAL:
		var model: Node3D = VISUALS.build_weapon(weapon_id, Color.WHITE)
		var info: Dictionary = HOLD.measure(model, weapon_id)
		var box: AABB = info.aabb
		_check(box.size.length() > 0.1, "%s has measurable bounds" % weapon_id)
		_check(is_finite(info.grip.x) and is_finite(info.foregrip.z), "%s grip points are finite" % weapon_id)
		report.append("weapon %-18s length %.2f m scaled, rear %.2f, two-handed %s" % [weapon_id, info.length, info.rear, str(info.two_handed)])
		model.free()


## Horizontal distance from the rig's vertical axis to a box seen in rig space (0 when it crosses).
func _axis_distance(box: AABB) -> float:
	var nearest_x := clampf(0.0, box.position.x, box.end.x)
	var nearest_z := clampf(0.0, box.position.z, box.end.z)
	return Vector2(nearest_x, nearest_z).length()


func _rig_space_box(mount: Node3D, rig: Node3D, local_box: AABB) -> AABB:
	var to_rig := rig.global_transform.affine_inverse() * mount.global_transform
	var box := AABB(to_rig * local_box.position, Vector3.ZERO)
	for corner in range(8):
		var offset := Vector3(
			local_box.size.x if (corner & 1) != 0 else 0.0,
			local_box.size.y if (corner & 2) != 0 else 0.0,
			local_box.size.z if (corner & 4) != 0 else 0.0)
		box = box.expand(to_rig * (local_box.position + offset))
	return box


func _test_rig(outfit: String) -> void:
	var host := Node3D.new()
	root.add_child(host)
	var rig := RIG.build(host, Color.CYAN, outfit)
	var elbow_right := rig.get_node("ArmPivot_R/ElbowPivot") as Node3D
	var elbow_left := rig.get_node("ArmPivot_L/ElbowPivot") as Node3D
	var worst_glove := 0.0
	var worst_grip := 0.0
	var worst_left := 0.0
	var worst_aim := 0.0
	var tightest := 10.0
	for weapon_id: String in PLAYER.ARCADE_WEAPON_LOCAL:
		var data: Dictionary = PLAYER.ARCADE_WEAPON_LOCAL[weapon_id]
		var mount: Node3D = VISUALS.build_weapon(weapon_id, data.color)
		var info: Dictionary = HOLD.measure(mount, weapon_id)
		mount.scale = Vector3.ONE * HOLD.WEAPON_SCALE
		elbow_right.add_child(mount)
		for aim_pitch in [0.0, 0.6, -0.6]:
			for speed in [0.0, 6.0]:
				var hold: Dictionary = HOLD.hold_targets(info, aim_pitch)
				for frame in range(40):
					RIG.animate(rig, float(frame) / 60.0, speed, true, false, "", 1.0 / 60.0, hold)
				HOLD.place_mount(mount, elbow_right, rig, info, aim_pitch, 0.0)
				# Right glove on its target, grip inside the glove.
				var glove_world: Vector3 = elbow_right.global_transform * HOLD.GLOVE_LOCAL
				var target_world: Vector3 = rig.global_transform * hold.right
				worst_glove = maxf(worst_glove, glove_world.distance_to(target_world))
				var grip_world: Vector3 = mount.global_transform * info.grip
				worst_grip = maxf(worst_grip, grip_world.distance_to(glove_world))
				# The weapon points where the body points, tilted by the aim pitch.
				var forward := -mount.global_transform.basis.z.normalized()
				var wanted := (rig.global_transform.basis.orthonormalized() * Basis(Vector3.RIGHT, aim_pitch)) * Vector3.FORWARD
				worst_aim = maxf(worst_aim, rad_to_deg(forward.angle_to(wanted)))
				if hold.left != null:
					var left_world: Vector3 = elbow_left.global_transform * HOLD.GLOVE_LOCAL
					worst_left = maxf(worst_left, left_world.distance_to(rig.global_transform * hold.left))
				# No clipping: keep clear of the torso cylinder while it overlaps the torso height.
				var box := _rig_space_box(mount, rig, info.aabb)
				if box.end.y > -0.325 and box.position.y < 0.325:
					var gap := _axis_distance(box) - HOLD.TORSO_RADIUS
					tightest = minf(tightest, gap)
					if gap < CLEARANCE:
						failures.append("%s (%s, pitch %.1f) clips the torso by %.3f m" % [weapon_id, outfit, aim_pitch, gap])
		mount.free()
	report.append("%s: worst glove error %.4f m, grip %.4f m, aim %.2f deg, left hand %.4f m, tightest torso gap %.3f m" % [outfit, worst_glove, worst_grip, worst_aim, worst_left, tightest])
	_check(worst_glove < 0.04, "%s: right glove reaches its target (worst %f)" % [outfit, worst_glove])
	_check(worst_grip < 0.005, "%s: the grip stays inside the glove (worst %f)" % [outfit, worst_grip])
	_check(worst_aim < 0.6, "%s: the weapon points where the body aims (worst %f deg)" % [outfit, worst_aim])
	_check(worst_left < 0.06, "%s: the off hand supports two-handed weapons (worst %f)" % [outfit, worst_left])
	host.free()


func _test_local_player() -> void:
	var player = PLAYER.new()
	root.add_child(player)
	await process_frame
	await process_frame
	player.set("_intro_left", 0.0)
	var weapon: Node3D = player.get("_tp_weapon")
	_check(weapon != null, "the local character carries a world weapon")
	if weapon == null:
		player.queue_free()
		return
	_check(weapon.get_parent().name == "ElbowPivot" and weapon.get_parent().get_parent().name == "ArmPivot_R", "the weapon is in the right hand")
	var meshes_on_body_layer := true
	var stack: Array[Node] = [weapon]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D and (node as VisualInstance3D).layers != 2:
			meshes_on_body_layer = false
		stack.append_array(node.get_children())
	_check(meshes_on_body_layer, "the world weapon is on the body render layer, so first person never draws it")
	for frame in range(5):
		player.call("_process", 1.0 / 60.0)
	_check(not weapon.visible, "the world weapon is hidden in first person")
	player.toggle_third_person()
	for frame in range(5):
		player.call("_process", 1.0 / 60.0)
	_check(weapon.visible, "the world weapon shows in third person")
	player.set_selected_weapon("ranger_rifle")
	var rebuilt: Node3D = player.get("_tp_weapon")
	_check(rebuilt != weapon and rebuilt.name == "ArcadeWeapon_ranger_rifle", "switching weapon swaps the world model")
	for frame in range(5):
		player.call("_process", 1.0 / 60.0)
	_check(rebuilt.visible, "the new world weapon is visible in third person")
	player.play_emote("griddy")
	for frame in range(3):
		player.call("_process", 1.0 / 60.0)
	_check(not rebuilt.visible, "emotes put the weapon away")
	player.stop_emote()
	player.set_combat_dead(true)
	player.call("_process", 1.0 / 60.0)
	_check(not rebuilt.visible, "a dead character holds no weapon")
	player.queue_free()
	await process_frame


func _test_remote() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var remote := REMOTE.new()
	host.add_child(remote)
	for weapon_id in ["aether", "ranger_rifle", "rotary_arc", "hand_cannon"]:
		remote.sync_weapon(weapon_id, true)
		for frame in range(80):
			remote.call("_process", 1.0 / 60.0)
		var mount := remote.get("_weapon_mount") as Node3D
		var rig := remote.get("_motion_rig") as Node3D
		var elbow := rig.get_node("ArmPivot_R/ElbowPivot") as Node3D
		_check(mount.get_parent() == elbow, "%s: remote weapon is in the right hand" % weapon_id)
		var info: Dictionary = remote.get("_weapon_info")
		var glove_world: Vector3 = elbow.global_transform * HOLD.GLOVE_LOCAL
		_check((mount.global_transform * info.grip).distance_to(glove_world) < 0.005, "%s: remote grip sits in the glove" % weapon_id)
		var box := _rig_space_box(mount, rig, info.aabb)
		_check(_axis_distance(box) - HOLD.TORSO_RADIUS >= CLEARANCE or box.position.y > 0.325 or box.end.y < -0.325, "%s: remote weapon clears the torso" % weapon_id)
		remote.set("aim_pitch", 0.5)
		for frame in range(40):
			remote.call("_process", 1.0 / 60.0)
		var forward := -mount.global_transform.basis.z.normalized()
		var level := -rig.global_transform.basis.orthonormalized().z
		_check(forward.y > level.y + 0.3, "%s: raising aim pitch lifts the remote weapon" % weapon_id)
		remote.set("aim_pitch", 0.0)
	host.free()
