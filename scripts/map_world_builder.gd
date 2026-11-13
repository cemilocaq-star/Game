class_name MapWorldBuilder
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
	_build_objective_sites(root)
	return root


static func _build_objective_sites(root: Node3D) -> void:
	var site_data := [
		{"id": "A", "position": Vector3(-9.0, 0.0, -8.0), "color": Color("#FF9B62")},
		{"id": "B", "position": Vector3(9.0, 0.0, 8.0), "color": Color("#65DFFF")}
	]
	for site in site_data:
		var site_id := str(site.id)
		var site_position: Vector3 = site.position
		var tint: Color = site.color
		_box(root, "ObjectiveSite_%s_Pad" % site_id, Vector3(5.0, 0.22, 5.0), site_position + Vector3(0.0, 0.11, 0.0), tint.darkened(0.62))
		var ring := MeshInstance3D.new()
		ring.name = "ObjectiveSite_%s_EnergyRing" % site_id
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 1.72
		ring_mesh.outer_radius = 1.9
		ring.mesh = ring_mesh
		ring.position = site_position + Vector3(0.0, 0.28, 0.0)
		var ring_material := _material(tint)
		ring_material.emission_enabled = true
		ring_material.emission = tint
		ring_material.emission_energy_multiplier = 1.35
		ring.material_override = ring_material
		root.add_child(ring)
		_cylinder(root, "ObjectiveSite_%s_Beacon" % site_id, 0.16, 2.4, site_position + Vector3(0.0, 1.2, 0.0), tint, false)
		_label(root, "ENERGY SITE " + site_id, site_position + Vector3(0.0, 2.65, 0.0), tint.lightened(0.25))


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


## Jungle Arena (map 5). Everything is point-symmetric around the center: side "A" (west/north,
## stepped pyramid) and side "B" (east/south, ruined temple) mirror each other, so both
## objective sites get the same cover, climbs and routes. The river trench runs north-south
## through the middle and is the swim zone (see in_swim_zone).
const JUNGLE_RIVER_HALF_WIDTH := 2.4
const JUNGLE_RIVER_BED_Y := -1.2
const JUNGLE_WATER_Y := -0.2


static func _build_jungle_temple(root: Node3D) -> void:
	_jungle_floor_and_river(root)
	_jungle_waterfall(root)
	_jungle_crossings(root)
	_jungle_river_exits(root)
	_jungle_side(root, "A", 1.0)
	_jungle_side(root, "B", -1.0)
	_jungle_mid_ruins(root)
	_jungle_flags_and_cover(root)
	_jungle_paths(root)
	_jungle_foliage(root)
	_label(root, "JUNGLE ARENA", Vector3(0.0, 6.7, -13.4), Color("#E5FFD8"))


## Node names cannot contain "." so numbers used in names are written as 1p5 / n2p4.
static func _tag(value: float) -> String:
	return str(snappedf(value, 0.01)).replace(".", "p").replace("-", "n")


## Maps a point on side "A" to its counterpart on side "B" (point reflection through the center).
static func _mirror(side_sign: float, value: Vector3) -> Vector3:
	return Vector3(value.x * side_sign, value.y, value.z * side_sign)


static func _ramp(parent: Node3D, node_name: String, bottom: Vector3, top: Vector3, width: float, thickness: float, color: Color, solid: bool = true) -> Node3D:
	var direction := top - bottom
	var x_axis := direction.normalized()
	var z_axis := x_axis.cross(Vector3.UP).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	var host := _box(parent, node_name, Vector3(direction.length(), thickness, width), (bottom + top) * 0.5 - y_axis * thickness * 0.5, color, solid)
	host.basis = Basis(x_axis, y_axis, z_axis)
	return host


static func _emissive(node: Node3D, color: Color, energy: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var material := _material(color)
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = energy
			(child as MeshInstance3D).material_override = material


static func _jungle_floor_and_river(root: Node3D) -> void:
	var grass := Color("#3F6E42")
	var bed := Color("#6F7A62")
	var half := JUNGLE_RIVER_HALF_WIDTH
	# Thick floor slabs on both banks so the river trench has solid sides all the way down.
	var bank_width := 18.0 - half
	_box(root, "JungleFloorWest", Vector3(bank_width, 2.0, 30.0), Vector3(-(half + bank_width * 0.5), -1.0, 0.0), grass)
	_box(root, "JungleFloorEast", Vector3(bank_width, 2.0, 30.0), Vector3(half + bank_width * 0.5, -1.0, 0.0), grass)
	_box(root, "JungleRiverBed", Vector3(half * 2.0, 1.0, 30.0), Vector3(0.0, JUNGLE_RIVER_BED_Y - 0.5, 0.0), bed)
	_water(root, "JungleRiverWater", Vector3(half * 2.0, 0.05, 28.2), Vector3(0.0, JUNGLE_WATER_Y - 0.025, 0.0), Color("#3FC3D6"))
	# Mossy stone lip along both banks.
	for side in [-1.0, 1.0]:
		for index in range(6):
			var z := -11.0 + float(index) * 4.4
			_ellipsoid(root, "JungleBankStone_%s_%d" % [_tag(side), index], Vector3(0.9, 0.34, 1.5), Vector3(side * (half + 0.12), 0.06, z), Color("#7A8A6B"), false)


static func _jungle_waterfall(root: Node3D) -> void:
	var rock := Color("#767C6E")
	var rock_dark := Color("#596257")
	var moss := Color("#5E8F4E")
	# Cliff that spans the river's north end; the pool under it is too low to stand in.
	_box(root, "JungleWaterfallCliff", Vector3(6.6, 6.0, 3.8), Vector3(0.0, 3.0, -12.2), rock)
	_box(root, "JungleWaterfallBasin", Vector3(6.6, 1.2, 3.8), Vector3(0.0, -0.6, -12.2), rock_dark)
	_box(root, "JungleCliffWestShoulder", Vector3(3.2, 3.2, 3.0), Vector3(-5.0, 1.6, -12.6), rock_dark)
	_box(root, "JungleCliffEastShoulder", Vector3(3.2, 3.2, 3.0), Vector3(5.0, 1.6, -12.6), rock_dark)
	_ellipsoid(root, "JungleCliffMoss_Top", Vector3(6.2, 0.7, 3.4), Vector3(0.0, 6.0, -12.2), moss, false)
	_ellipsoid(root, "JungleCliffMoss_W", Vector3(3.0, 0.6, 2.8), Vector3(-5.0, 3.2, -12.6), moss, false)
	_ellipsoid(root, "JungleCliffMoss_E", Vector3(3.0, 0.6, 2.8), Vector3(5.0, 3.2, -12.6), moss, false)
	var ribbon := _box(root, "JungleWaterfallRibbon", Vector3(3.4, 5.9, 0.25), Vector3(0.0, 3.0, -10.2), Color("#7FE3F2"), false)
	_emissive(ribbon, Color("#7FE3F2"), 0.45)
	for index in range(4):
		var foam := _ellipsoid(root, "JungleWaterfallFoam_%d" % index, Vector3(1.5, 0.16, 0.9), Vector3(-1.4 + float(index) * 0.95, JUNGLE_WATER_Y + 0.02, -9.7 + float(index % 2) * 0.35), Color("#F2FFFF"), false)
		foam.rotation.y = float(index) * 0.4
	_rock_cluster(root, "JungleWaterfallRocks_W", Vector3(-3.3, 0.0, -9.2), rock_dark, 1.15)
	_rock_cluster(root, "JungleWaterfallRocks_E", Vector3(3.3, 0.0, -9.0), rock, 1.0)


## Two crossings that are solid all the way down to the river bed, so nobody can swim under them.
static func _jungle_crossings(root: Node3D) -> void:
	var wood := Color("#8A5A34")
	var wood_dark := Color("#5E3D24")
	var stone := Color("#8E9A78")
	# North: log bridge. Its ramps lead to the east and west banks.
	var bz := -2.4
	_box(root, "JungleLogBridge", Vector3(7.4, 1.7, 2.2), Vector3(0.0, -0.35, bz), wood_dark)
	_box(root, "JungleLogBridgePlanks", Vector3(7.4, 0.08, 2.2), Vector3(0.0, 0.5, bz), wood, false)
	for side in [-1.0, 1.0]:
		var tag := "W" if side < 0.0 else "E"
		_ramp(root, "JungleLogBridgeRamp_" + tag, Vector3(side * 5.8, 0.0, bz), Vector3(side * 3.7, 0.5, bz), 2.2, 0.3, wood)
		for post_index in range(2):
			_cylinder(root, "JungleLogBridgePost_%s_%d" % [tag, post_index], 0.09, 1.1, Vector3(side * 3.4, 1.0, bz - 1.0 + float(post_index) * 2.0), wood_dark, false)
	for rail_index in range(2):
		_box(root, "JungleLogBridgeRail_%d" % rail_index, Vector3(6.8, 0.08, 0.08), Vector3(0.0, 1.45, bz - 1.05 + float(rail_index) * 2.1), wood, false)
	# South: stone causeway; also the landing area where players spawn. It is raised 0.5 above
	# the banks, so short ramps on its north and south ends lead up from each bank strip.
	_box(root, "JungleSpawnCauseway", Vector3(8.4, 1.7, 4.2), Vector3(0.0, -0.35, 6.1), stone)
	_box(root, "JungleCausewayPaving", Vector3(8.4, 0.06, 4.2), Vector3(0.0, 0.52, 6.1), Color("#B3BC9A"), false)
	for side in [-1.0, 1.0]:
		var tag := "W" if side < 0.0 else "E"
		_ramp(root, "JungleCausewayRampNorth_" + tag, Vector3(side * 3.3, 0.0, 2.2), Vector3(side * 3.3, 0.5, 4.0), 1.6, 0.3, stone)
		_ramp(root, "JungleCausewayRampSouth_" + tag, Vector3(side * 3.3, 0.0, 10.1), Vector3(side * 3.3, 0.5, 8.2), 1.6, 0.3, stone)
		for index in range(3):
			_cylinder(root, "JungleCausewayPillar_%s_%d" % [tag, index], 0.26, 0.7, Vector3(side * 4.0, 0.85, 4.6 + float(index) * 1.5), Color("#7A8A6B"), false)


## Gentle slopes from the river bed to the banks so a swimmer can always climb out.
static func _jungle_river_exits(root: Node3D) -> void:
	var stone := Color("#7A8A6B")
	var half := JUNGLE_RIVER_HALF_WIDTH
	var exits := [[-1.0, -8.5], [-1.0, 1.5], [-1.0, 11.5], [1.0, -6.5], [1.0, 10.5]]
	for index in range(exits.size()):
		var side: float = exits[index][0]
		var z: float = exits[index][1]
		_ramp(root, "JungleRiverExit_%d" % index, Vector3(side * (half - 1.7), JUNGLE_RIVER_BED_Y, z), Vector3(side * half, 0.0, z), 2.0, 0.3, stone)


static func _jungle_side(root: Node3D, side_id: String, side_sign: float) -> void:
	var is_pyramid := side_id == "A"
	var stone := Color("#8E9A78") if is_pyramid else Color("#9AA088")
	var stone_dark := Color("#667A5E")
	var stone_light := Color("#B3BC9A")
	var moss := Color("#5E8F4E")
	var wood := Color("#8A5A34")
	var wood_dark := Color("#5E3D24")
	var rope := Color("#C8A46A")
	var prefix := "JunglePyramid" if is_pyramid else "JungleRuins"
	var center := _mirror(side_sign, Vector3(-14.3, 0.0, -9.5))

	# Three tiers, one meter each, so the climb is jump-sized; the south ramp reaches tier 1.
	_box(root, prefix + "Tier1", Vector3(6.4, 1.0, 6.4), center + Vector3(0.0, 0.5, 0.0), stone)
	_box(root, prefix + "Tier2", Vector3(4.4, 1.0, 4.4), center + Vector3(0.0, 1.5, 0.0), stone)
	_box(root, prefix + "Tier3", Vector3(2.6, 1.0, 2.6), center + Vector3(0.0, 2.5, 0.0), stone_light)
	var ramp_bottom := _mirror(side_sign, Vector3(-14.3, 0.0, -2.3))
	var ramp_top := _mirror(side_sign, Vector3(-14.3, 1.0, -6.3))
	_ramp(root, prefix + "Ramp", ramp_bottom, ramp_top, 2.4, 0.3, stone_light)
	for index in range(5):
		var t := (float(index) + 0.5) / 5.0
		var rib := _box(root, "%sRamp_Step_%d" % [prefix, index], Vector3(0.14, 0.07, 2.4), ramp_bottom.lerp(ramp_top, t) + Vector3(0.0, 0.05, 0.0), stone_dark, false)
		rib.basis = _mirror_basis(ramp_bottom, ramp_top)
	# Moss caps on the tier edges and hanging vines.
	for tier in range(3):
		var width := 6.4 - float(tier) * 2.0
		_ellipsoid(root, "%sMoss_%d" % [prefix, tier], Vector3(width * 0.55, 0.26, width * 0.4), center + Vector3(side_sign * 0.5, 1.02 + float(tier), side_sign * 0.4), moss, false)
	for index in range(5):
		_ellipsoid(root, "%sVine_%d" % [prefix, index], Vector3(0.18, 1.4, 0.16), center + Vector3(-3.0 + float(index) * 1.5, 0.6, 3.25 * side_sign), Color("#3F7A3C"), false)
	if is_pyramid:
		# Shrine: four pillars and a roof well above head height, plus snake-stone guardians.
		for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
			_cylinder(root, "PyramidShrinePillar_%s_%s" % [_tag(corner.x), _tag(corner.y)], 0.12, 2.0, center + Vector3(corner.x * 1.0, 4.0, corner.y * 1.0), stone_dark, false)
		_box(root, "PyramidShrineRoof", Vector3(3.0, 0.25, 3.0), center + Vector3(0.0, 5.1, 0.0), stone_dark, false)
		for guard_side in [-1.0, 1.0]:
			var guard := _mirror(side_sign, Vector3(-14.3 + guard_side * 2.1, 0.0, -5.2))
			_rock_cluster(root, "PyramidGuardian_%s" % _tag(guard_side), guard, Color("#5E8A55"), 0.9)
	else:
		# Ruined temple: a broken arch gate, a carved totem and a low altar.
		_arch(root, "RuinsGate", center + Vector3(0.0, 1.0, -2.6), 3.0, 2.8, 0.45, stone_dark)
		_box(root, "RuinsTotem", Vector3(0.9, 2.2, 0.5), center + Vector3(0.0, 4.1, 0.0), stone_dark, false)
		_box(root, "RuinsAltar", Vector3(1.8, 0.5, 1.1), center + Vector3(side_sign * -1.2, 3.25, 0.0), stone_light, false)
		_ellipsoid(root, "RuinsGlyph", Vector3(0.5, 0.5, 0.12), center + Vector3(0.0, 4.4, -0.3), Color("#65DFFF"), false)

	# Treehouse above the objective, reached by a wooden ramp and by a rope bridge from tier 3.
	var house := _mirror(side_sign, Vector3(-7.1, 0.0, -11.85))
	var house_name := "JungleTreehouse_" + side_id
	_box(root, house_name + "_Platform", Vector3(5.0, 0.3, 3.9), house + Vector3(0.0, 2.85, 0.0), wood)
	for corner in [Vector2(-2.2, -1.7), Vector2(2.2, -1.7), Vector2(-2.2, 1.7), Vector2(2.2, 1.7)]:
		_cylinder(root, "%s_Post_%s_%s" % [house_name, _tag(corner.x), _tag(corner.y)], 0.18, 2.7, house + Vector3(corner.x, 1.35, corner.y), wood_dark)
	_box(root, house_name + "_BackWall", Vector3(5.0, 2.0, 0.2), house + Vector3(0.0, 4.0, -1.85 * side_sign), wood_dark)
	_box(root, house_name + "_Roof", Vector3(5.8, 0.25, 4.6), house + Vector3(0.0, 5.7, 0.0), Color("#6F8B4B"), false)
	for corner in [Vector2(-2.4, 1.8), Vector2(2.4, 1.8)]:
		_cylinder(root, "%s_RoofPost_%s" % [house_name, _tag(corner.x)], 0.08, 2.6, house + Vector3(corner.x, 4.3, corner.y * side_sign), wood_dark, false)
	var house_ramp_bottom := _mirror(side_sign, Vector3(-5.5, 0.0, -5.0))
	var house_ramp_top := _mirror(side_sign, Vector3(-5.5, 3.0, -9.9))
	_ramp(root, "JungleTreehouseRamp_" + side_id, house_ramp_bottom, house_ramp_top, 1.8, 0.3, wood)
	for index in range(7):
		var t := (float(index) + 0.5) / 7.0
		var cleat := _box(root, "JungleTreehouseRamp_%s_Cleat_%d" % [side_id, index], Vector3(0.1, 0.06, 1.8), house_ramp_bottom.lerp(house_ramp_top, t) + Vector3(0.0, 0.05, 0.0), wood_dark, false)
		cleat.basis = _mirror_basis(house_ramp_bottom, house_ramp_top)
	var bridge_center := _mirror(side_sign, Vector3(-11.3, 2.9, -10.4))
	_box(root, "JungleRopeBridge_" + side_id, Vector3(3.4, 0.2, 1.2), bridge_center, wood)
	for rail in [-0.6, 0.6]:
		_box(root, "JungleRopeBridge_%s_Rope_%s" % [side_id, _tag(rail)], Vector3(3.6, 0.05, 0.05), bridge_center + Vector3(0.0, 0.85, rail), rope, false)
		for post in [-1.6, 1.6]:
			_cylinder(root, "JungleRopeBridge_%s_Post_%s_%s" % [side_id, _tag(rail), _tag(post)], 0.05, 0.9, bridge_center + Vector3(post, 0.5, rail), wood_dark, false)


## Basis that lays a flat box along a ramp running from `bottom` to `top`.
static func _mirror_basis(bottom: Vector3, top: Vector3) -> Basis:
	var x_axis := (top - bottom).normalized()
	var z_axis := x_axis.cross(Vector3.UP).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


## Broken colonnades beside the river, mirrored through the center.
static func _jungle_mid_ruins(root: Node3D) -> void:
	var stone := Color("#8E9A78")
	var stone_dark := Color("#667A5E")
	var stone_light := Color("#B3BC9A")
	var moss := Color("#5E8F4E")
	for side_info in [["W", 1.0], ["E", -1.0]]:
		var tag: String = side_info[0]
		var side_sign: float = side_info[1]
		_box(root, "JungleMidPlaza_" + tag, Vector3(5.0, 0.08, 4.4), _mirror(side_sign, Vector3(-9.3, 0.04, 4.8)), stone_light, false)
		var pillars := [Vector3(-11.0, 1.5, 3.0), Vector3(-8.6, 1.5, 3.0), Vector3(-11.0, 1.5, 6.6), Vector3(-7.6, 0.9, 6.6)]
		for index in range(pillars.size()):
			var height := 3.0 if index < 3 else 1.8
			_cylinder(root, "JungleMidPillar_%s_%d" % [tag, index], 0.42, height, _mirror(side_sign, Vector3(pillars[index].x, height * 0.5, pillars[index].z)), stone)
		_box(root, "JungleMidLowWall_" + tag, Vector3(3.2, 1.1, 0.5), _mirror(side_sign, Vector3(-9.3, 0.55, 4.9)), stone_dark)
		_box(root, "JungleMidBrokenWall_" + tag, Vector3(0.5, 0.8, 2.0), _mirror(side_sign, Vector3(-11.4, 0.4, 4.9)), stone_dark)
		_box(root, "JungleMidLintel_" + tag, Vector3(2.9, 0.4, 0.5), _mirror(side_sign, Vector3(-9.8, 3.2, 3.0)), stone, false)
		_ellipsoid(root, "JungleMidMoss_" + tag, Vector3(1.4, 0.3, 1.0), _mirror(side_sign, Vector3(-9.3, 1.15, 4.9)), moss, false)


static func _jungle_flags_and_cover(root: Node3D) -> void:
	var wood_dark := Color("#5E3D24")
	for flag_info in [["Blue", Color("#3F6FD9"), Vector3(-14.5, 0.0, 11.5)], ["Red", Color("#D94A4A"), Vector3(14.5, 0.0, -11.5)]]:
		var flag_name: String = flag_info[0]
		var color: Color = flag_info[1]
		var base: Vector3 = flag_info[2]
		var pad := _box(root, "Jungle%sFlagBase" % flag_name, Vector3(2.4, 0.1, 2.4), base + Vector3(0.0, 0.05, 0.0), color.darkened(0.35), false)
		_emissive(pad, color, 0.7)
		_cylinder(root, "Jungle%sFlagPole" % flag_name, 0.07, 3.4, base + Vector3(0.0, 1.7, 0.0), Color("#D9D2C0"), false)
		var cloth := _box(root, "Jungle%sFlagCloth" % flag_name, Vector3(1.3, 0.8, 0.05), base + Vector3(0.7, 3.0, 0.0), color, false)
		_emissive(cloth, color, 0.25)
	# Crates and barrels as low cover near both flag bases and both objective sites.
	var crate := Color("#8A5A34")
	var crate_dark := Color("#6A4428")
	for cover_info in [["SW", 1.0, Vector3(-10.8, 0.0, 10.6)], ["NE", -1.0, Vector3(10.8, 0.0, -10.6)]]:
		var tag: String = cover_info[0]
		var origin: Vector3 = cover_info[2]
		_box(root, "JungleCrate_%s_0" % tag, Vector3(1.1, 1.1, 1.1), origin + Vector3(0.0, 0.55, 0.0), crate)
		_box(root, "JungleCrate_%s_1" % tag, Vector3(1.1, 1.1, 1.1), origin + Vector3(1.2, 0.55, 0.3), crate_dark)
		_box(root, "JungleCrate_%s_2" % tag, Vector3(0.9, 0.9, 0.9), origin + Vector3(0.5, 1.55, 0.1), crate)
		_cylinder(root, "JungleBarrel_%s_0" % tag, 0.4, 0.9, origin + Vector3(-1.0, 0.45, 0.4), wood_dark)
		_cylinder(root, "JungleBarrel_%s_1" % tag, 0.4, 0.9, origin + Vector3(-0.9, 0.45, 1.3), crate_dark)
	for site_cover in [Vector3(-12.2, 0.0, -4.4), Vector3(12.2, 0.0, 4.4), Vector3(-7.6, 0.0, -2.4), Vector3(7.6, 0.0, 2.4)]:
		_box(root, "JungleSiteCrate_%s_%s" % [_tag(site_cover.x), _tag(site_cover.z)], Vector3(1.2, 1.0, 1.2), site_cover + Vector3(0.0, 0.5, 0.0), crate)


static func _jungle_paths(root: Node3D) -> void:
	var sand := Color("#D3AA6B")
	var segments := [
		["PathPyramidSouth", Vector3(-14.3, 0.015, -0.4), Vector3(2.2, 0.03, 3.6)],
		["PathWestAcross", Vector3(-8.35, 0.015, 0.3), Vector3(11.9, 0.03, 1.8)],
		["PathWestHouse", Vector3(-5.5, 0.015, -2.7), Vector3(1.8, 0.03, 5.4)],
		["PathEastAcross", Vector3(8.35, 0.015, -0.3), Vector3(11.9, 0.03, 1.8)],
		["PathEastHouse", Vector3(5.5, 0.015, 2.7), Vector3(1.8, 0.03, 5.4)],
		["PathRuinsNorth", Vector3(14.3, 0.015, 0.4), Vector3(2.2, 0.03, 3.6)],
		["PathCauseway", Vector3(0.0, 0.015, 9.6), Vector3(2.2, 0.03, 4.8)]
	]
	for segment in segments:
		_box(root, "Jungle" + str(segment[0]), segment[2], segment[1], sand, false)


static func _jungle_foliage(root: Node3D) -> void:
	var leaf := Color("#4FA357")
	var leaf_dark := Color("#3E8A4B")
	var leaf_light := Color("#7CC463")
	var palms := [
		Vector3(-16.2, 0.0, -3.6), Vector3(-16.0, 0.0, 4.2), Vector3(-11.5, 0.0, 13.0), Vector3(-6.6, 0.0, 13.2),
		Vector3(8.0, 0.0, -13.2), Vector3(12.8, 0.0, -13.0), Vector3(16.2, 0.0, 3.6), Vector3(16.0, 0.0, -4.2),
		Vector3(11.5, 0.0, 13.2)
	]
	for index in range(palms.size()):
		_palm(root, "JunglePalm_%d" % index, palms[index], 3.6 + float(index % 4) * 0.5, leaf if index % 2 == 0 else leaf_light)
	# Broad canopy trees with solid trunks double as cover.
	for tree_info in [[Vector3(-16.0, 0.0, 0.0), 5.2], [Vector3(16.0, 0.0, 0.0), 5.2], [Vector3(-8.5, 0.0, 12.0), 4.6], [Vector3(8.5, 0.0, -12.0), 4.6]]:
		var origin: Vector3 = tree_info[0]
		var height: float = tree_info[1]
		var tree_name := "JungleTree_%s_%s" % [_tag(origin.x), _tag(origin.z)]
		_cylinder(root, tree_name + "_Trunk", 0.36, height, origin + Vector3(0.0, height * 0.5, 0.0), Color("#5E3D24"))
		_ellipsoid(root, tree_name + "_CrownA", Vector3(3.4, 1.9, 3.4), origin + Vector3(0.0, height + 0.3, 0.0), leaf_dark, false)
		_ellipsoid(root, tree_name + "_CrownB", Vector3(2.4, 1.5, 2.4), origin + Vector3(0.7, height + 1.2, 0.3), leaf, false)
	var bushes := [
		Vector3(-16.4, 0.0, -9.0), Vector3(-16.4, 0.0, 8.0), Vector3(-13.0, 0.0, 13.4), Vector3(-3.5, 0.0, 13.5),
		Vector3(3.8, 0.0, 13.5), Vector3(16.4, 0.0, 9.0), Vector3(16.4, 0.0, -8.0), Vector3(13.0, 0.0, -13.4),
		Vector3(-12.5, 0.0, -13.4), Vector3(-3.5, 0.0, 9.0), Vector3(3.5, 0.0, -9.5), Vector3(-9.5, 0.0, 8.8),
		Vector3(9.5, 0.0, -8.8)
	]
	for index in range(bushes.size()):
		var bush_size := 1.0 + float(index % 3) * 0.35
		_ellipsoid(root, "JungleBush_%d" % index, Vector3(1.5 * bush_size, 0.9 * bush_size, 1.3 * bush_size), bushes[index] + Vector3(0.0, 0.35 * bush_size, 0.0), leaf if index % 2 == 0 else leaf_dark, false)
	var fern_xs := [-14.0, -10.0, -6.0, 6.0, 10.0, 14.0]
	for index in range(fern_xs.size()):
		var fern_position := Vector3(float(fern_xs[index]), 0.0, 13.6 if index % 2 == 0 else -13.6)
		_ellipsoid(root, "JungleFern_%d" % index, Vector3(0.5, 1.1, 0.5), fern_position + Vector3(0.0, 0.5, 0.0), leaf_light, false)


## True when `position` (a body origin, i.e. its feet) is inside the swim zone of the given map.
static func in_swim_zone(map_index: int, position: Vector3) -> bool:
	if map_index == 5:
		return absf(position.x) <= JUNGLE_RIVER_HALF_WIDTH + 0.2 and absf(position.z) <= 14.0 and position.y <= JUNGLE_WATER_Y - 0.4
	# Original beach pool used by every other map.
	return position.x >= -16.0 and position.x <= -8.0 and position.z >= -13.0 and position.z <= -5.0 and position.y <= 3.5


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
