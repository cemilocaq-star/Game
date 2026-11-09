extends RefCounted
## Shared, low-cost procedural character detailing for local and remote players.
## All geometry is visual-only and remains inside the existing gameplay capsule.

static func build(parent: Node3D, outfit_id: String, base_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CharacterDetailPass"
	parent.add_child(root)

	var primary := base_color
	var secondary := base_color.darkened(0.48)
	var accent := base_color.lightened(0.30)
	if outfit_id == "outfit_iron_vanguard":
		primary = Color("#A92332")
		secondary = Color("#D9B45B")
		accent = Color("#66EFFF")
	elif outfit_id == "outfit_web_sentinel":
		primary = Color("#B52D3D")
		secondary = Color("#183D78")
		accent = Color("#E34A62")
	elif outfit_id == "outfit_neon":
		accent = base_color
	elif outfit_id == "outfit_runner":
		secondary = Color("#263B36")
		accent = Color("#D3F36B")

	var fabric := _material(primary, 0.12, 0.64)
	var armor := _material(secondary, 0.68, 0.30)
	var trim := _material(accent, 0.42, 0.34)
	var dark := _material(Color("#182431"), 0.38, 0.42)
	var visor := _material(Color("#0B1724"), 0.86, 0.16)
	var sole := _material(Color("#101820"), 0.12, 0.78)

	# A compact head/visor silhouette for the standard outfits. Hero outfits
	# already supply their own helmet geometry in player.gd.
	if outfit_id != "outfit_iron_vanguard" and outfit_id != "outfit_web_sentinel":
		_add_sphere(root, "HelmetShell", 0.235, 0.42, Vector3(0, 0.67, 0.015), armor)
		_add_box(root, "FaceVisor", Vector3(0.31, 0.13, 0.055), Vector3(0, 0.66, -0.205), visor)
		_add_box(root, "VisorGlint", Vector3(0.16, 0.018, 0.012), Vector3(0, 0.705, -0.237), trim)

	_add_cylinder(root, "NeckGuard", 0.145, 0.17, 0.105, Vector3(0, 0.42, 0), armor)
	_add_box(root, "TacticalVest", Vector3(0.50, 0.46, 0.13), Vector3(0, 0.015, -0.305), fabric)
	_add_box(root, "ChestPlate", Vector3(0.34, 0.27, 0.055), Vector3(0, 0.095, -0.382), armor)
	_add_box(root, "ChestEmblem", Vector3(0.105, 0.105, 0.025), Vector3(0, 0.095, -0.418), trim)
	_add_box(root, "LowerTorsoPanel", Vector3(0.34, 0.12, 0.055), Vector3(0, -0.145, -0.355), dark)

	# Sleeves, shoulder caps, forearm guards and gloves are separated so the
	# character reads as an equipped avatar instead of a single capsule.
	for side in [-1.0, 1.0]:
		_add_sphere(root, "ShoulderPad_%s" % side, 0.15, 0.22, Vector3(side * 0.325, 0.295, -0.005), armor)
		_add_capsule(root, "Sleeve_%s" % side, 0.105, 0.43, Vector3(side * 0.355, 0.025, 0.015), fabric)
		_add_box(root, "ForearmGuard_%s" % side, Vector3(0.17, 0.21, 0.15), Vector3(side * 0.365, -0.16, -0.075), armor)
		_add_box(root, "ForearmStripe_%s" % side, Vector3(0.12, 0.025, 0.018), Vector3(side * 0.365, -0.11, -0.158), trim)
		_add_sphere(root, "Glove_%s" % side, 0.095, 0.14, Vector3(side * 0.36, -0.325, -0.04), dark)
		_add_capsule(root, "Leg_%s" % side, 0.115, 0.47, Vector3(side * 0.15, -0.555, 0.015), fabric)
		_add_box(root, "KneePad_%s" % side, Vector3(0.18, 0.13, 0.065), Vector3(side * 0.15, -0.47, -0.125), armor)
		_add_box(root, "ShinPlate_%s" % side, Vector3(0.135, 0.20, 0.055), Vector3(side * 0.15, -0.665, -0.12), trim)
		_add_box(root, "Boot_%s" % side, Vector3(0.22, 0.16, 0.32), Vector3(side * 0.15, -0.82, -0.045), dark)
		_add_box(root, "BootSole_%s" % side, Vector3(0.225, 0.035, 0.33), Vector3(side * 0.15, -0.905, -0.045), sole)

	_add_box(root, "UtilityBelt", Vector3(0.52, 0.09, 0.17), Vector3(0, -0.245, -0.275), dark)
	_add_box(root, "BeltBuckle", Vector3(0.11, 0.10, 0.035), Vector3(0, -0.245, -0.37), trim)
	_add_box(root, "LeftUtilityPouch", Vector3(0.12, 0.14, 0.12), Vector3(-0.225, -0.24, -0.24), armor)
	_add_box(root, "RightUtilityPouch", Vector3(0.12, 0.14, 0.12), Vector3(0.225, -0.24, -0.24), armor)
	_add_box(root, "Backpack", Vector3(0.34, 0.40, 0.16), Vector3(0, 0.045, 0.345), dark)
	_add_box(root, "BackpackTopPanel", Vector3(0.23, 0.075, 0.025), Vector3(0, 0.185, 0.435), trim)
	_add_box(root, "BackpackSideLeft", Vector3(0.075, 0.22, 0.13), Vector3(-0.205, 0.035, 0.35), armor)
	_add_box(root, "BackpackSideRight", Vector3(0.075, 0.22, 0.13), Vector3(0.205, 0.035, 0.35), armor)

	# Small reflective/colored details help players remain readable at distance.
	_add_box(root, "LeftChestTab", Vector3(0.035, 0.12, 0.018), Vector3(-0.19, 0.10, -0.39), trim)
	_add_box(root, "RightChestTab", Vector3(0.035, 0.12, 0.018), Vector3(0.19, 0.10, -0.39), trim)
	return root


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_sphere(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_cylinder(parent: Node3D, node_name: String, radius: float, top_radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = top_radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance
