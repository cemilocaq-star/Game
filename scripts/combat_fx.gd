extends RefCounted
## Lightweight client-only combat impact visuals. No collision or damage logic.

static func grenade_explosion(parent: Node3D, world_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "GrenadeExplosionFX"
	parent.add_child(root)
	root.global_position = world_position

	var flash := OmniLight3D.new()
	flash.light_color = Color("#FF9B45")
	flash.light_energy = 5.0
	flash.omni_range = 10.0
	root.add_child(flash)

	var core_material := _fx_material(Color("#FF8A36"), 3.2)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.42
	core_mesh.height = 0.84
	core.mesh = core_mesh
	core.material_override = core_material
	root.add_child(core)

	var ring_material := _fx_material(Color("#FFD08A"), 2.2)
	var ring := MeshInstance3D.new()
	ring.name = "ExpandingShockRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.34
	ring_mesh.outer_radius = 0.46
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90.0
	ring.material_override = ring_material
	root.add_child(ring)

	var smoke_material := _fx_material(Color(0.22, 0.27, 0.32, 0.56), 0.0)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for index in range(5):
		var smoke := MeshInstance3D.new()
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.28 + float(index % 3) * 0.07
		smoke_mesh.height = smoke_mesh.radius * 2.0
		smoke.mesh = smoke_mesh
		smoke.material_override = smoke_material
		smoke.position = Vector3(
			cos(float(index) * TAU / 5.0) * 0.28,
			0.12 + float(index % 2) * 0.16,
			sin(float(index) * TAU / 5.0) * 0.28
		)
		root.add_child(smoke)
		var smoke_tween := root.create_tween()
		smoke_tween.set_parallel(true)
		smoke_tween.tween_property(smoke, "position", smoke.position + Vector3(0, 1.0 + float(index % 3) * 0.18, 0), 0.75)
		smoke_tween.tween_property(smoke, "scale", Vector3.ONE * 2.6, 0.75)
		smoke_tween.tween_property(smoke_material, "albedo_color:a", 0.0, 0.75)

	for index in range(10):
		var spark := MeshInstance3D.new()
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.045, 0.045, 0.22)
		spark.mesh = spark_mesh
		spark.material_override = _fx_material(Color("#FFD477"), 3.8)
		root.add_child(spark)
		var angle := TAU * float(index) / 10.0
		var direction := Vector3(cos(angle), 0.25 + float(index % 3) * 0.22, sin(angle)).normalized()
		spark.look_at(spark.global_position + direction, Vector3.UP)
		var spark_tween := root.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", direction * (2.0 + float(index % 4) * 0.28), 0.36)
		spark_tween.tween_property(spark, "scale", Vector3(0.2, 0.2, 0.2), 0.36)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3.ONE * 7.5, 0.30)
	tween.tween_property(core_material, "albedo_color:a", 0.0, 0.30)
	tween.tween_property(ring, "scale", Vector3.ONE * 8.0, 0.42)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, 0.42)
	tween.tween_property(flash, "light_energy", 0.0, 0.30)
	tween.chain().tween_interval(0.42)
	tween.tween_callback(root.queue_free)


static func hit_impact(parent: Node3D, world_position: Vector3, weapon_id: String = "aether", tint: Color = Color("#72F6FF")) -> void:
	var root := Node3D.new()
	root.name = "ArcadeWeaponImpactFX_" + weapon_id
	parent.add_child(root)
	root.global_position = world_position
	var flash := OmniLight3D.new()
	flash.light_color = tint
	flash.light_energy = 2.2
	flash.omni_range = 2.8
	root.add_child(flash)

	var material := _fx_material(tint, 3.0)
	var core := MeshInstance3D.new()
	core.name = "ImpactCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.10
	core_mesh.height = 0.20
	core.mesh = core_mesh
	core.material_override = material
	root.add_child(core)

	var ring := MeshInstance3D.new()
	ring.name = "ImpactPulseRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.12
	ring_mesh.outer_radius = 0.19
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90.0
	ring.material_override = material
	root.add_child(ring)

	# Distinct silhouettes make the 23 archetypes readable without changing hit logic.
	var shard_count := 6
	var shard_shape := "orb"
	match weapon_id:
		"pixel_storm", "glitch_ray":
			shard_count = 8
			shard_shape = "pixel"
		"bubble_burst", "slime_slinger", "jellyfish_staff":
			shard_count = 5
			shard_shape = "bubble"
		"meteor_mallet", "thunder_drum", "hand_cannon":
			shard_count = 7
			shard_shape = "spark"
		"moon_disc", "banana_boomerang", "vortex_orbiter":
			shard_count = 4
			shard_shape = "disc"
		"duck_launcher", "rubber_chicken", "confetti_cannon":
			shard_count = 9
			shard_shape = "confetti"
	for index in range(shard_count):
		var shard := MeshInstance3D.new()
		shard.name = "ImpactShard_%02d" % index
		var shard_mesh: Mesh
		if shard_shape == "pixel" or shard_shape == "confetti":
			var block := BoxMesh.new()
			block.size = Vector3(0.055, 0.055, 0.055) if shard_shape == "pixel" else Vector3(0.045, 0.08, 0.035)
			shard_mesh = block
		elif shard_shape == "disc":
			var disc := CylinderMesh.new()
			disc.top_radius = 0.045
			disc.bottom_radius = 0.045
			disc.height = 0.025
			shard_mesh = disc
		else:
			var orb := SphereMesh.new()
			orb.radius = 0.045 if shard_shape == "spark" else 0.06
			orb.height = orb.radius * 2.0
			shard_mesh = orb
		shard.mesh = shard_mesh
		shard.material_override = material
		var angle := TAU * float(index) / float(shard_count)
		var direction := Vector3(cos(angle), 0.25 + float(index % 3) * 0.16, sin(angle)).normalized()
		shard.position = direction * 0.12
		root.add_child(shard)
		var shard_tween := root.create_tween()
		shard_tween.set_parallel(true)
		shard_tween.tween_property(shard, "position", direction * (0.48 + float(index % 3) * 0.08), 0.22)
		shard_tween.tween_property(shard, "scale", Vector3.ONE * 0.18, 0.22)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3.ONE * 2.8, 0.18)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.24)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.tween_property(flash, "light_energy", 0.0, 0.16)
	tween.chain().tween_interval(0.08)
	tween.tween_callback(root.queue_free)


static func _fx_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = emission_energy > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material
