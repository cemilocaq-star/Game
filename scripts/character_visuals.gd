extends RefCounted
## Rounded, low-poly character surface detailing shared by local and remote avatars.
## The animated limbs are owned by character_motion_rig.gd to avoid duplicate geometry.

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

	var fabric := _material(primary, 0.10, 0.72)
	var armor := _material(secondary, 0.58, 0.34)
	var trim := _material(accent, 0.35, 0.38)
	var dark := _material(Color("#182431"), 0.24, 0.62)
	var visor := _material(Color("#071521"), 0.78, 0.18)
	var glow := _material(accent, 0.28, 0.26)
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 0.32

	# Smooth helmet and visor. Hero outfits keep the helmet supplied by player.gd.
	if outfit_id != "outfit_iron_vanguard" and outfit_id != "outfit_web_sentinel":
		_add_ellipsoid(root, "HelmetShell", 0.225, Vector3(1.0, 1.04, 0.92), Vector3(0, 0.68, 0.015), armor)
		_add_ellipsoid(root, "FaceVisor", 0.17, Vector3(1.12, 0.43, 0.28), Vector3(0, 0.655, -0.16), visor)
		_add_ellipsoid(root, "VisorGlint", 0.045, Vector3(1.35, 0.22, 0.22), Vector3(0, 0.70, -0.207), glow)

	_add_capsule(root, "NeckGuard", 0.125, 0.20, Vector3(0, 0.405, 0.0), armor)
	# A curved vest shell and chest plate sit slightly forward of the base capsule.
	_add_capsule(root, "VestShell", 0.245, 0.58, Vector3(0, 0.015, -0.105), fabric)
	_add_ellipsoid(root, "ChestPlate", 0.225, Vector3(1.12, 0.76, 0.30), Vector3(0, 0.105, -0.315), armor)
	_add_ellipsoid(root, "ChestEmblem", 0.047, Vector3(1.0, 1.0, 0.42), Vector3(0, 0.10, -0.388), glow)
	_add_ellipsoid(root, "LowerTorsoGuard", 0.15, Vector3(1.35, 0.42, 0.32), Vector3(0, -0.205, -0.255), dark)
	_add_capsule(root, "CollarTrim", 0.105, 0.20, Vector3(0, 0.34, -0.07), trim)

	# Rounded belt, pouches and back pack; no cube-shaped limbs or panels.
	_add_capsule(root, "UtilityBelt", 0.045, 0.43, Vector3(0, -0.265, -0.205), dark, Vector3(0, 0, deg_to_rad(90.0)))
	_add_ellipsoid(root, "BeltBuckle", 0.055, Vector3(1.0, 0.82, 0.40), Vector3(0, -0.265, -0.257), trim)
	_add_capsule(root, "LeftUtilityPouch", 0.060, 0.15, Vector3(-0.225, -0.245, -0.215), armor)
	_add_capsule(root, "RightUtilityPouch", 0.060, 0.15, Vector3(0.225, -0.245, -0.215), armor)
	_add_capsule(root, "Backpack", 0.145, 0.42, Vector3(0, 0.015, 0.325), dark)
	_add_ellipsoid(root, "BackpackTop", 0.09, Vector3(1.45, 0.42, 0.78), Vector3(0, 0.205, 0.365), trim)
	_add_ellipsoid(root, "LeftChestTab", 0.035, Vector3(0.65, 1.45, 0.38), Vector3(-0.185, 0.11, -0.36), trim)
	_add_ellipsoid(root, "RightChestTab", 0.035, Vector3(0.65, 1.45, 0.38), Vector3(0.185, 0.11, -0.36), trim)

	return root


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
