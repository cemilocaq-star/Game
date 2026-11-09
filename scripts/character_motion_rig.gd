extends RefCounted
## Procedural low-cost limb rig shared by local and replicated characters.

static func build(parent: Node3D, color: Color) -> Node3D:
	var rig := Node3D.new()
	rig.name = "ProceduralMotionRig"
	parent.add_child(rig)
	var cloth := _material(color.darkened(0.08), 0.08, 0.72)
	var armor := _material(color.darkened(0.42), 0.52, 0.38)
	var glove := _material(Color("#172638"), 0.18, 0.78)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmPivot_L" if side < 0.0 else "ArmPivot_R"
		arm.position = Vector3(side * 0.285, 0.30, 0.0)
		rig.add_child(arm)
		_add_capsule(arm, "UpperArm", 0.095, 0.43, Vector3(0, -0.205, 0), cloth)
		_add_sphere(arm, "ShoulderJoint", 0.115, 0.16, Vector3.ZERO, armor)
		_add_capsule(arm, "Forearm", 0.078, 0.31, Vector3(0, -0.48, -0.005), armor)
		_add_sphere(arm, "Glove", 0.085, 0.12, Vector3(0, -0.68, -0.015), glove)

		var leg := Node3D.new()
		leg.name = "LegPivot_L" if side < 0.0 else "LegPivot_R"
		leg.position = Vector3(side * 0.15, -0.25, 0.0)
		rig.add_child(leg)
		_add_capsule(leg, "Thigh", 0.105, 0.48, Vector3(0, -0.22, 0), cloth)
		_add_sphere(leg, "Knee", 0.112, 0.13, Vector3(0, -0.43, -0.015), armor)
		_add_capsule(leg, "Shin", 0.085, 0.39, Vector3(0, -0.63, 0.005), cloth)
		_add_box(leg, "Boot", Vector3(0.19, 0.13, 0.30), Vector3(0, -0.87, -0.055), glove)
	return rig


static func animate(rig: Node3D, clock: float, speed: float, grounded: bool, sliding: bool, emote: String, delta: float) -> void:
	if not is_instance_valid(rig):
		return
	var intensity := clampf(speed / 6.0, 0.0, 1.5)
	var frequency := 8.5 + intensity * 3.5
	var phase := clock * frequency
	var swing := sin(phase) * 0.62 * intensity if grounded and not sliding else 0.0
	if emote != "":
		swing = sin(clock * TAU * (2.0 if emote == "griddy" else 1.35)) * 0.42
	for side in [-1.0, 1.0]:
		var arm_name := "ArmPivot_L" if side < 0.0 else "ArmPivot_R"
		var leg_name := "LegPivot_L" if side < 0.0 else "LegPivot_R"
		var arm := rig.get_node_or_null(arm_name) as Node3D
		var leg := rig.get_node_or_null(leg_name) as Node3D
		if is_instance_valid(arm):
			var arm_target: float = -swing * side
			if sliding:
				arm_target = -0.72
			arm.rotation.x = move_toward(arm.rotation.x, arm_target, delta * 9.0)
		if is_instance_valid(leg):
			var leg_target: float = swing * side
			if sliding:
				leg_target = -0.55
			leg.rotation.x = move_toward(leg.rotation.x, leg_target, delta * 10.0)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)


static func _add_sphere(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)


static func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
