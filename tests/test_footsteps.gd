extends SceneTree
## Footsteps: surface detection, per-map ground, wooden things by name, shared streams, and other
## players' footsteps being heard in the world.

const FOOTSTEPS := preload("res://scripts/footstep_audio.gd")
const MAP_WORLD := preload("res://scripts/map_world_builder.gd")
const ARENA_LAYOUT := preload("res://scripts/arena_layout.gd")
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const WORLD_AUDIO := preload("res://scripts/world_audio.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _floor(parent: Node, node_name: String, top: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.8, 20.0)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = top + Vector3(0.0, -0.4, 0.0)
	return body


func _run() -> void:
	# Classification of a hint.
	_check(FOOTSTEPS.classify("Metal_Door") == "metal", "metal is metal")
	_check(FOOTSTEPS.classify("SteelGrate") == "metal", "steel is metal")
	_check(FOOTSTEPS.classify("grass") == "grass", "grass is grass")
	_check(FOOTSTEPS.classify("OakPlank") == "wood", "plank is wood")
	_check(FOOTSTEPS.classify("snow") == "ice", "snow is ice")
	_check(FOOTSTEPS.classify("SandBank") == "dirt", "sand is dirt")
	_check(FOOTSTEPS.classify("ArenaFloor") == "stone", "an unknown name is stone")
	_check(FOOTSTEPS.classify("") == "stone", "no hint is stone")

	# Every map has a ground, and the maps do not all sound the same.
	var seen := {}
	for map_index in range(7):
		var ground: String = FOOTSTEPS.ground_for_map(map_index)
		_check(FOOTSTEPS.SURFACES.has(ground), "map %d has a known ground (%s)" % [map_index, ground])
		seen[ground] = true
	_check(seen.size() >= 4, "the seven maps use at least four different grounds (%d)" % seen.size())
	_check(FOOTSTEPS.ground_for_map(99) == "stone", "an unknown map falls back to stone")
	_check(FOOTSTEPS.surface_for("RopeBridge_East", 5) == "wood", "a bridge is wood on any map")
	_check(FOOTSTEPS.surface_for("TreehouseDeck", 5) == "wood", "a treehouse is wood")
	_check(FOOTSTEPS.surface_for("ArenaFloor", 3) == "ice", "a plain floor takes the map's ground")
	_check(FOOTSTEPS.surface_for("Slice", 4) == "dirt", "a name that merely contains 'ice' is not ice")

	# tag_tree: tags untagged bodies, keeps what is already set (meta or group), ignores non-bodies.
	var tree_root := Node3D.new()
	root.add_child(tree_root)
	var plain := _floor(tree_root, "ArenaFloor")
	var preset := _floor(tree_root, "Special")
	preset.set_meta("surface_type", "metal")
	var grouped := _floor(tree_root, "Grouped")
	grouped.add_to_group("surface_wood")
	var nested := Node3D.new()
	tree_root.add_child(nested)
	var deep := _floor(nested, "DeepBridge")
	var tagged: int = FOOTSTEPS.tag_tree(tree_root, 4)
	_check(tagged == 2, "tag_tree tags only the two untagged bodies (%d)" % tagged)
	_check(str(plain.get_meta("surface_type")) == "dirt", "a plain floor gets the map ground")
	_check(str(preset.get_meta("surface_type")) == "metal", "an existing surface is kept")
	_check(not grouped.has_meta("surface_type"), "a body with a surface group is left alone")
	_check(str(deep.get_meta("surface_type")) == "wood", "a nested bridge is wood")
	_check(FOOTSTEPS.tag_tree(tree_root, 4) == 0, "tagging twice changes nothing")

	# Generated maps: every solid body ends up with a surface, and the Jungle has wooden parts.
	for map_index in range(7):
		var holder := Node3D.new()
		root.add_child(holder)
		var world: Node3D = MAP_WORLD.build(holder, map_index, false)
		var base := ARENA_LAYOUT.build_collision(holder, map_index)
		var count: int = FOOTSTEPS.tag_tree(world, map_index) + FOOTSTEPS.tag_tree(base, map_index)
		var untagged := 0
		var wooden := 0
		for body in holder.find_children("*", "StaticBody3D", true, false):
			if not body.has_meta("surface_type"):
				untagged += 1
			elif str(body.get_meta("surface_type")) == "wood":
				wooden += 1
		_check(count > 10, "map %d: bodies were tagged (%d)" % [map_index, count])
		_check(untagged == 0, "map %d: every solid has a surface (%d without)" % [map_index, untagged])
		if map_index == 5:
			_check(wooden > 0, "the Jungle Arena has wooden walkways (%d)" % wooden)
		holder.queue_free()

	# Detection with real physics. The tagging floors above sit at the origin too, so remove them first.
	tree_root.free()
	var physics_root := Node3D.new()
	root.add_child(physics_root)
	var metal_floor := _floor(physics_root, "ArenaFloor")
	metal_floor.set_meta("surface_type", "metal")
	var wood_floor := _floor(physics_root, "Walkway", Vector3(40.0, 0.0, 0.0))
	wood_floor.add_to_group("surface_wood")
	var named_floor := _floor(physics_root, "GrassPatch", Vector3(80.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	var world_3d := root.get_world_3d()
	_check(FOOTSTEPS.detect(world_3d, Vector3(0, 0, 0)) == "metal", "a floor's meta decides the surface")
	_check(FOOTSTEPS.detect(world_3d, Vector3(40, 0, 0)) == "wood", "a surface group decides the surface")
	_check(FOOTSTEPS.detect(world_3d, Vector3(80, 0, 0)) == "grass", "the collider name decides when nothing else does")
	_check(FOOTSTEPS.detect(world_3d, Vector3(500, 0, 0)) == "stone", "nothing underfoot is stone")
	_check(FOOTSTEPS.detect(null, Vector3.ZERO) == "stone", "no world is stone")
	var excluded: Array[RID] = [metal_floor.get_rid()]
	_check(FOOTSTEPS.detect(world_3d, Vector3(0, 0, 0), excluded) == "stone", "an excluded body is not the surface")

	# Streams: made once, one per surface, and they differ.
	var first: AudioStreamWAV = FOOTSTEPS.stream("metal")
	_check(first == FOOTSTEPS.stream("metal"), "a surface's stream is made once and kept")
	_check(first.data.size() > 1000, "a step has some length")
	var differing := 0
	for surface in FOOTSTEPS.SURFACES:
		if (FOOTSTEPS.stream(surface) as AudioStreamWAV).data != first.data:
			differing += 1
	_check(differing == FOOTSTEPS.SURFACES.size() - 1, "every surface sounds different from metal (%d)" % differing)
	_check(FOOTSTEPS.step_distance(9.0, 6.0) > FOOTSTEPS.step_distance(4.0, 6.0), "a sprint stride is longer than a walking one")

	# Other players' footsteps.
	var host := Node3D.new()
	root.add_child(host)
	var remote := REMOTE.new()
	host.add_child(remote)
	remote.global_position = Vector3.ZERO
	var steps_before := host.find_children("*", "AudioStreamPlayer3D", false, false).size()
	remote.call("_update_footsteps", 0.0, 1.0 / 60.0)
	remote.call("_update_footsteps", 0.5, 2.0)
	_check(host.find_children("*", "AudioStreamPlayer3D", false, false).size() == steps_before, "standing still or creeping makes no footstep")
	var walked := 0
	for frame in range(120):
		remote.call("_update_footsteps", 6.0, 1.0 / 60.0)
	walked = host.find_children("*", "AudioStreamPlayer3D", false, false).size()
	_check(walked >= 6, "walking 12 m makes about one step per 1.55 m (%d)" % walked)
	_check(walked <= 8, "and not a footstep every frame (%d)" % walked)
	var step_sound := host.find_children("*", "AudioStreamPlayer3D", false, false)[0] as AudioStreamPlayer3D
	_check(step_sound.has_meta("sound_path"), "a remote footstep goes through the sound paths")
	_check(step_sound.stream == FOOTSTEPS.stream("metal"), "a remote footstep uses the surface underfoot")
	var count_after_walk := walked
	remote.set("_sliding", true)
	for frame in range(120):
		remote.call("_update_footsteps", 6.0, 1.0 / 60.0)
	_check(host.find_children("*", "AudioStreamPlayer3D", false, false).size() == count_after_walk, "a sliding player makes no footsteps")
	remote.set("_sliding", false)
	remote.set("_grounded", false)
	for frame in range(120):
		remote.call("_update_footsteps", 6.0, 1.0 / 60.0)
	_check(host.find_children("*", "AudioStreamPlayer3D", false, false).size() == count_after_walk, "a player in the air makes no footsteps")
	remote.set("_grounded", true)
	remote.set("_dead", true)
	for frame in range(120):
		remote.call("_update_footsteps", 6.0, 1.0 / 60.0)
	_check(host.find_children("*", "AudioStreamPlayer3D", false, false).size() == count_after_walk, "a defeated player makes no footsteps")
	_check(WORLD_AUDIO.listener_exclusions(null).is_empty(), "no node, nothing to exclude")

	if failures.is_empty():
		print("PASS: footsteps (surfaces per map, wood by name, shared streams, remote players heard in the world)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
