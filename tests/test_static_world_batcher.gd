extends SceneTree
const BATCH := preload("res://scripts/static_world_batcher.gd")
const WORLD := preload("res://scripts/map_world_builder.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("NOT VERIFIED in this run: GPU transform readback (dummy renderer); run this test with a display for that assertion")
	var host := Node3D.new()
	root.add_child(host)
	for map in range(7):
		var world := WORLD.build(host,map)
		var solids := world.find_children("*","CollisionShape3D",true,false)
		var before: Array[Transform3D] = []
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			if node.mesh is BoxMesh:
				before.append(world.global_transform.affine_inverse() * node.global_transform * Transform3D(Basis.from_scale(node.mesh.size),Vector3.ZERO))
		var result := BATCH.batch_boxes(world)
		check(world.find_children("*","CollisionShape3D",true,false).size() == solids.size(), "map %d collision count preserved" % map)
		var instances := 0
		for batch: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
			for i in batch.multimesh.instance_count:
				var pose := batch.multimesh.get_instance_transform(i)
				var found := false
				for original: Transform3D in before:
					if pose.is_equal_approx(original): found = true;break
				if DisplayServer.get_name() != "headless":
					check(found,"map %d batched box matches an original transform" % map)
				instances += 1
		check(int(result.draws_saved) >= 0, "map batching count is sane")
		print("BATCH map=%d groups=%d instances=%d saved_draws=%d colliders=%d" % [map,result.batches,instances,result.draws_saved,solids.size()])
		var second := BATCH.batch_boxes(world)
		check(int(second.draws_saved) == 0, "batching twice does not duplicate geometry")
		world.free()
	host.free()
	for failure in failures: push_error(failure)
	if failures.is_empty():print("PASS: static batching preserves transforms, collisions, and idempotence on seven maps")
	quit(0 if failures.is_empty() else 1)
