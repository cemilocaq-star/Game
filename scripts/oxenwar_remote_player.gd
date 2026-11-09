extends Node3D
## Lightweight visual proxy for another connected player.

var target_position := Vector3.ZERO
var target_yaw := 0.0
var display_name := "Player"
var _visual: MeshInstance3D
var _name_tag: Label3D

func _ready() -> void:
	_visual = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	_visual.mesh = capsule
	add_child(_visual)
	_name_tag = Label3D.new()
	_name_tag.position = Vector3(0, 2.15, 0)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 32
	_name_tag.outline_size = 8
	_name_tag.pixel_size = 0.006
	add_child(_name_tag)

func set_identity(player_name: String, color: Color) -> void:
	display_name = player_name.substr(0, 24)
	if is_instance_valid(_name_tag):
		_name_tag.text = display_name
	if is_instance_valid(_visual):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.65
		_visual.material_override = material

func apply_network_state(position_value: Vector3, yaw_value: float) -> void:
	target_position = position_value
	target_yaw = yaw_value
	if not is_inside_tree():
		global_position = target_position
		rotation.y = target_yaw

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 14.0))
