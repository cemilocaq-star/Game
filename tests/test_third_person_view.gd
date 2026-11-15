extends SceneTree
## The local character used to be invisible (the first-person camera hides it). A spawn intro orbit
## and a C / VIEW third-person camera now show it; first person is restored afterwards.

const PLAYER := preload("res://scripts/player.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var player = PLAYER.new()
	root.add_child(player)
	await process_frame
	await process_frame
	var camera: Camera3D = player.get("_camera")
	var viewmodel: Node3D = player.get("_blaster_model")
	_check(camera != null and viewmodel != null, "player has a camera and a viewmodel")
	if camera == null or viewmodel == null:
		_finish(player)
		return

	# The body is on render layer 2; the first-person camera only draws layer 1.
	var body: MeshInstance3D = player.get("_body_mesh")
	_check(body != null and body.layers == 2, "the local body is on its own render layer")

	# Entering the game: the intro shows the character from the front.
	_check(player.is_external_view(), "the match starts with the character intro")
	_check(camera.cull_mask == 3, "the intro camera draws the character layer")
	_check(not viewmodel.visible, "the first-person weapon is hidden during the intro")
	_check(camera.position.z < -1.0, "the intro starts in front of the character (z=%f)" % camera.position.z)
	player.set("_intro_left", 0.4)
	for _frame in range(10):
		await process_frame
	_check(camera.cull_mask == 3, "the intro is still running after a few frames")
	player.set("_intro_left", 0.001)
	await process_frame
	await process_frame
	_check(not player.is_external_view(), "the intro ends by itself")
	_check(camera.cull_mask == 1, "first person is restored after the intro")
	_check(camera.position.is_equal_approx(Vector3(0.0, 1.55, -0.34)), "the first-person camera position is restored (%s)" % str(camera.position))
	_check(viewmodel.visible, "the first-person weapon is back")
	_check(is_zero_approx(camera.rotation.y), "the camera yaw offset is cleared")

	# C / VIEW toggles a third-person camera behind the character.
	player.toggle_third_person()
	await process_frame
	await process_frame
	_check(player.third_person and camera.cull_mask == 3, "third person draws the character")
	_check(camera.position.z > 1.5, "the third-person camera is behind the character (z=%f)" % camera.position.z)
	_check(camera.position.y > 1.2, "the third-person camera is above the shoulder")
	_check(not viewmodel.visible, "the first-person weapon is hidden in third person")
	player.pitch = deg_to_rad(40.0)
	player.set("_intro_left", 0.0)
	await process_frame
	_check(camera.position.y < 1.0, "looking up swings the orbit camera down below the head (y=%f)" % camera.position.y)
	player.pitch = 0.0
	player.toggle_third_person()
	await process_frame
	await process_frame
	_check(camera.cull_mask == 1 and viewmodel.visible, "toggling again returns to first person")
	_check(camera.position.is_equal_approx(Vector3(0.0, 1.55, -0.34)), "first-person position after toggling back")

	# Choosing a view during the intro ends the intro.
	player.set("_intro_left", 2.0)
	player.set_third_person(false)
	_check(not player.is_external_view(), "choosing first person skips the intro")
	_finish(player)


func _finish(player: Node) -> void:
	player.free()
	if failures.is_empty():
		print("PASS: character intro, third-person camera and first-person restore")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
