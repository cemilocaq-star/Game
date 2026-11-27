extends SceneTree
## The two KayKit maps (7 Crypt Dungeon, 8 Orbital Outpost): the asset library, collision on the server,
## models on the client, and that no solid blocks a spawn, an orb pickup or an energy site.

const MAPS := preload("res://scripts/kaykit_maps.gd")
const WORLD := preload("res://scripts/map_world_builder.gd")
const LAYOUT := preload("res://scripts/arena_layout.gd")

var failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)


func _count_models(path: String) -> int:
	var total := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	for file in dir.get_files():
		if file.get_extension() in ["glb", "gltf"]:
			total += 1
	for sub in dir.get_directories():
		total += _count_models(path.path_join(sub))
	return total


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := _count_models("res://assets/models")
	_check(library >= 50, "at least 50 imported models in the library (%d)" % library)
	_check(FileAccess.file_exists("res://assets/models/CREDITS.md"), "model credits file present")
	_check(LAYOUT.MAP_COUNT >= 9, "the two new maps are registered")
	_check(LAYOUT.map_name(7) == "CRYPT DUNGEON" and LAYOUT.map_name(8) == "ORBITAL OUTPOST", "new map names")

	var host := Node3D.new()
	root.add_child(host)
	for map_index in [MAPS.CRYPT_MAP, MAPS.OUTPOST_MAP]:
		var server_world: Node3D = WORLD.build(host, map_index, false)
		var client_world: Node3D = WORLD.build(host, map_index, true)
		var boxes := MAPS.solid_boxes(map_index)
		var server_bodies := server_world.find_children("*", "StaticBody3D", true, false)
		_check(server_bodies.size() >= boxes.size(), "map %d: server has collision for every prop" % map_index)
		_check(server_world.find_children("*", "MeshInstance3D", true, false).size() < client_world.find_children("*", "MeshInstance3D", true, false).size(),
			"map %d: models only on the client" % map_index)
		var model_meshes := 0
		for node in client_world.find_children("*_Model", "Node3D", true, false):
			model_meshes += node.find_children("*", "MeshInstance3D", true, false).size()
		_check(model_meshes >= boxes.size(), "map %d: every solid prop has a loaded model (%d meshes)" % [map_index, model_meshes])
		_check(not client_world.find_children("*", "MultiMeshInstance3D", true, false).is_empty(), "map %d: floor is one batched mesh" % map_index)
		_check(client_world.find_children("*", "OmniLight3D", true, false).size() <= 4, "map %d: at most four lights" % map_index)

		# Nothing solid may sit on a spawn, an orb or an energy site.
		for team in ["red", "blue", "ffa"]:
			for slot in range(16):
				var spawn: Vector3 = LAYOUT.spawn_position(map_index, team, slot)
				for box in boxes:
					_check(not box.grow(0.6).has_point(Vector3(spawn.x, 0.5, spawn.z)), "map %d: %s spawn %d is clear of %s" % [map_index, team, slot, str(box)])
		for orb in LAYOUT.orb_positions(map_index):
			for box in boxes:
				_check(not box.grow(0.8).has_point(orb), "map %d: orb %s is clear of %s" % [map_index, str(orb), str(box)])
		for site_id in ["A", "B"]:
			var site: Vector3 = LAYOUT.objective_site(map_index, site_id)
			var pad := AABB(Vector3(site.x - 2.5, 0.0, site.z - 2.5), Vector3(5.0, 2.0, 5.0))
			for box in boxes:
				_check(not pad.intersects(box), "map %d: energy site %s is clear of %s" % [map_index, site_id, str(box)])
		# Props stay inside the arena.
		for box in boxes:
			_check(box.position.x > -18.0 and box.end.x < 18.0 and box.position.z > -15.5 and box.end.z < 15.5, "map %d: prop inside the arena %s" % [map_index, str(box)])
		client_world.free()
		server_world.free()

	if failures.is_empty():
		print("PASS: KayKit maps (%d models in the library)" % library)
		quit(0)
	else:
		quit(1)
