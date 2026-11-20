extends SceneTree
## The first-person weapon layer wired into the real player: pivot hierarchy, ADS FOV, reload,
## weapon switch, death reset.

const PLAYER := preload("res://scripts/player.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## Headless frames can be arbitrarily short, so animation time is driven explicitly.
func _advance(player, frames: int) -> void:
	for _frame in range(frames):
		player.call("_process", 1.0 / 60.0)


func _run() -> void:
	var player = PLAYER.new()
	root.add_child(player)
	await process_frame
	await process_frame
	player.set("_intro_left", 0.0)
	await process_frame
	await process_frame
	var camera: Camera3D = player.get("_camera")
	var model: Node3D = player.get("_blaster_model")
	var pivot: Node3D = player.get("_weapon_pivot")
	_check(pivot != null and model != null and model.get_parent() == pivot, "the weapon model sits under the pivot")
	_check(pivot != null and pivot.get_parent() == camera, "the pivot sits under the camera")

	# ADS drives the FOV through the eased blend.
	player.set("_aim_held", true)
	_advance(player, 30)
	_check(camera.fov < 69.0, "aiming narrows the FOV (%f)" % camera.fov)
	_check(pivot.transform.origin.x < -0.15, "aiming centres the weapon (pivot x=%f)" % pivot.transform.origin.x)
	player.set("_aim_held", false)
	_advance(player, 30)
	_check(camera.fov > 85.0, "releasing aim restores the FOV (%f)" % camera.fov)

	# Reload: starts, blocks firing, finishes.
	_check(player.request_reload(), "reload starts on request")
	_check(player.is_reloading(), "player reports reloading")
	player.set("_blaster_cooldown", 0.0)
	player.call("_fire_blaster")
	_check(float(player.get("_blaster_cooldown")) == 0.0, "firing is held back while the reload plays")
	_advance(player, 10)
	_check(pivot.transform.origin.distance_to(Vector3.ZERO) > 0.01 or pivot.transform.basis != Basis.IDENTITY, "the pivot actually moves during a reload")
	_advance(player, 220)
	_check(not player.is_reloading(), "the reload finishes")
	player.call("_fire_blaster")
	_check(float(player.get("_blaster_cooldown")) > 0.0, "firing works again afterwards")

	# Switching weapons cancels a reload and plays the raise.
	player.set("_blaster_cooldown", 0.0)
	player.request_reload()
	player.set_selected_weapon("hand_cannon")
	_check(not player.is_reloading(), "switching weapon cancels the reload")
	_check(player.get("_view_anim").is_switching(), "switching weapon plays the raise")
	model = player.get("_blaster_model")
	_check(model != null and model.get_parent() == pivot, "the new weapon model is also under the pivot")

	# Death resets the layer.
	player.set_combat_dead(true)
	_check(pivot.transform.is_equal_approx(Transform3D.IDENTITY), "death resets the pivot")
	_check(not player.request_reload(), "no reload while dead")
	player.set_combat_dead(false)

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: weapon view layer is wired into the player")
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
		for test_node in root.get_children():
			if test_node is AudioStreamPlayer:
				test_node.stop()
				test_node.stream = null
			test_node.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		quit(1)
