extends SceneTree
const NET := preload("res://scripts/oxenwar_network.gd")
const BODY := preload("res://scripts/oxenwar_server_player.gd")
const SETTINGS := preload("res://scripts/user_settings.gd")
class QuietGame extends "res://scripts/main.gd":
	func _ready() -> void:
		pass
	func _show_meme_toast(_message: String) -> void:
		pass
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var bindings := preload("res://scripts/input_bindings.gd")
	bindings.ensure()
	var initial_events := InputMap.action_get_events("move_forward").size()
	bindings.ensure()
	check(InputMap.action_get_events("move_forward").size() == initial_events, "initializing standalone players never duplicates bindings")
	var net := NET.new()
	root.add_child(net)
	var body := BODY.new()
	root.add_child(body)
	net._server_players[0] = body
	net._peer_users[0] = "fixture"
	net._last_input_seq[0] = 12
	net._last_input_ms[0] = Time.get_ticks_msec() - 100
	net._server_submit_input(Vector2.ONE, 1.0, true, true, true, true, 11, 0.0)
	check(body.input_vector == Vector2.ZERO, "stale input cannot change movement")
	check(int(net._last_input_seq[0]) == 12, "stale sequence cannot roll back accepted sequence")
	body.input_vector = Vector2.ONE
	body.sprinting = true
	body.jump_requested = true
	body.slide_requested = true
	body.dash_requested = true
	net._last_input_ms[0] = Time.get_ticks_msec() - 500
	net._server_process_rooms(0.0)
	check(body.input_vector == Vector2.ZERO and not body.sprinting, "lost input stops movement and sprint")
	check(not body.jump_requested and not body.slide_requested and not body.dash_requested, "lost input clears queued abilities")
	var game := QuietGame.new()
	root.add_child(game)
	game.player = game.PLAYER_SCRIPT.new()
	game.add_child(game.player)
	game.player.set_physics_process(false)
	game.network = net
	net.session_restored_on_auth = true
	game._on_network_authentication_changed(true, "fixture")
	check(game.player.is_physics_processing(), "actual authenticated game keeps local prediction running")
	# A far correction changes position but never overwrites newer local look.
	net.set_local_player(body, "fixture", Color.CYAN)
	body.rotation.y = 1.2
	net.reconcile_local_player({"position": Vector3(50,0,0), "yaw": -2.0, "velocity": Vector3.ZERO})
	check(is_equal_approx(body.rotation.y, 1.2), "position reconciliation preserves local look")
	check(SETTINGS.gyro_bias().is_finite(), "calibration default is finite")
	net._server_players.clear()
	game.free()
	body.free()
	net.free()
	if failures.is_empty(): print("PASS: authenticated prediction, stale input rejection, input timeout, look reconciliation and gyro default")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
