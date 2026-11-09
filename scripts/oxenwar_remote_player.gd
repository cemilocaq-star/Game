extends Node3D
## Lightweight visual proxy for another connected player.

const CharacterVisuals = preload("res://scripts/character_visuals.gd")
const CharacterMotionRig = preload("res://scripts/character_motion_rig.gd")

var target_position := Vector3.ZERO
var target_yaw := 0.0
var _sliding := false
var display_name := "Player"
var _base_color := Color("#27D7E7")
var _outfit_id := "outfit_default"
var _visual: MeshInstance3D
var _name_tag: Label3D
var _emote_id := ""
var _emote_clock := 0.0
var _swimwear_root: Node3D
var _character_detail_root: Node3D
var _motion_rig: Node3D
var _motion_clock := 0.0
var _previous_position := Vector3.ZERO

func _ready() -> void:
	_visual = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	_visual.mesh = capsule
	_visual.position.y = 0.9
	add_child(_visual)
	_build_remote_swimwear()
	_rebuild_remote_detail()
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
		material.albedo_color = _base_color
		material.roughness = 0.65
		_visual.material_override = material
		_rebuild_remote_detail()

func _build_remote_swimwear() -> void:
	_swimwear_root = Node3D.new()
	_swimwear_root.name = "BeachSwimwear"
	_swimwear_root.visible = false
	_visual.add_child(_swimwear_root)
	var shirt := MeshInstance3D.new()
	var shirt_mesh := BoxMesh.new()
	shirt_mesh.size = Vector3(0.66, 0.56, 0.44)
	shirt.mesh = shirt_mesh
	shirt.position.y = 0.18
	shirt.material_override = _remote_material(Color("#16A6C8"))
	_swimwear_root.add_child(shirt)
	var shorts := MeshInstance3D.new()
	var shorts_mesh := BoxMesh.new()
	shorts_mesh.size = Vector3(0.68, 0.34, 0.46)
	shorts.mesh = shorts_mesh
	shorts.position.y = -0.30
	shorts.material_override = _remote_material(Color("#FFB347"))
	_swimwear_root.add_child(shorts)
	var glasses := Node3D.new()
	glasses.position = Vector3(0.0, 0.62, -0.34)
	_swimwear_root.add_child(glasses)
	for side in [-1.0, 1.0]:
		var lens := MeshInstance3D.new()
		var lens_mesh := BoxMesh.new()
		lens_mesh.size = Vector3(0.22, 0.12, 0.055)
		lens.mesh = lens_mesh
		lens.position.x = side * 0.13
		lens.material_override = _remote_material(Color("#172638"))
		glasses.add_child(lens)

func _rebuild_remote_detail() -> void:
	if is_instance_valid(_character_detail_root):
		_character_detail_root.queue_free()
	if is_instance_valid(_visual):
		_character_detail_root = CharacterVisuals.build(_visual, _outfit_id, _base_color)
		_character_detail_root.visible = not (is_instance_valid(_swimwear_root) and _swimwear_root.visible)
	if is_instance_valid(_motion_rig):
		_motion_rig.queue_free()
	if is_instance_valid(_visual):
		_motion_rig = CharacterMotionRig.build(_visual, _base_color)

func _remote_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	return material

func apply_network_state(position_value: Vector3, yaw_value: float, sliding: bool = false, health: float = 100.0, dead: bool = false, team_id: String = "", emote_id: String = "", swimming: bool = false) -> void:
	target_position = position_value
	target_yaw = yaw_value
	if is_instance_valid(_swimwear_root):
		_swimwear_root.visible = swimming
	if is_instance_valid(_character_detail_root):
		_character_detail_root.visible = not swimming
	if emote_id != _emote_id:
		_emote_id = emote_id if emote_id in ["griddy", "goofy"] else ""
		_emote_clock = 0.0
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
	if _emote_id != "":
		_emote_clock += delta
		var rate := 2.0 if _emote_id == "griddy" else 1.35
		var phase := _emote_clock * TAU * rate
		_visual.position.y = 0.9 + absf(sin(phase)) * 0.12
		_visual.rotation.z = sin(phase) * (0.24 if _emote_id == "griddy" else 0.34)
	elif _sliding:
		_visual.position.y = move_toward(_visual.position.y, 0.5, delta * 8.0)
		_visual.rotation.z = move_toward(_visual.rotation.z, 0.0, delta * 2.0)
	else:
		_visual.position.y = move_toward(_visual.position.y, 0.9, delta * 4.0)
		_visual.rotation.z = move_toward(_visual.rotation.z, 0.0, delta * 2.0)
	global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 14.0))
	_motion_clock += delta
	var estimated_speed := global_position.distance_to(_previous_position) / maxf(delta, 0.0001)
	_previous_position = global_position
	if not _sliding and _emote_id == "":
		_visual.position.y = 0.9 + (absf(sin(_motion_clock * 10.0)) * 0.035 if estimated_speed > 0.5 else sin(_motion_clock * 1.8) * 0.012)
	CharacterMotionRig.animate(_motion_rig, _motion_clock, estimated_speed, true, _sliding, _emote_id, delta)
