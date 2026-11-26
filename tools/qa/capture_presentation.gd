extends SceneTree
## Renders the actual game and menu with a local fixture profile. No network login is performed.
const MENU := preload("res://scripts/oxenwar_menu.gd")
const PAUSE := preload("res://scripts/pause_menu.gd")

class OfflineGame extends "res://scripts/main.gd":
	func _request_player_identity() -> void:
		local_player_name = "Local capture"
		player_profile = {"avatar_color_id": "color_cyan", "outfit_id": "outfit_ghost_ops", "accessory_id": "accessory_headphones"}
		selected_map_index = 4
		pending_launch_action = "practice"

	func _start_multiplayer_client() -> void:
		network = NETWORK_SCRIPT.new()
		network.name = "OxenWarNet"
		add_child(network)

	func _send_presence_heartbeat() -> void:
		pass

var output := ""
var game: Node3D
class CaptureBackend extends Node:
	var user_id := "local-capture"
	func update_presence() -> Dictionary:
		return {"ok": true}
	func get_player_stats() -> Dictionary:
		return {"ok": true, "data": {"total_xp":0, "matches_played":0}}
	func get_weapon_mastery() -> Dictionary:
		return {"ok": true, "data": {}}
	func get_friend_requests() -> Dictionary:
		return {"ok": true, "data": []}
	func get_friends() -> Dictionary:
		return {"ok": true, "data": []}
	func get_friend_presence(_ids: PackedStringArray) -> Dictionary:
		return {"ok": true, "data": []}
	func get_cosmetics() -> Dictionary:
		return {"ok": false}


func _initialize() -> void:
	call_deferred("_run")

func _save(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join(name + ".png")
	if image.save_png(path) != OK:
		push_error("Capture failed: " + path)
		quit(1)
	print("CAPTURE " + name)

func _run() -> void:
	output = OS.get_environment("OXENWAR_CAPTURE_DIR")
	if output.is_empty():
		push_error("Set OXENWAR_CAPTURE_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var menu := MENU.new()
	root.add_child(menu)
	menu.locale = "en"
	menu.call("_build")
	await _save("01_login")
	var fixture := CaptureBackend.new()
	root.add_child(fixture)
	menu.backend = fixture
	menu.authenticated = true
	menu.profile = {"username": "Local capture", "display_name": "Local capture", "outfit_id": "outfit_ghost_ops"}
	menu.call("_build")
	await _save("02_lobby")
	for tab in ["character", "stats", "friends"]:
		menu.call("_on_tab_pressed", tab)
		await _save("menu_" + tab)
	menu.free()
	fixture.free()
	game = OfflineGame.new()
	root.add_child(game)
	await create_timer(1.0).timeout
	var player: Node3D = game.get("player")
	player.set("_intro_left", 0.0)
	player.global_position = Vector3(0, 2, 6)
	player.rotation.y = 0.0
	await create_timer(0.8).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _save("03_first_person")
	game.call("_toggle_arsenal")
	await create_timer(0.3).timeout
	await _save("04_arsenal")
	game.call("_toggle_arsenal")
	for id in ["ranger_rifle", "heavy_sidearm", "longshot"]:
		game.call("_select_weapon", id)
		await create_timer(0.7).timeout
		await _save("weapon_" + id)
	player.call("toggle_third_person")
	await create_timer(0.4).timeout
	await _save("05_third_person")
	game.call("_toggle_pause_menu")
	await _save("06_settings")
	game.call("_toggle_pause_menu")
	game.call("_toggle_scoreboard")
	await _save("07_scoreboard")
	game.call("_toggle_scoreboard")
	game.call("_toggle_lobby")
	await _save("08_match_lobby")
	game.call("_toggle_lobby")
	var review := Camera3D.new()
	game.add_child(review)
	review.position = Vector3(24.0, 25.0, 30.0)
	review.look_at(Vector3.ZERO)
	review.far = 180.0
	review.current = true
	var performance: Array[Dictionary] = []
	for map in range(7):
		game.set("active_map_index", map)
		game.call("_rebuild_arena")
		await create_timer(0.15).timeout
		await _save("map_%d" % map)
		performance.append({"map":map,"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
	game.call("_finish_round")
	await _save("09_results_fixture")
	var metrics := FileAccess.open(output.path_join("render_metrics.json"), FileAccess.WRITE)
	metrics.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "context": "software renderer; captures, not hardware benchmark", "maps":performance}, "  "))
	metrics.close()
	game.free()
	quit()
