extends Node3D
## A real skinned character (KayKit Adventurers, CC0) with skeletal animation clips, used for every
## player model seen in third person. Lower body and full-body states (idle, walk, run, strafe, jump,
## death, emotes) come from one AnimationPlayer; while a weapon is held, a second AnimationPlayer plays
## an upper-body-only aiming / reload / shoot layer on top, so legs keep running while arms aim.
##
## The model faces +Z in its own file, so it is turned half a circle to face -Z like everything else here.
## Feet are at y = 0 and the figure is scaled to HEIGHT metres.

const ARCADE_WEAPON_VISUALS := preload("res://scripts/arcade_weapon_visuals.gd")
const WEAPON_HOLD := preload("res://scripts/weapon_hold.gd")

const MODEL_DIR := "res://assets/characters/kaykit/"
const ANIMATION_SOURCE := "Rogue" ## only this file carries the clips; the others share its skeleton
const MODELS := ["Rogue", "RogueHooded", "Knight", "Barbarian", "Mage"]
const OUTFIT_MODELS := {
	"outfit_default": "Rogue", "outfit_runner": "Barbarian", "outfit_neon": "Mage",
	"outfit_ghost_ops": "RogueHooded", "outfit_iron_vanguard": "Knight", "outfit_web_sentinel": "Rogue",
}
const HEIGHT := 1.78
const WEAPON_SCALE := 0.85
## Handslot bone frame -> weapon frame (weapon barrel is -Z; the bone's X axis points along the forearm line
## when aiming, measured from the 2H_Ranged_Aiming clip).
const WEAPON_ROTATION := Vector3(0.0, -PI / 2.0, 0.0)

const LOOPED := ["Idle", "Walking_A", "Walking_B", "Walking_Backwards", "Running_A", "Running_B", "Running_Strafe_Left",
	"Running_Strafe_Right", "Jump_Idle", "2H_Ranged_Aiming", "Cheer", "Spellcast_Raise", "Block", "Unarmed_Idle",
	"Interact", "Use_Item", "Throw", "Dodge_Left", "Dodge_Right", "Spellcasting", "Sit_Floor_Idle"]
const HELD_AT_END := ["Death_A", "Death_B"]
const UPPER_BONES := ["spine", "chest", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "head"]
## Emote id -> {clip, speed, spin, sway, snap}. Clips are KayKit's; spin/sway/snap are extra root motion.
const EMOTE_CLIPS := {
	"griddy": {"clip": "Dodge_Left", "alt": "Dodge_Right", "speed": 1.0, "bob": 0.05},
	"goofy": {"clip": "Throw", "speed": 1.3, "sway": 0.28},
	"robot": {"clip": "Block", "speed": 1.0, "snap": 0.5},
	"wave": {"clip": "Spellcast_Raise", "speed": 1.0},
	"salute": {"clip": "Interact", "speed": 0.8},
	"clap": {"clip": "Use_Item", "speed": 1.4},
	"flex": {"clip": "Unarmed_Idle", "speed": 1.0, "bob": 0.03},
	"spin": {"clip": "Cheer", "speed": 1.0, "spin": 2.4},
	"defeat": {"clip": "Sit_Floor_Idle", "speed": 1.0},
}
const BLEND := 0.18

var model_name := ""
var skeleton: Skeleton3D
var lower: AnimationPlayer
var upper: AnimationPlayer
var weapon_mount: Node3D
var _model_root: Node3D
var _spin_root: Node3D
var _weapon_attachment: BoneAttachment3D
var _weapon_id := ""
var _clip := ""
var _upper_clip := ""
var _emote := ""
var _emote_clock := 0.0
var _dead := false
var _ring: MeshInstance3D
var _animation_scale := 1.0


static func model_for_outfit(outfit_id: String) -> String:
	if OUTFIT_MODELS.has(outfit_id):
		return OUTFIT_MODELS[outfit_id]
	return MODELS[absi(outfit_id.hash()) % MODELS.size()]


## Builds the figure. Returns false when the model could not be loaded (callers keep their old visuals).
func build(outfit_id: String, team_color: Color = Color.WHITE) -> bool:
	model_name = model_for_outfit(outfit_id)
	var scene := load(MODEL_DIR + model_name + ".glb") as PackedScene
	if scene == null:
		return false
	_spin_root = Node3D.new()
	_spin_root.name = "SpinRoot"
	add_child(_spin_root)
	_model_root = scene.instantiate() as Node3D
	_model_root.name = "Model"
	_model_root.rotation.y = PI
	_spin_root.add_child(_model_root)
	skeleton = _first_skeleton(_model_root)
	if skeleton == null:
		return false
	_hide_props(_model_root)
	_fit_height()
	if not _setup_animation():
		return false
	_add_team_ring(team_color)
	play_base("Idle", 1.0, true)
	return true


func _first_skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


## Held items baked into the character file (swords, crossbows, shields) are hidden; weapons come from the game.
func _hide_props(root: Node) -> void:
	for attachment in root.find_children("*", "BoneAttachment3D", true, false):
		var bone := str((attachment as BoneAttachment3D).bone_name)
		if bone.begins_with("handslot") or bone.begins_with("hand"):
			(attachment as Node3D).visible = false


func _fit_height() -> void:
	var head := skeleton.find_bone("head")
	var rest_head := skeleton.get_bone_global_rest(head).origin.y if head >= 0 else 1.23
	var model_height := rest_head + 0.30 ## the head bone is at the neck; add the head
	_animation_scale = HEIGHT / maxf(model_height, 0.5)
	_model_root.scale = Vector3.ONE * _animation_scale


func _setup_animation() -> bool:
	# Clips come from the Rogue file; every other model has the same bones and borrows them.
	var source_player: AnimationPlayer
	if model_name == ANIMATION_SOURCE:
		source_player = _first_player(_model_root)
	else:
		var source_scene := load(MODEL_DIR + ANIMATION_SOURCE + ".glb") as PackedScene
		if source_scene == null:
			return false
		var source_root := source_scene.instantiate()
		source_player = _first_player(source_root)
		if source_player == null:
			source_root.free()
			return false
		# Keep the clip library alive after the helper scene is freed.
		var library := AnimationLibrary.new()
		for clip_name in source_player.get_animation_list():
			library.add_animation(clip_name, source_player.get_animation(clip_name).duplicate())
		source_root.free()
		var existing := _first_player(_model_root)
		lower = existing if existing != null else AnimationPlayer.new()
		if existing == null:
			lower.name = "AnimationPlayer"
			_model_root.add_child(lower)
		lower.root_node = _root_node_for(lower)
		for old_library in lower.get_animation_library_list():
			lower.remove_animation_library(old_library)
		lower.add_animation_library("", library)
		return _finish_players()
	if source_player == null:
		return false
	lower = source_player
	return _finish_players()


func _root_node_for(player: AnimationPlayer) -> NodePath:
	## Tracks are written relative to the model's root ("Rig/Skeleton3D:bone"). The player sits under the same root.
	return player.get_path_to(_model_root)


func _first_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


func _finish_players() -> bool:
	if not lower.has_animation("Idle"):
		return false
	for clip_name in LOOPED:
		if lower.has_animation(clip_name):
			lower.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	for clip_name in HELD_AT_END:
		if lower.has_animation(clip_name):
			lower.get_animation(clip_name).loop_mode = Animation.LOOP_NONE
	lower.playback_default_blend_time = BLEND
	# Upper-body layer: same clips with every non-upper-body track removed.
	upper = AnimationPlayer.new()
	upper.name = "UpperBodyPlayer"
	lower.get_parent().add_child(upper)
	upper.root_node = lower.root_node
	var upper_library := AnimationLibrary.new()
	for clip_name in ["2H_Ranged_Aiming", "2H_Ranged_Reload", "2H_Ranged_Shoot"]:
		if lower.has_animation(clip_name):
			var filtered := lower.get_animation(clip_name).duplicate() as Animation
			for index in range(filtered.get_track_count() - 1, -1, -1):
				var bone := str(filtered.track_get_path(index)).get_slice(":", 1)
				if not UPPER_BONES.has(bone):
					filtered.remove_track(index)
			filtered.loop_mode = Animation.LOOP_LINEAR if clip_name == "2H_Ranged_Aiming" else Animation.LOOP_NONE
			upper_library.add_animation(clip_name, filtered)
	upper.add_animation_library("", upper_library)
	upper.playback_default_blend_time = 0.12
	return true


func _add_team_ring(team_color: Color) -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "TeamRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.58
	_ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.emission_enabled = true
	material.emission = team_color
	material.emission_energy_multiplier = 0.8
	_ring.material_override = material
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func set_team_color(color: Color) -> void:
	if _ring != null and _ring.material_override is StandardMaterial3D:
		var material := _ring.material_override as StandardMaterial3D
		material.albedo_color = color
		material.emission = color


func play_base(clip_name: String, speed: float = 1.0, instant: bool = false) -> void:
	if lower == null or not lower.has_animation(clip_name):
		return
	if clip_name != _clip:
		_clip = clip_name
		lower.play(clip_name, 0.0 if instant else -1.0, speed)
	else:
		lower.speed_scale = speed


func _play_upper(clip_name: String) -> void:
	if upper == null:
		return
	if clip_name.is_empty():
		if not _upper_clip.is_empty():
			upper.stop()
			_upper_clip = ""
		return
	if clip_name != _upper_clip and upper.has_animation(clip_name):
		_upper_clip = clip_name
		upper.play(clip_name)


## Held weapon, attached to the right hand slot. Pass "" to put it away.
func set_weapon(weapon_id: String, color: Color) -> void:
	if weapon_id == _weapon_id and (weapon_id.is_empty() or is_instance_valid(weapon_mount)):
		return
	_weapon_id = weapon_id
	if is_instance_valid(weapon_mount):
		weapon_mount.free()
	weapon_mount = null
	if weapon_id.is_empty() or skeleton == null:
		return
	if _weapon_attachment == null:
		_weapon_attachment = BoneAttachment3D.new()
		_weapon_attachment.name = "RightHandSlot"
		_weapon_attachment.bone_name = "handslot.r"
		skeleton.add_child(_weapon_attachment)
	var body := ARCADE_WEAPON_VISUALS.build_weapon(weapon_id, color)
	var info: Dictionary = WEAPON_HOLD.measure(body, weapon_id)
	weapon_mount = Node3D.new()
	weapon_mount.name = "HeldWeapon"
	var local_scale := WEAPON_SCALE / maxf(_animation_scale, 0.001)
	body.scale = Vector3.ONE * local_scale
	body.position = -(info.grip as Vector3) * local_scale
	weapon_mount.add_child(body)
	weapon_mount.basis = Basis.from_euler(WEAPON_ROTATION)
	_weapon_attachment.add_child(weapon_mount)


func fire() -> void:
	if _upper_clip == "2H_Ranged_Aiming" and upper.has_animation("2H_Ranged_Shoot"):
		upper.play("2H_Ranged_Shoot")
		upper.queue("2H_Ranged_Aiming")


func set_dead(dead: bool) -> void:
	if dead == _dead:
		return
	_dead = dead
	if dead:
		_play_upper("")
		_emote = ""
		_clip = ""
		play_base("Death_A", 1.0)
	else:
		_clip = ""
		play_base("Idle", 1.0, true)


## Which clip a movement state needs: `local_velocity` is the ground velocity in the body's frame (x = right, z = back).
static func movement_clip(speed: float, local_velocity: Vector3, grounded: bool, sliding: bool) -> Dictionary:
	if not grounded:
		return {"clip": "Jump_Idle", "speed": 1.0}
	if sliding:
		return {"clip": "Running_B", "speed": 1.0}
	if speed < 0.35:
		return {"clip": "Idle", "speed": 1.0}
	var forward := -local_velocity.z
	var side := local_velocity.x
	var run_speed := clampf(speed / 5.5, 0.6, 1.5)
	if absf(side) > absf(forward) * 1.2 and speed > 1.0:
		return {"clip": "Running_Strafe_Right" if side > 0.0 else "Running_Strafe_Left", "speed": run_speed}
	if forward < -0.25 * speed:
		return {"clip": "Walking_Backwards", "speed": clampf(speed / 2.6, 0.7, 1.4)}
	if speed < 2.6:
		return {"clip": "Walking_A", "speed": clampf(speed / 1.9, 0.7, 1.4)}
	return {"clip": "Running_A", "speed": run_speed}


## Called every frame by the owner. `velocity_local` is world velocity rotated into the body frame.
func update_pose(delta: float, speed: float, velocity_local: Vector3, grounded: bool, sliding: bool, emote_id: String, armed: bool, reloading: bool) -> void:
	if skeleton == null:
		return
	if _dead:
		return
	var emote := emote_id if EMOTE_CLIPS.has(emote_id) else ""
	if not emote.is_empty():
		if emote != _emote:
			_emote = emote
			_emote_clock = 0.0
		_emote_clock += delta
		_play_upper("")
		var plan: Dictionary = EMOTE_CLIPS[emote]
		var clip_name: String = plan.clip
		if plan.has("alt") and int(_emote_clock / 0.45) % 2 == 1:
			clip_name = plan.alt
		play_base(clip_name, float(plan.get("speed", 1.0)))
		# Repeat one-shot clips for as long as the emote lasts.
		if lower.current_animation == "" or (not lower.is_playing() and lower.has_animation(clip_name)):
			lower.play(clip_name, 0.0, float(plan.get("speed", 1.0)))
		var phase := _emote_clock * TAU
		_spin_root.rotation.y = fmod(_emote_clock * float(plan.get("spin", 0.0)) * TAU * 0.5, TAU) if plan.has("spin") else _snap_yaw(float(plan.get("snap", 0.0)), phase)
		_spin_root.rotation.z = sin(phase * 0.6) * float(plan.get("sway", 0.0))
		_spin_root.position.y = absf(sin(phase * 1.2)) * float(plan.get("bob", 0.0))
		return
	if not _emote.is_empty():
		_emote = ""
		_clip = ""
	_spin_root.rotation = Vector3.ZERO
	_spin_root.position = Vector3.ZERO
	var plan_move := movement_clip(speed, velocity_local, grounded, sliding)
	play_base(str(plan_move.clip), float(plan_move.speed))
	if armed and is_instance_valid(weapon_mount):
		_play_upper("2H_Ranged_Reload" if reloading else "2H_Ranged_Aiming")
		if not reloading and _upper_clip == "2H_Ranged_Reload":
			_upper_clip = ""
	else:
		_play_upper("")
	if is_instance_valid(weapon_mount):
		weapon_mount.visible = armed


func _snap_yaw(amount: float, phase: float) -> float:
	## Stepped, robot-like turning: the yaw holds, then jumps.
	if amount <= 0.0:
		return 0.0
	return roundf(sin(phase * 0.5) * 2.0) / 2.0 * amount
