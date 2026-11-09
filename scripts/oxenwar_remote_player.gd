extends Node3D
## Lightweight visual proxy for another connected player.

var target_position := Vector3.ZERO
var target_yaw := 0.0
var _sliding := false
var display_name := "Player"
var _base_color := Color("#27D7E7")
var _outfit_id := "outfit_default"
var _visual: MeshInstance3D
var _name_tag: Label3D

func _ready() -> void:
	_visual = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	_visual.mesh = capsule
	_visual.position.y = 0.9
	add_child(_visual)
	_name_tag = Label3D.new()
	_name_tag.position = Vector3(0, 2.15, 0)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 32
	_name_tag.outline_size = 8
	_name_tag.pixel_size = 0.006
	add_child(_name_tag)

func set_player_identity(player_name: String, color: Color, outfit_id: String = "outfit_default") -> void:
	display_name = player_name.substr(0, 24)
	_outfit_id = outfit_id
	if is_instance_valid(_name_tag):
		_name_tag.text = display_name
	if is_instance_valid(_visual):
		_base_color = Color("#A92332") if outfit_id == "outfit_iron_vanguard" else (Color("#B52D3D") if outfit_id == "outfit_web_sentinel" else color)
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.65
		_visual.material_override = material

func apply_network_state(position_value: Vector3, yaw_value: float, sliding: bool = false, health: float = 100.0, dead: bool = false, team_id: String = "") -> void:
	target_position = position_value
	target_yaw = yaw_value
	if is_instance_valid(_name_tag):
		_name_tag.text = "%s  •  K.O." % display_name if dead else "%s  •  HP %d" % [display_name, int(ceil(health))]
	if is_instance_valid(_visual):
		var material := _visual.material_override as StandardMaterial3D
		if is_instance_valid(material):
			var team_color := Color("#F05A66") if team_id == "red" else (Color("#4C91FF") if team_id == "blue" else _base_color)
			material.albedo_color = team_color.darkened(0.65) if dead else team_color
		_visual.visible = not dead
	if _sliding != sliding:
		_sliding = sliding
		_visual.scale.y = 0.56 if sliding else 1.0
		_visual.position.y = 0.5 if sliding else 0.9
		_name_tag.position.y = 1.35 if sliding else 2.15
	if not is_inside_tree():
		global_position = target_position
		rotation.y = target_yaw

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 14.0))
