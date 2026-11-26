extends SceneTree

const MAP_WORLD = preload("res://scripts/map_world_builder.gd")
const ARENA_LAYOUT = preload("res://scripts/arena_layout.gd")


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var client := MAP_WORLD.build(holder, 6)
	var server := ARENA_LAYOUT.build_collision(holder, 6)
	var valid := true
	for path in [
		"res://assets/CosmicHalo_Cosmetic.glb",
		"res://assets/DuckBeacon_Mascot.glb",
		"res://assets/GoldenOrb_Collectible.glb",
		"res://assets/LostFoodCourt_Arena_Blockout.glb",
	]:
		var model_scene := load(path) as PackedScene
		if model_scene == null:
			push_error("Could not load supplied GLB: " + path)
			valid = false
			continue
		var model := model_scene.instantiate()
		if model.find_children("*", "MeshInstance3D", true, false).is_empty() and not model is MeshInstance3D:
			push_error("Supplied GLB has no mesh: " + path)
			valid = false
		model.free()
	for landmark_name in ["CanyonFarWestPinnacle", "CanyonFarEastPinnacle", "CanyonFarEastBoulder"]:
		var landmark := client.get_node_or_null(landmark_name) as Node3D
		if landmark == null or landmark.find_children("*", "MeshInstance3D", true, false).is_empty():
			push_error("Missing canyon render mesh: " + landmark_name)
			valid = false
		elif not landmark.find_children("*", "CollisionObject3D", true, false).is_empty():
			push_error("Landmark added collision: " + landmark_name)
			valid = false
		if not server.find_children(landmark_name, "Node3D", true, false).is_empty():
			push_error("Server instantiated render-only landmark: " + landmark_name)
			valid = false
	holder.free()
	if valid:
		print("PASS: four supplied GLBs load and canyon landmarks instantiate on clients without altering room collision")
	quit(0 if valid else 1)
