extends RefCounted
## Plays a one-shot sound at a place in the world, heard the way it would reach the listener:
## through an open door or around a corner if there is a way, muffled if it is behind walls.
## Used for gunfire, explosions and other players' footsteps.

const PATHS := preload("res://scripts/sound_paths.gd")
const BUSES := preload("res://scripts/audio_buses.gd")


## Starts the sound and frees the player when it ends. Returns the player, or null when the sound
## is out of earshot or cannot be played. `listener` is where the ear is (usually the camera).
static func play_at(parent: Node3D, stream: AudioStream, position: Vector3, volume_db: float, max_distance: float, unit_size: float, listener: Vector3, exclude: Array[RID] = [], pitch_scale: float = 1.0, node_name: String = "WorldSound") -> AudioStreamPlayer3D:
	if parent == null or stream == null or not parent.is_inside_tree():
		return null
	if listener.distance_to(position) > max_distance:
		return null
	var audio := AudioStreamPlayer3D.new()
	audio.name = node_name
	audio.stream = stream
	audio.volume_db = volume_db
	audio.max_distance = max_distance
	audio.unit_size = unit_size
	audio.pitch_scale = pitch_scale
	audio.bus = BUSES.bus_or_master(BUSES.SFX)
	parent.add_child(audio)
	audio.global_position = position
	var tracer: Callable = PATHS.physics_tracer(parent.get_world_3d().direct_space_state, exclude)
	var resolved: Dictionary = PATHS.resolve(listener, position, tracer)
	PATHS.apply(audio, resolved, position, volume_db)
	audio.set_meta("sound_path", resolved.kind)
	audio.finished.connect(audio.queue_free)
	audio.play()
	return audio


## Where the listener's ears are: the active camera, or `fallback` when there is none.
static func listener_position(from: Node, fallback: Vector3) -> Vector3:
	if from == null or not from.is_inside_tree():
		return fallback
	var camera := from.get_viewport().get_camera_3d()
	return camera.global_position if camera != null else fallback


## The listening player's own body, so its collider does not count as a wall between ear and sound.
static func listener_exclusions(from: Node) -> Array[RID]:
	var result: Array[RID] = []
	if from == null or not from.is_inside_tree():
		return result
	var camera := from.get_viewport().get_camera_3d()
	var node: Node = camera
	while node != null:
		if node is CollisionObject3D:
			result.append((node as CollisionObject3D).get_rid())
			break
		node = node.get_parent()
	return result
