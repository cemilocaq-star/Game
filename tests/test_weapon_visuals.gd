extends SceneTree
## Regression checks for the procedural first-person arcade weapon models.

const WEAPON_VISUALS := preload("res://scripts/arcade_weapon_visuals.gd")
const MIN_PARTS := 7

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var ids: Array[String] = _registered_weapon_ids()
	_assert_true("weapon registry parsed from main.gd (%d ids)" % ids.size(), ids.size() >= 23)

	var signatures: Dictionary = {}
	var total_parts: int = 0
	for weapon_id in ids:
		var model: Node3D = WEAPON_VISUALS.build_weapon(weapon_id, Color("#27D7E7"))
		_assert_true(weapon_id + ": model created", is_instance_valid(model))
		if not is_instance_valid(model):
			continue
		_assert_true(weapon_id + ": has a dedicated model, not the fallback", model.get_node_or_null("FallbackCore") == null)

		var shape_kinds: Dictionary = {}
		var material_kinds: Dictionary = {}
		var glowing: int = 0
		var mesh_count: int = 0
		var names: Array[String] = []
		for node in _collect(model):
			names.append(str(node.name))
			if node is MeshInstance3D:
				var instance: MeshInstance3D = node as MeshInstance3D
				mesh_count += 1
				_assert_true(weapon_id + ": mesh exists on " + str(node.name), instance.mesh != null)
				if instance.mesh != null:
					shape_kinds[instance.mesh.get_class()] = true
				var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
				if material != null:
					material_kinds["%.2f_%.2f_%s" % [material.metallic, material.roughness, str(material.transparency)]] = true
					if material.emission_enabled:
						glowing += 1
		total_parts += mesh_count
		_assert_true("%s: enough parts (%d)" % [weapon_id, mesh_count], mesh_count >= MIN_PARTS)
		_assert_true(weapon_id + ": uses more than one primitive type", shape_kinds.size() >= 2)
		_assert_true(weapon_id + ": has at least two material kinds", material_kinds.size() >= 2)
		_assert_true(weapon_id + ": has an energy/emissive part", glowing >= 1)

		names.sort()
		var signature: String = ",".join(names)
		_assert_false(weapon_id + ": silhouette differs from other weapons", signatures.has(signature))
		signatures[signature] = weapon_id
		model.free()

	_assert_true("average parts per weapon is at least 9 (got %d total)" % total_parts, ids.size() > 0 and float(total_parts) / float(ids.size()) >= 9.0)

	# Node names animated by player.gd are part of the contract.
	var animated: Dictionary = {
		"vortex_orbiter": ["VortexRing", "OrbitingMoon_0", "OrbitingMoon_1", "OrbitingMoon_2"],
		"rotary_arc": ["RotaryArcFrontRing", "RotaryArcPowerCore"],
		"aether": ["AetherCell"],
		"pulse_carbine": ["PulseCore"],
		"ranger_rifle": ["RangerSideCell"],
		"heavy_sidearm": ["SidearmChargeGem"],
		"longshot": ["LongshotChargeCell"],
	}
	for weapon_id in animated.keys():
		var animated_model: Node3D = WEAPON_VISUALS.build_weapon(str(weapon_id), Color("#27D7E7"))
		for node_name in animated[weapon_id]:
			_assert_true("%s: animated node %s exists" % [weapon_id, node_name], animated_model.get_node_or_null(str(node_name)) is Node3D)
		animated_model.free()

	# Spinning rings are pivots that hold a mesh, so rotation.z spins them about their own axis.
	var vortex: Node3D = WEAPON_VISUALS.build_weapon("vortex_orbiter", Color("#27D7E7"))
	var vortex_ring: Node3D = vortex.get_node_or_null("VortexRing") as Node3D
	_assert_true("vortex ring is a pivot holding a mesh", is_instance_valid(vortex_ring) and not (vortex_ring is MeshInstance3D) and vortex_ring.get_child_count() >= 1)
	vortex.free()

	if failures.is_empty():
		print("PASS: %d arcade weapon models have dedicated multi-part meshes, mixed materials, unique silhouettes and intact animation nodes" % ids.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _registered_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	var text: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var start: int = text.find("const WEAPON_ORDER := [")
	if start < 0:
		return ids
	var finish: int = text.find("]", start)
	var matcher: RegEx = RegEx.new()
	matcher.compile("\"(\\w+)\"")
	for found in matcher.search_all(text.substr(start, finish - start)):
		ids.append(found.get_string(1))
	return ids


func _collect(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_collect(child))
	return found


func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append(label + ": expected true")


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append(label + ": expected false")
