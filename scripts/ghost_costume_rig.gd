extends Skeleton3D
## Rigid armor shells bound to bones driven by the shared locomotion pivots.

const PARTS := {
	"UpperArm_L": preload("res://assets/characters/Ghost_UpperArm_L.glb"),
	"UpperArm_R": preload("res://assets/characters/Ghost_UpperArm_R.glb"),
	"Forearm_L": preload("res://assets/characters/Ghost_Forearm_L.glb"),
	"Forearm_R": preload("res://assets/characters/Ghost_Forearm_R.glb"),
	"Thigh_L": preload("res://assets/characters/Ghost_Thigh_L.glb"),
	"Thigh_R": preload("res://assets/characters/Ghost_Thigh_R.glb"),
	"Shin_L": preload("res://assets/characters/Ghost_Shin_L.glb"),
	"Shin_R": preload("res://assets/characters/Ghost_Shin_R.glb"),
	"Foot_L": preload("res://assets/characters/Ghost_Foot_L.glb"),
	"Foot_R": preload("res://assets/characters/Ghost_Foot_R.glb"),
}
var _drivers: Array[Node3D] = []


func bind_to(rig: Node3D) -> void:
	for side in ["L", "R"]:
		var arm := rig.get_node("ArmPivot_" + side) as Node3D
		var elbow := arm.get_node("ElbowPivot") as Node3D
		var thigh := rig.get_node("LegPivot_" + side) as Node3D
		var knee := thigh.get_node("KneePivot") as Node3D
		var arm_bone := _add_part("UpperArm_" + side, arm, -1)
		_add_part("Forearm_" + side, elbow, arm_bone)
		var leg_bone := _add_part("Thigh_" + side, thigh, -1)
		var knee_bone := _add_part("Shin_" + side, knee, leg_bone)
		_add_part("Foot_" + side, knee, knee_bone, false)
		for pivot in [arm, elbow, thigh, knee]:
			for piece in pivot.get_children():
				if piece is MeshInstance3D and piece.name != "Glove":
					piece.hide()
	sync_pose()


func _add_part(part: String, driver: Node3D, parent_bone: int, use_driver: bool = true) -> int:
	var index := get_bone_count()
	add_bone(part)
	set_bone_parent(index, parent_bone)
	set_bone_rest(index, Transform3D(Basis.IDENTITY, driver.position if use_driver else Vector3.ZERO))
	_drivers.append(driver if use_driver else null)
	var socket := BoneAttachment3D.new()
	socket.bone_name = part
	add_child(socket)
	socket.bone_idx = index
	socket.add_child(PARTS[part].instantiate())
	return index


func sync_pose() -> void:
	for index in range(_drivers.size()):
		var driver := _drivers[index]
		if is_instance_valid(driver):
			set_bone_pose_position(index, driver.position)
			set_bone_pose_rotation(index, driver.quaternion)
	force_update_all_bone_transforms()
	for index in range(get_bone_count()):
		var socket := get_child(index) as BoneAttachment3D
		socket.transform = get_bone_global_pose(index)
