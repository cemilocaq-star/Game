extends Node
## Keeps the SFX bus reverb matched to where the listener is: measures the surroundings a few times a
## second (room_acoustics.gd) and eases the reverb toward the result so it never jumps.

const ACOUSTICS := preload("res://scripts/room_acoustics.gd")
const PATHS := preload("res://scripts/sound_paths.gd")
const BUSES := preload("res://scripts/audio_buses.gd")

var _clock := 0.0
var _settings := {"wet": ACOUSTICS.OPEN_WET, "room_size": ACOUSTICS.MIN_ROOM_SIZE, "damping": 0.35}
var _target := {"wet": ACOUSTICS.OPEN_WET, "room_size": ACOUSTICS.MIN_ROOM_SIZE, "damping": 0.35}


func _ready() -> void:
	name = "RoomAcousticsDriver"
	BUSES.ensure()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	_clock += delta
	if _clock >= ACOUSTICS.MEASURE_INTERVAL:
		_clock = 0.0
		var tracer: Callable = PATHS.physics_tracer(camera.get_world_3d().direct_space_state, _own_bodies(camera))
		_target = ACOUSTICS.reverb_for(ACOUSTICS.measure(camera.global_position, tracer))
	_settings = ACOUSTICS.ease_toward(_settings, _target, delta)
	ACOUSTICS.apply(BUSES.room_reverb(), _settings)


func current() -> Dictionary:
	return _settings


func target() -> Dictionary:
	return _target


func _own_bodies(camera: Camera3D) -> Array[RID]:
	var result: Array[RID] = []
	var node: Node = camera
	while node != null:
		if node is CollisionObject3D:
			result.append((node as CollisionObject3D).get_rid())
			break
		node = node.get_parent()
	return result
