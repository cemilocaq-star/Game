extends Node3D
## Lightweight visual proxy for another connected player.

const CharacterVisuals = preload("res://scripts/character_visuals.gd")
const WEAPON_VISUALS := preload("res://scripts/arcade_weapon_visuals.gd")
const PLAYER := preload("res://scripts/player.gd")
const CharacterMotionRig = preload("res://scripts/character_motion_rig.gd")
const NET_SYNC := preload("res://scripts/net_sync.gd")
const WEAPON_HOLD := preload("res://scripts/weapon_hold.gd")

var target_position := Vector3.ZERO
var target_yaw := 0.0
var _snapshots = NET_SYNC.SnapshotBuffer.new()
var _sliding := false
var _dead := false
var _grounded := true
var _result_pose := ""
var _weapon_id := ""
var _weapon_mount: Node3D
var _weapon_kick := 0.0
var _weapon_info: Dictionary = {}
## Vertical aim of this player (radians, + = up). Not replicated yet, so weapons stay level.
var aim_pitch := 0.0
var _aim_pitch_target := 0.0
var _fall_elapsed := 0.0
const FALL_DURATION := 0.38
var display_name := "Player"
var _base_color := Color("#27D7E7")
var _outfit_id := "outfit_default"
var _avatar_color := Color("#27D7E7")
var _accessory_id := "accessory_cap"
var _accessory_root: Node3D
var _visual: MeshInstance3D
var _name_tag: Label3D
var _emote_id := ""
var _emote_clock := 0.0
var _swimwear_root: Node3D
var _character_detail_root: Node3D
var _hero_root: Node3D
var _motion_rig: Node3D
var _motion_clock := 0.0
var _previous_position := Vector3.ZERO
var _has_previous_position := false

func _ready() -> void:
	_visual = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	_visual.mesh = capsule
	_visual.position.y = 0.9
	add_child(_visual)
	_visual.material_override = _remote_material(_base_color)
	_build_remote_swimwear()
	_rebuild_remote_detail()
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.position = Vector3(0, 2.15, 0)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 32
	_name_tag.outline_size = 8
	_name_tag.pixel_size = 0.006
	add_child(_name_tag)

func set_player_identity(player_name: String, color: Color, outfit_id: String = "outfit_default", accessory_value: Variant = null) -> void:
	var accessory_id := "accessory_cap" if accessory_value == null or str(accessory_value).is_empty() else str(accessory_value)
	display_name = player_name.substr(0, 24)
	if is_instance_valid(_name_tag) and _name_tag.text != display_name:
		_name_tag.text = display_name
	if is_instance_valid(_visual) and _visual.material_override != null and color == _avatar_color and outfit_id == _outfit_id and accessory_id == _accessory_id:
		return
	_outfit_id = outfit_id
	_avatar_color = color
	_accessory_id = accessory_id
	_base_color = Color("#A92332") if outfit_id == "outfit_iron_vanguard" else (Color("#B52D3D") if outfit_id == "outfit_web_sentinel" else CharacterVisuals.suit_color_for(outfit_id, color))
	if is_instance_valid(_visual):
		_visual.material_override = _remote_material(_base_color)
		_rebuild_remote_detail()

func _build_remote_swimwear() -> void:
	_swimwear_root = Node3D.new()
	_swimwear_root.name = "BeachSwimwear"
	_swimwear_root.visible = false
	_visual.add_child(_swimwear_root)
	var shirt := MeshInstance3D.new()
	var shirt_mesh := CapsuleMesh.new()
	shirt_mesh.radius = 0.31
	shirt_mesh.height = 0.54
	shirt.mesh = shirt_mesh
	shirt.position = Vector3(0.0, 0.02, 0.0)
	shirt.material_override = _remote_material(Color("#16A6C8"))
	_swimwear_root.add_child(shirt)

	var shorts := MeshInstance3D.new()
	var shorts_mesh := SphereMesh.new()
	shorts_mesh.radius = 0.30
	shorts_mesh.height = 0.60
	shorts.mesh = shorts_mesh
	shorts.scale = Vector3(1.12, 0.62, 0.82)
	shorts.position = Vector3(0.0, -0.17, 0.0)
	shorts.material_override = _remote_material(Color("#FFB347"))
	_swimwear_root.add_child(shorts)

	var glasses := Node3D.new()
	glasses.position = Vector3(0.0, 0.76, -0.33)
	_swimwear_root.add_child(glasses)
	for side in [-1.0, 1.0]:
		var lens := MeshInstance3D.new()
		var lens_mesh := SphereMesh.new()
		lens_mesh.radius = 0.09
		lens_mesh.height = 0.18
		lens.mesh = lens_mesh
		lens.scale = Vector3(1.2, 0.72, 0.34)
		lens.position.x = side * 0.13
		lens.material_override = _remote_material(Color("#172638"))
		glasses.add_child(lens)

func _rebuild_remote_detail() -> void:
	if is_instance_valid(_accessory_root):
		_visual.remove_child(_accessory_root)
		_accessory_root.queue_free()
	if is_instance_valid(_visual):
		_accessory_root = CharacterVisuals.add_accessory(_visual, _accessory_id, _avatar_color)
	if is_instance_valid(_character_detail_root):
		_character_detail_root.queue_free()
	if is_instance_valid(_hero_root):
		_hero_root.queue_free()
		_hero_root = null
	if is_instance_valid(_visual):
		CharacterVisuals.apply_body_shape(_visual, _outfit_id)
		_character_detail_root = CharacterVisuals.build(_visual, _outfit_id, _base_color)
		_hero_root = CharacterVisuals.add_hero_details(_visual, _outfit_id)
		CharacterVisuals.set_clothing_visible(_character_detail_root, not (is_instance_valid(_swimwear_root) and _swimwear_root.visible))
	if is_instance_valid(_motion_rig):
		_motion_rig.queue_free()
	if is_instance_valid(_visual):
		_motion_rig = CharacterMotionRig.build(_visual, _base_color, _outfit_id)
		_weapon_mount = null
		_attach_weapon()


## The pitch arrives with each snapshot; the weapon eases toward it so a 20 Hz update never snaps.
func set_aim_pitch(pitch: float) -> void:
	if is_finite(pitch):
		_aim_pitch_target = clampf(pitch, deg_to_rad(-82.0), deg_to_rad(82.0))


func sync_weapon(weapon_id: String, grounded: bool) -> void:
	_grounded = grounded
	if weapon_id == _weapon_id or not PLAYER.ARCADE_WEAPON_LOCAL.has(weapon_id):
		return
	_weapon_id = weapon_id
	_weapon_kick = 0.0
	_attach_weapon()


func _attach_weapon() -> void:
	if is_instance_valid(_weapon_mount):
		_weapon_mount.free()
	if _weapon_id.is_empty() or not is_instance_valid(_motion_rig):
		return
	var hand := _motion_rig.get_node("ArmPivot_R/ElbowPivot") as Node3D
	var data: Dictionary = PLAYER.ARCADE_WEAPON_LOCAL[_weapon_id]
	_weapon_mount = WEAPON_VISUALS.build_weapon(_weapon_id, data.color)
	_weapon_info = WEAPON_HOLD.measure(_weapon_mount, _weapon_id)
	_weapon_mount.scale = Vector3.ONE * WEAPON_HOLD.WEAPON_SCALE
	_weapon_mount.position = WEAPON_HOLD.GLOVE_LOCAL - (_weapon_info.grip as Vector3) * WEAPON_HOLD.WEAPON_SCALE
	hand.add_child(_weapon_mount)


func set_big_head(enabled: bool) -> void:
	if is_instance_valid(_character_detail_root):
		var head := _character_detail_root.get_node_or_null("HeadPivot") as Node3D
		if head:
			head.scale = Vector3.ONE * (1.65 if enabled else 1.0)


func set_result_pose(outcome: String) -> void:
	_result_pose = outcome if outcome in ["win", "loss"] else ""


func play_weapon_fire(weapon_id: String) -> void:
	if not _dead and weapon_id == _weapon_id:
		_weapon_kick = 1.0

func _remote_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	return material

func apply_network_state(position_value: Vector3, yaw_value: float, sliding: bool = false, health: float = 100.0, dead: bool = false, team_id: String = "", emote_id: String = "", swimming: bool = false) -> void:
	target_position = position_value
	target_yaw = yaw_value
	_snapshots.push(Time.get_ticks_msec(), position_value, yaw_value)
	if is_instance_valid(_swimwear_root):
		_swimwear_root.visible = swimming
	CharacterVisuals.set_clothing_visible(_character_detail_root, not swimming)
	if emote_id != _emote_id:
		_emote_id = emote_id if emote_id in ["griddy", "goofy", "robot", "wave"] else ""
		_emote_clock = 0.0
	if is_instance_valid(_name_tag):
		_name_tag.text = "%s  •  K.O." % display_name if dead else "%s  •  HP %d" % [display_name, int(ceil(health))]
	if is_instance_valid(_visual):
		var material := _visual.material_override as StandardMaterial3D
		if is_instance_valid(material):
			var team_color := Color("#F05A66") if team_id == "red" else (Color("#4C91FF") if team_id == "blue" else _base_color)
			material.albedo_color = team_color.darkened(0.65) if dead else team_color
		if dead != _dead:
			_dead = dead
			_fall_elapsed = 0.0
			_weapon_kick = 0.0
			_visual.visible = true
			if not dead:
				_visual.rotation = Vector3.ZERO
	if _sliding != sliding:
		_sliding = sliding
		_visual.scale.y = 0.56 if sliding else 1.0
		_visual.position.y = 0.5 if sliding else 0.9
		_name_tag.position.y = 1.35 if sliding else 2.15
	if not is_inside_tree():
		global_position = target_position
		rotation.y = target_yaw

func _process(delta: float) -> void:
	if _dead:
		_fall_elapsed = minf(FALL_DURATION, _fall_elapsed + delta)
		var progress := _fall_elapsed / FALL_DURATION
		_visual.rotation = Vector3(-1.45 * smoothstep(0.0, 1.0, progress), 0.0, 0.0)
		_visual.position.y = lerpf(0.9, 0.29, progress)
		_visual.visible = _fall_elapsed < FALL_DURATION
	elif _emote_id != "":
		_emote_clock += delta
		var rate := 1.55
		var bounce := 0.12
		var roll := 0.24
		var pitch := 0.12
		var turn := 0.0
		match _emote_id:
			"goofy":
				rate = 1.30
				bounce = 0.08
				roll = 0.34
				pitch = 0.18
			"robot":
				rate = 1.8
				bounce = 0.025
				roll = 0.07
				pitch = 0.035
				turn = 0.28
			"wave":
				rate = 1.05
				bounce = 0.035
				roll = 0.06
				pitch = 0.05
		var phase := _emote_clock * TAU * rate
		_visual.position.y = 0.9 + absf(sin(phase)) * bounce
		_visual.rotation = Vector3(sin(phase * 0.5) * pitch, sin(phase * 0.5) * turn, sin(phase) * roll)
	elif _sliding:
		_visual.position.y = move_toward(_visual.position.y, 0.5, delta * 8.0)
		_visual.rotation.x = move_toward(_visual.rotation.x, 0.0, delta * 2.0)
		_visual.rotation.y = move_toward(_visual.rotation.y, 0.0, delta * 2.0)
		_visual.rotation.z = move_toward(_visual.rotation.z, 0.0, delta * 2.0)
	else:
		_visual.position.y = move_toward(_visual.position.y, 0.9, delta * 4.0)
		_visual.rotation.x = move_toward(_visual.rotation.x, 0.0, delta * 2.0)
		_visual.rotation.y = move_toward(_visual.rotation.y, 0.0, delta * 2.0)
		_visual.rotation.z = move_toward(_visual.rotation.z, 0.0, delta * 2.0)
	# Snapshot interpolation: draw the player INTERP_DELAY_MS in the past, between two real snapshots.
	var rendered: Dictionary = _snapshots.sample(Time.get_ticks_msec() - NET_SYNC.INTERP_DELAY_MS)
	if bool(rendered.get("valid", false)) and _snapshots.size() >= 2:
		global_position = rendered.position
		rotation.y = float(rendered.yaw)
	else:
		global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 14.0))
	_motion_clock += delta
	var estimated_speed := 0.0
	if _has_previous_position:
		estimated_speed = global_position.distance_to(_previous_position) / maxf(delta, 0.0001)
	else:
		_has_previous_position = true
	_previous_position = global_position
	if not _dead and not _sliding and _emote_id == "":
		_visual.position.y = 0.9 + (absf(sin(_motion_clock * 10.0)) * 0.035 if estimated_speed > 0.5 else sin(_motion_clock * 1.8) * 0.012)
	var pose := _emote_id if _result_pose.is_empty() else ("wave" if _result_pose == "win" else "defeat")
	aim_pitch = lerpf(aim_pitch, _aim_pitch_target, 1.0 - exp(-14.0 * delta))
	var armed := is_instance_valid(_weapon_mount) and not _dead and pose.is_empty()
	var hold: Dictionary = {}
	if armed:
		hold = WEAPON_HOLD.hold_targets(_weapon_info, aim_pitch)
	CharacterMotionRig.animate(_motion_rig, _motion_clock, estimated_speed, _grounded or not _result_pose.is_empty(), _sliding and _result_pose.is_empty(), pose, delta, hold)
	_weapon_kick = move_toward(_weapon_kick, 0.0, delta * 7.0)
	if is_instance_valid(_weapon_mount):
		_weapon_mount.visible = armed
		WEAPON_HOLD.place_mount(_weapon_mount, _weapon_mount.get_parent() as Node3D, _motion_rig, _weapon_info, aim_pitch, _weapon_kick)
