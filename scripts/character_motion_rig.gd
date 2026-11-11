extends RefCounted
## Shared rounded procedural character rig for local and replicated avatars.
## Movement and emotes are cosmetic only; they never change CharacterBody3D physics.

const CHARACTER_VISUALS := preload("res://scripts/character_visuals.gd")

## Builds the articulated limb rig. When `outfit_id` has a costume profile
## (see CharacterVisuals.profile_for) the limbs, hands and feet take the
## costume's colors; every other outfit keeps the original color-derived look.
static func build(parent: Node3D, color: Color, outfit_id: String = "") -> Node3D:
	var rig := Node3D.new()
	rig.name = "ProceduralMotionRig"
	parent.add_child(rig)

	var profile: Dictionary = CHARACTER_VISUALS.profile_for(outfit_id)
	var styled := not profile.is_empty()

	var cloth := _material(color.darkened(0.08), 0.08, 0.72)
	var armor := _material(color.darkened(0.42), 0.52, 0.38)
	var glove := _material(Color("#172638"), 0.18, 0.78)
	var boot_material := _material(Color("#101C2A"), 0.22, 0.68)
	var trim := _material(color.lightened(0.24), 0.34, 0.42)

	var sleeve_material: Material = cloth
	var forearm_material: Material = armor
	var thigh_material: Material = cloth
	var shin_material: Material = cloth
	var joint_material: Material = armor
	var skin_material: Material = null
	var foot_style := "boot"
	var knee_pads := false
	var shoulder_x := 0.285
	var shoulder_y := 0.30
	var hip_y := -0.25
	if styled:
		# Slim troll torso: arms sit outside it and the soles land at ground level.
		shoulder_x = CHARACTER_VISUALS.TROLL_SHOULDER_X
		shoulder_y = CHARACTER_VISUALS.TROLL_SHOULDER_Y
		hip_y = CHARACTER_VISUALS.TROLL_HIP_Y
		var sleeve_color: Color = profile["sleeve"]
		var hand_color: Color = profile["hand"]
		var thigh_color: Color = profile["thigh"]
		var shin_color: Color = profile["shin"]
		var joint_color: Color = profile["joint"]
		var trim_color: Color = profile["trim"]
		var skin_color: Color = profile["skin"]
		sleeve_material = _material(sleeve_color, 0.08, 0.74)
		forearm_material = sleeve_material
		thigh_material = _material(thigh_color, 0.06, 0.78)
		shin_material = _material(shin_color, 0.08, 0.72)
		joint_material = _material(joint_color, 0.30, 0.50)
		glove = _material(hand_color, 0.10, 0.74)
		trim = _material(trim_color, 0.34, 0.42)
		skin_material = _material(skin_color, 0.0, 0.82)
		foot_style = str(profile["foot"])
		knee_pads = bool(profile["knee_pad"])
		boot_material = _material(Color("#14171A"), 0.22, 0.62)

	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmPivot_L" if side < 0.0 else "ArmPivot_R"
		arm.position = Vector3(side * shoulder_x, shoulder_y, 0.0)
		rig.add_child(arm)
		_add_capsule(arm, "UpperArm", 0.087, 0.43, Vector3(0, -0.20, 0), sleeve_material)
		_add_ellipsoid(arm, "ShoulderJoint", 0.112, Vector3(1.0, 0.92, 0.88), Vector3.ZERO, joint_material)
		_add_ellipsoid(arm, "ShoulderTrim", 0.105, Vector3(1.06, 0.50, 0.82), Vector3(0, 0.015, -0.012), trim)

		var elbow := Node3D.new()
		elbow.name = "ElbowPivot"
		elbow.position = Vector3(0, -0.385, 0)
		arm.add_child(elbow)
		_add_ellipsoid(elbow, "ElbowJoint", 0.075, Vector3.ONE, Vector3.ZERO, joint_material)
		_add_capsule(elbow, "Forearm", 0.073, 0.35, Vector3(0, -0.17, -0.005), forearm_material)
		_add_ellipsoid(elbow, "ForearmCuff", 0.082, Vector3(1.0, 0.40, 0.95), Vector3(0, -0.07, -0.005), trim)
		_add_ellipsoid(elbow, "Glove", 0.082, Vector3(0.98, 1.12, 0.92), Vector3(0, -0.355, -0.02), glove)

		var leg := Node3D.new()
		leg.name = "LegPivot_L" if side < 0.0 else "LegPivot_R"
		leg.position = Vector3(side * 0.15, hip_y, 0.0)
		rig.add_child(leg)
		_add_ellipsoid(leg, "HipJoint", 0.105, Vector3(1.0, 0.78, 0.92), Vector3(0, 0.015, 0), joint_material)
		_add_capsule(leg, "Thigh", 0.102, 0.45, Vector3(0, -0.205, 0.0), thigh_material)

		var knee := Node3D.new()
		knee.name = "KneePivot"
		knee.position = Vector3(0, -0.385, 0.0)
		leg.add_child(knee)
		_add_ellipsoid(knee, "KneeJoint", 0.085, Vector3(1.0, 0.90, 0.94), Vector3(0, 0, -0.012), joint_material)
		_add_capsule(knee, "Shin", 0.080, 0.37, Vector3(0, -0.185, 0.01), shin_material)
		_add_ellipsoid(knee, "ShinGuard", 0.077, Vector3(1.05, 1.25, 0.38), Vector3(0, -0.19, -0.069), trim)
		if knee_pads:
			_add_ellipsoid(knee, "RiotKneePad", 0.12, Vector3(1.05, 1.0, 0.65), Vector3(0, 0.0, -0.075), joint_material)
		_add_foot(knee, foot_style, side < 0.0, boot_material, skin_material)

	return rig


## Foot styles: "boot" (default), "bare" (skin foot with toes) and "flipflop"
## (skin foot, mismatched pink/cyan sole and a strap, as on the Ghost-Ops troll).
static func _add_foot(knee: Node3D, style: String, is_left: bool, boot_material: Material, skin_material: Material) -> void:
	if style == "boot" or skin_material == null:
		_add_ellipsoid(knee, "Boot", 0.105, Vector3(1.05, 0.60, 1.55), Vector3(0, -0.395, -0.07), boot_material)
		return

	_add_ellipsoid(knee, "Boot", 0.105, Vector3(1.05, 0.60, 1.55), Vector3(0, -0.395, -0.07), skin_material)
	for index in range(3):
		_add_ellipsoid(knee, "Toe_%d" % index, 0.03, Vector3(1.0, 0.80, 1.20), Vector3((float(index) - 1.0) * 0.05, -0.405, -0.225), skin_material)
	if style == "flipflop":
		var sole_color := Color("#FF4FA3") if is_left else Color("#35F4FF")
		var sole_material := _material(sole_color, 0.0, 0.60)
		_add_ellipsoid(knee, "FlipFlopSole", 0.105, Vector3(1.10, 0.18, 1.70), Vector3(0, -0.445, -0.075), sole_material)
		_add_capsule(knee, "FlipFlopStrap", 0.014, 0.16, Vector3(0, -0.385, -0.125), sole_material, Vector3(0.0, 0.0, deg_to_rad(90.0)))


static func animate(rig: Node3D, clock: float, speed: float, grounded: bool, sliding: bool, emote: String, delta: float) -> void:
	if not is_instance_valid(rig):
		return

	var move_weight := clampf(speed / 6.6, 0.0, 1.0)
	var cadence := lerpf(7.2, 12.4, move_weight)
	var phase := clock * cadence
	var active_emote := emote in ["griddy", "goofy", "robot", "wave"]
	var emote_phase := clock * TAU * _emote_rate(emote)
	var bob_target := 0.0
	var body_lean := 0.0
	var body_sway := 0.0

	if sliding:
		body_lean = 0.28
		bob_target = -0.045
	elif active_emote:
		match emote:
			"griddy":
				body_lean = 0.035
				body_sway = sin(emote_phase * 0.5) * 0.12
				bob_target = absf(sin(emote_phase)) * 0.035
			"goofy":
				body_lean = 0.10 + sin(emote_phase) * 0.035
				body_sway = sin(emote_phase * 0.5) * 0.17
				bob_target = absf(sin(emote_phase)) * 0.055
			"robot":
				body_lean = 0.015
				body_sway = sin(emote_phase * 0.5) * 0.025
				bob_target = absf(sin(emote_phase * 0.5)) * 0.018
			"wave":
				body_lean = -0.025
				body_sway = sin(emote_phase * 0.5) * 0.035
				bob_target = absf(sin(emote_phase)) * 0.014
	elif not grounded:
		body_lean = -0.12
		bob_target = -0.035
	else:
		body_lean = -0.035 * move_weight
		body_sway = sin(phase * 0.5) * 0.025 * move_weight
		bob_target = absf(sin(phase)) * 0.024 * move_weight

	rig.position.y = move_toward(rig.position.y, bob_target, delta * 5.0)
	rig.rotation.x = move_toward(rig.rotation.x, body_lean, delta * 6.0)
	rig.rotation.y = move_toward(rig.rotation.y, body_sway, delta * 7.0)

	# The oversized troll head follows movement with a subtle, readable bounce.
	var details := rig.get_parent().get_node_or_null("CharacterDetailPass") as Node3D if is_instance_valid(rig.get_parent()) else null
	if is_instance_valid(details):
		var head := details.get_node_or_null("HeadPivot") as Node3D
		if is_instance_valid(head):
			var head_target := Vector3(sin(clock * 1.7) * 0.018, sin(phase * 0.22) * 0.055 * move_weight, sin(clock * 1.25) * 0.022)
			if sliding:
				head_target.x = -0.12
			elif not grounded:
				head_target.x = 0.10
			elif emote == "goofy":
				head_target.z = sin(emote_phase) * 0.12
			head.rotation.x = lerp_angle(head.rotation.x, head_target.x, clampf(delta * 6.0, 0.0, 1.0))
			head.rotation.y = lerp_angle(head.rotation.y, head_target.y, clampf(delta * 5.0, 0.0, 1.0))
			head.rotation.z = lerp_angle(head.rotation.z, head_target.z, clampf(delta * 6.0, 0.0, 1.0))

	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var is_right: bool = side > 0.0
		var arm_name := "ArmPivot_R" if is_right else "ArmPivot_L"
		var leg_name := "LegPivot_R" if is_right else "LegPivot_L"
		var arm := rig.get_node_or_null(arm_name) as Node3D
		var leg := rig.get_node_or_null(leg_name) as Node3D
		if not is_instance_valid(arm) or not is_instance_valid(leg):
			continue
		var elbow := arm.get_node_or_null("ElbowPivot") as Node3D
		var knee := leg.get_node_or_null("KneePivot") as Node3D
		if not is_instance_valid(elbow) or not is_instance_valid(knee):
			continue

		var phase_offset := PI if is_right else 0.0
		var stride := sin(phase + phase_offset)
		var arm_x := -stride * 0.72 * move_weight if grounded and not sliding and not active_emote else 0.0
		var arm_z: float = side * 0.035 * move_weight
		var elbow_x := 0.18 + maxf(0.0, stride) * 0.24 * move_weight
		var leg_x := stride * 0.62 * move_weight if grounded and not sliding and not active_emote else 0.0
		var knee_x := maxf(0.0, -stride) * 0.58 * move_weight
		var ankle_x := -knee_x * 0.28 - leg_x * 0.20
		var leg_z: float = side * 0.025 * move_weight

		if sliding:
			arm_x = -0.82
			arm_z = side * 0.10
			elbow_x = 0.42
			leg_x = -0.48
			knee_x = 0.18
			ankle_x = 0.14
			leg_z = side * 0.025
		elif not grounded:
			arm_x = -0.28
			arm_z = side * 0.24
			elbow_x = 0.35
			leg_x = 0.26 if is_right else -0.12
			knee_x = 0.30
			ankle_x = -0.10
		elif emote == "griddy":
			var dance := sin(emote_phase + phase_offset)
			arm_x = -0.52 + dance * 0.46
			arm_z = side * (0.12 + absf(dance) * 0.08)
			elbow_x = 0.56 + maxf(0.0, dance) * 0.28
			leg_x = dance * 0.38
			knee_x = maxf(0.0, -dance) * 0.44
			ankle_x = -dance * 0.16
			leg_z = side * (0.10 + absf(dance) * 0.07)
		elif emote == "goofy":
			var dance := sin(emote_phase * 0.82 + phase_offset)
			arm_x = -0.18 + dance * 0.70
			arm_z = side * (0.20 + dance * 0.10)
			elbow_x = 0.25 + absf(dance) * 0.70
			leg_x = dance * 0.48
			knee_x = maxf(0.0, -dance) * 0.66
			ankle_x = -dance * 0.20
			leg_z = side * 0.12
		elif emote == "robot":
			arm_x = -0.72 if is_right else -0.48
			arm_z = 0.22 if is_right else -0.22
			elbow_x = -0.92 if is_right else -0.58
			leg_x = sin(emote_phase + phase_offset) * 0.18
			knee_x = 0.12
			ankle_x = 0.0
			leg_z = side * 0.035
		elif emote == "wave":
			if is_right:
				arm_x = -2.05 + sin(emote_phase * 1.4) * 0.12
				arm_z = 0.08
				elbow_x = -0.55 + sin(emote_phase * 2.8) * 0.48
			else:
				arm_x = -0.12
				arm_z = -0.04
				elbow_x = 0.22
			leg_x = sin(emote_phase + phase_offset) * 0.055
			knee_x = 0.04
			ankle_x = 0.0
			leg_z = side * 0.015

		_move_rotation(arm, Vector3(arm_x, 0.0, arm_z), delta, 11.0)
		_move_rotation(elbow, Vector3(elbow_x, 0.0, 0.0), delta, 13.0)
		_move_rotation(leg, Vector3(leg_x, 0.0, leg_z), delta, 10.0)
		_move_rotation(knee, Vector3(knee_x, 0.0, 0.0), delta, 12.0)


static func _emote_rate(emote: String) -> float:
	match emote:
		"griddy":
			return 1.55
		"goofy":
			return 1.30
		"robot":
			return 1.8
		"wave":
			return 1.05
	return 1.0


static func _move_rotation(node: Node3D, target: Vector3, delta: float, rate: float) -> void:
	node.rotation.x = move_toward(node.rotation.x, target.x, delta * rate)
	node.rotation.y = move_toward(node.rotation.y, target.y, delta * rate)
	node.rotation.z = move_toward(node.rotation.z, target.z, delta * rate)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation_value
	instance.material_override = material
	parent.add_child(instance)


static func _add_ellipsoid(parent: Node3D, node_name: String, radius: float, scale_value: Vector3, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.scale = scale_value
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
