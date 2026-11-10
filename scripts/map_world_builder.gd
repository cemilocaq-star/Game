extends RefCounted
## Original, lightweight exploration maps built from rounded low-poly meshes.
## These spaces are designed around discovery, traversal and collectibles.

static func build(parent: Node3D, map_index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "GeneratedWorld_%d" % map_index
	parent.add_child(root)
	match map_index:
		4:
			_build_sunken_oasis(root)
		5:
			_build_jungle_temple(root)
		6:
			_build_redstone_canyon(root)
		1:
			_build_neon_rooftops(root)
		2:
			_build_sky_islands(root)
		3:
			_build_candy_garden(root)
		_:
			_build_lost_mall(root)
	return root


static func _build_sunken_oasis(root: Node3D) -> void:
	var sand := Color("#D8B77D")
	var sandstone := Color("#B98752")
	var pale_stone := Color("#E6C998")
	var dark_stone := Color("#72543D")
	var teal := Color("#39BFC1")
	var cloth_red := Color("#C86F4D")
	var cloth_blue := Color("#4F9AAB")

	_box(root, "OasisWestMarketHall", Vector3(7.0, 3.0, 0.75), Vector3(-11.0, 1.5, -8.2), sandstone)
	_box(root, "OasisEastMarketHall", Vector3(7.0, 3.0, 0.75), Vector3(11.0, 1.5, 8.2), sandstone)
	_box(root, "OasisNorthGallery", Vector3(12.0, 2.2, 0.65), Vector3(0.0, 1.1, -13.0), pale_stone)
	_box(root, "OasisSouthGallery", Vector3(12.0, 2.2, 0.65), Vector3(0.0, 1.1, 13.0), pale_stone)
	_arch(root, "OasisGrandArch", Vector3(0.0, 0.0, -10.5), 5.2, 3.5, 0.72, sandstone)

	_box(root, "OasisPondRim", Vector3(8.8, 0.32, 5.8), Vector3(0.0, 0.22, 0.2), pale_stone)
	_water(root, "OasisPond", Vector3(7.9, 0.07, 4.9), Vector3(0.0, 0.40, 0.2), Color("#39AEBB"))
	_cylinder(root, "OasisFountainBase", 0.82, 0.28, Vector3(0.0, 0.62, 0.2), pale_stone)
	_cylinder(root, "OasisFountainStem", 0.22, 0.90, Vector3(0.0, 1.18, 0.2), sandstone)
	_ellipsoid(root, "OasisFountainBowl", Vector3(0.72, 0.20, 0.72), Vector3(0.0, 1.66, 0.2), teal)

	_stairs(root, "OasisWestSteps", Vector3(-7.3, 0.0, -5.2), 5, 0.75, 0.48, Vector3(1.15, 0.0, 1.1), sandstone)
	_stairs(root, "OasisEastSteps", Vector3(7.3, 0.0, 5.1), 5, 0.75, 0.48, Vector3(1.15, 0.0, 1.1), sandstone)
	_stall(root, "SpiceStall", Vector3(-10.3, 0.0, 2.7), cloth_red, pale_stone)
	_stall(root, "DateStall", Vector3(10.0, 0.0, -2.4), cloth_blue, pale_stone)
	_stall(root, "CeramicStall", Vector3(3.8, 0.0, 10.4), Color("#C9A6D7"), pale_stone)

	_palm(root, "OasisPalm_NW", Vector3(-14.0, 0.0, -11.5), 3.5)
	_palm(root, "OasisPalm_NE", Vector3(14.0, 0.0, -11.5), 3.2)
	_palm(root, "OasisPalm_SW", Vector3(-14.0, 0.0, 11.0), 3.0)
	_palm(root, "OasisPalm_SE", Vector3(14.0, 0.0, 11.0), 3.7)
	_rock_cluster(root, "OasisRockGarden", Vector3(-4.5, 0.0, 8.7), sandstone)
	_rock_cluster(root, "OasisDuneGarden", Vector3(4.5, 0.0, -8.8), pale_stone)
	_label(root, "OASIS COURTYARD", Vector3(0.0, 3.4, -13.8), Color("#FFF1D3"))


static func _build_jungle_temple(root: Node3D) -> void:
	var moss := Color("#526D4B")
	var stone := Color("#8B9272")
	var dark_stone := Color("#4E6251")
	var leaf := Color("#5FA85C")
	var water := Color("#46B8C7")
	var wood := Color("#805B3A")

	_water(root, "JungleRiver", Vector3(5.4, 0.07, 24.0), Vector3(0.0, 0.12, 0.0), water)
	_box(root, "JungleRiverBankWest", Vector3(0.55, 0.55, 25.0), Vector3(-3.05, 0.28, 0.0), moss)
	_box(root, "JungleRiverBankEast", Vector3(0.55, 0.55, 25.0), Vector3(3.05, 0.28, 0.0), moss)
	_box(root, "JungleBridgeNorth", Vector3(8.2, 0.34, 1.8), Vector3(0.0, 0.62, -6.0), wood)
	_box(root, "JungleBridgeSouth", Vector3(8.2, 0.34, 1.8), Vector3(0.0, 0.62, 6.2), wood)
	_arch(root, "JungleTempleGate", Vector3(0.0, 0.0, -10.5), 6.4, 3.8, 0.95, stone)
	_stairs(root, "JungleTempleStairs", Vector3(0.0, 0.0, -8.1), 6, 0.9, 0.43, Vector3(5.4, 0.0, 1.0), dark_stone)
	_box(root, "JungleTempleDeck", Vector3(8.0, 0.75, 4.0), Vector3(0.0, 0.72, -13.0), stone)
	for side in [-1.0, 1.0]:
		for index in range(3):
			_cylinder(root, "JungleTempleColumn_%s_%d" % [str(side), index], 0.33, 3.2, Vector3(side * 3.3, 1.6, -12.0 + float(index) * 1.7), pale_stone())
	_palm(root, "JungleTree_West", Vector3(-14.0, 0.0, -10.0), 4.3, leaf)
	_palm(root, "JungleTree_East", Vector3(14.0, 0.0, -9.0), 4.0, leaf)
	_palm(root, "JungleTree_SW", Vector3(-14.0, 0.0, 9.5), 4.5, leaf)
	_palm(root, "JungleTree_SE", Vector3(14.0, 0.0, 10.0), 3.8, leaf)
	_palm(root, "JungleTree_MidWest", Vector3(-8.0, 0.0, 4.0), 3.3, leaf)
	_palm(root, "JungleTree_MidEast", Vector3(8.0, 0.0, -3.5), 3.6, leaf)
	_rock_cluster(root, "JungleRiverRocks_W", Vector3(-4.1, 0.0, -1.5), dark_stone)
	_rock_cluster(root, "JungleRiverRocks_E", Vector3(4.0, 0.0, 2.5), stone)
	_box(root, "JungleWaterfallCliff", Vector3(2.3, 4.6, 0.8), Vector3(0.0, 2.2, -11.1), dark_stone)
	_water(root, "JungleWaterfallRibbon", Vector3(1.35, 3.2, 0.12), Vector3(0.0, 2.1, -10.62), water)
	_label(root, "HIDDEN CANOPY TEMPLE", Vector3(0.0, 4.8, -13.7), Color("#D7FFD2"))


static func _build_redstone_canyon(root: Node3D) -> void:
	var red_rock := Color("#A75D42")
	var light_rock := Color("#D18A5C")
	var sandstone := Color("#C59A68")
	var wood := Color("#76533B")
	var dry_grass := Color("#A8A05B")

	_rock_cluster(root, "CanyonWestSpire", Vector3(-13.8, 0.0, -7.7), red_rock, 1.8)
	_rock_cluster(root, "CanyonEastSpire", Vector3(13.6, 0.0, -8.6), light_rock, 1.7)
	_rock_cluster(root, "CanyonSouthRocks", Vector3(0.0, 0.0, 12.0), red_rock, 1.3)
	_arch(root, "CanyonNaturalArch", Vector3(0.0, 0.0, -7.5), 7.8, 4.0, 1.15, light_rock)
	_box(root, "CanyonAqueductWall", Vector3(16.0, 1.0, 0.55), Vector3(0.0, 2.5, 5.7), sandstone)
	_box(root, "CanyonAqueductWalkway", Vector3(15.0, 0.32, 1.8), Vector3(0.0, 3.12, 5.7), wood)
	_arch(root, "CanyonAqueductWestArch", Vector3(-5.0, 0.0, 5.7), 3.0, 2.6, 0.55, sandstone)
	_arch(root, "CanyonAqueductEastArch", Vector3(5.0, 0.0, 5.7), 3.0, 2.6, 0.55, sandstone)
	_stall(root, "CanyonCaravanTent", Vector3(-9.0, 0.0, 4.0), Color("#D7A35E"), sandstone)
	_stall(root, "CanyonTeaTent", Vector3(9.2, 0.0, -1.5), Color("#A65D4A"), sandstone)
	_palm(root, "CanyonDryPalm_W", Vector3(-14.0, 0.0, 11.0), 2.7, dry_grass)
	_palm(root, "CanyonDryPalm_E", Vector3(14.0, 0.0, 10.5), 2.5, dry_grass)
	_stairs(root, "CanyonLookoutSteps", Vector3(0.0, 0.0, -1.5), 5, 0.85, 0.42, Vector3(4.8, 0.0, 0.9), red_rock)
	_box(root, "CanyonLookoutDeck", Vector3(5.2, 0.5, 3.2), Vector3(0.0, 2.0, -3.5), sandstone)
	_label(root, "REDSTONE CANYON", Vector3(0.0, 4.1, -13.6), Color("#FFE4CF"))


static func _build_lost_mall(root: Node3D) -> void:
	var concrete := Color("#657A86")
	var pale := Color("#B5C5C9")
	var accent := Color("#45BEB8")
	_box(root, "MallAtriumFountainRim", Vector3(6.8, 0.3, 6.8), Vector3(0.0, 0.22, 0.0), pale)
	_water(root, "MallAtriumFountain", Vector3(5.9, 0.06, 5.9), Vector3(0.0, 0.4, 0.0), accent)
	for side in [-1.0, 1.0]:
		for index in range(3):
			_cylinder(root, "MallColumn_%d_%d" % [int(side), index], 0.42, 3.8, Vector3(side * 14.0, 1.9, -8.0 + float(index) * 8.0), pale)
	_box(root, "MallWestShop", Vector3(5.5, 3.0, 4.0), Vector3(-12.0, 1.5, 0.0), concrete)
	_box(root, "MallEastShop", Vector3(5.5, 3.0, 4.0), Vector3(12.0, 1.5, 0.0), concrete)
	_box(root, "MallWestSign", Vector3(4.0, 0.16, 0.18), Vector3(-12.0, 2.65, -2.12), accent, false)
	_box(root, "MallEastSign", Vector3(4.0, 0.16, 0.18), Vector3(12.0, 2.65, -2.12), accent, false)
	_label(root, "LOST FOOD COURT", Vector3(0.0, 3.0, -13.5), Color("#E7FFFF"))


static func _build_neon_rooftops(root: Node3D) -> void:
	var dark := Color("#263B53")
	var blue := Color("#286A97")
	var cyan := Color("#42DCE2")
	for i in range(5):
		var x := -12.0 + float(i) * 6.0
		var height := 2.0 + float(i % 3) * 0.7
		_box(root, "NeonTower_%d" % i, Vector3(3.6, height, 3.6), Vector3(x, height * 0.5, -10.0), dark)
		_box(root, "NeonTowerTrim_%d" % i, Vector3(3.75, 0.16, 0.18), Vector3(x, height - 0.25, -8.12), cyan, false)
	_box(root, "NeonSkywalk", Vector3(17.0, 0.36, 2.0), Vector3(0.0, 2.3, -5.0), blue)
	_box(root, "NeonGardenPlatform", Vector3(7.0, 0.55, 5.0), Vector3(0.0, 1.6, 8.0), dark)
	_label(root, "NEON ROOFTOP GARDEN", Vector3(0.0, 4.2, -13.5), Color("#C7FFFF"))


static func _build_sky_islands(root: Node3D) -> void:
	var stone := Color("#687A99")
	var pale := Color("#A4B8CE")
	var glow := Color("#89DDF2")
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		var position := Vector3(cos(angle) * 10.0, 0.8 + float(i % 2) * 1.2, sin(angle) * 8.0)
		_ellipsoid(root, "SkyIsland_%d" % i, Vector3(3.6, 1.0, 3.0), position, stone)
		_box(root, "SkyIslandDeck_%d" % i, Vector3(4.0, 0.28, 3.2), position + Vector3(0.0, 0.72, 0.0), pale)
		_ellipsoid(root, "SkyIslandGlow_%d" % i, Vector3(0.5, 0.18, 0.5), position + Vector3(0.0, 1.3, 0.0), glow, false)
	_box(root, "SkyCenterPlatform", Vector3(7.5, 0.55, 5.8), Vector3(0.0, 1.0, 0.0), stone)


static func _build_candy_garden(root: Node3D) -> void:
	var pink := Color("#E58EC5")
	var mint := Color("#7ACFC0")
	var cream := Color("#F3DDAA")
	for i in range(5):
		var x := -12.0 + float(i) * 6.0
		var color := pink if i % 2 == 0 else mint
		_cylinder(root, "CandyTower_%d" % i, 1.1, 3.0 + float(i % 2), Vector3(x, 1.5, -8.0), color)
		_ellipsoid(root, "CandyTop_%d" % i, Vector3(1.35, 0.55, 1.35), Vector3(x, 3.2 + float(i % 2), -8.0), cream)
	_ellipsoid(root, "CandyFountain", Vector3(3.0, 0.75, 2.3), Vector3(0.0, 1.1, 0.0), pink)
	_label(root, "CANDY GARDEN", Vector3(0.0, 4.5, -13.3), Color("#FFF4FB"))


static func _stall(root: Node3D, node_name: String, origin: Vector3, canopy_color: Color, stone_color: Color) -> void:
	_box(root, node_name + "_Counter", Vector3(2.4, 0.82, 1.0), origin + Vector3(0.0, 0.42, 0.0), stone_color)
	_box(root, node_name + "_Canopy", Vector3(2.8, 0.18, 1.5), origin + Vector3(0.0, 1.65, 0.0), canopy_color, false)
	for side in [-1.0, 1.0]:
		_cylinder(root, node_name + "_Pole_%s" % str(side), 0.055, 1.55, origin + Vector3(side * 1.15, 0.82, 0.0), Color("#71553D"), false)


static func _arch(root: Node3D, node_name: String, origin: Vector3, width: float, height: float, thickness: float, color: Color) -> void:
	_box(root, node_name + "_Left", Vector3(thickness, height, thickness), origin + Vector3(-width * 0.5, height * 0.5, 0.0), color)
	_box(root, node_name + "_Right", Vector3(thickness, height, thickness), origin + Vector3(width * 0.5, height * 0.5, 0.0), color)
	_box(root, node_name + "_Top", Vector3(width + thickness, thickness, thickness), origin + Vector3(0.0, height, 0.0), color)


static func _stairs(root: Node3D, node_name: String, origin: Vector3, count: int, step_width: float, step_height: float, footprint: Vector3, color: Color) -> void:
	for index in range(count):
		var depth := footprint.z / float(count)
		var rise := float(index + 1) * step_height
		var z := origin.z - footprint.z * 0.5 + depth * (float(index) + 0.5)
		_box(root, "%s_%d" % [node_name, index], Vector3(footprint.x, rise, depth), Vector3(origin.x, rise * 0.5, z), color)


static func _palm(root: Node3D, node_name: String, origin: Vector3, height: float, leaf_color: Color = Color("#4D9753")) -> void:
	_cylinder(root, node_name + "_Trunk", 0.22, height, origin + Vector3(0.0, height * 0.5, 0.0), Color("#8A633D"), false)
	var crown := origin + Vector3(0.0, height, 0.0)
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var leaf := _ellipsoid(root, "%s_Leaf_%d" % [node_name, index], Vector3(0.34, 1.2, 0.22), crown + Vector3(cos(angle) * 0.48, -0.12, sin(angle) * 0.48), leaf_color, false)
		leaf.rotation.y = angle
		leaf.rotation.z = -0.34 if index % 2 == 0 else 0.34
	_ellipsoid(root, node_name + "_Crown", Vector3(0.55, 0.42, 0.55), crown, leaf_color, false)


static func _rock_cluster(root: Node3D, node_name: String, origin: Vector3, color: Color, size_scale: float = 1.0) -> void:
	var offsets := [
		Vector3(-0.55, 0.42, 0.0), Vector3(0.48, 0.55, 0.25),
		Vector3(0.0, 0.76, -0.48), Vector3(0.75, 0.28, -0.55)
	]
	var scales := [
		Vector3(0.85, 0.72, 0.8), Vector3(0.72, 0.95, 0.7),
		Vector3(0.64, 1.15, 0.6), Vector3(0.95, 0.58, 0.72)
	]
	for index in range(offsets.size()):
		var rock := _ellipsoid(root, "%s_%d" % [node_name, index], scales[index] * size_scale, origin + offsets[index] * size_scale, color, true)
		rock.rotation.y = float(index) * 0.63


static func _water(root: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	_box(root, node_name, size, position, color, false)
	var water_node := root.get_node_or_null(node_name) as Node3D
	if water_node:
		var mesh_node := water_node.get_child(0) as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color.r, color.g, color.b, 0.78)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.16
		material.metallic = 0.12
		material.emission_enabled = true
		material.emission = color.darkened(0.34)
		material.emission_energy_multiplier = 0.18
		mesh_node.material_override = material


static func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, solid: bool = true) -> Node3D:
	var host: Node3D = StaticBody3D.new() if solid else Node3D.new()
	host.name = node_name
	host.position = position
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		host.add_child(collision)
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := _material(color)
	instance.material_override = material
	host.add_child(instance)
	parent.add_child(host)
	return host


static func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, solid: bool = true) -> Node3D:
	var host: Node3D = StaticBody3D.new() if solid else Node3D.new()
	host.name = node_name
	host.position = position
	if solid:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		host.add_child(collision)
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.84
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.material_override = _material(color)
	host.add_child(instance)
	parent.add_child(host)
	return host


static func _ellipsoid(parent: Node3D, node_name: String, scale_value: Vector3, position: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 8
	instance.mesh = mesh
	instance.scale = scale_value
	instance.position = position
	instance.material_override = _material(color)
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.name = node_name + "_Collision"
		body.position = position
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(scale_value.x, maxf(scale_value.y, scale_value.z)) * 0.5
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
	return instance


static func _label(parent: Node3D, text_value: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.008
	label.modulate = color
	parent.add_child(label)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	material.metallic = 0.04
	return material


static func pale_stone() -> Color:
	return Color("#D6CEAA")
