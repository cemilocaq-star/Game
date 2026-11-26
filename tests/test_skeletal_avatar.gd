extends SceneTree

const AVATAR := preload("res://scripts/skeletal_avatar.gd")
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const CATALOG := preload("res://scripts/emote_catalog.gd")
const PLAYER := preload("res://scripts/player.gd")

var failures: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Movement state -> clip choice.
	_check(AVATAR.movement_clip(0.0, Vector3.ZERO, true, false).clip == "Idle", "standing still plays Idle")
	_check(AVATAR.movement_clip(1.5, Vector3(0, 0, -1.5), true, false).clip == "Walking_A", "slow forward walk")
	_check(AVATAR.movement_clip(6.0, Vector3(0, 0, -6.0), true, false).clip == "Running_A", "fast forward run")
	_check(AVATAR.movement_clip(4.0, Vector3(4.0, 0, 0), true, false).clip == "Running_Strafe_Right", "strafe right")
	_check(AVATAR.movement_clip(4.0, Vector3(-4.0, 0, 0), true, false).clip == "Running_Strafe_Left", "strafe left")
	_check(AVATAR.movement_clip(2.0, Vector3(0, 0, 2.0), true, false).clip == "Walking_Backwards", "backwards")
	_check(AVATAR.movement_clip(5.0, Vector3(0, 0, -5.0), false, false).clip == "Jump_Idle", "airborne")
	# Every emote in the shared catalog has a skeletal clip.
	for id in CATALOG.IDS:
		_check(AVATAR.EMOTE_CLIPS.has(id), "emote %s has a skeletal clip" % id)
	var seen_models: Dictionary = {}
	for outfit in ["outfit_default", "outfit_runner", "outfit_neon", "outfit_ghost_ops", "outfit_iron_vanguard", "outfit_web_sentinel", "outfit_unknown_x"]:
		seen_models[AVATAR.model_for_outfit(outfit)] = true
	_check(seen_models.size() >= 4, "outfits map to several different characters, got %d" % seen_models.size())
	for model_name in AVATAR.MODELS:
		await _check_model(model_name)
	await _check_remote_player()
	if failures.is_empty():
		print("PASS: skeletal avatars load, animate, hold weapons and replace the procedural body on remote players")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _outfit_for(model_name: String) -> String:
	for outfit in AVATAR.OUTFIT_MODELS:
		if AVATAR.OUTFIT_MODELS[outfit] == model_name:
			return outfit
	return "outfit_default"

func _check_model(model_name: String) -> void:
	var avatar := AVATAR.new()
	root.add_child(avatar)
	var outfit := _outfit_for(model_name)
	_check(avatar.build(outfit, Color.RED), "%s builds" % model_name)
	if avatar.skeleton == null:
		avatar.queue_free()
		return
	_check(avatar.model_name == model_name, "%s chosen for %s, got %s" % [model_name, outfit, avatar.model_name])
	_check(avatar.lower != null and avatar.lower.has_animation("Running_A") and avatar.lower.has_animation("Death_A"), "%s has the shared clips" % model_name)
	_check(avatar.lower.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR, "%s Idle loops" % model_name)
	var upper_clip := avatar.upper.get_animation("2H_Ranged_Aiming")
	var full_clip := avatar.lower.get_animation("2H_Ranged_Aiming")
	_check(upper_clip.get_track_count() > 4 and upper_clip.get_track_count() < full_clip.get_track_count(), "%s upper-body layer is a strict subset (%d of %d tracks)" % [model_name, upper_clip.get_track_count(), full_clip.get_track_count()])
	var head := avatar.skeleton.find_bone("head")
	var head_height := avatar.skeleton.get_bone_global_rest(head).origin.y * avatar._animation_scale
	_check(head_height > 1.25 and head_height < 1.75, "%s neck height %.2f m is a human size" % [model_name, head_height])
	_check(avatar.skeleton.find_bone("handslot.r") >= 0, "%s has a right hand slot" % model_name)
	for weapon_id in PLAYER.ARCADE_WEAPON_LOCAL:
		avatar.set_weapon(weapon_id, Color.WHITE)
		_check(is_instance_valid(avatar.weapon_mount) and avatar.weapon_mount.get_parent() is BoneAttachment3D, "%s holds %s in its hand" % [model_name, weapon_id])
	# Drive every state for a few frames; nothing may error and the clip must change as expected.
	avatar.update_pose(0.016, 6.0, Vector3(0, 0, -6.0), true, false, "", true, false)
	_check(avatar.lower.current_animation == "Running_A" and avatar._upper_clip == "2H_Ranged_Aiming", "%s runs with the upper-body aim layer" % model_name)
	avatar.update_pose(0.016, 0.0, Vector3.ZERO, true, false, "", true, true)
	_check(avatar._upper_clip == "2H_Ranged_Reload", "%s reload layer" % model_name)
	avatar.update_pose(0.016, 0.0, Vector3.ZERO, true, false, "", false, false)
	_check(avatar._upper_clip == "" and not avatar.weapon_mount.visible, "%s unarmed hides the weapon and drops the layer" % model_name)
	for id in CATALOG.IDS:
		avatar.update_pose(0.1, 0.0, Vector3.ZERO, true, false, id, false, false)
		_check(avatar.lower.current_animation == AVATAR.EMOTE_CLIPS[id].clip or AVATAR.EMOTE_CLIPS[id].has("alt"), "%s plays emote %s" % [model_name, id])
	avatar.update_pose(0.1, 0.0, Vector3.ZERO, true, false, "spin", false, false)
	avatar.update_pose(0.3, 0.0, Vector3.ZERO, true, false, "spin", false, false)
	_check(absf(avatar._spin_root.rotation.y) > 0.01, "%s spin emote turns the body" % model_name)
	avatar.update_pose(0.1, 0.0, Vector3.ZERO, true, false, "", false, false)
	_check(avatar._spin_root.rotation == Vector3.ZERO, "%s pose resets after an emote" % model_name)
	avatar.set_dead(true)
	_check(avatar.lower.current_animation == "Death_A", "%s plays the death clip" % model_name)
	avatar.set_dead(false)
	_check(avatar.lower.current_animation == "Idle", "%s returns to Idle after respawn" % model_name)
	await process_frame
	avatar.queue_free()

func _check_remote_player() -> void:
	var remote := Node3D.new()
	remote.set_script(REMOTE)
	root.add_child(remote)
	await process_frame
	remote.set_player_identity("Tester", Color("#27D7E7"), "outfit_iron_vanguard", null)
	var avatar: Node3D = remote.get("_avatar")
	_check(is_instance_valid(avatar), "remote players get a skeletal avatar")
	if is_instance_valid(avatar):
		_check(avatar.model_name == "Knight", "remote player outfit picks its character, got %s" % avatar.model_name)
		var visual: MeshInstance3D = remote.get("_visual")
		_check(visual.layers == 0, "the procedural body is no longer rendered")
		remote.sync_weapon("ranger_rifle", true)
		_check(is_instance_valid(avatar.weapon_mount), "remote avatar holds the synced weapon")
		remote.apply_network_state(Vector3(2, 0, 0), 0.0, false, 100.0, false, "", "wave", false)
		for i in 4:
			await process_frame
		_check(avatar.lower.current_animation == "Spellcast_Raise", "networked emote drives the skeletal clip, got %s" % avatar.lower.current_animation)
		remote.apply_network_state(Vector3(2, 0, 0), 0.0, false, 0.0, true, "", "", false)
		await process_frame
		_check(avatar.lower.current_animation == "Death_A", "networked death plays the death clip")
	remote.queue_free()
