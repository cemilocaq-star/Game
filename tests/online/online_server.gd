extends SceneTree
## Dedicated server for the online test. Needs OXENWAR_SERVER_SECRET (any value) in the environment.

const NET := preload("res://tests/online/network_under_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var net := NET.new()
	net.name = "OxenWarNetwork"
	root.add_child(net)
	if not net.start_server():
		quit(1)
		return
	print("ONLINE_SERVER_READY")
	# Safety net: never outlive the test.
	await create_timer(120.0).timeout
	quit(0)
