extends SceneTree

const NETWORK := preload("res://scripts/oxenwar_network.gd")
const RIG := preload("res://scripts/character_motion_rig.gd")
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const PLAYER := preload("res://scripts/player.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _run() -> void:
	for yaw: float in [-PI, -PI / 2.0, 0.0, PI / 2.0, PI]:
		var camera_pose := Node3D.new()
		camera_pose.rotation.y = yaw
		_check(NETWORK.view_forward(yaw).is_equal_approx(-camera_pose.basis.z), "server/client aiming agrees at yaw %.2f" % yaw)
		camera_pose.free()
	var host := Node3D.new()
	root.add_child(host)
	var rig := RIG.build(host, Color.WHITE, "outfit_ghost_ops")
	var skeleton := rig.get_node("GhostCostumeSkeleton") as Skeleton3D
	_check(skeleton.get_bone_count() == 10, "ten costume bones")
	var shin := skeleton.find_bone("Shin_L")
	_check(skeleton.get_bone_parent(shin) == skeleton.find_bone("Thigh_L"), "shin follows thigh")
	RIG.animate(rig, 0.33, 6.0, true, false, "", 0.2)
	var knee := rig.get_node("LegPivot_L/KneePivot") as Node3D
	_check(skeleton.get_bone_pose_rotation(shin).is_equal_approx(knee.quaternion), "bone follows locomotion")
	var socket := skeleton.get_child(shin) as BoneAttachment3D
	_check(socket.transform.is_equal_approx(skeleton.get_bone_global_pose(shin)), "mesh attachment follows bone")
	var remote := REMOTE.new()
	host.add_child(remote)
	for weapon_id: String in PLAYER.ARCADE_WEAPON_LOCAL:
		remote.sync_weapon(weapon_id, false)
		var weapon := remote.get("_weapon_mount") as Node3D
		_check(weapon.name == "ArcadeWeapon_" + weapon_id, "equipped third-person model " + weapon_id)
		remote.sync_weapon(weapon_id, true)
		_check(remote.get("_weapon_mount") == weapon, "snapshot reuses selected mesh")
		remote.play_weapon_fire(weapon_id)
		_check(remote.get("_weapon_kick") == 1.0, "matching fire event triggers recoil")
	remote.apply_network_state(Vector3.ZERO, 0.0, false, 0.0, true)
	remote.call("_process", 0.1)
	_check(not remote.get("_weapon_mount").visible, "dead avatar hides weapon")
	remote.apply_network_state(Vector3.ZERO, 0.0)
	remote.call("_process", 0.1)
	_check(remote.get("_weapon_mount").visible and remote.get("_weapon_kick") == 0.0, "respawn restores weapon and clears recoil")
	var local := PLAYER.new()
	var camera := Camera3D.new()
	var viewmodel := Node3D.new()
	local.set("_camera", camera)
	local.set("_blaster_model", viewmodel)
	local.add_child(camera)
	camera.add_child(viewmodel)
	local.set_combat_dead(true)
	_check(not viewmodel.visible, "local viewmodel hides on death")
	local.set_combat_dead(false)
	_check(viewmodel.visible and viewmodel.position == PLAYER.WEAPON_REST, "local respawn restores weapon pose")
	local.free()
	host.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: skeletal costume binding, all 27 replicated weapons, recoil and respawn")
	quit(0 if failures.is_empty() else 1)
