extends RefCounted
## Shared arena description. The client (main.gd) draws it, and the dedicated server builds the
## same collision for every room, so both sides always agree on the walls, floors and spawn points.

const MAP_WORLD_SCRIPT := preload("res://scripts/map_world_builder.gd")

const MAP_NAMES := ["LOST MALL", "NEON CITY", "SPACE ISLANDS", "CANDY WORLD", "SUNKEN OASIS", "JUNGLE ARENA", "REDSTONE CANYON"]
const MAP_COUNT := 7
const DEFAULT_MAP := 4
const JUNGLE_MAP := 5

const ORBS_DEFAULT: Array[Vector3] = [
	Vector3(-12, 1.0, -8), Vector3(-7, 2.0, -5), Vector3(0, 2.0, -10),
	Vector3(7, 2.0, -5), Vector3(12, 1.0, -8), Vector3(-10, 1.0, 5),
	Vector3(-4, 1.8, 1), Vector3(4, 1.8, 1), Vector3(10, 1.0, 5),
	Vector3(0, 2.2, 10), Vector3(-2, 1.2, -2), Vector3(2, 1.2, -2)
]
## The Jungle Arena has a river, a waterfall cliff and raised platforms where the default orbs would
## sit inside solid rock, so it has its own pickup spots on the banks, bridges, platforms and river.
const ORBS_JUNGLE: Array[Vector3] = [
	Vector3(-12, 0.6, 0), Vector3(12, 0.6, 0), Vector3(-7, 0.6, 4),
	Vector3(7, 0.6, -4), Vector3(-7.1, 3.6, -11.85), Vector3(7.1, 3.6, 11.85),
	Vector3(-14.3, 3.6, -9.5), Vector3(14.3, 3.6, 9.5), Vector3(0, 1.1, -2.4),
	Vector3(0, -0.6, -6), Vector3(0, -0.6, 10.5), Vector3(-12, 0.6, 6)
]


static func sanitize_map(map_index: int) -> int:
	if map_index >= 0 and map_index < MAP_COUNT:
		return map_index
	return DEFAULT_MAP


static func map_name(map_index: int) -> String:
	return MAP_NAMES[sanitize_map(map_index)]


static func orb_positions(map_index: int) -> Array[Vector3]:
	return ORBS_JUNGLE if map_index == JUNGLE_MAP else ORBS_DEFAULT


## Where a player appears. `slot` spreads players that spawn together a little.
static func spawn_position(map_index: int, team_id: String, slot: int = 0) -> Vector3:
	if map_index == JUNGLE_MAP:
		# The spawn causeway is a narrow bridge over the river (x -2.4..2.4, z 6..7.6 is free).
		var jungle_x := -1.2 if team_id == "red" else (1.2 if team_id == "blue" else 0.0)
		return Vector3(jungle_x + float(slot % 4) * 0.4 - 0.6, 1.5, 6.0 + float(int(slot / 4) % 2) * 1.2)
	var offset := Vector3(float(slot % 4) * 1.6 - 2.4, 0.0, float(int(slot / 4) % 4) * 1.6)
	var team_x := -10.0 if team_id == "red" else (10.0 if team_id == "blue" else 0.0)
	return Vector3(team_x, 1.5, 6.0) + offset


## The solid base of the arena: {name, size, position, role}. Role is "floor", "wall", "stage" or
## "platform" so the client can pick a color for it.
static func base_boxes(map_index: int) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var jungle := map_index == JUNGLE_MAP
	if not jungle:
		boxes.append({"name": "ArenaFloor", "size": Vector3(36, 0.8, 30), "position": Vector3(0, -0.4, 0), "role": "floor"})
	# Jungle Arena has 3 m high platforms next to the walls, so its walls are tall enough that
	# nobody can jump over them from a treehouse or pyramid.
	var wall_height := 9.0 if jungle else 3.6
	boxes.append({"name": "NorthWall", "size": Vector3(36, wall_height, 0.9), "position": Vector3(0, wall_height * 0.5, -14.55), "role": "wall"})
	boxes.append({"name": "SouthWall", "size": Vector3(36, wall_height, 0.9), "position": Vector3(0, wall_height * 0.5, 14.55), "role": "wall"})
	boxes.append({"name": "EastWall", "size": Vector3(0.9, wall_height, 28.2), "position": Vector3(17.55, wall_height * 0.5, 0), "role": "wall"})
	boxes.append({"name": "WestWall", "size": Vector3(0.9, wall_height, 28.2), "position": Vector3(-17.55, wall_height * 0.5, 0), "role": "wall"})
	if jungle:
		# Jungle Arena builds its own floor, river and platforms in MapWorldBuilder.
		return boxes
	boxes.append({"name": "CentralStage", "size": Vector3(9, 1.2, 6.2), "position": Vector3(0, 0.6, 0), "role": "stage"})
	boxes.append({"name": "WestUpperPlatform", "size": Vector3(6.5, 1.2, 5.2), "position": Vector3(-11.2, 1.9, -5.6), "role": "platform"})
	boxes.append({"name": "EastUpperPlatform", "size": Vector3(6.5, 1.2, 5.2), "position": Vector3(11.2, 1.9, -5.6), "role": "platform"})
	boxes.append({"name": "SouthPlatform", "size": Vector3(8.2, 1.2, 4.0), "position": Vector3(0, 1.5, 9.5), "role": "platform"})
	boxes.append({"name": "NorthBridge", "size": Vector3(12, 0.8, 2.2), "position": Vector3(0, 1.8, -10), "role": "platform"})
	boxes.append({"name": "WestHop", "size": Vector3(2.2, 1.3, 2.2), "position": Vector3(-5.2, 0.65, -3.8), "role": "platform"})
	boxes.append({"name": "EastHop", "size": Vector3(2.2, 1.3, 2.2), "position": Vector3(5.2, 0.65, -3.8), "role": "platform"})
	boxes.append({"name": "SouthHop", "size": Vector3(2.2, 1.3, 2.2), "position": Vector3(-5.2, 0.65, 3.8), "role": "platform"})
	boxes.append({"name": "NorthHop", "size": Vector3(2.2, 1.3, 2.2), "position": Vector3(5.2, 0.65, 3.8), "role": "platform"})
	boxes.append({"name": "WestRampBlock", "size": Vector3(7, 0.7, 3.0), "position": Vector3(-8.3, 0.55, 0.8), "role": "platform"})
	boxes.append({"name": "EastRampBlock", "size": Vector3(7, 0.7, 3.0), "position": Vector3(8.3, 0.55, 0.8), "role": "platform"})
	return boxes


## Builds the collision of a whole map (base boxes plus the map layout) under `parent`. The server
## calls this once per room, inside that room's own physics world. Returns the holder node.
static func build_collision(parent: Node, map_index: int) -> Node3D:
	map_index = sanitize_map(map_index)
	var holder := Node3D.new()
	holder.name = "RoomArena"
	parent.add_child(holder)
	for box in base_boxes(map_index):
		var body := StaticBody3D.new()
		body.name = str(box.name)
		body.position = box.position
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		shape_node.shape = shape
		body.add_child(shape_node)
		holder.add_child(body)
	MAP_WORLD_SCRIPT.build(holder, map_index)
	return holder
