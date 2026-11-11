extends SceneTree
## Regression checks for rounded character details, run-cycle pivots and emote poses.

const CHARACTER_VISUALS := preload("res://scripts/character_visuals.gd")
const CHARACTER_MOTION_RIG := preload("res://scripts/character_motion_rig.gd")
const REMOTE_PLAYER := preload("res://scripts/oxenwar_remote_player.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var host := Node3D.new()
	root.add_child(host)

	var details := CHARACTER_VISUALS.build(host, "outfit_default", Color("#27D7E7"))
	_assert_true("character detail root created", is_instance_valid(details))
	_assert_true("character has visual detail meshes", details.get_child_count() >= 10)
	for child in details.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			_assert_true("detail mesh exists: " + mesh_instance.name, mesh_instance.mesh != null)
			_assert_false("detail is not a square box: " + mesh_instance.name, mesh_instance.mesh is BoxMesh)

	var rig := CHARACTER_MOTION_RIG.build(host, Color("#27D7E7"))
	for node_path in [
		"ArmPivot_L", "ArmPivot_R",
		"ArmPivot_L/ElbowPivot", "ArmPivot_R/ElbowPivot",
		"LegPivot_L", "LegPivot_R",
		"LegPivot_L/KneePivot", "LegPivot_R/KneePivot"
	]:
		_assert_true("rig pivot exists: " + node_path, rig.get_node_or_null(node_path) is Node3D)

	# The run cycle must alternate left/right arms and legs.
	CHARACTER_MOTION_RIG.animate(rig, 0.37, 6.0, true, false, "", 1.0)
	var arm_left := rig.get_node("ArmPivot_L") as Node3D
	var arm_right := rig.get_node("ArmPivot_R") as Node3D
	var leg_left := rig.get_node("LegPivot_L") as Node3D
	var leg_right := rig.get_node("LegPivot_R") as Node3D
	_assert_true("run cycle alternates arms", arm_left.rotation.x * arm_right.rotation.x < 0.0)
	_assert_true("run cycle alternates legs", leg_left.rotation.x * leg_right.rotation.x < 0.0)

	# Four emotes must produce distinct right-arm poses.
	var poses: Dictionary = {}
	for emote in ["griddy", "goofy", "robot", "wave"]:
		CHARACTER_MOTION_RIG.animate(rig, 0.37, 0.0, true, false, emote, 1.0)
		poses[emote] = (rig.get_node("ArmPivot_R") as Node3D).rotation.x
	var emote_ids := ["griddy", "goofy", "robot", "wave"]
	for first_index in range(emote_ids.size()):
		for second_index in range(first_index + 1, emote_ids.size()):
			var first_id: String = emote_ids[first_index]
			var second_id: String = emote_ids[second_index]
			_assert_true(
				"emotes have distinct arm poses: %s / %s" % [first_id, second_id],
				absf(float(poses[first_id]) - float(poses[second_id])) > 0.05
			)

	# Sliding has a stable pose even when an emote state is present.
	CHARACTER_MOTION_RIG.animate(rig, 1.0, 6.0, true, true, "wave", 1.0)
	_assert_close(
		"slide pose arm target",
		(rig.get_node("ArmPivot_R") as Node3D).rotation.x,
		-0.82,
		0.02
	)

	# Remote players use the same rig and emote timing; the first update must
	# not be interpreted as a full-speed sprint from world origin.
	var remote := Node3D.new()
	remote.set_script(REMOTE_PLAYER)
	host.add_child(remote)
	remote.call("apply_network_state", Vector3(4.0, 0.0, 0.0), 0.5, false, 100.0, false, "", "wave", false)
	remote.call("_process", 0.016)
	var remote_rig := remote.get("_motion_rig") as Node3D
	_assert_true("remote motion rig created", is_instance_valid(remote_rig))
	var remote_arm := remote_rig.get_node("ArmPivot_R") as Node3D if is_instance_valid(remote_rig) else null
	_assert_true("remote wave pose begins", is_instance_valid(remote_arm) and remote_arm.rotation.x < -0.05)

	# The default character must not pick up any signature-troll footwear or gear.
	_assert_false("default outfit has no costume profile", CHARACTER_VISUALS.has_character_profile("outfit_default"))
	_assert_true("default suit color falls back to the player's color", CHARACTER_VISUALS.suit_color_for("outfit_default", Color("#27D7E7")).is_equal_approx(Color("#27D7E7")))
	_assert_true("default rig keeps plain boots", rig.get_node_or_null("LegPivot_L/KneePivot/FlipFlopSole") == null and rig.get_node_or_null("LegPivot_L/KneePivot/Toe_0") == null)

	_run_signature_troll_tests()

	host.free()
	if failures.is_empty():
		print("PASS: rounded character meshes, articulated pivots, alternating run cycle, four distinct emotes, slide pose, remote animation initialization and three signature troll costumes")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


## Golden Pilot (outfit_runner), Ghost-Ops (outfit_ghost_ops) and Neon Cyan Riot
## (outfit_neon): each must have its own signature parts, skin color and footwear
## while keeping every pivot the run cycle and emotes animate.
func _run_signature_troll_tests() -> void:
	var signature := {
		"outfit_runner": ["HeadPivot/PilotCap", "HeadPivot/GoggleLens_L", "HeadPivot/GoggleLens_R", "PilotScarf", "PilotShorts", "HeadPivot/TrollTusk_L", "HeadPivot/TrollTusk_R"],
		"outfit_ghost_ops": ["HeadPivot/GhostBalaclava", "HeadPivot/SkullJawPatch", "HeadPivot/SkullTooth_0", "HeadPivot/SkullTooth_5", "VestSkullPatch", "ShoulderRadio", "CargoShorts", "HeadPivot/TrollTusk_L"],
		"outfit_neon": ["HeadPivot/RiotHelmet", "HeadPivot/RiotVisor", "RiotChestPlate", "RiotShield", "RiotShoulderArmor_L", "RiotShoulderArmor_R", "HeadPivot/TrollTusk_R"],
	}
	var skins: Array[Color] = []
	for outfit_key in signature.keys():
		var outfit: String = outfit_key
		_assert_true("outfit has a costume profile: " + outfit, CHARACTER_VISUALS.has_character_profile(outfit))
		var suit: Color = CHARACTER_VISUALS.suit_color_for(outfit, Color("#27D7E7"))
		_assert_false("costume suit color replaces the player's color: " + outfit, suit.is_equal_approx(Color("#27D7E7")))

		var troll_host := Node3D.new()
		root.add_child(troll_host)
		var details := CHARACTER_VISUALS.build(troll_host, outfit, Color("#27D7E7"))
		for node_path in signature[outfit]:
			_assert_true("%s has signature part %s" % [outfit, node_path], details.get_node_or_null(node_path) is MeshInstance3D)
		_assert_false("%s uses only rounded meshes" % outfit, _contains_box_mesh(details))

		var head_mesh := details.get_node_or_null("HeadPivot/TrollHead") as MeshInstance3D
		var head_material := head_mesh.material_override as StandardMaterial3D if head_mesh != null else null
		_assert_true("%s head has a skin material" % outfit, head_material != null)
		if head_material != null:
			var expected_skin: Color = CHARACTER_VISUALS.profile_for(outfit)["skin"]
			_assert_true("%s skin matches its profile" % outfit, head_material.albedo_color.is_equal_approx(expected_skin))
			skins.append(head_material.albedo_color)

		# Ghost-Ops hides the cartoon smile behind a skull mask; the others keep it.
		if outfit == "outfit_ghost_ops":
			_assert_true("ghost-ops replaces the smile with a skull mask", details.get_node_or_null("HeadPivot/Smile") == null)
		else:
			_assert_true("%s keeps the friendly smile" % outfit, details.get_node_or_null("HeadPivot/Smile") != null)

		var troll_rig := CHARACTER_MOTION_RIG.build(troll_host, suit, outfit)
		for pivot_path in [
			"ArmPivot_L", "ArmPivot_R", "ArmPivot_L/ElbowPivot", "ArmPivot_R/ElbowPivot",
			"LegPivot_L", "LegPivot_R", "LegPivot_L/KneePivot", "LegPivot_R/KneePivot"
		]:
			_assert_true("%s rig pivot exists: %s" % [outfit, pivot_path], troll_rig.get_node_or_null(pivot_path) is Node3D)
		CHARACTER_MOTION_RIG.animate(troll_rig, 0.37, 6.0, true, false, "", 1.0)
		var troll_arm_left := troll_rig.get_node("ArmPivot_L") as Node3D
		var troll_arm_right := troll_rig.get_node("ArmPivot_R") as Node3D
		_assert_true("%s run cycle alternates arms" % outfit, troll_arm_left.rotation.x * troll_arm_right.rotation.x < 0.0)

		match outfit:
			"outfit_runner":
				_assert_true("pilot has bare feet with toes", troll_rig.get_node_or_null("LegPivot_L/KneePivot/Toe_0") != null and troll_rig.get_node_or_null("LegPivot_R/KneePivot/Toe_2") != null)
				_assert_true("pilot has no flip-flops", troll_rig.get_node_or_null("LegPivot_L/KneePivot/FlipFlopSole") == null)
			"outfit_ghost_ops":
				var left_sole := troll_rig.get_node_or_null("LegPivot_L/KneePivot/FlipFlopSole") as MeshInstance3D
				var right_sole := troll_rig.get_node_or_null("LegPivot_R/KneePivot/FlipFlopSole") as MeshInstance3D
				_assert_true("ghost-ops wears flip-flops on both feet", left_sole != null and right_sole != null)
				if left_sole != null and right_sole != null:
					var left_color := (left_sole.material_override as StandardMaterial3D).albedo_color
					var right_color := (right_sole.material_override as StandardMaterial3D).albedo_color
					_assert_false("ghost-ops flip-flops are mismatched colors", left_color.is_equal_approx(right_color))
			"outfit_neon":
				_assert_true("riot troll has knee pads", troll_rig.get_node_or_null("LegPivot_L/KneePivot/RiotKneePad") != null and troll_rig.get_node_or_null("LegPivot_R/KneePivot/RiotKneePad") != null)
				_assert_true("riot troll keeps heavy boots", troll_rig.get_node_or_null("LegPivot_L/KneePivot/Toe_0") == null)
		troll_host.free()

	_assert_true("three signature skins were checked", skins.size() == 3)
	for first_index in range(skins.size()):
		for second_index in range(first_index + 1, skins.size()):
			_assert_false("signature trolls have distinct skin colors (%d/%d)" % [first_index, second_index], skins[first_index].is_equal_approx(skins[second_index]))


func _contains_box_mesh(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		return true
	for child in node.get_children():
		if _contains_box_mesh(child):
			return true
	return false


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append(label + ": expected true")


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append(label + ": expected false")


func _assert_close(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.3f ± %.3f, got %.3f" % [label, expected, tolerance, actual])
