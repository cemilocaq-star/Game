extends Node
## Server-authoritative OxenWar networking.
## Client sends input only. Server authenticates Supabase sessions, simulates physics,
## owns room membership, score, event timers and collectible respawns.

signal player_state_received(peer_id: int, state: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_status_changed(message: String)
signal authentication_changed(authenticated: bool, message: String)
signal local_state_received(state: Dictionary)
signal room_state_changed(state: Dictionary)
signal invite_received(owner_name: String, room_code: String)
signal blaster_fx_received(shooter_peer_id: int, origin: Vector3, endpoint: Vector3, weapon_id: String)
signal grenade_spawn_received(grenade_id: int, origin: Vector3, velocity: Vector3)
signal grenade_exploded_received(grenade_id: int, position: Vector3)
signal kill_feed_received(killer_name: String, victim_name: String, weapon_name: String)
signal killstreak_received(player_name: String, streak: int, bonus: int)

const PORT := 2456
const MAX_CLIENTS := 32
const ROOM_CAPACITY := 8
const SNAPSHOT_INTERVAL := 0.033 # 30 snapshots/s (was 20): smoother interpolation, still cheap with partial snapshots
const INPUT_SEND_MS := 33
const FULL_STATE_EVERY := 10 # every Nth snapshot carries the slow fields (names, colours, xp...); the rest only the fast ones
const NET_SYNC := preload("res://scripts/net_sync.gd")
const WEAPON_FEEL := preload("res://scripts/weapon_feel.gd")
const ROOM_GRACE_SECONDS := 30.0
const ROUND_SECONDS := 300.0
const MEME_EVENTS := preload("res://scripts/meme_events.gd")
const EVENT_INTERVAL := 30.0
const EVENT_DURATION := 12.0
const SUPABASE_URL := "https://lznnfwhlsquiitkhjzlc.supabase.co"
const SUPABASE_KEY := "sb_publishable_z7UuZtF9NQwox1Ae0droQA_mxpD-P7L"
const SERVER_PLAYER_SCRIPT := preload("res://scripts/oxenwar_server_player.gd")
const LAN_DISCOVERY := preload("res://scripts/lan_discovery.gd")
const EMOTE_CATALOG := preload("res://scripts/emote_catalog.gd")
## Open servers accept guests: a display name is the whole identity, nothing is saved to an account.
const GUEST_TICKET_PREFIX := "GUEST-"
const GUEST_USER_PREFIX := "guest-"
## An open server started from the game ("host a room on this PC") closes itself after this long without players.
const OPEN_IDLE_QUIT_SECONDS := 600.0
const GRENADE_PHYSICS := preload("res://scripts/grenade_physics.gd")
const ARENA_LAYOUT := preload("res://scripts/arena_layout.gd")
const EVENTS := ["DUCK_PARADE", "PINK_SKY", "GOLDEN_ORB_RUSH", "CONFETTI_STORM", "LOW_GRAVITY", "BONK_MODE", "NPC_MODE", "DUCK_EXE", "METEOR_SHOWER", "ICE_WORLD", "FREEZE_FRAME", "DOUBLE_XP"]
const ARCADE_WEAPONS := {
	"aether": {"name":"AETHER", "damage":34.0, "cooldown_ms":240, "range":65.0},
	"minicore": {"name":"MINICORE", "damage":10.0, "cooldown_ms":90, "range":46.0},
	"hand_cannon": {"name":"NOVA HAND CANNON", "damage":48.0, "cooldown_ms":680, "range":58.0},
	"pulse_carbine": {"name":"PULSE CARBINE", "damage":20.0, "cooldown_ms":180, "range":62.0},
	"star_piercer": {"name":"STAR PIERCER", "damage":70.0, "cooldown_ms":1050, "range":92.0},
	"duck_launcher": {"name":"DUCK LAUNCHER", "damage":24.0, "cooldown_ms":620, "range":42.0},
	"banana_boomerang": {"name":"BANANA BOOMERANG", "damage":16.0, "cooldown_ms":420, "range":38.0},
	"confetti_cannon": {"name":"CONFETTI CANNON", "damage":8.0, "cooldown_ms":110, "range":34.0},
	"prism_scepter": {"name":"PRISM SCEPTER", "damage":28.0, "cooldown_ms":320, "range":72.0},
	"vortex_orbiter": {"name":"VORTEX ORBITER", "damage":17.0, "cooldown_ms":150, "range":52.0},
	"comet_bow": {"name":"COMET BOW", "damage":56.0, "cooldown_ms":900, "range":88.0},
	"bubble_burst": {"name":"BUBBLE BURST", "damage":12.0, "cooldown_ms":250, "range":36.0},
	"glitch_ray": {"name":"GLITCH RAY", "damage":22.0, "cooldown_ms":130, "range":60.0},
	"meteor_mallet": {"name":"METEOR MALLET", "damage":42.0, "cooldown_ms":700, "range":30.0},
	"frost_wand": {"name":"FROST WAND", "damage":19.0, "cooldown_ms":280, "range":58.0},
	"solar_lance": {"name":"SOLAR LANCE", "damage":62.0, "cooldown_ms":980, "range":86.0},
	"slime_slinger": {"name":"SLIME SLINGER", "damage":15.0, "cooldown_ms":360, "range":44.0},
	"pixel_storm": {"name":"PIXEL STORM", "damage":9.0, "cooldown_ms":80, "range":40.0},
	"thunder_drum": {"name":"THUNDER DRUM", "damage":24.0, "cooldown_ms":400, "range":55.0},
	"moon_disc": {"name":"MOON DISC", "damage":30.0, "cooldown_ms":520, "range":68.0},
	"jellyfish_staff": {"name":"JELLYFISH STAFF", "damage":20.0, "cooldown_ms":300, "range":50.0},
	"portal_popper": {"name":"PORTAL POPPER", "damage":38.0, "cooldown_ms":640, "range":62.0},
	"rubber_chicken": {"name":"RUBBER CHICKEN", "damage":14.0, "cooldown_ms":480, "range":32.0},
	"ranger_rifle": {"name":"RANGER RIFLE", "damage":24.0, "cooldown_ms":160, "range":68.0},
	"heavy_sidearm": {"name":"HEAVY SIDEARM", "damage":44.0, "cooldown_ms":600, "range":52.0},
	"longshot": {"name":"LONGSHOT", "damage":78.0, "cooldown_ms":1250, "range":100.0},
	"rotary_arc": {"name":"ROTARY ARC", "damage":11.0, "cooldown_ms":75, "range":48.0}
}

var is_dedicated_server := false
## Open server: no Supabase account, secret or ticket is needed; guests join with a name and a room code.
var open_mode := false
var _lan_responder: RefCounted
var _idle_quit_after := 0.0
var _idle_seconds := 0.0
var _is_guest := false
var _guest_name := ""
var is_authenticated := false
var local_player: Node3D
var local_player_name := "Player"
var local_player_color := Color("#27D7E7")
var _access_token := ""
var _game_ticket := ""
var _ticket_request_in_progress := false
var _last_send_ms := 0
var _pending_jump := false
var _pending_slide := false
var _pending_dash := false
var _snapshot_accumulator := 0.0
var _input_seq := 0
var _seq_times: Dictionary = {} # client: input sequence -> send time (ms)
var _local_history = NET_SYNC.PositionHistory.new() # client: where the predicted player was, per frame
var _rtt_ms := 0.0
var _ping_left := 0.0
var _client_state_cache: Dictionary = {} # client: peer id -> last merged state (partial snapshots)
var _client_cache_room := ""
var _last_input_seq: Dictionary = {} # server: peer id -> newest input sequence
var _pos_history: Dictionary = {} # server: peer id -> PositionHistory (lag compensation)
var _server_players: Dictionary = {} # peer id -> CharacterBody3D
var _last_input_ms: Dictionary = {}
var _last_blaster_ms: Dictionary = {}
## Per-peer bloom state, rolled on the server so the client cannot choose its own spread.
var _shot_trackers: Dictionary = {}
var _last_grenade_ms: Dictionary = {}
var _next_grenade_id := 1
var _client_peer_ids: Dictionary = {}
var _peer_users: Dictionary = {} # peer id -> Supabase user id
var _user_peers: Dictionary = {} # Supabase user id -> peer id
var _profiles: Dictionary = {}
var _session_tokens: Dictionary = {} # server memory only; never persisted/logged
var _player_joined_at_ms: Dictionary = {} # server monotonic join times
var _rooms: Dictionary = {} # room code -> room state
var _user_rooms: Dictionary = {} # user id -> room code
var _sessions: Dictionary = {} # user id -> reconnect reservation
var _rng := RandomNumberGenerator.new()
var _reconnect_timer: Timer
var _reconnect_attempts := 0
var _last_room_code := ""
var _last_host := ""
var _server_secret := ""
# Server directory: the dedicated server announces its public address and room codes to Supabase so
# clients can find it automatically (START) or find the server of a room code (JOIN).
var _directory_host := ""
var _directory_timer := 0.0
var _directory_signature := ""
var _directory_busy := false
var _directory_warned := false
var _directory_attempted := false
var _directory_failures := 0

func start_server(open_server: bool = false) -> bool:
	is_dedicated_server = true
	_rng.randomize()
	open_mode = open_server or OS.get_environment("OXENWAR_OPEN_MODE").strip_edges() == "1"
	_server_secret = OS.get_environment("OXENWAR_SERVER_SECRET").strip_edges()
	if _server_secret.is_empty() and not open_mode:
		push_error("OXENWAR_SERVER_SECRET is required; refusing to start dedicated server.")
		return false

	var transport := OS.get_environment("OXENWAR_TRANSPORT").strip_edges().to_lower()
	var peer: MultiplayerPeer
	var error: Error = OK
	if transport == "websocket":
		# Hosted web platforms terminate TLS at their edge and forward WebSocket
		# upgrades to the container's injected PORT. Clients connect with wss://.
		# Render's public HTTP port is handled by the lightweight health/WebSocket
		# tunnel in server/render_entrypoint.py. Godot listens on a private port.
		var websocket_port := int(OS.get_environment("OXENWAR_PORT"))
		if websocket_port <= 0:
			websocket_port = int(OS.get_environment("PORT"))
		if websocket_port <= 0:
			websocket_port = 8081
		var websocket_peer := WebSocketMultiplayerPeer.new()
		error = websocket_peer.create_server(websocket_port, "0.0.0.0")
		if error != OK:
			push_error("OxenWar server could not bind WebSocket port %d: %s" % [websocket_port, error_string(error)])
			return false
		peer = websocket_peer
		print("OxenWar authoritative server listening on WebSocket port %d" % websocket_port)
	else:
		var enet_peer := ENetMultiplayerPeer.new()
		error = enet_peer.create_server(PORT, MAX_CLIENTS)
		if error != OK:
			push_error("OxenWar server could not bind UDP %d: %s" % [PORT, error_string(error)])
			return false
		peer = enet_peer
		print("OxenWar authoritative server listening on UDP %d" % PORT)

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if open_mode:
		print("OxenWar open mode: guests may join with a name and a room code, no account needed")
		if transport != "websocket":
			_start_lan_responder()
		if OS.get_cmdline_user_args().has("--idle-quit"):
			_idle_quit_after = OPEN_IDLE_QUIT_SECONDS
	# Without a secret there is no way to talk to the Supabase directory or save results.
	if not _server_secret.is_empty():
		_directory_host = _detect_public_host()
		if _directory_host.is_empty():
			push_warning("OXENWAR_PUBLIC_HOST is not set and no hosting platform was detected: this server will not appear in the automatic server list.")
		else:
			print("OxenWar server directory address: %s" % _directory_host)
	return true

func _start_lan_responder() -> void:
	_lan_responder = LAN_DISCOVERY.Responder.new()
	var error: Error = _lan_responder.start()
	if error != OK:
		push_warning("OxenWar LAN discovery could not bind UDP %d (%s); another server may already be running on this device." % [LAN_DISCOVERY.PORT, error_string(error)])
		_lan_responder = null
	else:
		print("OxenWar LAN discovery listening on UDP %d" % LAN_DISCOVERY.PORT)

func _poll_lan_responder() -> void:
	if _lan_responder != null:
		var codes: Array = []
		for code in _rooms.keys():
			codes.append(str(code))
		_lan_responder.poll({"port": PORT, "players": _server_players.size(), "max": MAX_CLIENTS, "rooms": codes})

func _check_idle_quit(delta: float) -> void:
	if _idle_quit_after <= 0.0:
		return
	if _server_players.is_empty() and _rooms.is_empty():
		_idle_seconds += delta
		if _idle_seconds >= _idle_quit_after:
			print("OxenWar open server closing after %d idle seconds" % int(_idle_quit_after))
			get_tree().quit()
	else:
		_idle_seconds = 0.0

func connect_to_server(host: String, access_token: String) -> void:
	_is_guest = false
	_access_token = access_token
	_last_host = host.strip_edges()
	_reconnect_attempts = 0
	_request_ticket_and_connect()

## Joins an open server with only a display name. No account, no Supabase.
func connect_as_guest(host: String, display_name: String) -> void:
	_is_guest = true
	_guest_name = _clean_guest_name(display_name)
	_access_token = ""
	_last_host = host.strip_edges()
	_reconnect_attempts = 0
	_request_ticket_and_connect()

func is_guest_connection() -> bool:
	return _is_guest

func current_host() -> String:
	return _last_host

static func _clean_guest_name(value: String) -> String:
	var cleaned := ""
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if character != "-" and character.unicode_at(0) >= 32:
			cleaned += character
	cleaned = cleaned.strip_edges().substr(0, 20)
	return cleaned if not cleaned.is_empty() else "Guest"

func _request_ticket_and_connect() -> void:
	if is_dedicated_server or _ticket_request_in_progress:
		return
	if _is_guest:
		if _last_host.is_empty():
			connection_status_changed.emit("No server found.")
			return
		_game_ticket = GUEST_TICKET_PREFIX + _guest_name
		_connect_now()
		return
	if _last_host.is_empty() or _access_token.is_empty():
		connection_status_changed.emit("Sign in and enter a server address.")
		return
	_ticket_request_in_progress = true
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + _access_token,
		"Content-Type: application/json"
	])
	var ticket_response := await _http_json(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/functions/v1/oxenwar-server-sync", headers, {"action": "issue_ticket"})
	_ticket_request_in_progress = false
	if not ticket_response.get("ok", false):
		connection_status_changed.emit("Secure game ticket request failed (HTTP %d)" % int(ticket_response.get("status", 0)))
		_schedule_reconnect()
		return
	var ticket_data: Dictionary = ticket_response.get("data", {})
	_game_ticket = str(ticket_data.get("ticket", ""))
	if _game_ticket.is_empty():
		connection_status_changed.emit("Supabase did not issue a game ticket")
		_schedule_reconnect()
		return
	_connect_now()

func _connect_now() -> void:
	if _last_host.is_empty() or _game_ticket.is_empty():
		connection_status_changed.emit("Secure game ticket is missing.")
		return
	var peer: MultiplayerPeer
	var error: Error = OK
	var websocket_url := _last_host.begins_with("ws://") or _last_host.begins_with("wss://")
	if websocket_url:
		var websocket_peer := WebSocketMultiplayerPeer.new()
		error = websocket_peer.create_client(_last_host)
		peer = websocket_peer
	else:
		var enet_peer := ENetMultiplayerPeer.new()
		var enet_host := _last_host
		var enet_port := PORT
		if _last_host.count(":") == 1:
			enet_host = _last_host.get_slice(":", 0)
			enet_port = int(_last_host.get_slice(":", 1))
		error = enet_peer.create_client(enet_host, enet_port)
		peer = enet_peer
	if error != OK:
		connection_status_changed.emit("Connection failed: " + error_string(error))
		_schedule_reconnect()
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	connection_status_changed.emit("Connecting securely to " + _last_host if _last_host.begins_with("wss://") else ("Connecting to " + _last_host if websocket_url or _last_host.count(":") == 1 else "Connecting to " + _last_host + ":" + str(PORT)))

func update_access_token(token: String) -> void:
	if not token.is_empty():
		_access_token = token

func set_local_player(player: Node3D, display_name: String, color: Color) -> void:
	local_player = player
	local_player_name = display_name.substr(0, 24)
	local_player_color = color

func request_create_room(private_room: bool = true, mode: String = "ffa", map_index: int = 4) -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_create_room", private_room, _sanitize_mode(mode), ARENA_LAYOUT.sanitize_map(map_index))

func request_quick_match(mode: String = "ffa", map_index: int = 4) -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_quick_match", _sanitize_mode(mode), ARENA_LAYOUT.sanitize_map(map_index))

func _sanitize_mode(mode: String) -> String:
	if mode == "team_deathmatch" or mode == "king_of_the_hill" or mode == "demolition":
		return mode
	return "ffa"

func request_emote(emote_id: String) -> void:
	if is_authenticated and not is_dedicated_server and (emote_id.is_empty() or EMOTE_CATALOG.is_valid(emote_id)):
		rpc_id(1, "_server_set_emote", emote_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_set_emote(emote_id: String) -> void:
	if not multiplayer.is_server() or (not emote_id.is_empty() and not EMOTE_CATALOG.is_valid(emote_id)):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code) or bool(_rooms[room_code].get("round_finished", false)):
		return
	_server_players[peer_id].emote_id = emote_id

func request_objective_interact() -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_objective_interact")

@rpc("any_peer", "call_remote", "reliable")
func _server_objective_interact() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code):
		return
	var room: Dictionary = _rooms[room_code]
	if str(room.get("mode", "")) != "demolition" or bool(room.get("round_finished", false)):
		return
	var actor = _server_players[peer_id]
	if actor.is_dead:
		return
	var team := str(actor.team_id)
	if bool(room.get("bomb_planted", false)):
		var planted_position: Vector3 = room.get("bomb_position", Vector3.ZERO)
		if team != "blue" or actor.global_position.distance_to(planted_position) > 3.0:
			return
		room.objective_action = "defuse"
	else:
		if team != "red":
			return
		var site_map := int(room.get("map_index", 4))
		var site_a: Vector3 = ARENA_LAYOUT.objective_site(site_map, "A") + Vector3(0.0, 1.5, 0.0)
		var site_b: Vector3 = ARENA_LAYOUT.objective_site(site_map, "B") + Vector3(0.0, 1.5, 0.0)
		var dist_a: float = actor.global_position.distance_to(site_a)
		var dist_b: float = actor.global_position.distance_to(site_b)
		if minf(dist_a, dist_b) > 3.0:
			return
		room.objective_action = "plant_a" if dist_a <= dist_b else "plant_b"
	room.objective_interactor = peer_id
	room.objective_progress = 0.0
	_rooms[room_code] = room

func _server_step_objective(room_code: String, room: Dictionary, delta: float) -> Dictionary:
	if str(room.get("mode", "")) != "demolition" or bool(room.get("round_finished", false)):
		return room
	var red_alive := 0
	var blue_alive := 0
	var red_total := 0
	var blue_total := 0
	for member_uid in room.members.keys():
		var member_peer := int(room.members[member_uid])
		if member_peer <= 0 or not _server_players.has(member_peer):
			continue
		var member = _server_players[member_peer]
		if str(member.team_id) == "red":
			red_total += 1
			if not member.is_dead:
				red_alive += 1
		elif str(member.team_id) == "blue":
			blue_total += 1
			if not member.is_dead:
				blue_alive += 1
	if red_total > 0 and blue_total > 0 and red_alive == 0 and str(room.get("objective_winner_team", "")).is_empty():
		room.objective_winner_team = "blue"
		room.objective_result = "ATTACKERS ELIMINATED"
		room.round_left = 0.0
		return room
	if red_total > 0 and blue_total > 0 and blue_alive == 0 and not bool(room.get("bomb_planted", false)):
		room.objective_winner_team = "red"
		room.objective_result = "DEFENDERS ELIMINATED"
		room.round_left = 0.0
		return room
	if bool(room.get("bomb_planted", false)):
		room.bomb_fuse = maxf(0.0, float(room.get("bomb_fuse", 0.0)) - delta)
		if float(room.bomb_fuse) <= 0.0:
			room.objective_winner_team = "red"
			room.bomb_planted = false
			room.objective_result = "CORE DETONATED"
			room.round_left = 0.0
			return room
	var peer_id := int(room.get("objective_interactor", 0))
	var action := str(room.get("objective_action", ""))
	if peer_id <= 0 or action.is_empty() or not _server_players.has(peer_id):
		room.objective_progress = 0.0
		return room
	var actor = _server_players[peer_id]
	if actor.is_dead:
		room.objective_interactor = 0
		room.objective_action = ""
		room.objective_progress = 0.0
		return room
	var valid := false
	if action == "defuse":
		var planted_position: Vector3 = room.get("bomb_position", Vector3.ZERO)
		valid = bool(room.get("bomb_planted", false)) and str(actor.team_id) == "blue" and actor.global_position.distance_to(planted_position) <= 3.0
	else:
		var site: Vector3 = ARENA_LAYOUT.objective_site(int(room.get("map_index", 4)), "A" if action == "plant_a" else "B") + Vector3(0.0, 1.5, 0.0)
		valid = not bool(room.get("bomb_planted", false)) and str(actor.team_id) == "red" and actor.global_position.distance_to(site) <= 3.0
	if not valid:
		room.objective_interactor = 0
		room.objective_action = ""
		room.objective_progress = 0.0
		return room
	room.objective_progress = float(room.get("objective_progress", 0.0)) + delta
	if float(room.objective_progress) >= 3.0:
		if action == "defuse":
			room.objective_winner_team = "blue"
			room.bomb_planted = false
			room.objective_result = "ENERGY CORE DEFUSED"
			room.round_left = 0.0
		else:
			room.bomb_planted = true
			room.bomb_site = "A" if action == "plant_a" else "B"
			room.bomb_position = ARENA_LAYOUT.objective_site(int(room.get("map_index", 4)), str(room.bomb_site)) + Vector3(0.0, 1.5, 0.0)
			room.bomb_fuse = 35.0
			room.objective_result = "ENERGY CORE PLANTED • SITE " + str(room.bomb_site)
		room.objective_interactor = 0
		room.objective_action = ""
		room.objective_progress = 0.0
	return room

func request_grenade_throw(direction: Vector3) -> void:
	if is_authenticated and not is_dedicated_server and direction.length() > 0.9:
		rpc_id(1, "_server_throw_grenade", direction.normalized())

func request_join_room(code: String) -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_join_room", code.strip_edges().to_upper())

func request_leave_room() -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_leave_room")

func request_invite_friend(friend_user_id: String) -> void:
	if is_authenticated and not is_dedicated_server and not friend_user_id.is_empty():
		rpc_id(1, "_server_invite_friend", friend_user_id)

func request_select_weapon(weapon_id: String) -> void:
	if is_authenticated and not is_dedicated_server and ARCADE_WEAPONS.has(weapon_id):
		rpc_id(1, "_server_select_weapon", weapon_id)

## `aim_direction` is where the crosshair points. The server adds the spread itself.
func request_blaster_fire(weapon_id: String, aim_direction: Vector3, aiming: bool = false) -> void:
	if is_authenticated and not is_dedicated_server and ARCADE_WEAPONS.has(weapon_id) and aim_direction.length() > 0.9:
		rpc_id(1, "_server_blaster_fire", weapon_id, aim_direction.normalized(), view_delay_ms(), aiming)

func _process(delta: float) -> void:
	if is_dedicated_server:
		_server_process_rooms(delta)
		_server_process_directory(delta)
		_poll_lan_responder()
		_check_idle_quit(delta)
		return
	if not is_authenticated or local_player == null or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var controls_blocked: bool = ("ui_blocked" in local_player and bool(local_player.get("ui_blocked"))) or bool(local_player.get("is_dead"))
	_pending_jump = (_pending_jump or Input.is_action_just_pressed("jump")) and not controls_blocked
	_pending_slide = (_pending_slide or Input.is_action_just_pressed("slide")) and not controls_blocked
	_pending_dash = (_pending_dash or Input.is_action_just_pressed("dash")) and not controls_blocked
	var now := Time.get_ticks_msec()
	_local_history.record(now, local_player.global_position)
	_ping_left -= delta
	if _ping_left <= 0.0:
		_ping_left = 1.0
		rpc_id(1, "_server_ping", now)
	if now - _last_send_ms < INPUT_SEND_MS:
		return
	_last_send_ms = now
	var move := Vector2.ZERO if controls_blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprint := Input.is_action_pressed("sprint") and not controls_blocked
	_input_seq += 1
	_seq_times[_input_seq] = now
	_seq_times.erase(_input_seq - 120)
	rpc_id(1, "_server_submit_input", move, local_player.rotation.y, _pending_jump, sprint, _pending_slide, _pending_dash, _input_seq, float(local_player.get("pitch")))
	_pending_jump = false
	_pending_slide = false
	_pending_dash = false

## Delay the shooter's screen was behind the server: half the round trip plus the interpolation delay.
func view_delay_ms() -> int:
	return NET_SYNC.rewind_ms(_rtt_ms)

func round_trip_ms() -> float:
	return _rtt_ms

@rpc("any_peer", "call_remote", "unreliable")
func _server_ping(client_ms: int) -> void:
	if not multiplayer.is_server():
		return
	rpc_id(multiplayer.get_remote_sender_id(), "_client_pong", client_ms)

@rpc("authority", "call_remote", "unreliable")
func _client_pong(client_ms: int) -> void:
	if multiplayer.is_server():
		return
	var sample := float(maxi(0, Time.get_ticks_msec() - client_ms))
	_rtt_ms = sample if _rtt_ms <= 0.0 else lerpf(_rtt_ms, sample, 0.3)

## Client-side reconciliation: the local player predicts its own movement, so the (older) server
## position is compared with where the client was at that same input. Only real disagreement is
## corrected, and smoothly; the camera yaw always stays under the player's control.
func reconcile_local_player(state: Dictionary) -> void:
	if not is_instance_valid(local_player):
		return
	var server_position: Variant = state.get("position")
	if not (server_position is Vector3):
		return
	var seq := int(state.get("input_seq", 0))
	var age_ms := clampi(int(state.get("input_age_ms", 0)), 0, 200)
	var reference: Variant = null
	if seq > 0 and _seq_times.has(seq):
		reference = _local_history.position_at(int(_seq_times[seq]) + age_ms)
	if reference == null:
		reference = local_player.global_position
	var result: Dictionary = NET_SYNC.reconcile(server_position, reference, local_player.global_position, bool(state.get("dead", false)))
	var action := str(result.get("action", "none"))
	if action == "none":
		return
	local_player.global_position = result.get("position", local_player.global_position)
	if action == "snap":
		_local_history = NET_SYNC.PositionHistory.new()
		if "velocity" in local_player:
			local_player.velocity = Vector3.ZERO
		# Local look stays responsive across position corrections.

func _on_connected_to_server() -> void:
	_reconnect_attempts = 0
	connection_status_changed.emit("Connected • joining as guest" if _is_guest else "Connected • verifying Supabase account")
	rpc_id(1, "_server_authenticate", _game_ticket)

func _on_connection_failed() -> void:
	is_authenticated = false
	authentication_changed.emit(false, "Server connection failed")
	connection_status_changed.emit("Connection failed; retrying...")
	_schedule_reconnect()

func _on_server_disconnected() -> void:
	is_authenticated = false
	authentication_changed.emit(false, "Server disconnected")
	connection_status_changed.emit("Server disconnected; reconnecting...")
	_clear_client_room()
	_schedule_reconnect()

func _clear_client_room() -> void:
	for peer_id in _client_peer_ids.keys():
		_forget_client_peer(int(peer_id))
	_client_state_cache.clear()
	_client_cache_room = ""
	_local_history = NET_SYNC.PositionHistory.new()
	_seq_times.clear()
	_pending_jump = false
	_pending_slide = false
	_pending_dash = false


func _forget_client_peer(peer_id: int) -> void:
	_client_state_cache.erase(peer_id)
	if _client_peer_ids.erase(peer_id):
		player_disconnected.emit(peer_id)


func _schedule_reconnect() -> void:
	if is_dedicated_server or (_access_token.is_empty() and not _is_guest) or _last_host.is_empty():
		return
	if _reconnect_timer == null:
		_reconnect_timer = Timer.new()
		_reconnect_timer.one_shot = true
		add_child(_reconnect_timer)
		_reconnect_timer.timeout.connect(_request_ticket_and_connect)
	if _reconnect_timer.is_stopped():
		_reconnect_attempts += 1
		_reconnect_timer.wait_time = minf(15.0, 1.5 * pow(1.6, minf(_reconnect_attempts, 5)))
		_reconnect_timer.start()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.get_peers().size() > MAX_CLIENTS:
		push_warning("OxenWar connection limit reached; rejecting peer %d." % peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	print("OxenWar incoming peer: ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var user_id := str(_peer_users.get(peer_id, ""))
	if user_id.is_empty():
		return
	if _user_peers.has(user_id) and int(_user_peers[user_id]) != peer_id:
		if _server_players.has(peer_id):
			_server_players[peer_id].queue_free()
			_server_players.erase(peer_id)
		_peer_users.erase(peer_id)
		_last_input_ms.erase(peer_id)
		_last_input_seq.erase(peer_id)
		_pos_history.erase(peer_id)
		_last_blaster_ms.erase(peer_id)
		_last_grenade_ms.erase(peer_id)
		_shot_trackers.erase(peer_id)
		return
	var room_code := str(_user_rooms.get(user_id, ""))
	if not room_code.is_empty() and _rooms.has(room_code):
		var room: Dictionary = _rooms[room_code]
		room.members[user_id] = 0
		_rooms[room_code] = room
		_sessions[user_id] = {
			"room_code": room_code,
			"expires": Time.get_ticks_msec() + int(ROOM_GRACE_SECONDS * 1000.0),
			"position": _server_players[peer_id].global_position if _server_players.has(peer_id) else Vector3(0, 1.5, 6),
			"score": int(_server_players[peer_id].score) if _server_players.has(peer_id) else 0,
			"xp": int(_server_players[peer_id].xp) if _server_players.has(peer_id) else 0,
			"match_xp": int(_server_players[peer_id].match_xp) if _server_players.has(peer_id) else 0,
			"collections": _server_players[peer_id].collection_counts.duplicate(true) if _server_players.has(peer_id) else {},
			"health": float(_server_players[peer_id].health) if _server_players.has(peer_id) else 100.0,
			"dead": bool(_server_players[peer_id].is_dead) if _server_players.has(peer_id) else false,
			"respawn_left": float(_server_players[peer_id].respawn_left) if _server_players.has(peer_id) else 0.0,
			"kills": int(_server_players[peer_id].kills) if _server_players.has(peer_id) else 0,
			"deaths": int(_server_players[peer_id].deaths) if _server_players.has(peer_id) else 0,
			"equipped_weapon_id": str(_server_players[peer_id].equipped_weapon_id) if _server_players.has(peer_id) else "aether",
			"team_id": str(_server_players[peer_id].team_id) if _server_players.has(peer_id) else "",
			"kill_streak": int(_server_players[peer_id].kill_streak) if _server_players.has(peer_id) else 0,
			"best_kill_streak": int(_server_players[peer_id].best_kill_streak) if _server_players.has(peer_id) else 0,
			"stamina": float(_server_players[peer_id].stamina) if _server_players.has(peer_id) else 100.0,
			"damage_received": float(_server_players[peer_id].damage_received) if _server_players.has(peer_id) else 0.0,
			"secret_404_found": bool(_server_players[peer_id].secret_404_found) if _server_players.has(peer_id) else false,
			"emote_id": str(_server_players[peer_id].emote_id) if _server_players.has(peer_id) else "",
			"is_swimming": bool(_server_players[peer_id].is_swimming) if _server_players.has(peer_id) else false,
			"blaster_mastery_xp": int(_server_players[peer_id].blaster_mastery_xp) if _server_players.has(peer_id) else 0,
			"grenade_mastery_xp": int(_server_players[peer_id].grenade_mastery_xp) if _server_players.has(peer_id) else 0,
			"damage_dealt": float(_server_players[peer_id].damage_dealt) if _server_players.has(peer_id) else 0.0,
			"shots_fired": int(_server_players[peer_id].shots_fired) if _server_players.has(peer_id) else 0,
			"shots_hit": int(_server_players[peer_id].shots_hit) if _server_players.has(peer_id) else 0,
			"playtime_seconds": maxi(0, int((Time.get_ticks_msec() - int(_player_joined_at_ms.get(user_id, Time.get_ticks_msec()))) / 1000)),
			"outcome": str(_server_players[peer_id].match_outcome) if _server_players.has(peer_id) else "abandoned",
			"session_token": str(_session_tokens.get(user_id, "")),
			"already_persisted": bool(room.get("persisted", {}).has(user_id)) or bool(room.get("persisting", {}).has(user_id))
		}
		if _server_players.has(peer_id):
			_server_players[peer_id].queue_free()
		_server_players.erase(peer_id)
	else:
		if _server_players.has(peer_id):
			_server_players[peer_id].queue_free()
			_server_players.erase(peer_id)
	_peer_users.erase(peer_id)
	_last_input_ms.erase(peer_id)
	_last_input_seq.erase(peer_id)
	_pos_history.erase(peer_id)
	_last_blaster_ms.erase(peer_id)
	_last_grenade_ms.erase(peer_id)
	_shot_trackers.erase(peer_id)
	if int(_user_peers.get(user_id, 0)) == peer_id:
		_user_peers.erase(user_id)
		_session_tokens.erase(user_id)
		_profiles.erase(user_id)
		_player_joined_at_ms.erase(user_id)
	_broadcast_room_state(room_code)
	print("OxenWar peer disconnected: ", peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_authenticate(ticket: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var identity: Dictionary
	if ticket.begins_with(GUEST_TICKET_PREFIX):
		if not open_mode:
			rpc_id(peer_id, "_client_auth_result", false, "This server needs an account. Sign in, or pick an open server.")
			return
		identity = _guest_identity(ticket.trim_prefix(GUEST_TICKET_PREFIX))
	elif ticket.length() < 40 or ticket.length() > 8192:
		rpc_id(peer_id, "_client_auth_result", false, "Invalid game ticket")
		return
	else:
		identity = await _redeem_game_ticket(ticket)
	if not identity.get("ok", false):
		rpc_id(peer_id, "_client_auth_result", false, "Game ticket invalid, expired or already used")
		return
	var user_id := str(identity.get("user_id", ""))
	if user_id.is_empty():
		rpc_id(peer_id, "_client_auth_result", false, "Ticket has no player identity")
		return
	if _user_peers.has(user_id) and int(_user_peers[user_id]) != peer_id:
		rpc_id(peer_id, "_client_auth_result", false, "This account is already connected")
		return
	var profile: Dictionary = identity.get("profile", {})
	_peer_users[peer_id] = user_id
	_user_peers[user_id] = peer_id
	_profiles[user_id] = profile
	_session_tokens[user_id] = str(identity.get("session_token", ""))
	var player = _create_server_player(peer_id, profile, identity.get("stats", {}))
	var restored: Dictionary = _sessions.get(user_id, {})
	var restored_room := str(restored.get("room_code", ""))
	var restored_room_active := _rooms.has(restored_room) and not bool(_rooms[restored_room].get("round_finished", false))
	var can_restore := not restored.is_empty() and int(restored.get("expires", 0)) >= Time.get_ticks_msec() and restored_room_active
	if can_restore:
		player.global_position = restored.get("position", Vector3(0, 1.5, 6))
		player.score = int(restored.get("score", 0))
		player.xp = int(restored.get("xp", player.xp))
		player.match_xp = int(restored.get("match_xp", 0))
		player.collection_counts = restored.get("collections", {})
		player.health = clampf(float(restored.get("health", 100.0)), 0.0, 100.0)
		player.is_dead = bool(restored.get("dead", false))
		player.respawn_left = maxf(0.0, float(restored.get("respawn_left", 0.0)))
		player.kills = int(restored.get("kills", 0))
		player.deaths = int(restored.get("deaths", 0))
		player.blaster_mastery_xp = int(restored.get("blaster_mastery_xp", 0))
		player.grenade_mastery_xp = int(restored.get("grenade_mastery_xp", 0))
		player.equipped_weapon_id = str(restored.get("equipped_weapon_id", "aether"))
		var restored_team := str(restored.get("team_id", ""))
		player.team_id = restored_team if restored_team in ["red", "blue"] else ""
		player.kill_streak = maxi(0, int(restored.get("kill_streak", 0)))
		player.best_kill_streak = maxi(player.kill_streak, int(restored.get("best_kill_streak", 0)))
		player.stamina = clampf(float(restored.get("stamina", 100.0)), 0.0, 100.0)
		player.damage_received = maxf(0.0, float(restored.get("damage_received", 0.0)))
		player.secret_404_found = bool(restored.get("secret_404_found", false))
		var restored_emote := str(restored.get("emote_id", ""))
		player.emote_id = EMOTE_CATALOG.sanitize(restored_emote)
		player.is_swimming = bool(restored.get("is_swimming", false))
		player.damage_dealt = float(restored.get("damage_dealt", 0.0))
		player.shots_fired = int(restored.get("shots_fired", 0))
		player.shots_hit = int(restored.get("shots_hit", 0))
		player.match_outcome = str(restored.get("outcome", "abandoned"))
		_player_joined_at_ms[user_id] = Time.get_ticks_msec() - int(restored.get("playtime_seconds", 0)) * 1000
		var room: Dictionary = _rooms[restored_room]
		room.members[user_id] = peer_id
		player.apply_event(str(room.event_id))
		_rooms[restored_room] = room
		_user_rooms[user_id] = restored_room
		_last_room_code = restored_room
		_move_player_to_room_world(peer_id, restored_room)
		_broadcast_room_state(restored_room)
	elif not restored.is_empty():
		await _persist_session_result(user_id, restored)
		_server_remove_from_room(user_id)
	_sessions.erase(user_id)
	# The client sends its selected lobby action after receiving this result.
	# Do not auto-create a quick-match room here: that would race CREATE/JOIN
	# and persist a false "abandoned" match before the player has entered one.
	rpc_id(peer_id, "_client_auth_result", true, "Authenticated", user_id, str(profile.get("display_name", "Player")), str(profile.get("avatar_color_id", "color_cyan")), can_restore)

## Identity of a guest on an open server: a random id (so two guests never collide), the chosen name, no stats.
func _guest_identity(raw_name: String) -> Dictionary:
	var suffix := ""
	for i in range(10):
		suffix += "abcdefghijklmnopqrstuvwxyz0123456789".substr(_rng.randi_range(0, 35), 1)
	var colors := ["color_cyan", "color_violet", "color_orange", "color_lime"]
	return {
		"ok": true, "user_id": GUEST_USER_PREFIX + suffix,
		"profile": {"display_name": _clean_guest_name(raw_name), "avatar_color_id": colors[_rng.randi_range(0, colors.size() - 1)]},
		"stats": {}, "session_token": ""
	}

func _is_guest_user(user_id: String) -> bool:
	return user_id.begins_with(GUEST_USER_PREFIX)

func _redeem_game_ticket(ticket: String) -> Dictionary:
	if _server_secret.is_empty():
		return {"ok": false}
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"x-oxenwar-server-secret: " + _server_secret
	])
	var response := await _http_json(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/functions/v1/oxenwar-server-sync", headers,
		{"action": "redeem_ticket", "ticket": ticket})
	if not response.get("ok", false):
		return {"ok": false}
	var data: Dictionary = response.get("data", {})
	if not data.get("ok", false) or str(data.get("session_token", "")).is_empty():
		return {"ok": false}
	return data

func _http_json(method: int, url: String, headers: PackedStringArray, payload: Variant = null) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 12.0
	add_child(request)
	var body := "" if payload == null else JSON.stringify(payload)
	var error := request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"ok": false, "status": 0}
	var response: Array = await request.request_completed
	request.queue_free()
	var status := int(response[1])
	var raw := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = {}
	if not raw.is_empty():
		var json := JSON.new()
		if json.parse(raw) == OK:
			parsed = json.data
	return {"ok": status >= 200 and status < 300, "status": status, "data": parsed}

func _create_server_player(peer_id: int, profile: Dictionary, stats: Dictionary = {}):
	var player = SERVER_PLAYER_SCRIPT.new()
	player.name = "ServerPlayer_%d" % peer_id
	player.position = Vector3(0, 1.5, 6)
	player.xp = int(stats.get("total_xp", 0))
	var spawn_offset := Vector3(float(_server_players.size() % 4) * 1.6 - 2.4, 0, float(_server_players.size() / 4) * 1.6)
	player.position += spawn_offset
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	_server_players[peer_id] = player
	return player

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _server_submit_input(move: Vector2, yaw: float, jump: bool, sprint: bool, slide: bool, dash: bool, seq: int = 0, pitch: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var now := Time.get_ticks_msec()
	if seq > 0 and seq <= int(_last_input_seq.get(peer_id, 0)):
		return
	if now - int(_last_input_ms.get(peer_id, 0)) < 15:
		return
	if not is_finite(move.x) or not is_finite(move.y) or not is_finite(yaw):
		return
	_last_input_ms[peer_id] = now
	_last_input_seq[peer_id] = maxi(int(_last_input_seq.get(peer_id, 0)), seq)
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code) or bool(_rooms[room_code].get("round_finished", false)):
		return
	var player = _server_players[peer_id]
	if player.is_dead:
		return
	player.input_vector = move.limit_length(1.0) * (-1.0 if str(room_code) != "" and str(_rooms[room_code].event_id) == "REVERSE_PANIC" else 1.0)
	player.look_yaw = wrapf(yaw, -PI, PI)
	# Only used so other players see where this one aims; clamped to the camera limits, and a
	# non-finite value (a bad client) leaves the previous pitch in place.
	if is_finite(pitch):
		player.look_pitch = clampf(pitch, deg_to_rad(-82.0), deg_to_rad(82.0))
	player.jump_requested = player.jump_requested or jump
	player.sprinting = sprint
	player.slide_requested = player.slide_requested or slide
	player.dash_requested = player.dash_requested or dash

func request_reload(weapon_id: String) -> void:
	if is_authenticated and not is_dedicated_server and ARCADE_WEAPONS.has(weapon_id):
		rpc_id(1, "_server_reload_weapon", weapon_id)


@rpc("any_peer", "call_remote", "reliable")
func _server_reload_weapon(weapon_id: String) -> void:
	if not multiplayer.is_server() or not ARCADE_WEAPONS.has(weapon_id):
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer) or not _server_players.has(peer):
		return
	var code := str(_user_rooms.get(str(_peer_users[peer]), ""))
	if not _rooms.has(code) or bool(_rooms[code].get("round_finished", false)):
		return
	var body = _server_players[peer]
	var now := Time.get_ticks_msec()
	if body.is_dead or body.equipped_weapon_id != weapon_id or now < body.reload_until_ms:
		return
	var duration := preload("res://scripts/weapon_viewmodel_anim.gd").reload_duration(float(ARCADE_WEAPONS[weapon_id].cooldown_ms) / 1000.0)
	body.reload_until_ms = now + int(duration * 1000.0)


@rpc("any_peer", "call_remote", "reliable")
func _server_select_weapon(weapon_id: String) -> void:
	if not multiplayer.is_server() or not ARCADE_WEAPONS.has(weapon_id):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var player = _server_players[peer_id]
	if player.is_dead:
		return
	if player.equipped_weapon_id != weapon_id:
		player.reload_until_ms = 0
	player.equipped_weapon_id = weapon_id

func _lag_position(peer_id: int, rewind_ms: int, fallback: Vector3) -> Vector3:
	var history = _pos_history.get(peer_id)
	if history == null or rewind_ms <= 0:
		return fallback
	var past: Variant = history.position_at(Time.get_ticks_msec() - rewind_ms)
	return past if past is Vector3 else fallback

func _lag_height(peer_id: int, rewind_ms: int, fallback: float) -> float:
	var history = _pos_history.get(peer_id)
	if history == null or rewind_ms <= 0:
		return fallback
	return history.height_at(Time.get_ticks_msec() - rewind_ms, fallback)

func _record_position_history(now_ms: int) -> void:
	for peer_id in _server_players.keys():
		var tracked = _server_players[peer_id]
		if not is_instance_valid(tracked):
			continue
		if not _pos_history.has(peer_id):
			_pos_history[peer_id] = NET_SYNC.PositionHistory.new()
		_pos_history[peer_id].record(now_ms, tracked.global_position, NET_SYNC.PLAYER_HEIGHT_SLIDING if bool(tracked.get("sliding_active")) else NET_SYNC.PLAYER_HEIGHT)

static func view_forward(yaw: float) -> Vector3:
	# Matches the player's -Z camera axis after the authoritative yaw rotation.
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD

@rpc("any_peer", "call_remote", "unreliable")
func _server_blaster_fire(weapon_id: String, direction: Vector3, view_delay_ms: int = 0, aiming: bool = false) -> void:
	if not ARCADE_WEAPONS.has(weapon_id):
		return
	if not multiplayer.is_server() or not is_finite(direction.x) or not is_finite(direction.y) or not is_finite(direction.z) or direction.length() < 0.9 or direction.length() > 1.1:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var now := Time.get_ticks_msec()
	var weapon: Dictionary = ARCADE_WEAPONS[weapon_id]
	if now - int(_last_blaster_ms.get(peer_id, 0)) < int(weapon.cooldown_ms):
		return
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code) or bool(_rooms[room_code].get("round_finished", false)):
		return
	var shooter = _server_players[peer_id]
	if shooter.is_dead or now < shooter.reload_until_ms or str(shooter.event_id) == "FREEZE_FRAME" or str(shooter.equipped_weapon_id) != weapon_id:
		return
	var aim_direction := direction.normalized()
	if absf(aim_direction.y) > 0.94:
		return
	var facing := view_forward(shooter.look_yaw)
	if aim_direction.dot(facing) < 0.12:
		return
	# Spread is rolled here, from the server's own tracker and the shooter's server-side movement.
	var tracker = _shot_trackers.get(peer_id)
	if tracker == null:
		tracker = WEAPON_FEEL.Tracker.new()
		_shot_trackers[peer_id] = tracker
	var last_shot_ms := int(_last_blaster_ms.get(peer_id, 0))
	if last_shot_ms > 0:
		tracker.step(float(now - last_shot_ms) / 1000.0)
	var feel_profile: Dictionary = WEAPON_FEEL.profile(float(weapon.cooldown_ms) / 1000.0, float(weapon.range))
	var horizontal_speed := Vector2(shooter.velocity.x, shooter.velocity.z).length()
	var shot: Dictionary = WEAPON_FEEL.authoritative_shot(aim_direction, tracker, feel_profile, horizontal_speed, shooter.is_on_floor(), bool(shooter.sliding_active), aiming)
	var safe_direction: Vector3 = shot.direction
	_last_blaster_ms[peer_id] = now
	shooter.shots_fired += 1
	if weapon_id == "aether":
		_award_weapon_mastery(shooter, "blaster", 1)
	var eye_height := 0.90 if shooter.sliding_active else 1.45
	var origin: Vector3 = shooter.global_position + Vector3.UP * eye_height
	var endpoint := origin + safe_direction * float(weapon.range)
	var fire_room: Dictionary = _rooms[room_code]
	var room_peers: Array[int] = []
	var exclude: Array[RID] = []
	for member_user in fire_room.members.keys():
		var member_id := int(fire_room.members[member_user])
		if member_id > 0 and _server_players.has(member_id):
			room_peers.append(member_id)
			exclude.append(_server_players[member_id].get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.exclude = exclude
	query.collide_with_areas = false
	var hit: Dictionary = shooter.get_world_3d().direct_space_state.intersect_ray(query)
	var best_distance := float(weapon.range)
	if not hit.is_empty():
		endpoint = hit.position
		best_distance = origin.distance_to(endpoint)
	# Lag compensation: test the ray against where each enemy was on the shooter's screen.
	var rewind := NET_SYNC.clamp_rewind(view_delay_ms)
	var target_peer := -1
	for candidate in room_peers:
		if candidate == peer_id:
			continue
		var candidate_player = _server_players[candidate]
		if bool(candidate_player.get("is_dead")):
			continue
		var candidate_base: Vector3 = _lag_position(candidate, rewind, candidate_player.global_position)
		var candidate_height: float = _lag_height(candidate, rewind, NET_SYNC.PLAYER_HEIGHT_SLIDING if bool(candidate_player.get("sliding_active")) else NET_SYNC.PLAYER_HEIGHT)
		var candidate_distance := NET_SYNC.ray_capsule_distance(origin, safe_direction, best_distance, candidate_base, NET_SYNC.PLAYER_RADIUS, candidate_height)
		if candidate_distance >= 0.0 and candidate_distance <= best_distance:
			best_distance = candidate_distance
			target_peer = candidate
	if target_peer != -1:
		endpoint = origin + safe_direction * best_distance
		var target = _server_players[target_peer]
		var same_team: bool = str(shooter.team_id) != "" and str(shooter.team_id) == str(target.get("team_id"))
		if not same_team and target.has_method("apply_damage"):
			var weapon_damage := float(weapon.damage)
			var was_killed: bool = target.apply_damage(weapon_damage)
			shooter.shots_hit += 1
			if weapon_id == "aether":
				_award_weapon_mastery(shooter, "blaster", 8)
			shooter.damage_dealt += weapon_damage
			target.damage_received += weapon_damage
			if was_killed:
				shooter.kills += 1
				if weapon_id == "aether":
					_award_weapon_mastery(shooter, "blaster", 35)
				shooter.kill_streak += 1
				shooter.best_kill_streak = maxi(shooter.best_kill_streak, shooter.kill_streak)
				target.deaths += 1
				target.kill_streak = 0
				_award_killstreak(room_code, peer_id)
				_broadcast_kill_feed(room_code, peer_id, target_peer, str(weapon.name))
			shooter.score += 10 + (50 if was_killed else 0)
	var room: Dictionary = _rooms[room_code]
	for member_user in room.members.keys():
		var member_peer := int(room.members[member_user])
		if member_peer > 0:
			rpc_id(member_peer, "_client_blaster_fx", peer_id, origin, endpoint, weapon_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_throw_grenade(direction: Vector3) -> void:
	if not multiplayer.is_server() or not is_finite(direction.x) or not is_finite(direction.y) or not is_finite(direction.z) or direction.length() < 0.9 or direction.length() > 1.1:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_grenade_ms.get(peer_id, 0)) < 5000:
		return
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code) or bool(_rooms[room_code].get("round_finished", false)):
		return
	var thrower = _server_players[peer_id]
	if thrower.is_dead or str(thrower.event_id) == "FREEZE_FRAME":
		return
	var forward := Vector3(sin(thrower.look_yaw), 0.0, -cos(thrower.look_yaw))
	if direction.normalized().dot(forward) < 0.05:
		return
	_last_grenade_ms[peer_id] = now
	var grenade_id := _next_grenade_id
	_next_grenade_id += 1
	var origin: Vector3 = thrower.global_position + Vector3.UP * 1.35 + forward * 0.55
	var launch_velocity := direction.normalized() * 13.0 + Vector3.UP * 4.2
	var room: Dictionary = _rooms[room_code]
	var grenades: Array = room.get("grenades", [])
	grenades.append({"id": grenade_id, "owner": peer_id, "team": str(thrower.team_id), "position": origin, "velocity": launch_velocity, "fuse": 2.5})
	room.grenades = grenades
	_rooms[room_code] = room
	for member_uid in room.members.keys():
		var member_peer := int(room.members[member_uid])
		if member_peer > 0:
			rpc_id(member_peer, "_client_grenade_spawn", grenade_id, origin, launch_velocity)

func _server_step_grenades(room_code: String, room: Dictionary, delta: float) -> Dictionary:
	var grenades: Array = room.get("grenades", [])
	var keep: Array = []
	for grenade_value in grenades:
		var grenade: Dictionary = grenade_value
		var owner_peer := int(grenade.get("owner", 0))
		var exclude: Array = []
		if _server_players.has(owner_peer):
			exclude.append(_server_players[owner_peer].get_rid())
		var stepped: Dictionary = GRENADE_PHYSICS.step(grenade.get("position", Vector3.ZERO), grenade.get("velocity", Vector3.ZERO), delta, _room_space(room_code), exclude)
		grenade.position = stepped.position
		grenade.velocity = stepped.velocity
		grenade.fuse = float(grenade.get("fuse", 0.0)) - delta
		if float(grenade.fuse) <= 0.0:
			_server_detonate_grenade(room_code, grenade)
		else:
			keep.append(grenade)
	room.grenades = keep
	return room

func _server_detonate_grenade(room_code: String, grenade: Dictionary) -> void:
	var blast_position: Vector3 = grenade.get("position", Vector3.ZERO)
	var owner_peer := int(grenade.get("owner", 0))
	var owner_team := str(grenade.get("team", ""))
	var sphere := SphereShape3D.new()
	sphere.radius = 5.0
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis.IDENTITY, blast_position)
	shape_query.collide_with_areas = false
	var hits: Array[Dictionary] = _room_space(room_code).intersect_shape(shape_query, 64)
	var damaged: Dictionary = {}
	for hit in hits:
		var target: Object = hit.get("collider")
		if not target is CharacterBody3D or not target.has_method("apply_damage"):
			continue
		var target_peer := 0
		for candidate in _server_players.keys():
			if _server_players[candidate] == target:
				target_peer = int(candidate)
				break
		if target_peer <= 0 or damaged.has(target_peer) or bool(target.get("is_dead")):
			continue
		var target_team := str(target.get("team_id"))
		if owner_team != "" and target_team == owner_team:
			continue
		var distance := blast_position.distance_to(target.global_position)
		var damage := 85.0 * (1.0 - clampf(distance / 5.0, 0.0, 1.0))
		if damage >= 8.0:
			var killed: bool = target.apply_damage(damage)
			target.damage_received += damage
			if _server_players.has(owner_peer) and target_peer != owner_peer:
				_server_players[owner_peer].damage_dealt += damage
				_award_weapon_mastery(_server_players[owner_peer], "grenade", maxi(1, int(round(damage * 0.2))))
			damaged[target_peer] = true
			if killed:
				target.deaths += 1
				target.kill_streak = 0
			if _server_players.has(owner_peer) and target_peer != owner_peer:
				if killed:
					_server_players[owner_peer].kills += 1
					_award_weapon_mastery(_server_players[owner_peer], "grenade", 45)
					_server_players[owner_peer].kill_streak += 1
					_server_players[owner_peer].best_kill_streak = maxi(_server_players[owner_peer].best_kill_streak, _server_players[owner_peer].kill_streak)
					_award_killstreak(room_code, owner_peer)
					_broadcast_kill_feed(room_code, owner_peer, target_peer, "GRENADE")
				_server_players[owner_peer].score += 8 + (45 if killed else 0)
	var room: Dictionary = _rooms.get(room_code, {})
	for member_uid in room.get("members", {}).keys():
		var member_peer := int(room.members[member_uid])
		if member_peer > 0:
			rpc_id(member_peer, "_client_grenade_explode", int(grenade.get("id", 0)), blast_position)



func _award_weapon_mastery(player, weapon_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if weapon_id == "blaster":
		player.blaster_mastery_xp = mini(100000, int(player.blaster_mastery_xp) + amount)
	elif weapon_id == "grenade":
		player.grenade_mastery_xp = mini(100000, int(player.grenade_mastery_xp) + amount)

func _award_killstreak(room_code: String, killer_peer: int) -> void:
	if not _rooms.has(room_code) or not _server_players.has(killer_peer):
		return
	var killer = _server_players[killer_peer]
	var streak := int(killer.kill_streak)
	var bonus_by_streak := {3: 20, 5: 40, 7: 60, 10: 100}
	if not bonus_by_streak.has(streak):
		return
	var bonus := int(bonus_by_streak[streak])
	killer.score += bonus
	var user_id := str(_peer_users.get(killer_peer, ""))
	var player_name := str(_profiles.get(user_id, {}).get("display_name", "Player"))
	var room: Dictionary = _rooms[room_code]
	for member_uid in room.members.keys():
		var member_peer := int(room.members[member_uid])
		if member_peer > 0:
			rpc_id(member_peer, "_client_killstreak", player_name, streak, bonus)

func _broadcast_kill_feed(room_code: String, killer_peer: int, victim_peer: int, weapon_name: String) -> void:
	if not _rooms.has(room_code):
		return
	var killer_uid := str(_peer_users.get(killer_peer, ""))
	var victim_uid := str(_peer_users.get(victim_peer, ""))
	var killer_name := str(_profiles.get(killer_uid, {}).get("display_name", "Player"))
	var victim_name := str(_profiles.get(victim_uid, {}).get("display_name", "Player"))
	var room: Dictionary = _rooms[room_code]
	for member_uid in room.members.keys():
		var member_peer := int(room.members[member_uid])
		if member_peer > 0:
			rpc_id(member_peer, "_client_kill_feed", killer_name, victim_name, weapon_name)


@rpc("authority", "call_remote", "reliable")
func _client_killstreak(player_name: String, streak: int, bonus: int) -> void:
	if not multiplayer.is_server():
		killstreak_received.emit(player_name, streak, bonus)

@rpc("authority", "call_remote", "reliable")
func _client_kill_feed(killer_name: String, victim_name: String, weapon_name: String) -> void:
	if not multiplayer.is_server():
		kill_feed_received.emit(killer_name, victim_name, weapon_name)

@rpc("authority", "call_remote", "unreliable")
func _client_grenade_spawn(grenade_id: int, origin: Vector3, launch_velocity: Vector3) -> void:
	if not multiplayer.is_server():
		grenade_spawn_received.emit(grenade_id, origin, launch_velocity)

@rpc("authority", "call_remote", "reliable")
func _client_grenade_explode(grenade_id: int, position_value: Vector3) -> void:
	if not multiplayer.is_server():
		grenade_exploded_received.emit(grenade_id, position_value)

@rpc("authority", "call_remote", "unreliable")
func _client_blaster_fx(shooter_peer_id: int, origin: Vector3, endpoint: Vector3, weapon_id: String) -> void:
	if not multiplayer.is_server():
		blaster_fx_received.emit(shooter_peer_id, origin, endpoint, weapon_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_create_room(private_room: bool = true, mode: String = "ffa", map_index: int = 4) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	var user_id := str(_peer_users[peer_id])
	_server_remove_from_room(user_id)
	var code := _generate_room_code()
	_rooms[code] = _new_room(code, user_id, not private_room, _sanitize_mode(mode), map_index)
	_assign_user_to_room(user_id, peer_id, code)
	_broadcast_room_state(code)

@rpc("any_peer", "call_remote", "reliable")
func _server_join_room(code: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	code = code.strip_edges().to_upper()
	if not _rooms.has(code):
		rpc_id(peer_id, "_client_room_error", "Room not found")
		return
	var room: Dictionary = _rooms[code]
	var user_id := str(_peer_users[peer_id])
	if bool(room.round_finished):
		rpc_id(peer_id, "_client_room_error", "This round has ended")
		return
	if room.members.size() >= int(room.max_players) and not room.members.has(user_id):
		rpc_id(peer_id, "_client_room_error", "Room is full")
		return
	if str(_user_rooms.get(user_id, "")) == code:
		_broadcast_room_state(code)
		return
	var guest_involved := open_mode and (_is_guest_user(user_id) or _is_guest_user(str(room.owner_uid)))
	if not bool(room.is_public) and str(room.owner_uid) != user_id and not guest_involved:
		var source_code := str(_user_rooms.get(user_id, ""))
		var friends := await _server_are_friends(user_id, str(room.owner_uid), str(_session_tokens.get(user_id, "")))
		if str(_peer_users.get(peer_id, "")) != user_id or str(_user_rooms.get(user_id, "")) != source_code:
			return
		if not friends:
			rpc_id(peer_id, "_client_room_error", "Private rooms are for friends only")
			return
		# The directory can change while the friendship request is in flight.
		if not _rooms.has(code) or _rooms[code] != room or bool(room.round_finished):
			rpc_id(peer_id, "_client_room_error", "This room is no longer available")
			return
		if room.members.size() >= int(room.max_players):
			rpc_id(peer_id, "_client_room_error", "Room is full")
			return
	_server_remove_from_room(user_id)
	_assign_user_to_room(user_id, peer_id, code)
	_broadcast_room_state(code)

@rpc("any_peer", "call_remote", "reliable")
func _server_quick_match(mode: String = "ffa", map_index: int = 4) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	_server_quick_match_for_peer(peer_id, _sanitize_mode(mode), map_index)

func _server_quick_match_for_peer(peer_id: int, mode: String = "ffa", map_index: int = 4) -> void:
	var user_id := str(_peer_users.get(peer_id, ""))
	if user_id.is_empty():
		return
	_server_remove_from_room(user_id)
	var target := ""
	for code in _rooms.keys():
		var room: Dictionary = _rooms[code]
		if bool(room.is_public) and str(room.get("mode", "ffa")) == _sanitize_mode(mode) and int(room.get("map_index", 4)) == ARENA_LAYOUT.sanitize_map(map_index) and not bool(room.round_finished) and room.members.size() < int(room.max_players):
			target = str(code)
			break
	if target.is_empty():
		target = _generate_room_code()
		_rooms[target] = _new_room(target, user_id, true, _sanitize_mode(mode), map_index)
	_assign_user_to_room(user_id, peer_id, target)
	_broadcast_room_state(target)

@rpc("any_peer", "call_remote", "reliable")
func _server_leave_room() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var user_id := str(_peer_users.get(peer_id, ""))
	_server_remove_from_room(user_id)
	rpc_id(peer_id, "_client_room_state", {})
	
@rpc("any_peer", "call_remote", "reliable")
func _server_invite_friend(friend_user_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var user_id := str(_peer_users.get(peer_id, ""))
	var room_code := str(_user_rooms.get(user_id, ""))
	if user_id.is_empty() or room_code.is_empty() or not _user_peers.has(friend_user_id):
		rpc_id(peer_id, "_client_room_error", "Friend is offline or no room is active")
		return
	if not await _server_are_friends(user_id, friend_user_id, str(_session_tokens.get(user_id, ""))):
		rpc_id(peer_id, "_client_room_error", "You can invite friends only")
		return
	var friend_peer := int(_user_peers[friend_user_id])
	rpc_id(friend_peer, "_client_room_invite", str(_profiles[user_id].get("display_name", "Friend")), room_code)

func _server_are_friends(user_id: String, other_id: String, session_token: String) -> bool:
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"x-oxenwar-server-secret: " + _server_secret
	])
	var result := await _http_json(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/functions/v1/oxenwar-server-sync", headers,
		{"action": "check_friend", "session_token": session_token, "friend_user_id": other_id})
	if not result.get("ok", false):
		return false
	var data: Dictionary = result.get("data", {})
	return bool(data.get("is_friend", false))

func _new_room(code: String, owner_uid: String, public_room: bool, mode: String = "ffa", map_index: int = 4) -> Dictionary:
	var availability := {}
	var respawn := {}
	map_index = ARENA_LAYOUT.sanitize_map(map_index)
	for i in range(ARENA_LAYOUT.orb_positions(map_index).size()):
		availability[i] = true
		respawn[i] = 0
	return {
		"code": code, "owner_uid": owner_uid, "is_public": public_room, "mode": _sanitize_mode(mode), "map_index": map_index, "grenades": [],
		"max_players": ROOM_CAPACITY, "members": {}, "orb_available": availability,
		"orb_respawn": respawn, "event_id": "", "event_left": 0.0,
		"event_clock": MEME_EVENTS.next_gap(_rng, false, true), "event_cooldowns": {}, "event_fail_streak": 0, "event_history": [], "previous_event": "", "round_left": 180.0 if _sanitize_mode(mode) == "demolition" else ROUND_SECONDS,
		"round_id": str(Time.get_unix_time_from_system()) + "-" + code,
		"started_at_ms": Time.get_ticks_msec(),
		"round_finished": false,
		"objective_winner_team": "", "bomb_planted": false, "bomb_site": "", "bomb_fuse": 0.0,
		"objective_interactor": 0, "objective_action": "", "objective_progress": 0.0,
		"hill_control": 0.0,
		"hill_points_red": 0.0,
		"hill_points_blue": 0.0,
		"persisted": {}
	}

## Every room lives in its own physics world (a SubViewport with its own World3D), so each room can
## use a different map and rooms cannot hit or collide with each other.
var _room_worlds: Dictionary = {}

func _ensure_room_world(code: String) -> SubViewport:
	if _room_worlds.has(code) and is_instance_valid(_room_worlds[code]):
		return _room_worlds[code]
	if not is_inside_tree() or not _rooms.has(code):
		return null
	var viewport := SubViewport.new()
	viewport.name = "RoomWorld_" + code
	viewport.own_world_3d = true
	viewport.size = Vector2i(2, 2)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	PhysicsServer3D.space_set_active(viewport.find_world_3d().space, true)
	ARENA_LAYOUT.build_collision(viewport, int(_rooms[code].get("map_index", 4)))
	_room_worlds[code] = viewport
	return viewport

func _room_space(code: String) -> PhysicsDirectSpaceState3D:
	var world := _ensure_room_world(code)
	if world != null:
		return world.find_world_3d().direct_space_state
	return get_viewport().world_3d.direct_space_state

func _move_player_to_room_world(peer_id: int, code: String) -> void:
	if not _server_players.has(peer_id):
		return
	var player = _server_players[peer_id]
	if _rooms.has(code):
		player.swim_map_index = int(_rooms[code].get("map_index", 4))
	var world := _ensure_room_world(code)
	if world != null and player.get_parent() != world:
		player.reparent(world, false)

func _return_player_to_lobby(peer_id: int) -> void:
	if _server_players.has(peer_id) and is_inside_tree() and _server_players[peer_id].get_parent() != self:
		_server_players[peer_id].reparent(self, false)

func _free_room_world(code: String) -> void:
	if _room_worlds.has(code):
		if is_instance_valid(_room_worlds[code]):
			_room_worlds[code].queue_free()
		_room_worlds.erase(code)

func _assign_user_to_room(user_id: String, peer_id: int, code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	room.members[user_id] = peer_id
	if _sanitize_mode(str(room.get("mode", "ffa"))) in ["team_deathmatch", "king_of_the_hill", "demolition"]:
		var red_count := 0
		var blue_count := 0
		for member_uid in room.members.keys():
			var member_peer := int(room.members[member_uid])
			if member_peer > 0 and _server_players.has(member_peer) and str(_server_players[member_peer].team_id) == "red":
				red_count += 1
			elif member_peer > 0 and _server_players.has(member_peer) and str(_server_players[member_peer].team_id) == "blue":
				blue_count += 1
		_server_players[peer_id].team_id = "red" if red_count <= blue_count else "blue"
	else:
		_server_players[peer_id].team_id = ""
	_rooms[code] = room
	_user_rooms[user_id] = code
	_last_room_code = code
	if _server_players.has(peer_id):
		_server_players[peer_id].set_physics_process(true)
		_move_player_to_room_world(peer_id, code)
		_pos_history.erase(peer_id)
		_shot_trackers.erase(peer_id)
		_last_blaster_ms.erase(peer_id)
		var assigned_map := int(room.get("map_index", 4))
		_server_players[peer_id].respawn_at(ARENA_LAYOUT.spawn_position(assigned_map, str(_server_players[peer_id].team_id), room.members.size() - 1))
		_server_players[peer_id].emote_id = ""
		_server_players[peer_id].score = 0
		_server_players[peer_id].kills = 0
		_server_players[peer_id].kill_streak = 0
		_server_players[peer_id].best_kill_streak = 0
		_server_players[peer_id].blaster_mastery_xp = 0
		_server_players[peer_id].grenade_mastery_xp = 0
		_server_players[peer_id].match_xp = 0
		_server_players[peer_id].deaths = 0
		_server_players[peer_id].shots_fired = 0
		_server_players[peer_id].shots_hit = 0
		_server_players[peer_id].damage_dealt = 0.0
		_server_players[peer_id].damage_received = 0.0
		_server_players[peer_id].match_outcome = "abandoned"
		_player_joined_at_ms[user_id] = Time.get_ticks_msec()
		_server_players[peer_id].collection_counts.clear()
		_server_players[peer_id].secret_404_found = false
		_server_players[peer_id].apply_event(str(room.event_id))

func _server_remove_from_room(user_id: String) -> void:
	var old_code := str(_user_rooms.get(user_id, ""))
	if old_code.is_empty() or not _rooms.has(old_code):
		_user_rooms.erase(user_id)
		var current_peer := int(_user_peers.get(user_id, 0))
		if current_peer > 0 and _server_players.has(current_peer):
			_server_players[current_peer].set_physics_process(false)
		return
	var room: Dictionary = _rooms[old_code]
	var old_peer := int(room.members.get(user_id, 0))
	if old_peer > 0 and _server_players.has(old_peer):
		_persist_room_member_result(old_code, user_id, _server_players[old_peer])
		_server_players[old_peer].input_vector = Vector2.ZERO
		_server_players[old_peer].velocity = Vector3.ZERO
		_server_players[old_peer].set_physics_process(false)
		_return_player_to_lobby(old_peer)
		for member_uid in room.members.keys():
			var member_peer := int(room.members[member_uid])
			if member_peer > 0 and member_peer != old_peer:
				rpc_id(member_peer, "_client_peer_left", old_peer)
	room.members.erase(user_id)
	_rooms[old_code] = room
	_user_rooms.erase(user_id)
	_player_joined_at_ms.erase(user_id)
	_broadcast_room_state(old_code)
	if room.members.is_empty():
		_rooms.erase(old_code)
		_free_room_world(old_code)

## Public address clients use to reach this server. OXENWAR_PUBLIC_HOST wins; Render and Fly.io are detected.
func _detect_public_host() -> String:
	var explicit := OS.get_environment("OXENWAR_PUBLIC_HOST").strip_edges()
	if not explicit.is_empty():
		return explicit.rstrip("/")
	var render_url := OS.get_environment("RENDER_EXTERNAL_URL").strip_edges()
	if render_url.begins_with("https://"):
		return "wss://" + render_url.trim_prefix("https://").rstrip("/")
	var fly_app := OS.get_environment("FLY_APP_NAME").strip_edges()
	if not fly_app.is_empty():
		return fly_app + ".fly.dev"
	return ""

func _server_process_directory(delta: float) -> void:
	if _directory_host.is_empty() or _directory_busy:
		return
	_directory_timer += delta
	var codes := PackedStringArray()
	for code in _rooms.keys():
		codes.append(str(code))
	codes.sort()
	var signature := "%d|%s" % [_server_players.size(), ",".join(codes)]
	var changed := signature != _directory_signature
	if directory_sync_due(_directory_attempted, _directory_failures, _directory_timer, changed):
		_sync_directory(signature)

## When to call the directory edge function: right away the first time, within ~2 seconds of a change, and
## otherwise a heartbeat every 25 seconds. After failures it backs off (10s, 20s, 40s ... max 300s) so a wrong
## secret or an outage can never turn into a request flood.
static func directory_sync_due(attempted: bool, failures: int, timer: float, changed: bool) -> bool:
	if not attempted:
		return true
	if failures > 0:
		return timer >= directory_retry_interval(failures)
	return (changed and timer >= 2.0) or timer >= 25.0

static func directory_retry_interval(failures: int) -> float:
	if failures <= 0:
		return 25.0
	return minf(10.0 * pow(2.0, float(failures - 1)), 300.0)

func _sync_directory(signature: String) -> void:
	_directory_busy = true
	_directory_attempted = true
	_directory_timer = 0.0
	var rooms: Array = []
	for code in _rooms.keys():
		if rooms.size() >= 200:
			break
		var room: Dictionary = _rooms[code]
		rooms.append({
			"code": str(code),
			"mode": _sanitize_mode(str(room.get("mode", "ffa"))),
			"map_index": ARENA_LAYOUT.sanitize_map(int(room.get("map_index", 4)))
		})
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"x-oxenwar-server-secret: " + _server_secret
	])
	var result := await _http_json(HTTPClient.METHOD_POST, SUPABASE_URL + "/functions/v1/oxenwar-server-sync", headers, {
		"action": "sync_directory",
		"host": _directory_host,
		"player_count": _server_players.size(),
		"max_players": MAX_CLIENTS,
		"rooms": rooms
	})
	if result.get("ok", false):
		_directory_signature = signature
		_directory_failures = 0
		_directory_warned = false
	else:
		_directory_failures += 1
		if not _directory_warned:
			_directory_warned = true
			var status := int(result.get("status", 0))
			var hint := " (OXENWAR_SERVER_SECRET differs from the Supabase secret)" if status == 403 else ""
			push_warning("OxenWar server directory sync failed with HTTP status %d%s; retrying with backoff" % [status, hint])
	_directory_busy = false

func _generate_room_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in range(6):
		code += alphabet.substr(_rng.randi_range(0, alphabet.length() - 1), 1)
	while _rooms.has(code):
		code = _generate_room_code()
	return code

func _server_process_rooms(delta: float) -> void:
	# A dropped input stream must not leave sprint or movement held indefinitely.
	var input_now := Time.get_ticks_msec()
	for peer in _server_players:
		if input_now - int(_last_input_ms.get(peer, input_now)) > 300:
			var body = _server_players[peer]
			body.input_vector = Vector2.ZERO
			body.sprinting = false
			body.jump_requested = false
			body.slide_requested = false
			body.dash_requested = false
	var now := Time.get_ticks_msec()
	for user_id in _sessions.keys():
		var session: Dictionary = _sessions[user_id]
		if now > int(session.expires):
			_persist_session_result(str(user_id), session)
			_sessions.erase(user_id)
			_player_joined_at_ms.erase(user_id)
			_user_rooms.erase(user_id)
			var code := str(session.get("room_code", ""))
			if _rooms.has(code):
				var room: Dictionary = _rooms[code]
				room.members.erase(user_id)
				_rooms[code] = room
				if room.members.is_empty():
					_rooms.erase(code)
					_free_room_world(code)
				else:
					_broadcast_room_state(code)
	_snapshot_accumulator += delta
	_record_position_history(now)
	for code in _rooms.keys():
		var room: Dictionary = _rooms[code]
		if bool(room.round_finished):
			_rooms[code] = room
			continue
		room = _server_step_grenades(str(code), room, delta)
		room = _server_step_objective(str(code), room, delta)
		room.round_left = maxf(0.0, float(room.round_left) - delta)
		# Keep the round active until the fuse is resolved, even when the plant
		# timer runs out. The HUD displays the bomb fuse during this interval.
		if bool(room.get("bomb_planted", false)) and str(room.get("objective_winner_team", "")).is_empty():
			room.round_left = maxf(0.01, float(room.round_left))
		if str(room.get("mode", "")) == "demolition" and not bool(room.get("bomb_planted", false)) and float(room.round_left) <= 0.0 and str(room.get("objective_winner_team", "")).is_empty():
			room.objective_winner_team = "blue"
			room.objective_result = "DEFENDERS SURVIVED"
		_server_step_meme_event(str(code), room, delta)
		for uid in room.members.keys():
			var respawn_peer := int(room.members[uid])
			if respawn_peer <= 0 or not _server_players.has(respawn_peer):
				continue
			var respawn_player = _server_players[respawn_peer]
			if respawn_player.is_dead and str(room.get("mode", "")) != "demolition":
				respawn_player.respawn_left = maxf(0.0, respawn_player.respawn_left - delta)
				if respawn_player.respawn_left <= 0.0:
					respawn_player.respawn_at(ARENA_LAYOUT.spawn_position(int(room.get("map_index", 4)), str(respawn_player.team_id), respawn_peer))
		if str(room.get("mode", "ffa")) == "king_of_the_hill":
			var red_inside := 0
			var blue_inside := 0
			var hill_center := Vector3(0, 1.5, 0)
			for hill_uid in room.members.keys():
				var hill_peer := int(room.members[hill_uid])
				if hill_peer <= 0 or not _server_players.has(hill_peer):
					continue
				var hill_player = _server_players[hill_peer]
				if hill_player.is_dead or hill_player.global_position.distance_to(hill_center) > 5.0:
					continue
				if str(hill_player.team_id) == "red":
					red_inside += 1
				elif str(hill_player.team_id) == "blue":
					blue_inside += 1
			if red_inside > 0 and blue_inside == 0:
				room.hill_control = minf(100.0, float(room.hill_control) + delta * 20.0)
			elif blue_inside > 0 and red_inside == 0:
				room.hill_control = maxf(-100.0, float(room.hill_control) - delta * 20.0)
			if float(room.hill_control) >= 100.0 and red_inside > 0 and blue_inside == 0:
				room.hill_points_red = float(room.hill_points_red) + delta
			elif float(room.hill_control) <= -100.0 and blue_inside > 0 and red_inside == 0:
				room.hill_points_blue = float(room.hill_points_blue) + delta
		var room_orbs: Array[Vector3] = ARENA_LAYOUT.orb_positions(int(room.get("map_index", 4)))
		for orb_index in range(room_orbs.size()):
			if not bool(room.orb_available[orb_index]) and now >= int(room.orb_respawn[orb_index]):
				room.orb_available[orb_index] = true
			if bool(room.orb_available[orb_index]):
				for uid in room.members.keys():
					var pid := int(room.members[uid])
					if pid <= 0 or not _server_players.has(pid):
						continue
					var player = _server_players[pid]
					if player.is_dead:
						continue
					if player.global_position.distance_to(room_orbs[orb_index]) <= 1.15:
						room.orb_available[orb_index] = false
						room.orb_respawn[orb_index] = now + 8000
						var points := 20 if str(room.event_id) == "GOLDEN_ORB_RUSH" else 10
						var xp_gain := 30 if str(room.event_id) == "DOUBLE_XP" else 15
						if str(room.event_id) == "GOLDEN_ORB_RUSH":
							xp_gain *= 2
						player.score += points
						player.xp += xp_gain
						player.match_xp += xp_gain
						var collection_id := "orb_%02d" % orb_index
						player.collection_counts[collection_id] = int(player.collection_counts.get(collection_id, 0)) + 1
						if orb_index == 11 and not player.secret_404_found:
							player.secret_404_found = true
							player.xp += 100
							player.match_xp += 100
							player.collection_counts["secret_404"] = 1
						break
		if float(room.round_left) <= 0.0 and not bool(room.round_finished):
			room.round_finished = true
			room["snap_counter"] = 0
			var red_kills := 0
			var blue_kills := 0
			var ffa_winner_peer := 0
			var best_kills := -1
			var best_score := -1
			for member_uid in room.members.keys():
				var member_peer := int(room.members[member_uid])
				if member_peer <= 0 or not _server_players.has(member_peer):
					continue
				var candidate = _server_players[member_peer]
				if str(candidate.team_id) == "red":
					red_kills += int(candidate.kills)
				elif str(candidate.team_id) == "blue":
					blue_kills += int(candidate.kills)
				if int(candidate.kills) > best_kills or (int(candidate.kills) == best_kills and int(candidate.score) > best_score):
					best_kills = int(candidate.kills)
					best_score = int(candidate.score)
					ffa_winner_peer = member_peer
				elif int(candidate.kills) == best_kills and int(candidate.score) == best_score:
					ffa_winner_peer = 0
			if str(room.mode) == "king_of_the_hill":
				red_kills = int(round(float(room.hill_points_red)))
				blue_kills = int(round(float(room.hill_points_blue)))
			elif str(room.mode) == "demolition":
				red_kills = 1 if str(room.get("objective_winner_team", "")) == "red" else 0
				blue_kills = 1 if str(room.get("objective_winner_team", "")) == "blue" else 0
			for member_uid in room.members.keys():
				var member_peer := int(room.members[member_uid])
				var outcome := "draw"
				if str(room.mode) in ["team_deathmatch", "king_of_the_hill", "demolition"]:
					if red_kills > blue_kills:
						outcome = "win" if _server_players.has(member_peer) and str(_server_players[member_peer].team_id) == "red" else "loss"
					elif blue_kills > red_kills:
						outcome = "win" if _server_players.has(member_peer) and str(_server_players[member_peer].team_id) == "blue" else "loss"
				elif ffa_winner_peer > 0:
					outcome = "win" if member_peer == ffa_winner_peer else "loss"
				if _server_players.has(member_peer):
					_server_players[member_peer].match_outcome = outcome
			for uid in room.members.keys():
				var finished_peer := int(room.members[uid])
				if finished_peer > 0 and _server_players.has(finished_peer):
					var finished_player = _server_players[finished_peer]
					finished_player.input_vector = Vector2.ZERO
					finished_player.velocity = Vector3.ZERO
					finished_player.set_physics_process(false)
					_persist_room_member_result(str(code), str(uid), finished_player)
		_rooms[code] = room
	if _snapshot_accumulator >= SNAPSHOT_INTERVAL:
		_snapshot_accumulator = 0.0
		for code in _rooms.keys():
			_broadcast_snapshot(str(code))

func _server_step_meme_event(code: String, room: Dictionary, delta: float) -> void:
	var alive: Array[int] = []
	for member in room.members.values():
		var peer := int(member)
		if _server_players.has(peer) and not _server_players[peer].is_dead:
			alive.append(peer)
	var changed := MEME_EVENTS.step(room, delta, _rng, alive)
	if room.round_left <= 0.0 and not str(room.event_id).is_empty():
		MEME_EVENTS.cancel(room, _rng)
		changed = true
	if changed:
		for member in room.members.values():
			if _server_players.has(int(member)):
				_server_players[int(member)].apply_event(str(room.event_id))
	if str(room.event_id) != MEME_EVENTS.SUNSHINE or bool(room.event_impact):
		return
	var peer := int(room.event_target)
	if not alive.has(peer):
		MEME_EVENTS.cancel(room, _rng)
		return
	var target = _server_players[peer]
	var aim: Vector3 = target.global_position + Vector3.UP * 1.0
	if not bool(room.event_actor_ready):
		room.event_actor = Vector3(0, 14, 0)
		room.event_actor_ready = true
		return
	var chase_delta := MEME_EVENTS.count_down(room, delta)
	if chase_delta <= 0.0:
		return
	var start: Vector3 = room.event_actor
	var next := MEME_EVENTS.track(start, aim, chase_delta)
	var space := _room_space(code)
	if space == null:
		return
	if start.is_equal_approx(next) and start.distance_to(aim) > 0.18:
		return
	var query := PhysicsRayQueryParameters3D.create(start, next, 1, [target.get_rid()])
	if not space.intersect_ray(query).is_empty():
		# Fly across cover at roof height before attempting a new approach.
		var overhead := Vector3(aim.x, 14.0, aim.z) if start.y >= 13.9 else Vector3(start.x, 14.0, start.z)
		next = MEME_EVENTS.track(start, overhead, chase_delta)
		query.to = next
		if not space.intersect_ray(query).is_empty():
			return
	room.event_actor = next
	if next.distance_to(aim) <= 0.18 and target.apply_damage(target.health):
		target.deaths += 1
		target.kill_streak = 0
		room.event_impact = true
		room.event_left = minf(float(room.event_left), 3.0)


func _collection_list(player) -> Array[String]:
	return _collection_list_from_counts(player.collection_counts)

func _collection_list_from_counts(counts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for collection_id in counts.keys():
		var quantity := mini(512 - result.size(), int(counts[collection_id]))
		for i in range(maxi(0, quantity)):
			result.append(str(collection_id))
	return result

func _persist_session_result(user_id: String, session: Dictionary) -> void:
	if bool(session.get("already_persisted", false)):
		return
	var counts: Dictionary = session.get("collections", {})
	await _persist_result_values(
		user_id, str(session.get("session_token", "")),
		int(session.get("score", 0)), int(session.get("match_xp", 0)),
		_collection_list_from_counts(counts), int(session.get("kills", 0)),
		int(session.get("deaths", 0)), float(session.get("damage_dealt", 0.0)),
		int(session.get("shots_fired", 0)), int(session.get("shots_hit", 0)),
		int(session.get("playtime_seconds", 0)), str(session.get("outcome", "abandoned")),
		int(session.get("blaster_mastery_xp", 0)), int(session.get("grenade_mastery_xp", 0))
	)

func _persist_room_member_result(room_code: String, user_id: String, player) -> void:
	if not _rooms.has(room_code):
		return
	var room: Dictionary = _rooms[room_code]
	var persisted: Dictionary = room.get("persisted", {})
	var persisting: Dictionary = room.get("persisting", {})
	if persisted.has(user_id) or persisting.has(user_id):
		return
	persisting[user_id] = true
	room["persisting"] = persisting
	var saved := await _persist_user_result(user_id, player)
	persisting.erase(user_id)
	if saved:
		persisted[user_id] = true
		room["persisted"] = persisted
	elif _sessions.has(user_id) and str(_sessions[user_id].get("room_code", "")) == room_code:
		# A disconnect while saving deferred its retry to reservation expiry.
		_sessions[user_id]["already_persisted"] = false

func _persist_user_result(user_id: String, player) -> bool:
	var joined_at := int(_player_joined_at_ms.get(user_id, Time.get_ticks_msec()))
	var playtime := maxi(0, int((Time.get_ticks_msec() - joined_at) / 1000))
	return await _persist_result_values(
		user_id, str(_session_tokens.get(user_id, "")), int(player.score),
		int(player.match_xp), _collection_list(player), int(player.kills),
		int(player.deaths), float(player.damage_dealt), int(player.shots_fired),
		int(player.shots_hit), playtime, str(player.match_outcome),
		int(player.blaster_mastery_xp), int(player.grenade_mastery_xp)
	)

func _persist_result_values(user_id: String, session_token: String, score: int, xp: int, collections: Array, kills: int, deaths: int, damage_dealt: float, shots_fired: int, shots_hit: int, playtime_seconds: int, outcome: String, mastery_blaster_xp: int, mastery_grenade_xp: int) -> bool:
	if user_id.is_empty() or _is_guest_user(user_id):
		return true
	if session_token.is_empty() or _server_secret.is_empty():
		push_warning("OXENWAR_SERVER_SECRET or server session is missing; match results cannot be persisted.")
		return false
	var payload := {
		"action": "sync_result",
		"session_token": session_token,
		"score": clampi(score, 0, 20000),
		"xp": clampi(xp, 0, 50000),
		"collections": collections,
		"kills": clampi(kills, 0, 5000),
		"deaths": clampi(deaths, 0, 5000),
		"damage_dealt": clampf(damage_dealt, 0.0, 10000000.0),
		"shots_fired": clampi(shots_fired, 0, 20000),
		"shots_hit": clampi(shots_hit, 0, 20000),
		"playtime_seconds": clampi(playtime_seconds, 0, 7200),
		"outcome": outcome if ["win", "loss", "draw", "abandoned"].has(outcome) else "abandoned",
		"blaster_mastery_xp": clampi(mastery_blaster_xp, 0, 100000),
		"grenade_mastery_xp": clampi(mastery_grenade_xp, 0, 100000)
	}
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"x-oxenwar-server-secret: " + _server_secret
	])
	var result := await _http_json(HTTPClient.METHOD_POST, SUPABASE_URL + "/functions/v1/oxenwar-server-sync", headers, payload)
	if not result.get("ok", false):
		push_warning("OxenWar result sync failed with HTTP status %d" % int(result.get("status", 0)))
		return false
	return true

func _meme_snapshot(room: Dictionary) -> Dictionary:
	if room.get("event_id") != MEME_EVENTS.SUNSHINE:
		return {}
	return {"serial": int(room.event_serial), "target": int(room.event_target),
		"actor": room.event_actor, "warning": float(room.event_warning), "impact": bool(room.event_impact)}


func _broadcast_snapshot(code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var states := {}
	var counter := int(room.get("snap_counter", 0))
	room["snap_counter"] = counter + 1
	var member_signature := ""
	var now_ms := Time.get_ticks_msec()
	var peer_states := {}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id <= 0 or not _server_players.has(peer_id):
			continue
		member_signature += "%d," % peer_id
		peer_states[peer_id] = str(user_id)
	# Slow fields (names, colours, xp, mastery...) go out every FULL_STATE_EVERY-th snapshot and
	# whenever someone joins or leaves; every other snapshot carries only what changes quickly.
	var full_state: bool = counter % FULL_STATE_EVERY == 0 or str(room.get("snap_members", "")) != member_signature
	room["snap_members"] = member_signature
	for peer_id in peer_states.keys():
		var user_id := str(peer_states[peer_id])
		var player = _server_players[peer_id]
		var profile: Dictionary = _profiles.get(user_id, {})
		var state := {
			"position": player.global_position, "yaw": player.rotation.y, "grounded": player.is_on_floor(), "match_outcome": player.match_outcome,
			"team_id": str(player.team_id), "emote_id": str(player.emote_id), "is_swimming": bool(player.is_swimming),
			"score": player.score, "kills": player.kills, "deaths": player.deaths, "kill_streak": player.kill_streak,
			"reload_left": maxf(0.0, float(player.reload_until_ms - now_ms) / 1000.0),
			"equipped_weapon_id": player.equipped_weapon_id, "shots_hit": player.shots_hit, "damage_received": player.damage_received,
			"stamina": player.stamina, "sliding": player.sliding_active, "pitch": player.look_pitch,
			"health": player.health, "dead": player.is_dead, "respawn_left": player.respawn_left,
			"input_seq": int(_last_input_seq.get(peer_id, 0)), "input_age_ms": maxi(0, now_ms - int(_last_input_ms.get(peer_id, now_ms)))
		}
		if full_state:
			state["display_name"] = str(profile.get("display_name", "Player"))
			state["color"] = _color_for_profile(profile)
			state["outfit_id"] = str(profile.get("outfit_id", "outfit_default"))
			state["accessory_id"] = profile.get("accessory_id")
			state["best_kill_streak"] = player.best_kill_streak
			state["blaster_mastery_xp"] = player.blaster_mastery_xp
			state["grenade_mastery_xp"] = player.grenade_mastery_xp
			state["shots_fired"] = player.shots_fired
			state["damage_dealt"] = player.damage_dealt
			state["xp"] = player.xp
			state["match_xp"] = player.match_xp
			state["collections"] = player.collection_counts.duplicate(true)
			state["secret_404_found"] = player.secret_404_found
		states[peer_id] = state
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id > 0:
			rpc_id(peer_id, "_client_receive_snapshot", states, str(room.event_id),
				float(room.event_left), float(room.round_left), room.orb_available, str(room.code), str(room.mode), float(room.hill_control), float(room.hill_points_red), float(room.hill_points_blue), bool(room.get("bomb_planted", false)), str(room.get("bomb_site", "")), float(room.get("bomb_fuse", 0.0)), float(room.get("objective_progress", 0.0)), str(room.get("objective_action", "")), str(room.get("objective_result", "PLANT THE ENERGY CORE")), _meme_snapshot(room))

func _broadcast_room_state(code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var roster: Array[Dictionary] = []
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		roster.append({
			"user_id": user_id,
			"display_name": str(_profiles.get(user_id, {}).get("display_name", "Player")),
			"online": peer_id > 0,
			"team_id": str(_server_players[peer_id].team_id) if peer_id > 0 and _server_players.has(peer_id) else ""
		})
	var state := {"code": code, "is_public": bool(room.is_public), "mode": str(room.get("mode", "ffa")), "map_index": int(room.get("map_index", 4)), "members": roster, "max_players": int(room.max_players)}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id > 0:
			rpc_id(peer_id, "_client_room_state", state)

func _color_for_profile(profile: Dictionary) -> String:
	var colors := {"color_cyan": "#27D7E7", "color_violet": "#9B70FF", "color_orange": "#FF9B42", "color_lime": "#A7E34B"}
	return str(colors.get(str(profile.get("avatar_color_id", "color_cyan")), "#27D7E7"))

var session_restored_on_auth := false

@rpc("authority", "call_remote", "reliable")
func _client_auth_result(ok: bool, message: String, user_id: String = "", display_name: String = "", color_id: String = "", session_restored: bool = false) -> void:
	if multiplayer.is_server():
		return
	is_authenticated = ok
	session_restored_on_auth = ok and session_restored
	if ok:
		local_player_name = display_name
		connection_status_changed.emit("Authenticated • " + display_name)
		authentication_changed.emit(true, message)
	else:
		connection_status_changed.emit(message)
		authentication_changed.emit(false, message)

@rpc("authority", "call_remote", "reliable")
func _client_room_state(state: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var announced_room := str(state.get("code", ""))
	if announced_room != _client_cache_room:
		_clear_client_room()
		_client_cache_room = announced_room
	room_state_changed.emit(state)

@rpc("authority", "call_remote", "reliable")
func _client_room_error(message: String) -> void:
	if not multiplayer.is_server():
		connection_status_changed.emit("Room: " + message)

@rpc("authority", "call_remote", "reliable")
func _client_room_invite(owner_name: String, room_code: String) -> void:
	if not multiplayer.is_server():
		invite_received.emit(owner_name, room_code)

@rpc("authority", "call_remote", "unreliable_ordered")
func _client_receive_snapshot(states: Dictionary, event_id: String, event_left: float, round_left: float, orb_available: Dictionary, room_code: String, mode: String, hill_control: float, hill_points_red: float, hill_points_blue: float, bomb_planted: bool, bomb_site: String, bomb_fuse: float, objective_progress: float, objective_action: String, objective_result: String, meme: Dictionary = {}) -> void:
	if multiplayer.is_server():
		return
	# The reliable roster selects the active room. An in-flight snapshot from
	# a room we left must not recreate its avatars or update its clock.
	if room_code.is_empty() or room_code != _client_cache_room:
		return
	for key in states.keys():
		var peer_id := int(key)
		# Snapshots may be partial: keep the slow fields from the last full one.
		var state: Dictionary = _client_state_cache.get(peer_id, {}).duplicate()
		state.merge(states[key], true)
		_client_state_cache[peer_id] = state
		if peer_id == multiplayer.get_unique_id():
			local_state_received.emit(state)
		else:
			player_state_received.emit(peer_id, state)
	for cached_peer in _client_state_cache.keys():
		if not states.has(cached_peer):
			_client_state_cache.erase(cached_peer)
	for key in states.keys():
		var incoming_peer := int(key)
		if incoming_peer != multiplayer.get_unique_id():
			_client_peer_ids[incoming_peer] = true
	for peer_id in _client_peer_ids.keys():
		if not states.has(peer_id):
			_forget_client_peer(int(peer_id))
	room_state_changed.emit({
		"code": room_code, "meme": meme, "event_id": event_id, "event_left": event_left,
		"round_left": round_left, "orb_available": orb_available, "mode": mode,
		"hill_control": hill_control, "hill_points_red": hill_points_red, "hill_points_blue": hill_points_blue,
		"bomb_planted": bomb_planted, "bomb_site": bomb_site, "bomb_fuse": bomb_fuse,
		"objective_progress": objective_progress, "objective_action": objective_action, "objective_result": objective_result
	})

@rpc("authority", "call_remote", "reliable")
func _client_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		_forget_client_peer(peer_id)

func _exit_tree() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
