extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const BACKEND_SCRIPT = preload("res://scripts/oxenwar_supabase.gd")
const MENU_SCRIPT = preload("res://scripts/oxenwar_menu.gd")
const NETWORK_SCRIPT = preload("res://scripts/oxenwar_network.gd")
const EVENT_FX_SCRIPT = preload("res://scripts/oxenwar_event_fx.gd")
const COMBAT_FX_SCRIPT = preload("res://scripts/combat_fx.gd")
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
var health_bar: ProgressBar
var health_label: Label
var death_label: Label
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
var active_map_index := 4
var selected_game_mode := "ffa"
var _client_grenade_visuals: Dictionary = {}
var admin_available := false
var admin_panel: PanelContainer
var admin_hint: Label
var network: Node
var event_fx: Node3D
var network_status_label: Label
var network_host_input: LineEdit
var room_code_input: LineEdit
var friend_name_input: LineEdit
var room_status_label: Label
var remote_players: Dictionary = {}
var match_killboard: Dictionary = {}
var match_stats: Dictionary = {}
var kill_feed_container: VBoxContainer
var scoreboard_panel: PanelContainer
var scoreboard_rows: VBoxContainer
var scoreboard_local_stats: Label
var active_room_mode := "ffa"
var round_match_xp := 0
var hill_points_red := 0.0
var hill_points_blue := 0.0
var hill_control := 0.0
var objective_label: Label
var killstreak_label: Label

const RANK_THRESHOLDS := [
	{"id":"bronze", "xp":0, "color":Color("#B87945")},
	{"id":"silver", "xp":500, "color":Color("#B9C5D1")},
	{"id":"gold", "xp":1500, "color":Color("#F0C65A")},
	{"id":"platinum", "xp":3500, "color":Color("#58D6D0")},
	{"id":"diamond", "xp":7000, "color":Color("#65AFFF")},
	{"id":"master", "xp":12000, "color":Color("#C18AFF")}
]

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
	"FREEZE_FRAME": "FREEZE FRAME — MOVEMENT PAUSED",
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
	event_fx = EVENT_FX_SCRIPT.new()
	event_fx.name = "OxenWarEventFX"
	add_child(event_fx)
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
		if is_instance_valid(network):
			network.update_access_token(str(backend.access_token))

func _start_dedicated_server() -> void:
	# Dedicated server builds the same collision arena before accepting players.
	graphics = GraphicsManager.new()
	graphics.load_settings()
	_build_arena()
	network = NETWORK_SCRIPT.new()
	network.name = "OxenWarNet"
	add_child(network)
	if not network.start_server():
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--smoke-test"):
		print("OxenWar dedicated server smoke test passed")
		get_tree().quit()

func _start_multiplayer_client() -> void:
	network = NETWORK_SCRIPT.new()
	network.name = "OxenWarNet"
	add_child(network)
	network.player_state_received.connect(_on_remote_player_state)
	network.blaster_fx_received.connect(_on_blaster_fx_received)
	network.grenade_spawn_received.connect(_on_grenade_spawn_received)
	network.grenade_exploded_received.connect(_on_grenade_exploded_received)
	network.kill_feed_received.connect(_on_kill_feed_received)
	network.killstreak_received.connect(_on_killstreak_received)
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
	if is_instance_valid(killstreak_label):
		var streak_now := int(state.get("kill_streak", 0))
		killstreak_label.text = "KILL STREAK  x%d" % streak_now if streak_now >= 2 else ""
		killstreak_label.visible = streak_now >= 2
	match_killboard[local_player_name] = int(state.get("kills", 0))
	_update_player_match_stats(local_player_name, state)
	player.stamina = float(state.get("stamina", player.stamina))
	player.health = float(state.get("health", player.health))
	player.is_dead = bool(state.get("dead", false))
	player.respawn_left = float(state.get("respawn_left", 0.0))
	player.set_swimming(bool(state.get("is_swimming", false)))
	player.apply_server_slide(bool(state.get("sliding", false)))
	var team_label := hud_layer.get_node_or_null("Control/TeamLabel") if is_instance_valid(hud_layer) else null
	if team_label:
		team_label.text = "TEAM " + str(state.get("team_id", "FREE")).to_upper()
	if is_instance_valid(progression):
		progression.sync_server_total_xp(int(state.get("xp", progression.total_xp)))
	_update_hud()

func _on_network_room_state(state: Dictionary) -> void:
	if state.has("event_id"):
		var next_event := str(state.get("event_id", ""))
		if next_event != active_event:
			active_event = next_event
			_on_server_event_changed(active_event)
		event_left = float(state.get("event_left", 0.0))
		round_left = float(state.get("round_left", ROUND_SECONDS))
		active_room_mode = str(state.get("mode", active_room_mode))
		hill_control = float(state.get("hill_control", hill_control))
		hill_points_red = float(state.get("hill_points_red", hill_points_red))
		hill_points_blue = float(state.get("hill_points_blue", hill_points_blue))
		if is_instance_valid(objective_label):
			objective_label.visible = active_room_mode == "king_of_the_hill"
			var hill_owner := "RED" if hill_control >= 100.0 else ("BLUE" if hill_control <= -100.0 else ("CONTESTED" if absf(hill_control) > 0.1 else "NEUTRAL"))
			objective_label.text = "HILL %s  •  RED %02d / BLUE %02d  •  CAPTURE %d%%" % [hill_owner, int(hill_points_red), int(hill_points_blue), int(absf(hill_control))]
		if round_left <= 0.0 and not _round_finished:
			_finish_round()
		var available: Dictionary = state.get("orb_available", {})
		for index in range(orb_spawns.size()):
			var orb = get_node_or_null("GoldenOrb_%02d" % index)
			if is_instance_valid(orb) and available.has(index):
				orb.visible = bool(available[index])
	if state.has("members"):
		var members: Array = state.get("members", [])
		var names: Array[String] = []
		for member in members:
			names.append(str(member.get("display_name", "Player")) + ("" if bool(member.get("online", false)) else " (offline)"))
		if is_instance_valid(room_status_label):
			room_status_label.text = "ROOM %s • %s • %d/%d • %s" % [
				str(state.get("code", "")), str(state.get("mode", "ffa")).to_upper(), members.size(), int(state.get("max_players", 8)),
				", ".join(names)
			]
	_update_hud()

func _on_server_event_changed(event_id: String) -> void:
	if is_instance_valid(event_fx):
		event_fx.set_event(event_id)
	if is_instance_valid(player):
		player.apply_event(event_id)
	if event_id.is_empty():
		RenderingServer.set_default_clear_color(Color(0.015, 0.025, 0.055))
		return
	if event_id == "PINK_SKY":
		RenderingServer.set_default_clear_color(Color(0.20, 0.045, 0.18))
	if event_id == "DUCK_PARADE" or event_id == "DUCK_EXE":
		_spawn_duck_mascot()
	if event_id == "METEOR_SHOWER":
		_spawn_meteor_shower()
	var messages := {
		"METEOR_SHOWER": "LOOK UP! DECORATIVE METEORS",
		"ICE_WORLD": "ICE WORLD: SERVER-SIMULATED SLIPPERY MOVEMENT",
		"DOUBLE_XP": "DOUBLE XP IS ACTIVE",
		"BONK_MODE": "BONK MODE: SERVER SPEED BOOST",
		"NPC_MODE": "NPC MODE: MOVEMENT MODIFIER",
		"GOLDEN_ORB_RUSH": "GOLDEN ORB RUSH: BONUS REWARDS",
		"CONFETTI_STORM": "CONFETTI STORM!",
		"DUCK_PARADE": "DUCK PARADE!",
		"DUCK_EXE": "DUCK.EXE HAS STOPPED RESPONDING",
		"FREEZE_FRAME": "FREEZE FRAME: ALL MOVEMENT PAUSED"
	}
	if messages.has(event_id):
		_show_meme_toast(str(messages[event_id]))

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
		network.request_create_room(true, selected_game_mode)

func _on_quick_match_pressed() -> void:
	if is_instance_valid(network):
		network.request_quick_match(selected_game_mode)

func _on_join_room_pressed() -> void:
	if is_instance_valid(network) and is_instance_valid(room_code_input):
		network.request_join_room(room_code_input.text)

func _on_invite_friend_pressed() -> void:
	if not is_instance_valid(network) or not network.is_authenticated or not is_instance_valid(backend) or not is_instance_valid(friend_name_input):
		return
	var target_name := friend_name_input.text.strip_edges().to_lower()
	if target_name.is_empty():
		return
	var friends: Dictionary = await backend.get_friends()
	if not friends.get("ok", false):
		if is_instance_valid(room_status_label):
			room_status_label.text = "Could not load friends"
		return
	for friend in friends.get("data", []):
		if str(friend.get("username", "")).to_lower() == target_name:
			network.request_invite_friend(str(friend.get("id", "")))
			if is_instance_valid(room_status_label):
				room_status_label.text = "Invite sent to " + str(friend.get("username", "friend"))
			return
	if is_instance_valid(room_status_label):
		room_status_label.text = "Friend username not found"

func _on_remote_player_state(peer_id: int, state: Dictionary) -> void:
	var remote_name := str(state.get("display_name", "Player"))
	match_killboard[remote_name] = int(state.get("kills", 0))
	_update_player_match_stats(remote_name, state)
	var remote = remote_players.get(peer_id)
	if not is_instance_valid(remote):
		remote = REMOTE_PLAYER_SCRIPT.new()
		remote.name = "RemotePlayer_%d" % peer_id
		add_child(remote)
		remote_players[peer_id] = remote
		remote.set_player_identity(str(state.get("display_name", "Player")), Color.from_string(str(state.get("color", "#27D7E7")), Color("#27D7E7")), str(state.get("outfit_id", "outfit_default")) )
	remote.apply_network_state(state.get("position", Vector3.ZERO), float(state.get("yaw", 0.0)), bool(state.get("sliding", false)), float(state.get("health", 100.0)), bool(state.get("dead", false)), str(state.get("team_id", "")), str(state.get("emote_id", "")), bool(state.get("is_swimming", false)))

func _make_remote_blaster_stream() -> AudioStreamWAV:
	const sample_rate := 22050
	const duration := 0.19
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var envelope := pow(maxf(0.0, 1.0 - float(i) / float(count)), 2.0)
		var sweep := sin(TAU * (260.0 - 105.0 * t / duration) * t)
		var overtone := sin(TAU * 520.0 * t) * 0.22
		var sample := clampf((sweep * 0.58 + overtone) * envelope * 0.72, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _on_blaster_fx_received(shooter_peer_id: int, origin: Vector3, endpoint: Vector3) -> void:
	var remote_audio := AudioStreamPlayer3D.new()
	remote_audio.name = "RemoteAetherPulseAudio"
	remote_audio.stream = _make_remote_blaster_stream()
	remote_audio.volume_db = -7.0
	remote_audio.max_distance = 42.0
	remote_audio.unit_size = 9.0
	add_child(remote_audio)
	remote_audio.global_position = origin
	remote_audio.play()
	remote_audio.finished.connect(remote_audio.queue_free)
	var beam := MeshInstance3D.new()
	beam.name = "RemoteAetherPulse"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 1.0)
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.9, 1.0, 0.92)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color("#35EFFF")
	material.emission_energy_multiplier = 2.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = material
	add_child(beam)
	beam.global_position = (origin + endpoint) * 0.5
	var up := Vector3.RIGHT if absf((endpoint - origin).normalized().dot(Vector3.UP)) > 0.97 else Vector3.UP
	beam.look_at(endpoint, up)
	beam.scale.z = maxf(0.05, origin.distance_to(endpoint))
	get_tree().create_timer(0.085).timeout.connect(beam.queue_free)
	if origin.distance_to(endpoint) < 64.0:
		COMBAT_FX_SCRIPT.hit_impact(self, endpoint)

func _on_grenade_spawn_received(grenade_id: int, origin: Vector3, launch_velocity: Vector3) -> void:
	var grenade := MeshInstance3D.new()
	grenade.name = "NetworkGrenade_%d" % grenade_id
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	grenade.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#E7A83E")
	material.metallic = 0.55
	material.roughness = 0.35
	grenade.material_override = material
	add_child(grenade)
	grenade.global_position = origin
	_client_grenade_visuals[grenade_id] = {"node": grenade, "velocity": launch_velocity}

func _on_grenade_exploded_received(grenade_id: int, position_value: Vector3) -> void:
	var entry: Dictionary = _client_grenade_visuals.get(grenade_id, {})
	var grenade: Node = entry.get("node")
	if is_instance_valid(grenade):
		grenade.queue_free()
	_client_grenade_visuals.erase(grenade_id)
	COMBAT_FX_SCRIPT.grenade_explosion(self, position_value)

func _update_player_match_stats(player_name: String, state: Dictionary) -> void:
	match_stats[player_name] = {
		"kills": int(state.get("kills", 0)), "deaths": int(state.get("deaths", 0)),
		"score": int(state.get("score", 0)), "team_id": str(state.get("team_id", "")),
		"shots_fired": int(state.get("shots_fired", 0)), "shots_hit": int(state.get("shots_hit", 0)),
		"damage_dealt": float(state.get("damage_dealt", 0.0)),
		"damage_received": float(state.get("damage_received", 0.0)),
		"match_xp": maxi(0, int(state.get("match_xp", 0)))
	}
	_refresh_scoreboard()

func _refresh_scoreboard() -> void:
	if not is_instance_valid(scoreboard_rows):
		return
	for child in scoreboard_rows.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = []
	for player_name in match_stats.keys():
		var stats: Dictionary = match_stats[player_name]
		entries.append({"name": str(player_name), "kills": int(stats.get("kills", 0)), "deaths": int(stats.get("deaths", 0)), "score": int(stats.get("score", 0))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.kills) == int(b.kills):
			return int(a.score) > int(b.score)
		return int(a.kills) > int(b.kills)
	)
	var local_stats: Dictionary = match_stats.get(local_player_name, {})
	if is_instance_valid(scoreboard_local_stats):
		scoreboard_local_stats.text = "YOU  •  K %d   D %d   SCORE %d" % [int(local_stats.get("kills", 0)), int(local_stats.get("deaths", 0)), int(local_stats.get("score", 0))]
	for index in range(mini(entries.size(), 8)):
		var entry: Dictionary = entries[index]
		var row := Label.new()
		row.text = "%d. %-22s %3d   %3d   %6d" % [index + 1, str(entry.name).substr(0, 22), int(entry.kills), int(entry.deaths), int(entry.score)]
		row.add_theme_color_override("font_color", Color("#E7F4FF") if str(entry.name) == local_player_name else Color("#AFC4D4"))
		scoreboard_rows.add_child(row)

func _toggle_scoreboard() -> void:
	if is_instance_valid(scoreboard_panel):
		scoreboard_panel.visible = not scoreboard_panel.visible
		if scoreboard_panel.visible:
			_refresh_scoreboard()

func _on_kill_feed_received(killer_name: String, victim_name: String, weapon_name: String) -> void:
	if not is_instance_valid(kill_feed_container):
		return
	var entry := Label.new()
	entry.text = "%s   ▸   %s   [%s]" % [killer_name, victim_name, weapon_name]
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.add_theme_font_size_override("font_size", 15)
	entry.add_theme_color_override("font_color", Color("#E9F8FF"))
	kill_feed_container.add_child(entry)
	while kill_feed_container.get_child_count() > 5:
		kill_feed_container.get_child(0).queue_free()
	var fade := create_tween()
	fade.tween_interval(5.0)
	fade.tween_property(entry, "modulate:a", 0.0, 0.45)
	fade.tween_callback(entry.queue_free)


func _on_killstreak_received(player_name: String, streak: int, bonus: int) -> void:
	var title := "DOMINATING" if streak >= 10 else ("UNSTOPPABLE" if streak >= 7 else ("RAMPAGE" if streak >= 5 else "KILL STREAK"))
	_show_meme_toast("%s  •  %s x%d  •  +%d SCORE" % [player_name.to_upper(), title, streak, bonus])

func _on_remote_player_left(peer_id: int) -> void:
	var remote: Node = remote_players.get(peer_id)
	if is_instance_valid(remote):
		remote.queue_free()
	remote_players.erase(peer_id)

func _process(delta: float) -> void:
	if OS.get_cmdline_user_args().has("--server"):
		return
	for grenade_id in _client_grenade_visuals.keys():
		var entry: Dictionary = _client_grenade_visuals[grenade_id]
		var grenade_node: Node3D = entry.get("node")
		if not is_instance_valid(grenade_node):
			_client_grenade_visuals.erase(grenade_id)
			continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		velocity.y -= 9.8 * delta
		grenade_node.global_position += velocity * delta
		entry.velocity = velocity
		_client_grenade_visuals[grenade_id] = entry
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
	if event.is_action_pressed("throw_grenade") and is_instance_valid(network) and network.is_authenticated and is_instance_valid(player):
		network.request_grenade_throw(-player.global_basis.z + Vector3.UP * 0.12)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_scoreboard()
		get_viewport().set_input_as_handled()
		return
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
	_add_key_action("throw_grenade", KEY_G)
	_add_key_action("emote_griddy", KEY_B)
	_add_key_action("emote_goofy", KEY_N)
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("slide", KEY_CTRL)
	_add_key_action("dash", KEY_Q)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	var fire_mouse := InputEventMouseButton.new()
	fire_mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", fire_mouse)
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
	sky_material.ground_bottom_color = Color("#111827")
	sky_material.ground_horizon_color = Color("#3B3550")
	sky_material.sun_angle_max = 28.0
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
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 52.0
	sun.shadow_blur = 2.0
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
	_build_swimming_pool()
	if not OS.get_cmdline_user_args().has("--server"):
		_build_arena_detail_pass()

func _build_arena_detail_pass() -> void:
	# Lightweight, collision-free art pass; dedicated servers skip all decorative nodes.
	var root := Node3D.new()
	root.name = "ArenaArtDetailPass"
	add_child(root)
	var trim := Color("#21DCCB")
	var pale := Color("#8BEAFF")
	var dark := Color("#18283A")
	_add_detail_box(root, "NorthFloorTrim", Vector3(34.8, 0.035, 0.10), Vector3(0, 0.025, -14.02), trim, 0.65)
	_add_detail_box(root, "SouthFloorTrim", Vector3(34.8, 0.035, 0.10), Vector3(0, 0.025, 14.02), trim, 0.65)
	_add_detail_box(root, "EastFloorTrim", Vector3(0.10, 0.035, 27.8), Vector3(17.02, 0.025, 0), pale, 0.55)
	_add_detail_box(root, "WestFloorTrim", Vector3(0.10, 0.035, 27.8), Vector3(-17.02, 0.025, 0), pale, 0.55)
	for x_index in range(-5, 6):
		var x := float(x_index) * 3.0
		_add_detail_box(root, "FloorGridX_%d" % x_index, Vector3(0.018, 0.012, 27.0), Vector3(x, 0.012, 0), dark, 0.0)
	for z_index in range(-4, 5):
		var z := float(z_index) * 3.0
		_add_detail_box(root, "FloorGridZ_%d" % z_index, Vector3(33.0, 0.012, 0.018), Vector3(0, 0.012, z), dark, 0.0)
	for corner in [Vector2(-16.2, -13.0), Vector2(16.2, -13.0), Vector2(-16.2, 13.0), Vector2(16.2, 13.0)]:
		_add_detail_box(root, "CornerBeaconHousing", Vector3(0.42, 3.0, 0.42), Vector3(corner.x, 1.5, corner.y), dark, 0.0)
		_add_detail_box(root, "CornerBeaconCap", Vector3(0.54, 0.12, 0.54), Vector3(corner.x, 2.95, corner.y), pale, 1.1)
		var beacon := OmniLight3D.new()
		beacon.name = "CornerBeaconLight"
		beacon.position = Vector3(corner.x, 2.65, corner.y)
		beacon.light_color = trim
		beacon.light_energy = 0.48 if graphics.resolved_quality in ["HIGH", "ULTRA"] else 0.22
		beacon.omni_range = 5.5
		beacon.shadow_enabled = graphics.resolved_quality == "ULTRA"
		root.add_child(beacon)
	_add_detail_box(root, "A_Site_Inlay", Vector3(2.2, 0.018, 0.08), Vector3(-11.0, 0.205, -13.0), Color("#FFB45C"), 0.3)
	_add_detail_box(root, "B_Site_Inlay", Vector3(2.2, 0.018, 0.08), Vector3(11.0, 0.205, 13.0), Color("#64B7FF"), 0.3)
	_add_detail_box(root, "Mid_Inlay", Vector3(0.08, 0.018, 2.2), Vector3(0, 0.205, -4.0), pale, 0.25)
	_add_detail_box(root, "Hill_North_Beam", Vector3(10.0, 0.045, 0.12), Vector3(0, 0.24, -5.0), Color("#F5C65D"), 1.2)
	_add_detail_box(root, "Hill_South_Beam", Vector3(10.0, 0.045, 0.12), Vector3(0, 0.24, 5.0), Color("#F5C65D"), 1.2)
	_add_detail_box(root, "Hill_East_Beam", Vector3(0.12, 0.045, 10.0), Vector3(5.0, 0.24, 0), Color("#F5C65D"), 1.2)
	_add_detail_box(root, "Hill_West_Beam", Vector3(0.12, 0.045, 10.0), Vector3(-5.0, 0.24, 0), Color("#F5C65D"), 1.2)

func _add_detail_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, emission_strength: float) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.28
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_strength
	mesh_node.material_override = material
	parent.add_child(mesh_node)
	return mesh_node

func _build_swimming_pool() -> void:
	var water := MeshInstance3D.new()
	water.name = "BeachPoolWater"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(8.0, 0.12, 8.0)
	water.mesh = water_mesh
	water.position = Vector3(-12.0, 0.12, -9.0)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.05, 0.48, 0.78, 0.78)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.18
	water_material.metallic = 0.12
	water_material.emission_enabled = true
	water_material.emission = Color(0.02, 0.16, 0.25)
	water_material.emission_energy_multiplier = 0.25
	water.material_override = water_material
	add_child(water)
	var pool_label := Label3D.new()
	pool_label.name = "SwimZoneLabel"
	pool_label.text = "BEACH / SWIM ZONE"
	pool_label.position = Vector3(-12.0, 0.45, -13.1)
	pool_label.font_size = 30
	pool_label.outline_size = 6
	pool_label.pixel_size = 0.008
	pool_label.modulate = Color("#BCEFFF")
	add_child(pool_label)

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
	var xp_gain := (25 if active_event == "GOLDEN_ORB_RUSH" else 15) * (2 if active_event == "DOUBLE_XP" else 1)
	player.add_score(points)
	progression.add_xp(xp_gain)
	round_match_xp += xp_gain
	if index == 11 and progression.discover_secret():
		round_match_xp += 100
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
	var choices: Array[String] = ["DUCK_PARADE", "PINK_SKY", "GOLDEN_ORB_RUSH", "CONFETTI_STORM", "LOW_GRAVITY", "BONK_MODE", "NPC_MODE", "DUCK_EXE", "METEOR_SHOWER", "ICE_WORLD", "FREEZE_FRAME", "DOUBLE_XP"]
	active_event = choices[rng.randi_range(0, choices.size() - 1)]
	event_left = EVENT_DURATION
	event_clock = EVENT_INTERVAL
	player.apply_event(active_event)
	if is_instance_valid(event_fx):
		event_fx.set_event(active_event)
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
	if is_instance_valid(event_fx):
		event_fx.set_event("")
	RenderingServer.set_default_clear_color(Color(0.015, 0.025, 0.055))

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)
	_add_hud_panel(root, "CombatStatusPanel", Vector2(12, 8), Vector2(472, 112), Color(0.025, 0.055, 0.09, 0.84), Color("#27D7E7"))
	_add_hud_panel(root, "VitalsPanel", Vector2(12, 112), Vector2(252, 122), Color(0.025, 0.055, 0.09, 0.88), Color("#3D8FA8"))
	_add_hud_panel(root, "LobbyPanel", Vector2(12, 238), Vector2(472, 252), Color(0.025, 0.055, 0.09, 0.78), Color("#34566A"))

	score_label = _make_label(root, "SCORE 0000", Vector2(22, 16), 26)
	event_label = _make_label(root, "COLLECT THE ORBS • PARKOUR ARENA", Vector2(22, 52), 18)
	status_label = _make_label(root, "WASD move • Space jump • Shift sprint • Ctrl slide • Q dash • Esc mouse", Vector2(22, 84), 14)
	network_status_label = _make_label(root, "MULTIPLAYER • Connecting...", Vector2(22, 245), 14)
	network_host_input = LineEdit.new()
	network_host_input.position = Vector2(22, 273)
	network_host_input.size = Vector2(240, 36)
	network_host_input.placeholder_text = "Server IP / hostname"
	network_host_input.text = OS.get_environment("OXENWAR_SERVER_HOST") if not OS.get_environment("OXENWAR_SERVER_HOST").is_empty() else "127.0.0.1"
	root.add_child(network_host_input)
	var connect_button := Button.new()
	connect_button.text = "CONNECT"
	connect_button.position = Vector2(270, 273)
	connect_button.size = Vector2(112, 36)
	connect_button.pressed.connect(_on_network_connect_pressed)
	root.add_child(connect_button)
	room_code_input = LineEdit.new()
	room_code_input.position = Vector2(22, 319)
	room_code_input.size = Vector2(128, 34)
	room_code_input.placeholder_text = "ROOM CODE"
	root.add_child(room_code_input)
	var create_room_button := Button.new()
	create_room_button.text = "CREATE ROOM"
	create_room_button.position = Vector2(158, 319)
	create_room_button.size = Vector2(112, 34)
	create_room_button.pressed.connect(_on_create_room_pressed)
	root.add_child(create_room_button)
	var quick_match_button := Button.new()
	quick_match_button.text = "QUICK MATCH"
	quick_match_button.position = Vector2(278, 319)
	quick_match_button.size = Vector2(112, 34)
	quick_match_button.pressed.connect(_on_quick_match_pressed)
	root.add_child(quick_match_button)
	var join_room_button := Button.new()
	join_room_button.text = "JOIN"
	join_room_button.position = Vector2(398, 319)
	join_room_button.size = Vector2(72, 34)
	join_room_button.pressed.connect(_on_join_room_pressed)
	root.add_child(join_room_button)
	friend_name_input = LineEdit.new()
	friend_name_input.position = Vector2(22, 359)
	friend_name_input.size = Vector2(160, 34)
	friend_name_input.placeholder_text = "Friend username"
	root.add_child(friend_name_input)
	var invite_friend_button := Button.new()
	invite_friend_button.text = "INVITE FRIEND"
	invite_friend_button.position = Vector2(190, 359)
	invite_friend_button.size = Vector2(118, 34)
	invite_friend_button.pressed.connect(_on_invite_friend_pressed)
	root.add_child(invite_friend_button)
	room_status_label = _make_label(root, "LOBBY • Sign in to play online", Vector2(22, 397), 13)
	var mode_select := OptionButton.new()
	mode_select.position = Vector2(22, 440)
	mode_select.size = Vector2(220, 32)
	mode_select.add_item("FREE FOR ALL")
	mode_select.set_item_metadata(0, "ffa")
	mode_select.add_item("TEAM DEATHMATCH")
	mode_select.set_item_metadata(1, "team_deathmatch")
	mode_select.add_item("KING OF THE HILL")
	mode_select.set_item_metadata(2, "king_of_the_hill")
	mode_select.item_selected.connect(func(index: int): selected_game_mode = str(mode_select.get_item_metadata(index)))
	root.add_child(mode_select)
	health_label = _make_label(root, "HEALTH 100 / 100", Vector2(22, 108), 14)
	objective_label = _make_label(root, "HILL NEUTRAL", Vector2(500, 18), 17)
	objective_label.visible = false
	objective_label.add_theme_color_override("font_color", Color("#F5D27A"))
	killstreak_label = _make_label(root, "", Vector2(500, 52), 21)
	killstreak_label.visible = false
	killstreak_label.add_theme_color_override("font_color", Color("#FFB84D"))
	var team_label := _make_label(root, "TEAM FREE", Vector2(22, 148), 14)
	team_label.name = "TeamLabel"
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(22, 128)
	health_bar.size = Vector2(220, 16)
	health_bar.max_value = 100
	health_bar.show_percentage = false
	root.add_child(health_bar)
	death_label = _make_label(root, "", Vector2(0, 0), 34)
	death_label.anchor_left = 0.5
	death_label.anchor_right = 0.5
	death_label.anchor_top = 0.5
	death_label.anchor_bottom = 0.5
	death_label.offset_left = -220
	death_label.offset_right = 220
	death_label.offset_top = -50
	death_label.offset_bottom = 50
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_color_override("font_color", Color("#FF667A"))
	root.add_child(death_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(22, 152)
	stamina_bar.size = Vector2(220, 20)
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	root.add_child(stamina_bar)
	level_label = _make_label(root, "LEVEL 1  •  0 / 100 XP", Vector2(22, 180), 17)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(22, 207)
	xp_bar.size = Vector2(220, 13)
	xp_bar.max_value = 100
	xp_bar.show_percentage = false
	root.add_child(xp_bar)

	_style_progress_bar(health_bar, Color("#FF536B"), Color("#401C2B"))
	_style_progress_bar(stamina_bar, Color("#39D9D0"), Color("#153C4B"))
	_style_progress_bar(xp_bar, Color("#B18CFF"), Color("#2D244D"))

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

	kill_feed_container = VBoxContainer.new()
	kill_feed_container.name = "KillFeed"
	kill_feed_container.anchor_left = 0.68
	kill_feed_container.anchor_right = 0.985
	kill_feed_container.anchor_top = 0.17
	kill_feed_container.anchor_bottom = 0.17
	kill_feed_container.offset_left = 0
	kill_feed_container.offset_right = 0
	kill_feed_container.offset_top = 0
	kill_feed_container.offset_bottom = 180
	kill_feed_container.add_theme_constant_override("separation", 5)
	root.add_child(kill_feed_container)

	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.name = "MatchScoreboard"
	scoreboard_panel.anchor_left = 0.5
	scoreboard_panel.anchor_right = 0.5
	scoreboard_panel.anchor_top = 0.16
	scoreboard_panel.anchor_bottom = 0.16
	scoreboard_panel.offset_left = -235
	scoreboard_panel.offset_right = 235
	scoreboard_panel.offset_top = 0
	scoreboard_panel.offset_bottom = 340
	scoreboard_panel.visible = false
	var scoreboard_style := StyleBoxFlat.new()
	scoreboard_style.bg_color = Color(0.018, 0.04, 0.07, 0.96)
	scoreboard_style.border_color = Color("#27D7E7")
	scoreboard_style.set_border_width_all(2)
	scoreboard_style.set_corner_radius_all(12)
	scoreboard_style.content_margin_left = 16
	scoreboard_style.content_margin_right = 16
	scoreboard_style.content_margin_top = 12
	scoreboard_style.content_margin_bottom = 12
	scoreboard_panel.add_theme_stylebox_override("panel", scoreboard_style)
	root.add_child(scoreboard_panel)
	var scoreboard_column := VBoxContainer.new()
	scoreboard_column.add_theme_constant_override("separation", 8)
	scoreboard_panel.add_child(scoreboard_column)
	var scoreboard_title := Label.new()
	scoreboard_title.text = "MATCH SCOREBOARD"
	scoreboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_title.add_theme_font_size_override("font_size", 22)
	scoreboard_title.add_theme_color_override("font_color", Color("#42E7F0"))
	scoreboard_column.add_child(scoreboard_title)
	scoreboard_local_stats = Label.new()
	scoreboard_local_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_column.add_child(scoreboard_local_stats)
	var scoreboard_header := Label.new()
	scoreboard_header.text = "PLAYER                              K     D      SCORE"
	scoreboard_header.add_theme_color_override("font_color", Color("#9CB8C9"))
	scoreboard_column.add_child(scoreboard_header)
	scoreboard_rows = VBoxContainer.new()
	scoreboard_rows.add_theme_constant_override("separation", 4)
	scoreboard_column.add_child(scoreboard_rows)
	_refresh_scoreboard()

	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_build_touch_controls(root)
		var score_button := Button.new()
		score_button.text = "SCOREBOARD"
		score_button.anchor_left = 0.72
		score_button.anchor_right = 0.98
		score_button.anchor_top = 0.02
		score_button.anchor_bottom = 0.02
		score_button.offset_bottom = 42
		score_button.pressed.connect(_toggle_scoreboard)
		root.add_child(score_button)
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

func _add_hud_panel(root: Control, panel_name: String, panel_position: Vector2, panel_size: Vector2, fill: Color, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	return panel

func _style_progress_bar(bar: ProgressBar, fill: Color, background: Color) -> void:
	if not is_instance_valid(bar):
		return
	var track := StyleBoxFlat.new()
	track.bg_color = background
	track.set_corner_radius_all(5)
	var progress := StyleBoxFlat.new()
	progress.bg_color = fill
	progress.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", progress)

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
	_admin_button(column, "Event: ICE WORLD", func(): _admin_trigger_event("ICE_WORLD"))
	_admin_button(column, "Event: FREEZE FRAME", func(): _admin_trigger_event("FREEZE_FRAME"))
	_admin_button(column, "Event: CONFETTI STORM", func(): _admin_trigger_event("CONFETTI_STORM"))
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
	if is_instance_valid(event_fx):
		event_fx.set_event(event_id)
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
	if active_map_index == 4:
		_build_dust_two_inspired_layout()
		return
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

func _build_dust_two_inspired_layout() -> void:
	# Original desert three-lane tactical layout; no Counter-Strike assets are copied.
	var sand := Color("#B99463")
	var stone := Color("#80694F")
	var dark := Color("#514638")
	_make_box("Dust2_A_Long_Cover_01", Vector3(5, 2.2, 1.0), Vector3(-11, 1.1, -8), stone)
	_make_box("Dust2_A_Long_Cover_02", Vector3(1.0, 2.2, 6), Vector3(-15, 1.1, -4), stone)
	_make_box("Dust2_A_Site", Vector3(9, 0.35, 7), Vector3(-11, 0.18, -10), sand)
	_make_box("Dust2_A_Site_BackWall", Vector3(0.8, 4.2, 10), Vector3(-16.5, 2.1, -10), dark)
	_make_box("Dust2_Mid_Catwalk", Vector3(15, 0.35, 3.5), Vector3(0, 0.18, -4), sand)
	_make_box("Dust2_Mid_CentralCover", Vector3(2.2, 2.4, 3.2), Vector3(0, 1.2, -5), stone)
	_make_box("Dust2_Mid_Tunnel_Left", Vector3(1.0, 3.2, 9), Vector3(-5.5, 1.6, 2), dark)
	_make_box("Dust2_Mid_Tunnel_Right", Vector3(1.0, 3.2, 9), Vector3(5.5, 1.6, 2), dark)
	_make_box("Dust2_B_Site", Vector3(9, 0.35, 7), Vector3(11, 0.18, 10), sand)
	_make_box("Dust2_B_BackWall", Vector3(0.8, 4.2, 10), Vector3(16.5, 2.1, 10), dark)
	_make_box("Dust2_B_Tunnel_Cover", Vector3(4, 2.0, 1.0), Vector3(11, 1.0, 6), stone)
	_make_box("Dust2_Short_Connector", Vector3(7, 0.35, 2.8), Vector3(7, 0.18, 0), sand)
	_make_box("Dust2_Long_Approach", Vector3(2.8, 0.35, 10), Vector3(-15, 0.18, 1), sand)
	_make_box("Dust2_TSpawn_Arch", Vector3(5, 3.4, 0.7), Vector3(0, 1.7, 13.5), stone)
	_make_box("Dust2_Mid_Upper_Cover", Vector3(4, 1.8, 2), Vector3(0, 0.9, 4), stone)

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
	_add_touch_button(root, "PULSE", "fire", Vector2(-255, -270), Vector2(96, 64), false)
	_add_touch_button(root, "GRENADE", "throw_grenade", Vector2(-150, -270), Vector2(88, 64), false)
	_add_touch_button(root, "GRIDDY", "emote_griddy", Vector2(-255, -350), Vector2(96, 56), false)
	_add_touch_button(root, "GOOFY", "emote_goofy", Vector2(-150, -350), Vector2(88, 56), false)

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
	var standings: Array[Dictionary] = []
	var team_totals := {"red": 0, "blue": 0}
	for player_name in match_stats.keys():
		var stats: Dictionary = match_stats[player_name]
		var row := {
			"name": str(player_name), "kills": int(stats.get("kills", 0)),
			"deaths": int(stats.get("deaths", 0)), "score": int(stats.get("score", 0)),
			"team_id": str(stats.get("team_id", "")),
			"shots_fired": int(stats.get("shots_fired", 0)), "shots_hit": int(stats.get("shots_hit", 0)),
			"damage_dealt": float(stats.get("damage_dealt", 0.0)),
			"damage_received": float(stats.get("damage_received", 0.0))
		}
		standings.append(row)
		var team := str(row.team_id)
		if team_totals.has(team):
			team_totals[team] = int(team_totals[team]) + int(row.kills)
	standings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.kills) == int(b.kills):
			return int(a.score) > int(b.score)
		return int(a.kills) > int(b.kills)
	)
	var mvp_rows := standings.duplicate()
	mvp_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) == int(b.score):
			return int(a.kills) > int(b.kills)
		return int(a.score) > int(b.score)
	)
	var winner_name := str(standings[0].name) if not standings.is_empty() else local_player_name
	var winner_kills := int(standings[0].kills) if not standings.is_empty() else 0
	var mvp_name := str(mvp_rows[0].name) if not mvp_rows.is_empty() else local_player_name
	var team_winner := ""
	if active_room_mode == "king_of_the_hill":
		team_totals.red = int(round(hill_points_red))
		team_totals.blue = int(round(hill_points_blue))
	if active_room_mode in ["team_deathmatch", "king_of_the_hill"]:
		if int(team_totals.red) > int(team_totals.blue):
			team_winner = "RED TEAM WINS  •  %d - %d" % [int(team_totals.red), int(team_totals.blue)]
		elif int(team_totals.blue) > int(team_totals.red):
			team_winner = "BLUE TEAM WINS  •  %d - %d" % [int(team_totals.blue), int(team_totals.red)]
		else:
			team_winner = "TEAM DRAW  •  %d - %d" % [int(team_totals.red), int(team_totals.blue)]
	var overlay := Control.new()
	overlay.name = "MatchResultsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 440)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.09, 0.98)
	panel_style.border_color = Color(0.12, 0.82, 0.76, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "MATCH RESULTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.86))
	column.add_child(title)
	var winner := Label.new()
	winner.text = team_winner if not team_winner.is_empty() else "WINNER  %s  •  %d KILLS" % [winner_name, winner_kills]
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner.add_theme_font_size_override("font_size", 20)
	winner.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	column.add_child(winner)
	var mvp := Label.new()
	mvp.text = "MVP  •  %s" % mvp_name
	mvp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp.add_theme_color_override("font_color", Color("#FFD47A"))
	column.add_child(mvp)
	var local_stats: Dictionary = match_stats.get(local_player_name, {})
	var shots := int(local_stats.get("shots_fired", 0))
	var hits := int(local_stats.get("shots_hit", 0))
	var accuracy := 100.0 * float(hits) / float(shots) if shots > 0 else 0.0
	var personal := Label.new()
	personal.text = "YOUR PERFORMANCE\nKILLS  %d     DEATHS  %d     SCORE  %d\nBLASTER ACCURACY  %.1f%%  (%d / %d)\nDAMAGE DEALT  %.0f     DAMAGE RECEIVED  %.0f" % [
		int(local_stats.get("kills", 0)), int(local_stats.get("deaths", 0)), int(local_stats.get("score", 0)),
		accuracy, hits, shots, float(local_stats.get("damage_dealt", 0.0)), float(local_stats.get("damage_received", 0.0))
	]
	personal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	personal.add_theme_color_override("font_color", Color("#D7E8F5"))
	column.add_child(personal)
	var earned_xp := maxi(0, int(local_stats.get("match_xp", round_match_xp)))
	var career_xp := progression.total_xp if is_instance_valid(progression) else earned_xp
	var previous_rank := _rank_for_total_xp(maxi(0, career_xp - earned_xp))
	var current_rank := _rank_for_total_xp(career_xp)
	_add_match_xp_card(column, earned_xp, career_xp, previous_rank, current_rank)
	var table_header := Label.new()
	table_header.text = "RANK   PLAYER                 K     D     SCORE    DMG"
	table_header.add_theme_color_override("font_color", Color("#74DDE5"))
	column.add_child(table_header)
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 2)
	column.add_child(board)
	for index in range(mini(5, standings.size())):
		var entry: Dictionary = standings[index]
		var row_label := Label.new()
		row_label.text = "%d.     %-20s %3d   %3d   %5d   %5.0f" % [
			index + 1, str(entry.name).substr(0, 20), int(entry.kills), int(entry.deaths),
			int(entry.score), float(entry.damage_dealt)
		]
		row_label.add_theme_color_override("font_color", Color("#FFFFFF") if str(entry.name) == local_player_name else Color("#AFC4D4"))
		board.add_child(row_label)
	if active_room_mode in ["team_deathmatch", "king_of_the_hill"]:
		var teams := Label.new()
		teams.text = ("RED CONTROL  %d SEC     •     BLUE CONTROL  %d SEC" if active_room_mode == "king_of_the_hill" else "RED TEAM  %d KILLS     •     BLUE TEAM  %d KILLS") % [int(team_totals.red), int(team_totals.blue)]
		teams.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		teams.add_theme_color_override("font_color", Color("#F0B8C0"))
		column.add_child(teams)
	var restart := Button.new()
	restart.text = "PLAY AGAIN"
	restart.custom_minimum_size = Vector2(180, 42)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	column.add_child(restart)


func _rank_for_total_xp(total_xp: int) -> Dictionary:
	var current: Dictionary = RANK_THRESHOLDS[0]
	var next_rank: Dictionary = {}
	for index in range(RANK_THRESHOLDS.size()):
		var tier: Dictionary = RANK_THRESHOLDS[index]
		if total_xp >= int(tier.xp):
			current = tier
			next_rank = RANK_THRESHOLDS[index + 1] if index + 1 < RANK_THRESHOLDS.size() else {}
		else:
			break
	var floor_xp := int(current.xp)
	var ceiling_xp := int(next_rank.xp) if not next_rank.is_empty() else floor_xp
	var progress := 1.0 if next_rank.is_empty() else clampf(float(total_xp - floor_xp) / float(maxi(1, ceiling_xp - floor_xp)), 0.0, 1.0)
	return {"current":current, "next":next_rank, "progress":progress}

func _add_match_xp_card(parent: VBoxContainer, earned_xp: int, total_xp: int, previous_rank: Dictionary, current_rank: Dictionary) -> void:
	var rank: Dictionary = current_rank.current
	var before: Dictionary = previous_rank.current
	var ranked_up := str(before.id) != str(rank.id)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10283A")
	style.border_color = rank.color if ranked_up else Color("#28516A")
	style.set_border_width_all(2 if ranked_up else 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	card.add_child(stack)
	var heading := Label.new()
	heading.text = "RANK UP!" if ranked_up else "MATCH XP REWARD"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", rank.color if ranked_up else Color("#65E6D3"))
	stack.add_child(heading)
	var badge := Label.new()
	badge.text = "◆  %s  ◆" % str(rank.id).to_upper()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 23)
	badge.add_theme_color_override("font_color", rank.color)
	stack.add_child(badge)
	var reward := Label.new()
	reward.text = "+%d XP  •  %d TOTAL XP" % [earned_xp, total_xp]
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_color_override("font_color", Color("#F4FAFF"))
	stack.add_child(reward)
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = float(current_rank.progress) * 100.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#203B50")
	track.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = rank.color
	fill.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("background", track)
	progress.add_theme_stylebox_override("fill", fill)
	stack.add_child(progress)
	if ranked_up:
		var transition := Label.new()
		transition.text = "%s  →  %s" % [str(before.id).to_upper(), str(rank.id).to_upper()]
		transition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		transition.add_theme_color_override("font_color", Color("#FFE08A"))
		stack.add_child(transition)
		card.scale = Vector2(0.88, 0.88)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.3)
	else:
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.25)

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
	if is_instance_valid(health_bar):
		health_bar.value = player.health
	if is_instance_valid(health_label):
		health_label.text = "HEALTH %d / 100" % int(ceil(player.health))
		health_label.add_theme_color_override("font_color", Color("#FF7285") if player.health <= 30.0 else Color("#E8F8FF"))
	if is_instance_valid(death_label):
		death_label.visible = player.is_dead
		death_label.text = "K.O.  •  RESPAWNING IN %d" % ceili(player.respawn_left) if player.is_dead else ""
	if active_event.is_empty():
		event_label.text = "COLLECT THE ORBS • NEXT EVENT %02d" % ceili(event_clock)
	else:
		event_label.text = "%s  %02d" % [EVENT_NAMES.get(active_event, active_event), ceili(event_left)]
	var round_label := hud_layer.get_node_or_null("Control/RoundLabel")
	if round_label:
		round_label.text = "ROUND %02d:%02d" % [int(int(round_left) / 60), int(round_left) % 60]
	if status_label:
		status_label.text = "STAMINA %d%%  •  %s" % [int(player.stamina), "LOW GRAVITY ACTIVE" if active_event == "LOW_GRAVITY" else "PARKOUR ARENA"]
