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

	host.free()
	if failures.is_empty():
		print("PASS: rounded character meshes, articulated pivots, alternating run cycle, four distinct emotes, slide pose and remote animation initialization")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append(label + ": expected true")


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append(label + ": expected false")


func _assert_close(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.3f ± %.3f, got %.3f" % [label, expected, tolerance, actual])
