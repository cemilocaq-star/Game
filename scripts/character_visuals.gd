extends RefCounted
## Original cartoon troll character pass shared by local and remote avatars.
## Uses smooth rounded meshes, expressive faces and non-combat costume details.

static func build(parent: Node3D, outfit_id: String, base_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CharacterDetailPass"
	parent.add_child(root)

	var skin := _skin_for_outfit(outfit_id)
	var fabric_color := base_color
	var fabric := _material(fabric_color, 0.06, 0.78)
	var fabric_light := _material(fabric_color.lightened(0.24), 0.04, 0.82)
	var trim := _material(_trim_for_outfit(outfit_id, base_color), 0.18, 0.48)
	var skin_material := _material(skin, 0.0, 0.82)
	var skin_shadow := _material(skin.darkened(0.18), 0.0, 0.88)
	var white := _material(Color("#FFF9E9"), 0.0, 0.35)
	var pupil := _material(Color("#162231"), 0.04, 0.25)
	var mouth := _material(Color("#492A34"), 0.0, 0.8)
	var tongue := _material(Color("#F18A9D"), 0.0, 0.62)
	var blush := _material(Color("#E98A83"), 0.0, 0.82)
	var dark := _material(Color("#24303A"), 0.12, 0.68)

	# Rounded tunic, collar and a simple decorative belt.
	_add_capsule(root, "TrollTunic", 0.255, 0.64, Vector3(0.0, -0.015, -0.035), fabric)
	_add_ellipsoid(root, "TunicFrontPanel", 0.205, Vector3(1.12, 1.12, 0.30), Vector3(0.0, 0.035, -0.205), fabric_light)
	_add_capsule(root, "SoftCollar", 0.105, 0.18, Vector3(0.0, 0.335, -0.045), trim)
	_add_ellipsoid(root, "WaistBand", 0.22, Vector3(1.05, 0.27, 0.70), Vector3(0.0, -0.285, -0.035), dark)
	_add_ellipsoid(root, "RoundBuckle", 0.055, Vector3(1.0, 0.92, 0.42), Vector3(0.0, -0.285, -0.205), trim)
	for index in range(3):
		_add_ellipsoid(root, "TunicButton_%d" % index, 0.025, Vector3.ONE, Vector3(0.0, 0.12 - float(index) * 0.105, -0.274), trim)
	_add_ellipsoid(root, "FriendlyBadge", 0.06, Vector3(1.0, 1.0, 0.45), Vector3(-0.145, 0.115, -0.253), trim)
	_add_ellipsoid(root, "TunicHem", 0.22, Vector3(1.08, 0.18, 0.70), Vector3(0.0, -0.285, -0.045), fabric_light)

	# Oversized head pivot makes the avatar read as a playful troll from every angle.
	var head := Node3D.new()
	head.name = "HeadPivot"
	head.position = Vector3(0.0, 0.845, 0.0)
	root.add_child(head)
	_add_ellipsoid(head, "TrollHead", 0.30, Vector3(1.02, 1.05, 0.90), Vector3.ZERO, skin_material)
	_add_ellipsoid(head, "LowerJaw", 0.205, Vector3(1.04, 0.62, 0.80), Vector3(0.0, -0.145, -0.018), skin_shadow)

	# Soft, pointed ears with rounded tips.
	for side in [-1.0, 1.0]:
		var ear := _add_ellipsoid(head, "TrollEar_%s" % str(side), 0.13, Vector3(1.25, 0.62, 0.52), Vector3(side * 0.275, -0.015, -0.005), skin_material)
		ear.rotation.z = -side * 0.22
		var inner_ear := _add_ellipsoid(head, "InnerEar_%s" % str(side), 0.065, Vector3(1.0, 0.50, 0.30), Vector3(side * 0.292, -0.015, -0.081), blush)
		inner_ear.rotation.z = -side * 0.22

	# Large eyes, pupils and expressive brows.
	for side in [-1.0, 1.0]:
		_add_ellipsoid(head, "EyeWhite_%s" % str(side), 0.078, Vector3(1.0, 1.12, 0.66), Vector3(side * 0.102, 0.055, -0.247), white)
		_add_ellipsoid(head, "EyeIris_%s" % str(side), 0.045, Vector3(0.95, 1.0, 0.55), Vector3(side * 0.091, 0.048, -0.291), trim)
		_add_ellipsoid(head, "EyePupil_%s" % str(side), 0.024, Vector3(0.92, 1.0, 0.50), Vector3(side * 0.087, 0.044, -0.315), pupil)
		_add_ellipsoid(head, "EyeSparkle_%s" % str(side), 0.012, Vector3.ONE, Vector3(side * 0.078 - 0.012, 0.066, -0.329), white)
		var brow := _add_capsule(head, "ExpressiveBrow_%s" % str(side), 0.032, 0.13, Vector3(side * 0.105, 0.16, -0.245), skin_shadow)
		brow.rotation.z = side * -0.16
		_add_ellipsoid(head, "RosyCheek_%s" % str(side), 0.045, Vector3(1.1, 0.52, 0.35), Vector3(side * 0.19, -0.105, -0.229), blush)

	_add_ellipsoid(head, "TrollNose", 0.06, Vector3(1.12, 0.82, 0.76), Vector3(0.0, -0.045, -0.30), skin_material)
	_add_ellipsoid(head, "Smile", 0.092, Vector3(1.25, 0.48, 0.46), Vector3(0.0, -0.185, -0.267), mouth)
	_add_ellipsoid(head, "Tongue", 0.052, Vector3(1.0, 0.50, 0.38), Vector3(0.0, -0.215, -0.292), tongue)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(head, "SmileTooth_%s" % str(side), 0.031, Vector3(0.72, 0.86, 0.54), Vector3(side * 0.035, -0.157, -0.304), white)

	_add_hair(head, outfit_id, skin, trim)
	_add_headwear(head, outfit_id, trim, dark)
	return root


static func _skin_for_outfit(outfit_id: String) -> Color:
	match outfit_id:
		"outfit_runner":
			return Color("#D89A5B")
		"outfit_neon":
			return Color("#61D3D6")
		"outfit_iron_vanguard":
			return Color("#A8C95D")
		"outfit_web_sentinel":
			return Color("#A579C9")
		_:
			return Color("#75BD5A")


static func _trim_for_outfit(outfit_id: String, base_color: Color) -> Color:
	match outfit_id:
		"outfit_runner":
			return Color("#EAC36D")
		"outfit_neon":
			return Color("#5BFFFF")
		"outfit_iron_vanguard":
			return Color("#F1C85E")
		"outfit_web_sentinel":
			return Color("#D6A1F4")
		_:
			return base_color.lightened(0.38)


static func _add_hair(head: Node3D, outfit_id: String, skin: Color, trim: Material) -> void:
	var hair_color := Color("#3B4A2B") if outfit_id == "outfit_default" else (Color("#5B3928") if outfit_id == "outfit_runner" else skin.darkened(0.38))
	var hair_material := _material(hair_color, 0.02, 0.86)
	if outfit_id == "outfit_neon":
		hair_material = _material(Color("#75F2D7"), 0.08, 0.42)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var tuft := _add_ellipsoid(head, "HairTuft_%d" % index, 0.11, Vector3(0.74, 1.24, 0.74), Vector3(cos(angle) * 0.17, 0.23 + (0.04 if index % 2 == 0 else 0.0), sin(angle) * 0.13), hair_material)
		tuft.rotation.z = -0.18 if index % 2 == 0 else 0.18
	_add_ellipsoid(head, "HairCrown", 0.15, Vector3(1.18, 0.50, 1.05), Vector3(0.0, 0.235, 0.025), hair_material)


static func _add_headwear(head: Node3D, outfit_id: String, trim: Material, dark: Material) -> void:
	if outfit_id == "outfit_runner":
		var cap := _add_ellipsoid(head, "PilotCap", 0.18, Vector3(1.35, 0.44, 1.0), Vector3(0.0, 0.255, 0.035), dark)
		cap.rotation.x = -0.08
		_add_ellipsoid(head, "PilotCapPeak", 0.08, Vector3(1.55, 0.20, 0.75), Vector3(0.0, 0.19, -0.19), trim)
		for side in [-1.0, 1.0]:
			_add_ellipsoid(head, "GoggleRim_%s" % str(side), 0.073, Vector3(1.12, 0.92, 0.36), Vector3(side * 0.095, 0.105, -0.30), trim)
			_add_ellipsoid(head, "GoggleLens_%s" % str(side), 0.052, Vector3(1.02, 0.86, 0.30), Vector3(side * 0.095, 0.105, -0.329), dark)
		_add_capsule(head, "GoggleBridge", 0.018, 0.12, Vector3(0.0, 0.105, -0.32), trim, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	elif outfit_id == "outfit_neon":
		var band := _add_capsule(head, "NeonHeadband", 0.035, 0.46, Vector3(0.0, 0.205, 0.0), trim)
		band.rotation.z = deg_to_rad(90.0)
		_add_ellipsoid(head, "NeonAntennaBase", 0.055, Vector3.ONE, Vector3(0.0, 0.30, 0.07), trim)
		_add_capsule(head, "NeonAntenna", 0.018, 0.22, Vector3(0.0, 0.43, 0.07), trim)
	elif outfit_id == "outfit_iron_vanguard":
		for index in range(3):
			var crown_piece := _add_ellipsoid(head, "GoldenCrown_%d" % index, 0.07, Vector3(0.82, 1.65, 0.72), Vector3((float(index) - 1.0) * 0.12, 0.30, 0.0), trim)
			crown_piece.rotation.z = (float(index) - 1.0) * -0.15
	elif outfit_id == "outfit_web_sentinel":
		var band := _add_capsule(head, "VioletHeadband", 0.04, 0.46, Vector3(0.0, 0.18, -0.015), trim)
		band.rotation.z = deg_to_rad(90.0)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _add_ellipsoid(parent: Node3D, node_name: String, radius: float, scale_value: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	instance.mesh = mesh
	instance.scale = scale_value
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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
	return instance
