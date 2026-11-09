extends Node3D
## Lightweight, original event visuals and synthesized ambience for OxenWar.
## All effects are generated from Godot primitives; no third-party audio is streamed.

var _effect_root: Node3D
var _music: AudioStreamPlayer
var _active_event := ""

func set_event(event_id: String) -> void:
	if event_id == _active_event:
		return
	_active_event = event_id
	_clear_effects()
	if event_id.is_empty():
		return
	_effect_root = Node3D.new()
	_effect_root.name = "EventFX_" + event_id
	add_child(_effect_root)
	match event_id:
		"ICE_WORLD", "FREEZE_FRAME":
			_build_ice_world(event_id == "FREEZE_FRAME")
		"CONFETTI_STORM":
			_build_confetti()
		"LOW_GRAVITY":
			_build_low_gravity()
		"GOLDEN_ORB_RUSH", "DOUBLE_XP":
			_build_reward_aura(event_id == "GOLDEN_ORB_RUSH")
		"METEOR_SHOWER":
			_build_stars()
		"PINK_SKY":
			_build_pink_sky()
		"BONK_MODE":
			_build_bonk_mode()
		"NPC_MODE":
			_build_npc_mode()
		"DUCK_PARADE", "DUCK_EXE":
			_build_duck_sparkles()
	_build_event_artifact(event_id)
	if event_id in ["ICE_WORLD", "FREEZE_FRAME", "CONFETTI_STORM", "LOW_GRAVITY", "GOLDEN_ORB_RUSH", "DOUBLE_XP", "METEOR_SHOWER", "DUCK_PARADE", "DUCK_EXE", "BONK_MODE", "PINK_SKY", "NPC_MODE"]:
		_start_synth_music(event_id)

func _clear_effects() -> void:
	if is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
	_music = null
	if is_instance_valid(_effect_root):
		_effect_root.queue_free()
	_effect_root = null

func _build_event_artifact(event_id: String) -> void:
	# Original, lightweight 3D centerpiece for each event. Geometry is generated
	# locally so events do not depend on remote downloads or runtime network access.
	var artifact := Node3D.new()
	artifact.name = "EventArtifact_" + event_id
	artifact.position = Vector3(0, 3.1, -1.8)
	_effect_root.add_child(artifact)
	var color := Color(0.25, 0.85, 1.0)
	match event_id:
		"ICE_WORLD", "FREEZE_FRAME":
			color = Color(0.42, 0.88, 1.0)
			for i in range(3):
				var crystal := PrismMesh.new()
				crystal.size = Vector3(0.65, 1.7 + float(i) * 0.25, 0.65)
				_artifact_part(artifact, crystal, color, Vector3((i - 1) * 0.58, 0.0, 0.0))
		"CONFETTI_STORM":
			for i in range(5):
				var tile := BoxMesh.new()
				tile.size = Vector3(0.48, 0.48, 0.12)
				var colors := [Color(1.0,0.3,0.6), Color(1.0,0.75,0.2), Color(0.25,0.8,1.0), Color(0.45,1.0,0.45), Color(0.7,0.4,1.0)]
				_artifact_part(artifact, tile, colors[i], Vector3(cos(float(i) * TAU / 5.0), sin(float(i) * TAU / 5.0), 0.0))
		"LOW_GRAVITY":
			var low_core := SphereMesh.new()
			low_core.radius = 0.58
			low_core.height = 1.16
			_artifact_part(artifact, low_core, color, Vector3.ZERO)
			for i in range(3):
				var low_ring := TorusMesh.new()
				low_ring.inner_radius = 0.72 + float(i) * 0.18
				low_ring.outer_radius = low_ring.inner_radius + 0.055
				var low_part := _artifact_part(artifact, low_ring, color.lightened(float(i) * 0.12), Vector3.ZERO)
				low_part.rotation_degrees.x = 55.0 + float(i) * 35.0
		"GOLDEN_ORB_RUSH", "DOUBLE_XP":
			color = Color(1.0, 0.72, 0.16) if event_id == "GOLDEN_ORB_RUSH" else Color(0.35, 1.0, 0.68)
			var reward_orb := SphereMesh.new()
			reward_orb.radius = 0.68
			reward_orb.height = 1.36
			_artifact_part(artifact, reward_orb, color, Vector3.ZERO)
			for i in range(2):
				var reward_halo := TorusMesh.new()
				reward_pink_halo.inner_radius = 0.86 + float(i) * 0.18
				reward_halo.outer_radius = reward_halo.inner_radius + 0.06
				var reward_part := _artifact_part(artifact, reward_halo, color.lightened(0.12), Vector3.ZERO)
				reward_part.rotation_degrees.x = 65.0 if i == 0 else -65.0
		"METEOR_SHOWER":
			color = Color(1.0, 0.38, 0.12)
			var core := SphereMesh.new()
			core.radius = 0.55
			core.height = 1.1
			_artifact_part(artifact, core, color, Vector3.ZERO)
			var meteor_tail := CylinderMesh.new()
			meteor_tail.top_radius = 0.04
			meteor_tail.bottom_radius = 0.36
			meteor_tail.height = 1.8
			var tail_part := _artifact_part(artifact, meteor_tail, Color(1.0, 0.68, 0.2), Vector3(0.0, 0.9, 0.0))
			tail_part.rotation_degrees.z = 22.0
		"BONK_MODE":
			color = Color(1.0, 0.56, 0.12)
			var bonk_handle := CylinderMesh.new()
			bonk_handle.top_radius = 0.07
			bonk_handle.bottom_radius = 0.09
			bonk_handle.height = 1.55
			var bonk_handle_part := _artifact_part(artifact, bonk_handle, Color(0.62, 0.42, 0.22), Vector3(0.0, -0.25, 0.0))
			bonk_handle_part.rotation_degrees.z = -25.0
			var bonk_head := BoxMesh.new()
			bonk_head.size = Vector3(1.15, 0.58, 0.62)
			_artifact_part(artifact, bonk_head, color, Vector3(0.3, 0.5, 0.0))
		"NPC_MODE":
			color = Color(0.3, 1.0, 0.52)
			var npc_stem := CylinderMesh.new()
			npc_stem.top_radius = 0.08
			npc_stem.bottom_radius = 0.08
			npc_stem.height = 1.2
			_artifact_part(artifact, npc_stem, color, Vector3(0.0, -0.15, 0.0))
			var npc_marker := SphereMesh.new()
			npc_marker.radius = 0.42
			npc_marker.height = 0.84
			_artifact_part(artifact, npc_marker, Color(1.0, 0.9, 0.25), Vector3(0.0, 0.65, 0.0))
		"PINK_SKY":
			color = Color(1.0, 0.28, 0.72)
			var core := SphereMesh.new()
			core.radius = 0.48
			core.height = 0.96
			_artifact_part(artifact, core, color, Vector3.ZERO)
			var pink_halo := TorusMesh.new()
			halo.inner_radius = 0.8
			pink_halo.outer_radius = 0.88
			var ring_part := _artifact_part(artifact, pink_halo, Color(1.0, 0.68, 0.9), Vector3.ZERO)
			ring_part.rotation_degrees.x = 62.0
		"DUCK_PARADE", "DUCK_EXE":
			color = Color(1.0, 0.82, 0.24)
			var duck_body_mesh := SphereMesh.new()
			duck_body_mesh.radius = 0.55
			duck_body_mesh.height = 0.85
			_artifact_part(artifact, duck_body_mesh, color, Vector3.ZERO, Vector3(1.25, 0.9, 0.9))
			var duck_beak := PrismMesh.new()
			duck_beak.size = Vector3(0.36, 0.22, 0.28)
			_artifact_part(artifact, duck_beak, Color(1.0, 0.42, 0.08), Vector3(0.0, 0.0, -0.52))
	var motion := create_tween().set_loops()
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(artifact, "position:y", 3.55, 0.85)
	motion.parallel().tween_property(artifact, "rotation:y", TAU, 2.8)
	motion.tween_property(artifact, "position:y", 3.1, 0.85)

func _artifact_part(parent: Node3D, mesh: Mesh, color: Color, position: Vector3, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = position
	part.scale = scale
	part.material_override = _emissive_material(color)
	parent.add_child(part)
	return part

func _build_ice_world(freeze_burst: bool) -> void:
	var floor_fx := MeshInstance3D.new()
	floor_fx.name = "FrostedArenaFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 28.0)
	floor_fx.mesh = plane
	floor_fx.position = Vector3(0, 0.025, 0)
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.25, 0.78, 1.0, 0.24 if not freeze_burst else 0.34)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	ice.metallic = 0.18
	ice.roughness = 0.22
	ice.emission_enabled = true
	ice.emission = Color(0.08, 0.45, 0.8)
	ice.emission_energy_multiplier = 0.45
	floor_fx.material_override = ice
	_effect_root.add_child(floor_fx)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4404 if freeze_burst else 2048
	for i in range(14):
		var shard := MeshInstance3D.new()
		shard.name = "IceShard_%02d" % i
		var shard_mesh := CylinderMesh.new()
		var height := rng.randf_range(0.7, 2.1 if freeze_burst else 1.6)
		shard_mesh.top_radius = 0.015
		shard_mesh.bottom_radius = rng.randf_range(0.18, 0.42)
		shard_mesh.height = height
		shard.mesh = shard_mesh
		shard.position = Vector3(rng.randf_range(-15.2, 15.2), height * 0.5, rng.randf_range(-12.2, 12.2))
		shard.rotation = Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.0, TAU), rng.randf_range(-0.16, 0.16))
		shard.material_override = ice.duplicate()
		_effect_root.add_child(shard)
		var tween := create_tween().set_loops()
		tween.tween_property(shard, "rotation:y", shard.rotation.y + TAU, rng.randf_range(3.5, 6.0))
		tween.parallel().tween_property(shard, "position:y", height * 0.5 + 0.12, 0.8)
		tween.tween_property(shard, "position:y", height * 0.5, 0.8)
	_add_particles("snowfall", Color(0.72, 0.92, 1.0, 0.9), 180)
	if freeze_burst:
		_add_particles("freeze_spark", Color(0.55, 0.9, 1.0, 1.0), 80)

func _build_confetti() -> void:
	_add_particles("confetti", Color(1.0, 0.42, 0.72, 1.0), 220)
	var glow := OmniLight3D.new()
	glow.name = "ConfettiPulse"
	glow.light_color = Color(1.0, 0.18, 0.52)
	glow.light_energy = 1.1
	glow.omni_range = 20.0
	glow.position = Vector3(0, 5, 0)
	_effect_root.add_child(glow)
	var tween := create_tween().set_loops()
	tween.tween_property(glow, "light_energy", 2.0, 0.7)
	tween.tween_property(glow, "light_energy", 0.7, 0.7)

func _build_low_gravity() -> void:
	_add_particles("float_dust", Color(0.38, 0.82, 1.0, 0.72), 100)
	for i in range(8):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.52
		torus.outer_radius = 0.58
		ring.mesh = torus
		ring.position = Vector3(cos(float(i) * TAU / 8.0) * 8.0, 1.0 + float(i % 3) * 1.2, sin(float(i) * TAU / 8.0) * 6.0)
		var material := _emissive_material(Color(0.25, 0.78, 1.0, 0.62))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = material
		_effect_root.add_child(ring)
		var tween := create_tween().set_loops()
		tween.tween_property(ring, "position:y", ring.position.y + 0.7, 1.6)
		tween.parallel().tween_property(ring, "rotation:z", 0.7, 1.6)
		tween.tween_property(ring, "position:y", ring.position.y, 1.6)
		tween.parallel().tween_property(ring, "rotation:z", 0.0, 1.6)

func _build_reward_aura(golden: bool) -> void:
	var color := Color(1.0, 0.68, 0.12) if golden else Color(0.36, 1.0, 0.68)
	_add_particles("reward_sparks", color, 90)
	var orb_positions: Array[Vector3] = [
		Vector3(-12, 1.0, -8), Vector3(-7, 2.0, -5), Vector3(0, 2.0, -10),
		Vector3(7, 2.0, -5), Vector3(12, 1.0, -8), Vector3(-10, 1.0, 5),
		Vector3(-4, 1.8, 1), Vector3(4, 1.8, 1), Vector3(10, 1.0, 5),
		Vector3(0, 2.2, 10), Vector3(-2, 1.2, -2), Vector3(2, 1.2, -2)
	]
	for i in range(orb_positions.size()):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.35
		torus.outer_radius = 0.39
		ring.mesh = torus
		ring.position = orb_positions[i] + Vector3(0, 0.22, 0)
		ring.scale = Vector3.ONE * 0.85
		ring.material_override = _emissive_material(color)
		_effect_root.add_child(ring)
		var tween := create_tween().set_loops()
		tween.tween_property(ring, "rotation:y", TAU, 2.2 + float(i) * 0.08)
		tween.parallel().tween_property(ring, "scale", Vector3.ONE * 1.15, 0.6)
		tween.tween_property(ring, "scale", Vector3.ONE * 0.85, 0.6)

func _build_stars() -> void:
	_add_particles("meteor_trails", Color(1.0, 0.48, 0.16, 0.9), 70)

func _build_pink_sky() -> void:
	_add_particles("pink_sky_glitter", Color(1.0, 0.35, 0.76, 0.8), 100)
	var glow := OmniLight3D.new()
	glow.name = "PinkSkyGlow"
	glow.light_color = Color(1.0, 0.18, 0.55)
	glow.light_energy = 1.4
	glow.omni_range = 28.0
	glow.position = Vector3(0, 8, 0)
	_effect_root.add_child(glow)
	var tween := create_tween().set_loops()
	tween.tween_property(glow, "light_energy", 2.4, 1.4)
	tween.tween_property(glow, "light_energy", 1.0, 1.4)
	for i in range(4):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.48
		torus.outer_radius = 0.52
		ring.mesh = torus
		ring.position = Vector3(0, 10.0 + float(i) * 0.35, 0)
		ring.scale = Vector3(11.0 + float(i) * 1.8, 1.0, 8.0 + float(i) * 1.3)
		ring.material_override = _emissive_material(Color(1.0, 0.25, 0.72, 0.7))
		_effect_root.add_child(ring)
		var spin := create_tween().set_loops()
		spin.tween_property(ring, "rotation:y", TAU, 8.0 + float(i) * 2.0)

func _build_bonk_mode() -> void:
	_add_particles("bonk_sparks", Color(1.0, 0.55, 0.12, 0.9), 100)
	for i in range(5):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.48
		ring.mesh = torus
		ring.position = Vector3(cos(float(i) * TAU / 5.0) * 7.0, 0.4 + float(i % 2), sin(float(i) * TAU / 5.0) * 6.0)
		ring.material_override = _emissive_material(Color(1.0, 0.48, 0.08))
		_effect_root.add_child(ring)
		var bounce := create_tween().set_loops()
		bounce.tween_property(ring, "position:y", ring.position.y + 0.8, 0.35)
		bounce.tween_property(ring, "position:y", ring.position.y, 0.35)

func _build_npc_mode() -> void:
	_add_particles("quest_sparkles", Color(0.35, 1.0, 0.54, 0.85), 90)
	for i in range(5):
		var marker := MeshInstance3D.new()
		var marker_mesh := SphereMesh.new()
		marker_mesh.radius = 0.22
		marker_mesh.height = 0.44
		marker.mesh = marker_mesh
		marker.position = Vector3(cos(float(i) * TAU / 5.0) * 9.0, 2.0, sin(float(i) * TAU / 5.0) * 7.0)
		marker.material_override = _emissive_material(Color(0.25, 1.0, 0.5))
		_effect_root.add_child(marker)
		var pulse := create_tween().set_loops()
		pulse.tween_property(marker, "scale", Vector3.ONE * 1.6, 0.55)
		pulse.tween_property(marker, "scale", Vector3.ONE, 0.55)

func _build_duck_sparkles() -> void:
	_add_particles("duck_sparkles", Color(1.0, 0.86, 0.28, 0.9), 48)

func _add_particles(effect_name: String, color: Color, amount: int) -> void:
	var particles := GPUParticles3D.new()
	particles.name = effect_name
	particles.amount = amount
	particles.lifetime = 4.0
	particles.preprocess = 1.5
	particles.explosiveness = 0.0
	particles.position = Vector3(0, 5.0, 0)
	particles.visibility_aabb = AABB(Vector3(-19, -7, -17), Vector3(38, 20, 34))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(16.0, 7.0, 13.0)
	process.direction = Vector3(0, -1, 0)
	process.spread = 28.0
	process.gravity = Vector3(0, -0.35 if effect_name in ["snowfall", "float_dust"] else 2.0, 0)
	process.initial_velocity_min = 0.6 if effect_name in ["snowfall", "float_dust"] else 1.5
	process.initial_velocity_max = 2.2 if effect_name in ["snowfall", "float_dust"] else 4.5
	process.scale_min = 0.045
	process.scale_max = 0.13
	process.color = color
	if effect_name == "confetti":
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1.0, 0.25, 0.5), Color(1.0, 0.78, 0.16), Color(0.2, 0.85, 1.0), Color(0.45, 1.0, 0.45)])
		gradient.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
		var gradient_texture := GradientTexture1D.new()
		gradient_texture.gradient = gradient
		process.color_ramp = gradient_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.albedo_color = color
	particle_material.emission_enabled = true
	particle_material.emission = color
	particle_material.emission_energy_multiplier = 0.5
	quad.material = particle_material
	particles.draw_pass_1 = quad
	_effect_root.add_child(particles)
	particles.emitting = true

func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	return material

func _start_synth_music(event_id: String) -> void:
	var notes: Array[float]
	match event_id:
		"ICE_WORLD", "FREEZE_FRAME":
			notes = [261.63, 329.63, 392.0, 329.63, 293.66, 349.23, 440.0, 349.23]
		"CONFETTI_STORM", "DUCK_PARADE", "DUCK_EXE":
			notes = [392.0, 493.88, 587.33, 493.88, 440.0, 523.25, 659.25, 523.25]
		"LOW_GRAVITY":
			notes = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63, 293.66, 220.0]
		"GOLDEN_ORB_RUSH", "DOUBLE_XP":
			notes = [329.63, 392.0, 493.88, 659.25, 493.88, 392.0, 440.0, 523.25]
		"METEOR_SHOWER":
			notes = [146.83, 174.61, 220.0, 261.63, 220.0, 174.61, 196.0, 146.83]
		"PINK_SKY", "NPC_MODE":
			notes = [293.66, 349.23, 440.0, 523.25, 440.0, 349.23, 392.0, 493.88]
		_:
			notes = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63, 293.66, 220.0]
	var sample_rate := 22050
	var note_seconds := 0.30
	var sample_count := int(float(sample_rate) * note_seconds * float(notes.size()))
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var time := float(i) / float(sample_rate)
		var note_index := mini(notes.size() - 1, int(time / note_seconds))
		var local_time := fmod(time, note_seconds)
		var envelope := 0.35 + 0.65 * sin(PI * local_time / note_seconds)
		var tone := sin(TAU * notes[note_index] * time) * 0.10
		tone += sin(TAU * notes[note_index] * 2.0 * time) * 0.025
		samples.encode_s16(i * 2, int(clampf(tone * envelope, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = samples
	_music = AudioStreamPlayer.new()
	_music.name = "OriginalEventSynth"
	_music.stream = stream
	_music.volume_db = -22.0
	add_child(_music)
	_music.play()
