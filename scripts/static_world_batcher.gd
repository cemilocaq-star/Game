extends RefCounted
## Batches only opaque, untextured, static world boxes. Physics bodies and source
## nodes stay intact; animated props, imported models and transparent water are excluded.
static func batch_boxes(root: Node3D) -> Dictionary:
	var groups: Dictionary = {}
	_collect(root, Transform3D.IDENTITY, groups)
	var saved := 0
	var batches := 0
	for key in groups:
		var entries: Array = groups[key]
		if entries.size() < 4:
			continue
		var source: MeshInstance3D = entries[0].node
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = entries.size()
		for i in entries.size():
			instances.set_instance_transform(i, entries[i].transform)
			entries[i].node.visible = false
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticBoxBatch_%d" % batches
		batch.multimesh = instances
		batch.material_override = source.material_override
		batch.layers = source.layers
		batch.cast_shadow = source.cast_shadow
		root.add_child(batch)
		saved += entries.size() - 1
		batches += 1
	return {"batches":batches,"draws_saved":saved}

static func _collect(node: Node, transform: Transform3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var next := transform * (child as Node3D).transform
		if child is MeshInstance3D and child.mesh is BoxMesh and child.visible:
			var mat := child.material_override as StandardMaterial3D
			if mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_texture == null and not mat.normal_enabled:
				var key := str([mat.albedo_color,mat.roughness,mat.metallic,mat.emission_enabled,mat.emission,mat.emission_energy_multiplier,child.layers,child.cast_shadow])
				if not groups.has(key): groups[key] = []
				var size: Vector3 = child.mesh.size
				groups[key].append({"node":child,"transform":next * Transform3D(Basis.from_scale(size),Vector3.ZERO)})
		_collect(child,next,groups)
