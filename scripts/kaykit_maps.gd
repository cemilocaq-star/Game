class_name KaykitMaps
extends RefCounted
## Two maps dressed with CC0 KayKit models (Dungeon Remastered, Space Base Bits); see assets/models/CREDITS.md.
##
## Collision never depends on a model: every solid is a plain box, so the dedicated server (which passes
## visuals = false and never loads a model) and the client agree exactly. Models are only the look of those
## boxes. All solids stand along the walls and in the corners so the routes between the two spawns and the
## energy sites stay exactly those of the default arena.

const DUNGEON := "res://assets/models/dungeon/%s.glb"
const SPACE := "res://assets/models/space/%s.gltf"

const CRYPT_MAP := 7
const OUTPOST_MAP := 8

const ARENA_HALF_X := 18.0
const ARENA_HALF_Z := 15.0
const NORTH_WALL_Z := -14.55
const SOUTH_WALL_Z := 14.55
const EAST_WALL_X := 17.55
const WEST_WALL_X := -17.55


static func build(root: Node3D, map_index: int, visuals: bool) -> void:
	if map_index == CRYPT_MAP:
		_build_crypt(root, visuals)
	elif map_index == OUTPOST_MAP:
		_build_outpost(root, visuals)


## The collision boxes of a map as world-space AABBs (tests use this to prove nothing blocks a spawn, an
## orb or an energy site).
static func solid_boxes(map_index: int) -> Array[AABB]:
	var boxes: Array[AABB] = []
	if map_index == CRYPT_MAP:
		for prop in CRYPT_PROPS:
			var size: Vector3 = prop[5]
			boxes.append(AABB(Vector3(float(prop[2]) - size.x * 0.5, 0.0, float(prop[3]) - size.z * 0.5), size))
	elif map_index == OUTPOST_MAP:
		for prop in OUTPOST_PROPS:
			var size: Vector3 = prop[7]
			boxes.append(AABB(Vector3(float(prop[2]) - size.x * 0.5, 0.0, float(prop[3]) - size.z * 0.5), size))
	return boxes


# ---------------------------------------------------------------------------------------------- Crypt

## Solid props of the crypt: {model, name, x, z, yaw, size (collision box, world axes)}.
const CRYPT_PROPS := [
	["crates_stacked", "CryptCrates_NW", -15.0, -12.6, 0.0, Vector3(2.1, 2.14, 2.25)],
	["box_large", "CryptBox_N", -11.0, -12.8, 0.0, Vector3(1.5, 1.5, 1.5)],
	["pillar_decorated", "CryptPillar_NW", -2.8, -12.9, 0.0, Vector3(2.23, 4.0, 1.71)],
	["pillar_decorated", "CryptPillar_NE", 2.8, -12.9, 0.0, Vector3(2.23, 4.0, 1.71)],
	["barrel_large", "CryptBarrel_NE", 12.8, -12.9, 0.0, Vector3(1.8, 2.0, 1.8)],
	["barrel_small_stack", "CryptBarrelStack_N", 10.6, -13.1, 0.0, Vector3(1.85, 1.77, 1.0)],
	["keg", "CryptKeg_NE", 15.2, -12.6, 0.0, Vector3(1.8, 2.05, 2.0)],
	["table_long", "CryptTable_E", 15.8, 2.5, 0.0, Vector3(2.0, 1.0, 4.0)],
	["table_long", "CryptTable_W", -15.8, 2.5, 0.0, Vector3(2.0, 1.0, 4.0)],
	["chest", "CryptChest_E", 15.8, -2.5, 0.0, Vector3(1.7, 0.97, 1.91)],
	["chest_gold", "CryptChestGold_W", -15.8, -2.5, 0.0, Vector3(1.7, 1.21, 1.91)],
	["barrier", "CryptBarrier_SW", -14.4, 12.7, 0.0, Vector3(4.0, 1.1, 0.5)],
	["barrier", "CryptBarrier_SE", 14.4, 12.7, 0.0, Vector3(4.0, 1.1, 0.5)],
	["barrel_large", "CryptBarrel_S", 0.0, 13.2, 0.0, Vector3(1.8, 2.0, 1.8)],
	["crates_stacked", "CryptCrates_S", 4.5, 13.0, 0.0, Vector3(2.1, 2.14, 2.25)],
]

const CRYPT_NORTH_WALLS := ["wall_gated", "wall_arched", "wall", "wall_archedwindow_gated", "wall_window_open",
	"wall_archedwindow_gated", "wall", "wall_arched", "wall_gated"]
const CRYPT_SIDE_WALLS := ["wall", "wall_window_open", "wall_arched", "wall_doorway", "wall_arched", "wall_window_open", "wall"]


static func _build_crypt(root: Node3D, visuals: bool) -> void:
	for prop in CRYPT_PROPS:
		var size: Vector3 = prop[5]
		_solid(root, str(prop[1]), Vector3(float(prop[2]), size.y * 0.5, float(prop[3])), size)
		if visuals:
			_model(root, DUNGEON % str(prop[0]), str(prop[1]) + "_Model", Vector3(float(prop[2]), 0.0, float(prop[3])), float(prop[4]), 1.0)
	if not visuals:
		return
	var tiles: Array[Transform3D] = []
	for ix in range(-4, 5):
		for iz in range(-3, 4):
			tiles.append(Transform3D(Basis.IDENTITY, Vector3(float(ix) * 4.0, -0.05, float(iz) * 4.0)))
	_multimesh(root, "CryptFloorTiles", DUNGEON % "floor_tile_large", tiles)
	# Wall facing: the models face +Z, so the wall on the north edge keeps yaw 0 and the others turn inwards.
	for i in range(CRYPT_NORTH_WALLS.size()):
		var x := -16.0 + float(i) * 4.0
		_model(root, DUNGEON % CRYPT_NORTH_WALLS[i], "CryptWallN_%d" % i, Vector3(x, 0.0, NORTH_WALL_Z), 0.0, 1.0)
		_model(root, DUNGEON % CRYPT_NORTH_WALLS[(i + 3) % CRYPT_NORTH_WALLS.size()], "CryptWallS_%d" % i, Vector3(x, 0.0, SOUTH_WALL_Z), PI, 1.0)
	for i in range(CRYPT_SIDE_WALLS.size()):
		var z := -12.0 + float(i) * 4.0
		_model(root, DUNGEON % CRYPT_SIDE_WALLS[i], "CryptWallE_%d" % i, Vector3(EAST_WALL_X, 0.0, z), -PI * 0.5, 1.0)
		_model(root, DUNGEON % CRYPT_SIDE_WALLS[(i + 2) % CRYPT_SIDE_WALLS.size()], "CryptWallW_%d" % i, Vector3(WEST_WALL_X, 0.0, z), PI * 0.5, 1.0)
	# Banners and torches hang on the wall faces; four warm lights keep the cost low on phones.
	_model(root, DUNGEON % "banner_red", "CryptBannerN_W", Vector3(-9.0, 0.2, -14.5), 0.0, 1.0)
	_model(root, DUNGEON % "banner_blue", "CryptBannerN_E", Vector3(9.0, 0.2, -14.5), 0.0, 1.0)
	_model(root, DUNGEON % "banner_blue", "CryptBannerS_W", Vector3(-9.0, 0.2, 14.5), PI, 1.0)
	_model(root, DUNGEON % "banner_red", "CryptBannerS_E", Vector3(9.0, 0.2, 14.5), PI, 1.0)
	for x in [-14.0, -5.0, 5.0, 14.0]:
		_model(root, DUNGEON % "torch_mounted", "CryptTorchN_%d" % int(x), Vector3(x, 2.2, -14.1), 0.0, 1.0)
		_model(root, DUNGEON % "torch_mounted", "CryptTorchS_%d" % int(x), Vector3(x, 2.2, 14.1), PI, 1.0)
	for z in [-8.0, 8.0]:
		_model(root, DUNGEON % "torch_mounted", "CryptTorchE_%d" % int(z), Vector3(17.1, 2.2, z), -PI * 0.5, 1.0)
		_model(root, DUNGEON % "torch_mounted", "CryptTorchW_%d" % int(z), Vector3(-17.1, 2.2, z), PI * 0.5, 1.0)
	for corner in [Vector2(-15.0, -11.0), Vector2(15.0, -11.0), Vector2(-15.0, 11.0), Vector2(15.0, 11.0)]:
		_light(root, "CryptTorchLight", Vector3(corner.x, 3.0, corner.y), Color("#FFB45E"))


# --------------------------------------------------------------------------------------------- Outpost

## {model, name, x, z, yaw, scale, y_offset, size (collision box, world axes)}
const OUTPOST_PROPS := [
	["basemodule_A", "OutpostModule_NW", -14.5, -12.3, 0.0, 2.4, 0.0, Vector3(5.4, 2.4, 5.2)],
	["basemodule_D", "OutpostModule_NE", 14.7, -12.3, 0.0, 2.4, 0.0, Vector3(5.85, 2.4, 5.1)],
	["cargodepot_A", "OutpostDepot_SW", -15.4, 12.5, 0.0, 2.0, 0.0, Vector3(4.14, 2.24, 4.16)],
	["cargodepot_B", "OutpostDepot_SE", 15.4, 12.5, 0.0, 2.0, 0.0, Vector3(4.16, 2.04, 4.36)],
	["windturbine_tall", "OutpostTurbine_N", 0.0, -13.2, 0.0, 2.2, 1.08, Vector3(3.7, 4.86, 2.2)],
	["spacetruck", "OutpostTruck_E", 15.8, 2.5, 0.0, 3.0, 0.27, Vector3(1.5, 1.74, 2.7)],
	["spacetruck_large", "OutpostTruck_W", -15.8, 2.5, 0.0, 3.0, 0.33, Vector3(1.5, 2.0, 3.1)],
	["cargo_A_stacked", "OutpostCargo_E", 15.6, -2.5, 0.0, 2.0, 0.02, Vector3(2.04, 2.04, 2.04)],
	["cargo_A_stacked", "OutpostCargo_W", -15.6, -2.5, 0.0, 2.0, 0.02, Vector3(2.04, 2.04, 2.04)],
	["solarpanel", "OutpostSolar_SW", -9.0, 13.1, 0.0, 3.0, 0.0, Vector3(2.7, 1.11, 1.35)],
	["solarpanel", "OutpostSolar_SE", 9.0, 13.1, 0.0, 3.0, 0.0, Vector3(2.7, 1.11, 1.35)],
	["rock_B", "OutpostRock_NW", -7.0, -13.1, 0.0, 3.0, 0.0, Vector3(2.1, 1.2, 2.4)],
	["rock_B", "OutpostRock_NE", 7.0, -13.1, 0.0, 3.0, 0.0, Vector3(2.1, 1.2, 2.4)],
	["structure_tall", "OutpostStructure_S", 0.0, 13.2, 0.0, 1.8, 0.0, Vector3(3.15, 3.6, 3.15)],
]


static func _build_outpost(root: Node3D, visuals: bool) -> void:
	for prop in OUTPOST_PROPS:
		var size: Vector3 = prop[7]
		var scale_value := float(prop[5])
		var floor_offset := float(prop[6])
		var base := Vector3(float(prop[2]), 0.0, float(prop[3]))
		# Collider stands on the floor; the model origin sits floor_offset higher when its mesh dips below it.
		_solid(root, str(prop[1]), base + Vector3(0.0, size.y * 0.5, 0.0), size)
		if visuals:
			_model(root, SPACE % str(prop[0]), str(prop[1]) + "_Model", base + Vector3(0.0, floor_offset, 0.0), float(prop[4]), scale_value)
	if not visuals:
		return
	var pads: Array[Transform3D] = []
	for ix in range(-4, 5):
		for iz in range(-3, 4):
			pads.append(Transform3D(Basis.from_scale(Vector3(1.6, 1.0, 1.6)), Vector3(float(ix) * 4.0, -0.1, float(iz) * 4.0)))
	_multimesh(root, "OutpostDeckPlates", SPACE % "roofmodule_base", pads)
	for corner in [Vector2(-9.0, -13.4), Vector2(9.0, -13.4), Vector2(-16.0, 7.0), Vector2(16.0, 7.0)]:
		_light(root, "OutpostBeaconLight", Vector3(corner.x, 3.2, corner.y), Color("#6FD8FF"))


# ------------------------------------------------------------------------------------------- helpers

static func _solid(root: Node3D, node_name: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)


static func _model(root: Node3D, path: String, node_name: String, origin: Vector3, yaw: float, scale_value: float) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.name = node_name
	model.position = origin
	model.rotation.y = yaw
	model.scale = Vector3.ONE * scale_value
	root.add_child(model)


## One draw call for many copies of a model's first mesh (floor tiles and deck plates).
static func _multimesh(root: Node3D, node_name: String, path: String, transforms: Array[Transform3D]) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate() as Node3D
	var source: MeshInstance3D = null
	for candidate in instance.find_children("*", "MeshInstance3D", true, false):
		source = candidate as MeshInstance3D
		break
	if source == null:
		instance.free()
		return
	# Keep the mesh's own offset inside the model (KayKit exports are almost always identity).
	var local := Transform3D.IDENTITY
	var cursor: Node = source
	while cursor != null and cursor != instance:
		if cursor is Node3D:
			local = (cursor as Node3D).transform * local
		cursor = cursor.get_parent()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = source.mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i] * local)
	var holder := MultiMeshInstance3D.new()
	holder.name = node_name
	holder.multimesh = batch
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(holder)
	instance.free()


static func _light(root: Node3D, node_name: String, position: Vector3, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 9.0
	light.shadow_enabled = false
	root.add_child(light)
