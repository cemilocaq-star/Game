extends SceneTree
## Audio buses and room acoustics: the bus layout, which sounds go where, and the reverb that follows
## how enclosed the listener is.

const BUSES := preload("res://scripts/audio_buses.gd")
const ACOUSTICS := preload("res://scripts/room_acoustics.gd")
const DRIVER := preload("res://scripts/room_acoustics_driver.gd")
const WORLD_AUDIO := preload("res://scripts/world_audio.gd")
const SFX_BANK := preload("res://scripts/sfx_bank.gd")
const SFX_DIRECTOR := preload("res://scripts/sfx_director.gd")
const FOOTSTEPS := preload("res://scripts/footstep_audio.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## A tracer for a rectangular room around the origin: half sizes (x, z), a ceiling height or -1 for none.
func _room(half_x: float, half_z: float, ceiling: float) -> Callable:
	return func(from: Vector3, to: Vector3) -> Dictionary:
		var direction := to - from
		var best := 2.0
		for axis in range(3):
			var limit := half_x if axis == 0 else half_z
			if axis == 1:
				if ceiling < 0.0:
					continue
				limit = ceiling
			var d := direction[axis]
			if absf(d) < 0.000001:
				continue
			var target := limit if d > 0.0 else (-limit if axis != 1 else 0.0)
			var t := (target - from[axis]) / d
			if t >= 0.0 and t <= 1.0 and t < best:
				best = t
		if best > 1.0:
			return {}
		return {"position": from.lerp(to, best)}


func _run() -> void:
	# Bus layout.
	var made: int = BUSES.ensure()
	_check(made == BUSES.ALL.size() or made == 0, "ensure makes the configured buses (%d)" % made)
	for bus_name in BUSES.ALL:
		var index := AudioServer.get_bus_index(bus_name)
		_check(index >= 0, "bus %s exists" % bus_name)
		_check(AudioServer.get_bus_send(index) == (&"SFX" if bus_name in [BUSES.WEAPONS, BUSES.FOOTSTEPS] else &"Master"), "bus %s sends to its mixer parent" % bus_name)
	_check(BUSES.ensure() == 0, "ensure twice makes nothing more")
	_check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(BUSES.SFX)) == 1, "the SFX bus has exactly one effect after two ensures")
	_check(BUSES.room_reverb() != null, "the room reverb is on the SFX bus")
	_check(BUSES.bus_or_master("NoSuchBus") == &"Master", "a missing bus falls back to Master")
	_check(BUSES.bus_or_master(BUSES.MUSIC) == &"Music", "an existing bus is used")

	# Rays.
	_check(ACOUSTICS.ray_directions().size() == 13, "thirteen rays: 8 sideways, 1 up, 4 diagonal")
	for direction in ACOUSTICS.ray_directions():
		_check(is_equal_approx(direction.length(), 1.0), "every ray is a unit vector")

	# Measurement: open ground, a courtyard (walls, no roof), a small room, a big hall.
	var origin := Vector3(0.0, 1.5, 0.0)
	var open: Dictionary = ACOUSTICS.measure(origin, _room(1000.0, 1000.0, -1.0))
	_check(float(open.enclosure) < 0.01 and int(open.open_sides) == 8 and not bool(open.ceiling), "open ground is not enclosed")
	var courtyard: Dictionary = ACOUSTICS.measure(origin, _room(8.0, 8.0, -1.0))
	var small_room: Dictionary = ACOUSTICS.measure(origin, _room(4.0, 4.0, 4.0))
	var hall: Dictionary = ACOUSTICS.measure(origin, _room(18.0, 18.0, 9.0))
	_check(float(courtyard.enclosure) > float(open.enclosure), "a courtyard is more enclosed than open ground")
	_check(float(small_room.enclosure) > float(courtyard.enclosure), "a roofed room is more enclosed than a courtyard")
	_check(bool(small_room.ceiling), "the roof is detected")
	_check(float(small_room.enclosure) > 0.9, "a small closed room is almost fully enclosed (%f)" % float(small_room.enclosure))
	_check(float(hall.mean_distance) > float(small_room.mean_distance), "a hall's walls are further away")

	# Reverb for each.
	var open_reverb: Dictionary = ACOUSTICS.reverb_for(open)
	var courtyard_reverb: Dictionary = ACOUSTICS.reverb_for(courtyard)
	var small_reverb: Dictionary = ACOUSTICS.reverb_for(small_room)
	var hall_reverb: Dictionary = ACOUSTICS.reverb_for(hall)
	_check(float(open_reverb.wet) <= ACOUSTICS.OPEN_WET + 0.001, "no reverb in the open")
	_check(float(small_reverb.wet) > float(courtyard_reverb.wet) and float(courtyard_reverb.wet) > float(open_reverb.wet), "more enclosure means more reverb")
	_check(float(small_reverb.wet) <= ACOUSTICS.MAX_WET + 0.001, "reverb never exceeds its cap")
	_check(float(hall_reverb.room_size) > float(small_reverb.room_size), "a hall rings bigger than a small room")
	_check(float(small_reverb.room_size) >= ACOUSTICS.MIN_ROOM_SIZE and float(hall_reverb.room_size) <= ACOUSTICS.MAX_ROOM_SIZE, "room size stays in range")
	_check(float(small_reverb.damping) > float(open_reverb.damping), "a closed room soaks up more of the highs")

	# Easing: moves toward the target, never overshoots, never jumps.
	var current := {"wet": 0.0, "room_size": 0.2, "damping": 0.35}
	var after: Dictionary = ACOUSTICS.ease_toward(current, small_reverb, 1.0 / 60.0)
	_check(float(after.wet) > 0.0 and float(after.wet) < float(small_reverb.wet) * 0.1, "one frame moves a little (%f)" % float(after.wet))
	for frame in range(600):
		current = ACOUSTICS.ease_toward(current, small_reverb, 1.0 / 60.0)
		_check(float(current.wet) <= float(small_reverb.wet) + 0.0001, "easing never overshoots")
	_check(absf(float(current.wet) - float(small_reverb.wet)) < 0.005, "ten seconds later it has arrived")

	# Apply to the real bus effect.
	ACOUSTICS.apply(BUSES.room_reverb(), small_reverb)
	_check(is_equal_approx(BUSES.room_reverb().wet, float(small_reverb.wet)), "apply sets the reverb wet level")
	ACOUSTICS.apply(null, small_reverb)

	# Which sounds go on which bus.
	var host := Node3D.new()
	root.add_child(host)
	var footstep := WORLD_AUDIO.play_at(host, FOOTSTEPS.stream("stone"), Vector3.ZERO, -6.0, 20.0, 5.0, Vector3.ZERO)
	_check(footstep != null and footstep.bus == &"SFX", "world sounds (steps, shots, explosions) play on SFX")
	SFX_BANK.play_ui(host, "ui_click")
	var ui_player := root.get_node_or_null("UiSfx1") as AudioStreamPlayer
	if ui_player == null:
		ui_player = root.get_node_or_null("UiSfx0") as AudioStreamPlayer
	_check(ui_player != null and ui_player.bus == &"UI", "menu sounds play on UI")
	var director := SFX_DIRECTOR.new()
	root.add_child(director)
	director.play("hit")
	var channel := director.get_node_or_null("Sfx_combat") as AudioStreamPlayer
	_check(channel != null and channel.bus == &"UI", "combat feedback ticks play on UI")

	# The driver: with no camera it does nothing; with a camera in a closed room it raises the reverb.
	var driver := DRIVER.new()
	root.add_child(driver)
	driver.call("_process", 0.1)
	_check(is_equal_approx(float(driver.call("current").wet), ACOUSTICS.OPEN_WET), "no camera, no change")
	await _driver_in_room(driver)

	if failures.is_empty():
		print("PASS: audio buses and room acoustics (layout, routing, enclosure rays, eased reverb, live driver)")
		await process_frame
		await process_frame
		for test_node in root.get_children():
			if test_node is AudioStreamPlayer:
				test_node.stop()
				test_node.stream = null
			test_node.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		await process_frame
		await process_frame
		for test_node in root.get_children():
			if test_node is AudioStreamPlayer:
				test_node.stop()
				test_node.stream = null
			test_node.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		quit(1)


func _driver_in_room(driver: Node) -> void:
	var room := Node3D.new()
	root.add_child(room)
	# Four walls and a ceiling around the origin, 5 m to a side.
	var boxes := [
		[Vector3(0.4, 6.0, 12.0), Vector3(5.2, 3.0, 0.0)], [Vector3(0.4, 6.0, 12.0), Vector3(-5.2, 3.0, 0.0)],
		[Vector3(12.0, 6.0, 0.4), Vector3(0.0, 3.0, 5.2)], [Vector3(12.0, 6.0, 0.4), Vector3(0.0, 3.0, -5.2)],
		[Vector3(12.0, 0.4, 12.0), Vector3(0.0, 4.2, 0.0)],
	]
	for entry in boxes:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[0]
		shape.shape = box
		body.add_child(shape)
		room.add_child(body)
		body.global_position = entry[1]
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.global_position = Vector3(0.0, 1.5, 0.0)
	camera.current = true
	await physics_frame
	await physics_frame
	driver.call("_process", 0.25)
	var target: Dictionary = driver.call("target")
	_check(float(target.wet) > 0.2, "inside a closed room the driver aims for real reverb (%f)" % float(target.wet))
	for frame in range(180):
		driver.call("_process", 1.0 / 60.0)
	_check(BUSES.room_reverb().wet > 0.15, "and the bus reverb follows (%f)" % BUSES.room_reverb().wet)
	camera.global_position = Vector3(60.0, 1.5, 60.0)
	await physics_frame
	driver.call("_process", 0.25)
	_check(float(driver.call("target").wet) < 0.05, "out in the open the target drops back (%f)" % float(driver.call("target").wet))
