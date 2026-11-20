extends RefCounted
## Footsteps: which surface a foot lands on, and what that surface sounds like.
##
## Shared by the local player (player.gd) and by other players (oxenwar_remote_player.gd), so both
## agree on the surface. A collider can say what it is with the meta "surface_type" or a group
## "surface_<name>". The maps build their floors from plain boxes, so tag_tree() gives every solid
## body in a built map a surface: wooden things (bridges, treehouses, rope walkways) by name,
## everything else by the map's own ground.

const SURFACES := ["stone", "metal", "wood", "ice", "dirt", "grass"]
## Map index -> ground. Matches ArenaLayout's map list: 0 Lost Mall, 1 Neon City, 2 Space Islands,
## 3 Candy World, 4 Sunken Oasis, 5 Jungle Arena, 6 Redstone Canyon.
const MAP_GROUND := {0: "stone", 1: "metal", 2: "metal", 3: "ice", 4: "dirt", 5: "grass", 6: "dirt"}
const WOOD_WORDS := ["bridge", "treehouse", "rope", "plank", "dock", "boardwalk"]
const META_KEY := "surface_type"

const SAMPLE_RATE := 22050
const DURATION := 0.105

static var _streams: Dictionary = {}


## The surface a hint names ("Metal_Door", "grass", "SkyIslandDeck"), or "stone" when it names none.
static func classify(hint: String) -> String:
	var text := hint.to_lower()
	if "grass" in text or "foliage" in text or "leaf" in text:
		return "grass"
	if "metal" in text or "steel" in text:
		return "metal"
	if "wood" in text or "plank" in text:
		return "wood"
	if "ice" in text or "snow" in text:
		return "ice"
	if "sand" in text or "dirt" in text or "soil" in text:
		return "dirt"
	return "stone"


static func ground_for_map(map_index: int) -> String:
	return str(MAP_GROUND.get(map_index, "stone"))


## The surface for a named solid in a map: wooden by name, otherwise the map's ground.
static func surface_for(node_name: String, map_index: int) -> String:
	var text := node_name.to_lower()
	for word in WOOD_WORDS:
		if word in text:
			return "wood"
	return ground_for_map(map_index)


## Gives every solid body under `root` a surface, unless it already has one (meta or group).
## Returns how many it tagged.
static func tag_tree(root: Node, map_index: int) -> int:
	var tagged := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is StaticBody3D):
			continue
		if node.has_meta(META_KEY) or _has_surface_group(node):
			continue
		node.set_meta(META_KEY, surface_for(str(node.name), map_index))
		tagged += 1
	return tagged


static func _has_surface_group(node: Node) -> bool:
	for group_name in node.get_groups():
		if str(group_name).begins_with("surface_"):
			return true
	return false


## The surface of what a collider says it is: meta, then group, then its own name.
static func surface_of(collider: Object) -> String:
	if collider == null:
		return "stone"
	var hint := ""
	if collider is CollisionObject3D:
		hint = str(collider.get_meta(META_KEY, ""))
		if hint.is_empty():
			for group_name in collider.get_groups():
				if str(group_name).begins_with("surface_"):
					hint = str(group_name).trim_prefix("surface_")
					break
	if hint.is_empty() and collider is Node:
		hint = str(collider.name)
	return classify(hint)


## What is under `position`: casts down a little and asks the collider. "stone" when nothing is there.
static func detect(world: World3D, position: Vector3, exclude: Array[RID] = []) -> String:
	if world == null:
		return "stone"
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.25, position - Vector3.UP * 1.1)
	query.exclude = exclude
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "stone"
	return surface_of(hit.get("collider"))


## Metres of walking between two footsteps.
static func step_distance(horizontal_speed: float, walk_speed: float) -> float:
	return 2.05 if horizontal_speed > walk_speed + 0.5 else 1.55


## A short synthesized step for a surface, made once and kept.
static func stream(surface: String) -> AudioStreamWAV:
	if not _streams.has(surface):
		_streams[surface] = _make_stream(surface)
	return _streams[surface] as AudioStreamWAV


static func _make_stream(surface: String) -> AudioStreamWAV:
	# Original synthesized foley: distinct tonal/noise profiles, generated locally.
	var sample_count := int(SAMPLE_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(surface)
	var frequency := 430.0
	var noise_mix := 0.28
	var amplitude := 0.52
	match surface:
		"grass":
			frequency = 180.0
			noise_mix = 0.78
			amplitude = 0.34
		"metal":
			frequency = 920.0
			noise_mix = 0.18
			amplitude = 0.48
		"wood":
			frequency = 270.0
			noise_mix = 0.24
			amplitude = 0.48
		"ice":
			frequency = 1080.0
			noise_mix = 0.52
			amplitude = 0.30
		"dirt":
			frequency = 220.0
			noise_mix = 0.88
			amplitude = 0.30
	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := pow(maxf(0.0, 1.0 - float(i) / float(sample_count)), 2.2)
		var tone := sin(TAU * frequency * t) * (1.0 - noise_mix)
		var noise := rng.randf_range(-1.0, 1.0) * noise_mix
		var transient := rng.randf_range(-1.0, 1.0) * 0.24 if i < int(SAMPLE_RATE * 0.009) else 0.0
		var sample := clampf((tone + noise + transient) * envelope * amplitude, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.stereo = false
	result.data = bytes
	return result
