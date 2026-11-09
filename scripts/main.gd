extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const BACKEND_SCRIPT = preload("res://scripts/oxenwar_supabase.gd")
const MENU_SCRIPT = preload("res://scripts/oxenwar_menu.gd")
const NETWORK_SCRIPT = preload("res://scripts/oxenwar_network.gd")
const REMOTE_PLAYER_SCRIPT = preload("res://scripts/oxenwar_remote_player.gd")
var local_player_name := "Player"
var local_admin_authorized := false
var player_profile: Dictionary = {}
var backend: Node
const ROUND_SECONDS := 300.0
const EVENT_INTERVAL := 30.0
const EVENT_DURATION := 12.0

var player: ArcadePlayer
var score_label: Label
var event_label: Label
var stamina_bar: ProgressBar
var status_label: Label
var round_left := ROUND_SECONDS
var event_clock := EVENT_INTERVAL
var event_left := 0.0
var active_event := ""
var orb_spawns: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var hud_layer: CanvasLayer
var _round_finished := false
var progression: ProgressionManager
var graphics: GraphicsManager
var level_label: Label
var xp_bar: ProgressBar
var graphics_option: OptionButton
var arena_meshes: Array[MeshInstance3D] = []
var arena_colors: Array[Color] = []
var map_extras: Array[Node3D] = []
var active_map_index := 0
var admin_available := false
var admin_panel: PanelContainer
var admin_hint: Label
var network: Node
var network_status_label: Label
var network_host_input: LineEdit
var room_code_input: LineEdit
var room_status_label: Label
var remote_players: Dictionary = {}

const EVENT_NAMES := {
	"DUCK_PARADE": "DUCK PARADE!",
	"PINK_SKY": "PINK SKY!",
	"GOLDEN_ORB_RUSH": "GOLDEN ORB RUSH — 2X POINTS!",
	"CONFETTI_STORM": "CONFETTI STORM!",
	"LOW_GRAVITY": "LOW GRAVITY!",
	"BONK_MODE": "BONK MODE — SPEED BOOST!",
	"NPC_MODE": "NPC MODE — SIDE QUEST ENERGY",
	"DUCK_EXE": "DUCK.EXE HAS STOPPED RESPONDING",
	"METEOR_SHOWER": "METEOR SHOWER!",
	"ICE_WORLD": "ICE WORLD!",
	"DOUBLE_XP": "DOUBLE XP!"
}

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--server"):
		_start_dedicated_server()
		return
	rng.randomize()
	await _request_player_identity()
	progression = ProgressionManager.new()
	add_child(progression)
	progression.level_up.connect(_on_level_up)
	graphics = GraphicsManager.new()
	graphics.load_settings()
	graphics.quality_changed.connect(_refresh_graphics_materials)
	_setup_input()
	_build_environment()
	_build_arena()
	_spawn_player()
	_start_multiplayer_client()
	_build_hud()
	_build_collectibles()
	_update_hud()
	var heartbeat := Timer.new()
	heartbeat.name = "OnlinePresenceHeartbeat"
	heartbeat.wait_time = 30.0
	heartbeat.autostart = true
	heartbeat.timeout.connect(_send_presence_heartbeat)
	add_child(heartbeat)
	_send_presence_heartbeat()

func _request_player_identity() -> void:
	backend = BACKEND_SCRIPT.new()
	backend.name = "OxenWarBackend"
	add_child(backend)
	var restored: Dictionary = await backend.restore_session()
	var menu = MENU_SCRIPT.new()
	menu.name = "OxenWarMainMenu"
	add_child(menu)
	await menu.configure(backend, restored)
	var identity: Dictionary = await menu.play_requested
	local_player_name = str(identity.get("display_name", "Player"))
	player_profile = identity.get("profile", {})
	local_admin_authorized = bool(identity.get("is_admin", false))
	menu.queue_free()

func _send_presence_heartbeat() -> void:
	if is_instance_valid(backend) and not str(backend.user_id).is_empty():
		await backend.update_presence()

func _start_dedicated_server() -> void:
	# Dedicated server builds the same collision arena before accepting players.
	graphics = GraphicsManager.new()
	graphics.load_settings()
	add_child(graphics)
	_build_arena()
	network = NETWORK_SCRIPT.new()
	network.name = "OxenWarNet"
	add_child(network)
	if not network.start_server():
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--smoke-test"):
		_finish_server_smoke_test()

func _finish_server_smoke_test() -> void:
	await get_tree().create_timer(1.0).timeout
	print("OxenWar dedicated server smoke test passed")
	get_tree().quit()

func _start_multiplayer_client() -> void:
	network = NETWORK_SCRIPT.new()
	network.name = "OxenWarNet"
	add_child(network)
	network.player_state_received.connect(_on_remote_player_state)
	network.player_disconnected.connect(_on_remote_player_left)
	network.connection_status_changed.connect(_on_network_status_changed)
	network.authentication_changed.connect(_on_network_authentication_changed)
	network.local_state_received.connect(_on_authoritative_local_state)
	network.room_state_changed.connect(_on_network_room_state)
	network.invite_received.connect(_on_room_invite_received)
	network.set_local_player(player, local_player_name, player.cosmetic_color)
	var host := OS.get_environment("OXENWAR_SERVER_HOST")
	if host.is_empty():
		host = str(ProjectSettings.get_setting("oxenwar/server_host", "127.0.0.1"))
	if is_instance_valid(backend) and not str(backend.access_token).is_empty():
		network.connect_to_server(host, str(backend.access_token))
	else:
		_on_network_status_changed("Sign in required for multiplayer")

func _on_network_status_changed(message: String) -> void:
	if is_instance_valid(network_status_label):
		network_status_label.text = "MULTIPLAYER • " + message

func _on_network_authentication_changed(authenticated: bool, message: String) -> void:
	if is_instance_valid(player) and authenticated:
		# Online movement is simulated by the server; the client only sends input.
		player.set_physics_process(false)
		for area in get_tree().get_nodes_in_group("local_collectibles"):
			if area is Area3D:
				area.monitoring = false
		_show_meme_toast("SERVER VERIFIED • " + message)
	elif is_instance_valid(player) and not authenticated:
		player.set_physics_process(false)

func _on_authoritative_local_state(state: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var position_value: Variant = state.get("position", player.global_position)
	if position_value is Vector3:
		player.global_position = position_value
	player.rotation.y = float(state.get("yaw", player.rotation.y))
	player.score = int(state.get("score", player.score))
	player.stamina = float(state.get("stamina", player.stamina))
	if is_instance_valid(progression):
		progression.sync_server_total_xp(int(state.get("xp", progression.total_xp)))
	_update_hud()

func _on_network_room_state(state: Dictionary) -> void:
	if state.has("event_id"):
		active_event = str(state.get("event_id", ""))
		event_left = float(state.get("event_left", 0.0))
		round_left = float(state.get("round_left", ROUND_SECONDS))
		var available: Dictionary = state.get("orb_available", {})
		for index in range(orb_spawns.size()):
			var orb := get_node_or_null("GoldenOrb_%02d" % index)
			if is_instance_valid(orb) and available.has(index):
				orb.visible = bool(available[index])
	if state.has("code"):
		var members: Array = state.get("members", [])
		var names: Array[String] = []
		for member in members:
			names.append(str(member.get("display_name", "Player")) + ("" if bool(member.get("online", false)) else " (offline)"))
		if is_instance_valid(room_status_label):
			room_status_label.text = "ROOM %s • %d/%d • %s" % [
				str(state.get("code", "")), members.size(), int(state.get("max_players", 8)),
				", ".join(names)
			]
	_update_hud()

func _on_room_invite_received(owner_name: String, room_code: String) -> void:
	if is_instance_valid(room_status_label):
		room_status_label.text = "%s invited you • room %s" % [owner_name, room_code]
	if is_instance_valid(room_code_input):
		room_code_input.text = room_code

func _on_network_connect_pressed() -> void:
	if is_instance_valid(network) and is_instance_valid(network_host_input) and is_instance_valid(backend):
		network.connect_to_server(network_host_input.text, str(backend.access_token))

func _on_create_room_pressed() -> void:
	if is_instance_valid(network):
		network.request_create_room(true)

func _on_quick_match_pressed() -> void:
	if is_instance_valid(network):
		network.request_quick_match()

func _on_join_room_pressed() -> void:
	if is_instance_valid(network) and is_instance_valid(room_code_input):
		network.request_join_room(room_code_input.text)

func _on_remote_player_state(peer_id: int, state: Dictionary) -> void:
	var remote: Node3D = remote_players.get(peer_id)
	if not is_instance_valid(remote):
		remote = REMOTE_PLAYER_SCRIPT.new()
		remote.name = "RemotePlayer_%d" % peer_id
		add_child(remote)
		remote_players[peer_id] = remote
		remote.set_identity(str(state.get("display_name", "Player")), Color.from_string(str(state.get("color", "#27D7E7")), Color("#27D7E7")))
	remote.apply_network_state(state.get("position", Vector3.ZERO), float(state.get("yaw", 0.0)))

func _on_remote_player_left(peer_id: int) -> void:
	var remote: Node = remote_players.get(peer_id)
	if is_instance_valid(remote):
		remote.queue_free()
	remote_players.erase(peer_id)

func _process(delta: float) -> void:
	if OS.get_cmdline_user_args().has("--server"):
		return
	if _round_finished:
		return
	if is_instance_valid(graphics):
		graphics.update_performance(delta)
	if is_instance_valid(network) and network.is_authenticated:
		_update_hud()
		return
	round_left = maxf(0.0, round_left - delta)
	if round_left <= 0.0:
		_finish_round()
		_update_hud()
		return
	if active_event.is_empty():
		event_clock -= delta
		if event_clock <= 0.0:
			_start_random_event()
	else:
		event_left -= delta
		if event_left <= 0.0:
			_end_event()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not admin_available or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8:
		_toggle_admin_panel()
		get_viewport().set_input_as_handled()

func _toggle_admin_panel() -> void:
	if not admin_available or not is_instance_valid(admin_panel):
		return
	admin_panel.visible = not admin_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if admin_panel.visible else Input.MOUSE_MODE_CAPTURED

func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("slide", KEY_CTRL)
	_add_key_action("dash", KEY_Q)
	_add_key_action("move_forward", KEY_UP)
	_add_key_action("move_back", KEY_DOWN)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_RIGHT)

func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.015, 0.025, 0.08)
	sky_material.sky_horizon_color = Color(0.18, 0.10, 0.25)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.56, 0.82)
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	graphics.configure(env, sun)

func _build_arena() -> void:
	_make_box("ArenaFloor", Vector3(36, 0.8, 30), Vector3(0, -0.4, 0), Color(0.07, 0.12, 0.19))
	_make_box("NorthWall", Vector3(36, 3.6, 0.9), Vector3(0, 1.8, -14.55), Color(0.045, 0.07, 0.12))
	_make_box("SouthWall", Vector3(36, 3.6, 0.9), Vector3(0, 1.8, 14.55), Color(0.045, 0.07, 0.12))
	_make_box("EastWall", Vector3(0.9, 3.6, 28.2), Vector3(17.55, 1.8, 0), Color(0.045, 0.07, 0.12))
	_make_box("WestWall", Vector3(0.9, 3.6, 28.2), Vector3(-17.55, 1.8, 0), Color(0.045, 0.07, 0.12))
	_make_box("CentralStage", Vector3(9, 1.2, 6.2), Vector3(0, 0.6, 0), Color(0.19, 0.26, 0.36))
	_make_box("WestUpperPlatform", Vector3(6.5, 1.2, 5.2), Vector3(-11.2, 1.9, -5.6), Color(0.08, 0.72, 0.58))
	_make_box("EastUpperPlatform", Vector3(6.5, 1.2, 5.2), Vector3(11.2, 1.9, -5.6), Color(0.12, 0.35, 0.92))
	_make_box("SouthPlatform", Vector3(8.2, 1.2, 4.0), Vector3(0, 1.5, 9.5), Color(0.88, 0.15, 0.42))
	_make_box("NorthBridge", Vector3(12, 0.8, 2.2), Vector3(0, 1.8, -10), Color(0.22, 0.29, 0.39))
	_make_box("WestHop", Vector3(2.2, 1.3, 2.2), Vector3(-5.2, 0.65, -3.8), Color(0.22, 0.29, 0.39))
	_make_box("EastHop", Vector3(2.2, 1.3, 2.2), Vector3(5.2, 0.65, -3.8), Color(0.22, 0.29, 0.39))
	_make_box("SouthHop", Vector3(2.2, 1.3, 2.2), Vector3(-5.2, 0.65, 3.8), Color(0.22, 0.29, 0.39))
	_make_box("NorthHop", Vector3(2.2, 1.3, 2.2), Vector3(5.2, 0.65, 3.8), Color(0.22, 0.29, 0.39))
	_make_box("WestRampBlock", Vector3(7, 0.7, 3.0), Vector3(-8.3, 0.55, 0.8), Color(0.96, 0.62, 0.12))
	_make_box("EastRampBlock", Vector3(7, 0.7, 3.0), Vector3(8.3, 0.55, 0.8), Color(0.96, 0.62, 0.12))
	_apply_map_variant()

func _make_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	arena_meshes.append(mesh_node)
	arena_colors.append(color)
	mesh_node.material_override = graphics.make_material(color)
	body.add_child(mesh_node)
	add_child(body)

func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "LocalPlayer"
	player.player_name = local_player_name
	var color_id := str(player_profile.get("avatar_color_id", "color_cyan"))
	var color_map := {
		"color_cyan": Color("#27D7E7"),
		"color_violet": Color("#9B70FF"),
		"color_orange": Color("#FF9B42"),
		"color_lime": Color("#A7E34B")
	}
	player.cosmetic_color = color_map.get(color_id, Color("#27D7E7"))
	var outfit_value: Variant = player_profile.get("outfit_id", null)
	player.cosmetic_outfit = "outfit_default" if outfit_value == null or str(outfit_value).is_empty() else str(outfit_value)
	var accessory_value: Variant = player_profile.get("accessory_id", null)
	player.cosmetic_accessory = "accessory_cap" if accessory_value == null or str(accessory_value).is_empty() else str(accessory_value)
	player.is_admin = local_admin_authorized
	admin_available = player.is_admin
	player.position = Vector3(0, 1.5, 6)
	player.collected.connect(_on_collected)
	add_child(player)

func _build_collectibles() -> void:
	orb_spawns = [Vector3(-12, 1.0, -8), Vector3(-7, 2.0, -5), Vector3(0, 2.0, -10), Vector3(7, 2.0, -5), Vector3(12, 1.0, -8), Vector3(-10, 1.0, 5), Vector3(-4, 1.8, 1), Vector3(4, 1.8, 1), Vector3(10, 1.0, 5), Vector3(0, 2.2, 10), Vector3(-2, 1.2, -2), Vector3(2, 1.2, -2)]
	for i in orb_spawns.size():
		_spawn_orb(i)

func _spawn_orb(index: int) -> void:
	var area := Area3D.new()
	area.name = "GoldenOrb_%02d" % index
	area.add_to_group("local_collectibles")
	area.position = orb_spawns[index]
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	collision.shape = sphere
	area.add_child(collision)
	var visual: Node3D
	var packed: PackedScene = load("res://assets/GoldenOrb_Collectible.glb")
	if packed:
		visual = packed.instantiate()
		visual.scale = Vector3.ONE * 0.01
	else:
		var mesh_node := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.32
		mesh.height = 0.64
		mesh_node.mesh = mesh
		visual = mesh_node
	area.add_child(visual)
	var bob := create_tween()
	bob.set_loops()
	bob.tween_property(visual, "rotation:y", TAU, 2.4)
	bob.tween_property(visual, "position:y", 0.22, 0.65)
	bob.tween_property(visual, "position:y", 0.0, 0.65)
	area.body_entered.connect(_on_orb_body_entered.bind(area, index))
	add_child(area)

func _on_orb_body_entered(body: Node3D, orb: Area3D, index: int) -> void:
	if is_instance_valid(network) and network.is_authenticated:
		return
	if body != player or not is_instance_valid(orb):
		return
	var points := 20 if active_event == "GOLDEN_ORB_RUSH" else 10
	player.add_score(points)
	progression.add_xp((25 if active_event == "GOLDEN_ORB_RUSH" else 15) * (2 if active_event == "DOUBLE_XP" else 1))
	if index == 11 and progression.discover_secret():
		_show_meme_toast("SECRET FOUND: 404 SKILL NOT FOUND  •  +100 XP")
	orb.set_deferred("monitoring", false)
	orb.visible = false
	await get_tree().create_timer(8.0).timeout
	if is_instance_valid(orb):
		orb.queue_free()
	if not _round_finished:
		_spawn_orb(index)

func _start_random_event() -> void:
	if is_instance_valid(network) and network.is_authenticated:
		return
	var choices: Array[String] = ["DUCK_PARADE", "PINK_SKY", "GOLDEN_ORB_RUSH", "CONFETTI_STORM", "LOW_GRAVITY", "BONK_MODE", "NPC_MODE", "DUCK_EXE", "METEOR_SHOWER", "ICE_WORLD", "DOUBLE_XP"]
	active_event = choices[rng.randi_range(0, choices.size() - 1)]
	event_left = EVENT_DURATION
	event_clock = EVENT_INTERVAL
	player.apply_event(active_event)
	if active_event == "PINK_SKY":
		RenderingServer.set_default_clear_color(Color(0.20, 0.045, 0.18))
	if active_event == "DUCK_PARADE" or active_event == "DUCK_EXE":
		_spawn_duck_mascot()
	if active_event == "METEOR_SHOWER":
		_spawn_meteor_shower()
	if active_event == "METEOR_SHOWER":
		_show_meme_toast("LOOK UP! SPACE ROCKS ARE FALLING (DECORATIVE)")
	if active_event == "ICE_WORLD":
		_show_meme_toast("ICE WORLD: SLIPPERY SPEED MODE")
	if active_event == "DOUBLE_XP":
		_show_meme_toast("DOUBLE XP IS ACTIVE")
	if active_event == "BONK_MODE":
		_show_meme_toast("BONK! THE LAWS OF PHYSICS TOOK A BREAK.")
	if active_event == "NPC_MODE":
		_show_meme_toast("SIDE QUEST: COLLECT THE SHINY THINGS.")

func _spawn_duck_mascot() -> void:
	var packed: PackedScene = load("res://assets/DuckBeacon_Mascot.glb")
	if not packed:
		return
	var mascot := packed.instantiate()
	mascot.name = "DuckParadeMascot"
	mascot.position = Vector3(0, 2.2, -2)
	mascot.scale = Vector3.ONE * 0.01
	add_child(mascot)
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_property(mascot, "rotation:y", TAU, 1.4)
	tween.tween_property(mascot, "position:y", 3.0, 0.35)
	tween.tween_property(mascot, "position:y", 2.2, 0.35)
	_remove_mascot_later(mascot)

func _remove_mascot_later(mascot: Node3D) -> void:
	await get_tree().create_timer(EVENT_DURATION).timeout
	if is_instance_valid(mascot):
		mascot.queue_free()

func _end_event() -> void:
	active_event = ""
	event_left = 0.0
	event_clock = EVENT_INTERVAL
	player.apply_event("")
	RenderingServer.set_default_clear_color(Color(0.015, 0.025, 0.055))

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	score_label = _make_label(root, "SCORE 0000", Vector2(22, 16), 26)
	event_label = _make_label(root, "COLLECT THE ORBS • PARKOUR ARENA", Vector2(22, 52), 18)
	status_label = _make_label(root, "WASD move • Space jump • Shift sprint • Ctrl slide • Q dash • Esc mouse", Vector2(22, 84), 14)
	network_status_label = _make_label(root, "MULTIPLAYER • Connecting...", Vector2(22, 198), 14)
	network_host_input = LineEdit.new()
	network_host_input.position = Vector2(22, 226)
	network_host_input.size = Vector2(240, 36)
	network_host_input.placeholder_text = "Server IP / hostname"
	network_host_input.text = OS.get_environment("OXENWAR_SERVER_HOST") if not OS.get_environment("OXENWAR_SERVER_HOST").is_empty() else "127.0.0.1"
	root.add_child(network_host_input)
	var connect_button := Button.new()
	connect_button.text = "CONNECT"
	connect_button.position = Vector2(270, 226)
	connect_button.size = Vector2(112, 36)
	connect_button.pressed.connect(_on_network_connect_pressed)
	root.add_child(connect_button)
	room_code_input = LineEdit.new()
	room_code_input.position = Vector2(22, 272)
	room_code_input.size = Vector2(128, 34)
	room_code_input.placeholder_text = "ROOM CODE"
	root.add_child(room_code_input)
	var create_room_button := Button.new()
	create_room_button.text = "CREATE ROOM"
	create_room_button.position = Vector2(158, 272)
	create_room_button.size = Vector2(112, 34)
	create_room_button.pressed.connect(_on_create_room_pressed)
	root.add_child(create_room_button)
	var quick_match_button := Button.new()
	quick_match_button.text = "QUICK MATCH"
	quick_match_button.position = Vector2(278, 272)
	quick_match_button.size = Vector2(112, 34)
	quick_match_button.pressed.connect(_on_quick_match_pressed)
	root.add_child(quick_match_button)
	var join_room_button := Button.new()
	join_room_button.text = "JOIN"
	join_room_button.position = Vector2(398, 272)
	join_room_button.size = Vector2(72, 34)
	join_room_button.pressed.connect(_on_join_room_pressed)
	root.add_child(join_room_button)
	room_status_label = _make_label(root, "LOBBY • Sign in to play online", Vector2(22, 310), 13)
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(22, 114)
	stamina_bar.size = Vector2(220, 20)
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	root.add_child(stamina_bar)
	level_label = _make_label(root, "LEVEL 1  •  0 / 100 XP", Vector2(22, 144), 17)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(22, 171)
	xp_bar.size = Vector2(220, 13)
	xp_bar.max_value = 100
	xp_bar.show_percentage = false
	root.add_child(xp_bar)

	graphics_option = OptionButton.new()
	graphics_option.anchor_left = 0.78
	graphics_option.anchor_right = 0.98
	graphics_option.anchor_top = 0.09
	graphics_option.anchor_bottom = 0.09
	graphics_option.offset_left = 0
	graphics_option.offset_right = 0
	graphics_option.offset_top = 0
	graphics_option.offset_bottom = 38
	for quality_name in ["AUTO", "LOW", "MEDIUM", "HIGH", "ULTRA"]:
		graphics_option.add_item(quality_name)
	graphics_option.select(["AUTO", "LOW", "MEDIUM", "HIGH", "ULTRA"].find(graphics.quality_setting))
	graphics_option.item_selected.connect(_on_graphics_selected)
	root.add_child(graphics_option)

	var round_label := _make_label(root, "", Vector2(0, 16), 20)
	round_label.anchor_left = 0.78
	round_label.anchor_right = 0.98
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	round_label.name = "RoundLabel"

	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_build_touch_controls(root)
	if admin_available:
		_build_admin_panel(root)
		var admin_button := Button.new()
		admin_button.text = "ADMIN"
		admin_button.anchor_left = 0.78
		admin_button.anchor_right = 0.98
		admin_button.anchor_top = 0.16
		admin_button.anchor_bottom = 0.16
		admin_button.offset_top = 0
		admin_button.offset_bottom = 38
		admin_button.pressed.connect(_toggle_admin_panel)
		root.add_child(admin_button)

func _build_admin_panel(root: Control) -> void:
	admin_hint = _make_label(root, "F8  •  FIXERPLY ADMIN", Vector2(22, 198), 13)
	admin_hint.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	admin_panel = PanelContainer.new()
	admin_panel.name = "AdminPowerPanel"
	admin_panel.anchor_left = 0.69
	admin_panel.anchor_right = 0.985
	admin_panel.anchor_top = 0.16
	admin_panel.anchor_bottom = 0.91
	admin_panel.offset_left = 0
	admin_panel.offset_right = 0
	admin_panel.offset_top = 0
	admin_panel.offset_bottom = 0
	admin_panel.custom_minimum_size = Vector2(330, 0)
	admin_panel.visible = false
	root.add_child(admin_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	admin_panel.add_child(column)
	var title := Label.new()
	title.text = "⚡ ADMIN POWER PANEL"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	column.add_child(title)
	var note := Label.new()
	note.text = "EDITOR TEST MODE • F8 TO CLOSE"
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	column.add_child(note)
	_admin_button(column, "Toggle Fly Mode", _admin_toggle_fly)
	_admin_button(column, "Toggle God Mode Flag", _admin_toggle_god_mode)
	_admin_button(column, "Equip / Remove Thor Hammer", _admin_toggle_hammer)
	_admin_button(column, "Lightning Show", _admin_lightning_show)
	_admin_button(column, "UFO Abduction Troll", _admin_ufo_troll)
	_admin_button(column, "Duck Army", _admin_duck_army)
	_admin_button(column, "Bounce Player (Troll)", _admin_bounce_player)
	_admin_button(column, "Reset Player Position", _admin_reset_player)
	_admin_button(column, "Cycle Map: %s" % _map_name(), _admin_cycle_map)
	_admin_button(column, "Event: LOW GRAVITY", func(): _admin_trigger_event("LOW_GRAVITY"))
	_admin_button(column, "Event: BONK MODE", func(): _admin_trigger_event("BONK_MODE"))
	_admin_button(column, "Event: METEOR SHOWER", func(): _admin_trigger_event("METEOR_SHOWER"))
	_admin_button(column, "Event: DOUBLE XP", func(): _admin_trigger_event("DOUBLE_XP"))
	_admin_button(column, "Stop Current Event", _end_event)
	_admin_button(column, "Close Panel", _toggle_admin_panel)

func _admin_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 32)
	button.pressed.connect(action)
	parent.add_child(button)

func _admin_toggle_fly() -> void:
	if not admin_available or not is_instance_valid(player):
		return
	player.set_admin_fly(not player.admin_fly_enabled)
	_show_meme_toast("ADMIN FLY: %s" % ("ON" if player.admin_fly_enabled else "OFF"))

func _admin_toggle_god_mode() -> void:
	if not admin_available or not is_instance_valid(player):
		return
	player.admin_god_mode = not player.admin_god_mode
	_show_meme_toast("GOD MODE FLAG: %s" % ("ON" if player.admin_god_mode else "OFF"))

func _admin_toggle_hammer() -> void:
	if admin_available and is_instance_valid(player):
		player.toggle_admin_hammer()
		_show_meme_toast("THOR HAMMER %s" % ("EQUIPPED" if player.admin_hammer_equipped else "REMOVED"))

func _admin_lightning_show() -> void:
	if not admin_available or not is_instance_valid(player):
		return
	var bolt := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.8, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.65, 1.0)
	material.emission_energy_multiplier = 5.0
	bolt.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var points := [Vector3(0, 8, 0), Vector3(0.8, 6.4, 0.2), Vector3(-0.5, 4.7, -0.2), Vector3(0.35, 2.8, 0.25), Vector3(0, 0.1, 0)]
	for i in range(points.size() - 1):
		bolt.surface_add_vertex(points[i])
		bolt.surface_add_vertex(points[i + 1])
	bolt.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = bolt
	visual.global_position = player.global_position - player.global_basis.z * 5.0
	add_child(visual)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.25, 0.65, 1.0)
	flash.light_energy = 5.0
	flash.omni_range = 12.0
	visual.add_child(flash)
	var tween := create_tween()
	tween.tween_interval(0.22)
	tween.tween_callback(visual.queue_free)
	_show_meme_toast("THUNDER STRIKE! ⚡ (VISUAL EFFECT)")

func _admin_ufo_troll() -> void:
	if not admin_available or not is_instance_valid(player):
		return
	var ufo := Node3D.new()
	ufo.name = "AdminUFO"
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.35
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.22
	disc.mesh = disc_mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.25, 0.72, 0.9)
	metal.metallic = 0.8
	disc.material_override = metal
	ufo.add_child(disc)
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.62
	dome_mesh.height = 0.7
	dome.mesh = dome_mesh
	dome.position.y = 0.28
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.9, 1.0, 0.72)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome.material_override = glass
	ufo.add_child(dome)
	ufo.global_position = player.global_position + Vector3(0, 10, 0)
	add_child(ufo)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ufo, "global_position", player.global_position + Vector3(0, 3.5, 0), 1.0)
	tween.tween_interval(1.0)
	tween.tween_property(ufo, "global_position", player.global_position + Vector3(0, 10, 0), 1.0)
	tween.tween_callback(ufo.queue_free)
	_show_meme_toast("UFO HAS ACQUIRED THE MAIN CHARACTER 🛸")

func _admin_duck_army() -> void:
	if not admin_available or not is_instance_valid(player):
		return
	var packed: PackedScene = load("res://assets/DuckBeacon_Mascot.glb")
	if not packed:
		return
	for i in range(6):
		var duck := packed.instantiate()
		duck.name = "AdminDuck_%02d" % i
		duck.scale = Vector3.ONE * 0.008
		var angle := TAU * float(i) / 6.0
		duck.global_position = player.global_position + Vector3(cos(angle) * 3.0, 1.0 + float(i % 2), sin(angle) * 3.0)
		add_child(duck)
		var tween := create_tween().set_loops(3)
		tween.tween_property(duck, "rotation:y", TAU, 1.5)
		_remove_mascot_later(duck)
	_show_meme_toast("THE DUCK ARMY HAS ARRIVED 🦆")

func _admin_bounce_player() -> void:
	if admin_available and is_instance_valid(player):
		player.velocity.y = 14.0
		_show_meme_toast("BONK! UP YOU GO.")

func _admin_reset_player() -> void:
	if admin_available and is_instance_valid(player):
		player.global_position = Vector3(0, 1.5, 6)
		player.velocity = Vector3.ZERO
		_show_meme_toast("PLAYER RESET")

func _admin_trigger_event(event_id: String) -> void:
	if (is_instance_valid(network) and network.is_authenticated) or not admin_available or not is_instance_valid(player):
		return
	active_event = event_id
	event_left = EVENT_DURATION * 2.0
	event_clock = EVENT_INTERVAL
	player.apply_event(event_id)
	if event_id == "DUCK_EXE" or event_id == "DUCK_PARADE":
		_spawn_duck_mascot()
	if event_id == "METEOR_SHOWER":
		_spawn_meteor_shower()
	if event_id == "PINK_SKY":
		RenderingServer.set_default_clear_color(Color(0.20, 0.045, 0.18))
	_show_meme_toast("ADMIN EVENT: %s" % EVENT_NAMES.get(event_id, event_id))

func _admin_cycle_map() -> void:
	if not admin_available:
		return
	active_map_index = (active_map_index + 1) % 4
	for extra in map_extras:
		if is_instance_valid(extra):
			extra.queue_free()
	map_extras.clear()
	_apply_map_variant()
	if is_instance_valid(admin_panel):
		for child in admin_panel.find_children("Button", "Button", true, false):
			if child is Button and child.text.begins_with("Cycle Map:"):
				child.text = "Cycle Map: %s" % _map_name()
	_show_meme_toast("MAP: %s" % _map_name())

func _map_name() -> String:
	return ["LOST MALL", "NEON CITY", "SPACE ISLANDS", "CANDY WORLD"][active_map_index]

func _apply_map_variant() -> void:
	if active_map_index == 0:
		return
	var tint := Color(0.1, 0.9, 0.78) if active_map_index == 1 else (Color(0.55, 0.35, 1.0) if active_map_index == 2 else Color(1.0, 0.35, 0.62))
	var layouts := {
		1: [[Vector3(5, 1, 5), Vector3(-12, 1.4, -7)], [Vector3(5, 1, 5), Vector3(12, 2.4, -7)], [Vector3(8, 0.8, 2), Vector3(0, 3.4, -10)], [Vector3(4, 2, 4), Vector3(-13, 3.0, 8)], [Vector3(4, 2, 4), Vector3(13, 3.0, 8)]],
		2: [[Vector3(5, 1, 5), Vector3(-12, 2.0, -8)], [Vector3(5, 1, 5), Vector3(12, 3.0, -8)], [Vector3(4, 1, 4), Vector3(-8, 4.0, 5)], [Vector3(4, 1, 4), Vector3(8, 5.0, 5)], [Vector3(7, 0.8, 2), Vector3(0, 6.0, 0)]],
		3: [[Vector3(7, 1, 5), Vector3(-11, 1.5, -7)], [Vector3(7, 1, 5), Vector3(11, 1.5, -7)], [Vector3(5, 1, 5), Vector3(-10, 2.8, 8)], [Vector3(5, 1, 5), Vector3(10, 2.8, 8)], [Vector3(9, 0.8, 2), Vector3(0, 3.6, 0)]]
	}
	for i in range(layouts[active_map_index].size()):
		var entry: Array = layouts[active_map_index][i]
		var platform := StaticBody3D.new()
		platform.name = "AdminMapPlatform_%d" % i
		platform.position = entry[1]
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = entry[0]
		collider.shape = shape
		platform.add_child(collider)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = entry[0]
		mesh_node.mesh = mesh
		mesh_node.material_override = graphics.make_material(tint)
		platform.add_child(mesh_node)
		add_child(platform)
		map_extras.append(platform)

func _spawn_meteor_shower() -> void:
	for i in range(7):
		var meteor := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.32
		mesh.height = 0.64
		meteor.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.42, 0.12)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.18, 0.04)
		material.emission_energy_multiplier = 2.2
		meteor.material_override = material
		meteor.position = Vector3(rng.randf_range(-14, 14), 13 + i * 0.7, rng.randf_range(-11, 11))
		add_child(meteor)
		var target := Vector3(meteor.position.x + rng.randf_range(-2, 2), 0.2, meteor.position.z + rng.randf_range(-2, 2))
		var tween := create_tween()
		tween.tween_property(meteor, "position", target, rng.randf_range(1.0, 1.8))
		tween.tween_callback(meteor.queue_free)

func _make_label(parent: Control, text_value: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _build_touch_controls(root: Control) -> void:
	var move_specs := [
		["◀", "move_left", Vector2(26, -132)],
		["▶", "move_right", Vector2(150, -132)],
		["▲", "move_forward", Vector2(88, -194)],
		["▼", "move_back", Vector2(88, -70)]
	]
	for spec in move_specs:
		_add_touch_button(root, spec[0], spec[1], spec[2], Vector2(56, 56), true)
	_add_touch_button(root, "JUMP", "jump", Vector2(-250, -190), Vector2(96, 64), false)
	_add_touch_button(root, "DASH", "dash", Vector2(-150, -118), Vector2(88, 60), false)
	_add_touch_button(root, "SPRINT", "sprint", Vector2(-250, -110), Vector2(96, 54), true)
	_add_touch_button(root, "SLIDE", "slide", Vector2(-150, -48), Vector2(88, 54), true)

func _add_touch_button(root: Control, text_value: String, action: String, offset: Vector2, button_size: Vector2, hold_action: bool) -> void:
	var button := Button.new()
	button.text = text_value
	button.size = button_size
	button.anchor_left = 1.0 if offset.x < 0 else 0.0
	button.anchor_right = 1.0 if offset.x < 0 else 0.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.position = offset
	button.add_theme_font_size_override("font_size", 17)
	button.modulate = Color(0.78, 0.93, 1.0, 0.82)
	root.add_child(button)
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
	button.tree_exiting.connect(func(): Input.action_release(action))


func _finish_round() -> void:
	if _round_finished:
		return
	_round_finished = true
	if is_instance_valid(player):
		progression.record_score(player.score)
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)

	var overlay := ColorRect.new()
	overlay.name = "RoundFinishedOverlay"
	overlay.color = Color(0.015, 0.025, 0.055, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 250)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.085, 0.14, 1.0)
	panel_style.border_color = Color(0.12, 0.78, 0.68, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title := Label.new()
	title.text = "ROUND COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.86))
	column.add_child(title)

	var result := Label.new()
	result.text = "FINAL SCORE  %04d" % player.score
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 23)
	result.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	column.add_child(result)

	var hint := Label.new()
	hint.text = "Nice run! Try again and beat your score."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.68, 0.78, 0.88))
	column.add_child(hint)

	var restart := Button.new()
	restart.text = "PLAY AGAIN"
	restart.custom_minimum_size = Vector2(180, 48)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	column.add_child(restart)


func _on_level_up(new_level: int, reward: String) -> void:
	_show_meme_toast("LEVEL UP!  LEVEL %d  •  UNLOCKED: %s" % [new_level, reward])
	_update_hud()

func _show_meme_toast(message: String) -> void:
	if not is_instance_valid(hud_layer):
		return
	var toast := Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_left = 0.12
	toast.anchor_right = 0.88
	toast.anchor_top = 0.34
	toast.anchor_bottom = 0.34
	toast.add_theme_font_size_override("font_size", 23)
	toast.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	hud_layer.add_child(toast)
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.12)
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.55)
	tween.tween_callback(toast.queue_free)

func _on_graphics_selected(index: int) -> void:
	var options := ["AUTO", "LOW", "MEDIUM", "HIGH", "ULTRA"]
	graphics.set_quality(options[index])
	_show_meme_toast("GRAPHICS: %s  →  %s" % [graphics.quality_setting, graphics.resolved_quality])

func _refresh_graphics_materials(_new_quality: String = "") -> void:
	for i in range(arena_meshes.size()):
		if is_instance_valid(arena_meshes[i]):
			arena_meshes[i].material_override = graphics.make_material(arena_colors[i])

func _on_collected(_points: int) -> void:
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(score_label):
		return
	score_label.text = "SCORE %04d" % player.score
	if is_instance_valid(progression) and is_instance_valid(level_label):
		level_label.text = "LEVEL %d  •  %d / %d XP" % [progression.level, progression.xp, progression.xp_for_next_level()]
		xp_bar.max_value = progression.xp_for_next_level()
		xp_bar.value = progression.xp
	stamina_bar.value = player.stamina
	if active_event.is_empty():
		event_label.text = "COLLECT THE ORBS • NEXT EVENT %02d" % ceili(event_clock)
	else:
		event_label.text = "%s  %02d" % [EVENT_NAMES.get(active_event, active_event), ceili(event_left)]
	var round_label := hud_layer.get_node_or_null("Control/RoundLabel")
	if round_label:
		round_label.text = "ROUND %02d:%02d" % [int(int(round_left) / 60), int(round_left) % 60]
	if status_label:
		status_label.text = "STAMINA %d%%  •  %s" % [int(player.stamina), "LOW GRAVITY ACTIVE" if active_event == "LOW_GRAVITY" else "PARKOUR ARENA"]
