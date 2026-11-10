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
const SNAPSHOT_INTERVAL := 0.05
const ROOM_GRACE_SECONDS := 30.0
const ROUND_SECONDS := 300.0
const EVENT_INTERVAL := 30.0
const EVENT_DURATION := 12.0
const SUPABASE_URL := "https://lznnfwhlsquiitkhjzlc.supabase.co"
const SUPABASE_KEY := "sb_publishable_z7UuZtF9NQwox1Ae0droQA_mxpD-P7L"
const SERVER_PLAYER_SCRIPT := preload("res://scripts/oxenwar_server_player.gd")
const ORB_POSITIONS: Array[Vector3] = [
	Vector3(-12, 1.0, -8), Vector3(-7, 2.0, -5), Vector3(0, 2.0, -10),
	Vector3(7, 2.0, -5), Vector3(12, 1.0, -8), Vector3(-10, 1.0, 5),
	Vector3(-4, 1.8, 1), Vector3(4, 1.8, 1), Vector3(10, 1.0, 5),
	Vector3(0, 2.2, 10), Vector3(-2, 1.2, -2), Vector3(2, 1.2, -2)
]
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
	"rubber_chicken": {"name":"RUBBER CHICKEN", "damage":14.0, "cooldown_ms":480, "range":32.0}
}

var is_dedicated_server := false
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
var _server_players: Dictionary = {} # peer id -> CharacterBody3D
var _last_input_ms: Dictionary = {}
var _last_blaster_ms: Dictionary = {}
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

func start_server() -> bool:
	is_dedicated_server = true
	_rng.randomize()
	_server_secret = OS.get_environment("OXENWAR_SERVER_SECRET").strip_edges()
	if _server_secret.is_empty():
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
	return true

func connect_to_server(host: String, access_token: String) -> void:
	_access_token = access_token
	_last_host = host.strip_edges()
	_reconnect_attempts = 0
	_request_ticket_and_connect()

func _request_ticket_and_connect() -> void:
	if is_dedicated_server or _ticket_request_in_progress:
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
		error = enet_peer.create_client(_last_host, PORT)
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
	connection_status_changed.emit("Connecting securely to " + _last_host if _last_host.begins_with("wss://") else ("Connecting to " + _last_host if websocket_url else "Connecting to " + _last_host + ":" + str(PORT)))

func update_access_token(token: String) -> void:
	if not token.is_empty():
		_access_token = token

func set_local_player(player: Node3D, display_name: String, color: Color) -> void:
	local_player = player
	local_player_name = display_name.substr(0, 24)
	local_player_color = color

func request_create_room(private_room: bool = true, mode: String = "ffa") -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_create_room", private_room, _sanitize_mode(mode))

func request_quick_match(mode: String = "ffa") -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_quick_match", _sanitize_mode(mode))

func _sanitize_mode(mode: String) -> String:
	if mode == "team_deathmatch" or mode == "king_of_the_hill":
		return mode
	return "ffa"

func request_emote(emote_id: String) -> void:
	if is_authenticated and not is_dedicated_server and emote_id in ["griddy", "goofy", "robot", "wave", ""]:
		rpc_id(1, "_server_set_emote", emote_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_set_emote(emote_id: String) -> void:
	if not multiplayer.is_server() or emote_id not in ["griddy", "goofy", "robot", "wave", ""]:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code) or bool(_rooms[room_code].get("round_finished", false)):
		return
	_server_players[peer_id].emote_id = emote_id

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

func request_blaster_fire(weapon_id: String, direction: Vector3) -> void:
	if is_authenticated and not is_dedicated_server and ARCADE_WEAPONS.has(weapon_id) and direction.length() > 0.9:
		rpc_id(1, "_server_blaster_fire", weapon_id, direction.normalized())

func _process(delta: float) -> void:
	if is_dedicated_server:
		_server_process_rooms(delta)
		return
	if not is_authenticated or local_player == null or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_pending_jump = _pending_jump or Input.is_action_just_pressed("jump")
	_pending_slide = _pending_slide or Input.is_action_just_pressed("slide")
	_pending_dash = _pending_dash or Input.is_action_just_pressed("dash")
	var now := Time.get_ticks_msec()
	if now - _last_send_ms < 50:
		return
	_last_send_ms = now
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprint := Input.is_action_pressed("sprint")
	rpc_id(1, "_server_submit_input", move, local_player.rotation.y, _pending_jump, sprint, _pending_slide, _pending_dash)
	_pending_jump = false
	_pending_slide = false
	_pending_dash = false

func _on_connected_to_server() -> void:
	_reconnect_attempts = 0
	connection_status_changed.emit("Connected • verifying Supabase account")
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
	for peer_id in _server_players.keys():
		player_disconnected.emit(int(peer_id))
	_server_players.clear()
	_schedule_reconnect()

func _schedule_reconnect() -> void:
	if is_dedicated_server or _access_token.is_empty() or _last_host.is_empty():
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
		_last_blaster_ms.erase(peer_id)
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
			"blaster_mastery_xp": int(_server_players[peer_id].blaster_mastery_xp) if _server_players.has(peer_id) else 0,
			"grenade_mastery_xp": int(_server_players[peer_id].grenade_mastery_xp) if _server_players.has(peer_id) else 0,
			"damage_dealt": float(_server_players[peer_id].damage_dealt) if _server_players.has(peer_id) else 0.0,
			"shots_fired": int(_server_players[peer_id].shots_fired) if _server_players.has(peer_id) else 0,
			"shots_hit": int(_server_players[peer_id].shots_hit) if _server_players.has(peer_id) else 0,
			"playtime_seconds": maxi(0, int((Time.get_ticks_msec() - int(_player_joined_at_ms.get(user_id, Time.get_ticks_msec()))) / 1000)),
			"outcome": str(_server_players[peer_id].match_outcome) if _server_players.has(peer_id) else "abandoned",
			"session_token": str(_session_tokens.get(user_id, "")),
			"already_persisted": bool(room.get("persisted", {}).has(user_id))
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
	_last_blaster_ms.erase(peer_id)
	if int(_user_peers.get(user_id, 0)) == peer_id:
		_user_peers.erase(user_id)
		_session_tokens.erase(user_id)
	_broadcast_room_state(room_code)
	print("OxenWar peer disconnected: ", peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_authenticate(ticket: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if ticket.length() < 40 or ticket.length() > 8192:
		rpc_id(peer_id, "_client_auth_result", false, "Invalid game ticket")
		return
	var identity := await _redeem_game_ticket(ticket)
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
		_broadcast_room_state(restored_room)
	elif not restored.is_empty():
		await _persist_session_result(user_id, restored)
		_server_remove_from_room(user_id)
	_sessions.erase(user_id)
	# The client sends its selected lobby action after receiving this result.
	# Do not auto-create a quick-match room here: that would race CREATE/JOIN
	# and persist a false "abandoned" match before the player has entered one.
	rpc_id(peer_id, "_client_auth_result", true, "Authenticated", user_id, str(profile.get("display_name", "Player")), str(profile.get("avatar_color_id", "color_cyan")), can_restore)

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
func _server_submit_input(move: Vector2, yaw: float, jump: bool, sprint: bool, slide: bool, dash: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id) or not _server_players.has(peer_id):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_input_ms.get(peer_id, 0)) < 15:
		return
	if not is_finite(move.x) or not is_finite(move.y) or not is_finite(yaw):
		return
	_last_input_ms[peer_id] = now
	var user_id := str(_peer_users[peer_id])
	var room_code := str(_user_rooms.get(user_id, ""))
	if room_code.is_empty() or not _rooms.has(room_code) or bool(_rooms[room_code].get("round_finished", false)):
		return
	var player = _server_players[peer_id]
	if player.is_dead:
		return
	player.input_vector = move.limit_length(1.0)
	player.look_yaw = wrapf(yaw, -PI, PI)
	player.jump_requested = player.jump_requested or jump
	player.sprinting = sprint
	player.slide_requested = player.slide_requested or slide
	player.dash_requested = player.dash_requested or dash

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
	player.equipped_weapon_id = weapon_id

@rpc("any_peer", "call_remote", "unreliable")
func _server_blaster_fire(weapon_id: String, direction: Vector3) -> void:
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
	if shooter.is_dead or str(shooter.event_id) == "FREEZE_FRAME" or str(shooter.equipped_weapon_id) != weapon_id:
		return
	var safe_direction := direction.normalized()
	if absf(safe_direction.y) > 0.94:
		return
	var facing := Vector3(sin(shooter.look_yaw), 0.0, -cos(shooter.look_yaw))
	if safe_direction.dot(facing) < 0.12:
		return
	_last_blaster_ms[peer_id] = now
	shooter.shots_fired += 1
	if weapon_id == "aether":
		_award_weapon_mastery(shooter, "blaster", 1)
	var origin: Vector3 = shooter.global_position + Vector3.UP * 1.45
	var endpoint := origin + safe_direction * float(weapon.range)
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.exclude = [shooter.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position
		var target: Object = hit.get("collider")
		if target is CharacterBody3D and target != shooter and target.has_method("apply_damage") and not bool(target.get("is_dead")):
			for target_peer in _server_players.keys():
				if _server_players[target_peer] == target:
					if str(shooter.team_id) != "" and str(shooter.team_id) == str(target.get("team_id")):
						break
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
						_broadcast_kill_feed(room_code, peer_id, int(target_peer), str(weapon.name))
					shooter.score += 10 + (50 if was_killed else 0)
					break
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
		var velocity: Vector3 = grenade.get("velocity", Vector3.ZERO)
		var position: Vector3 = grenade.get("position", Vector3.ZERO)
		velocity.y -= 9.8 * delta
		var next_position := position + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(position, next_position)
		var owner_peer := int(grenade.get("owner", 0))
		if _server_players.has(owner_peer):
			query.exclude = [_server_players[owner_peer].get_rid()]
		query.collide_with_areas = false
		var collision: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			next_position = collision.position + collision.normal * 0.08
			velocity = velocity.bounce(collision.normal) * 0.42
			if velocity.length() < 1.2:
				velocity = Vector3.ZERO
		grenade.position = next_position
		grenade.velocity = velocity
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
	var hits: Array[Dictionary] = get_viewport().world_3d.direct_space_state.intersect_shape(shape_query, 64)
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
func _server_create_room(private_room: bool = true, mode: String = "ffa") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	var user_id := str(_peer_users[peer_id])
	_server_remove_from_room(user_id)
	var code := _generate_room_code()
	_rooms[code] = _new_room(code, user_id, not private_room, _sanitize_mode(mode))
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
	if not bool(room.is_public) and str(room.owner_uid) != user_id:
		var friends := await _server_are_friends(user_id, str(room.owner_uid), str(_session_tokens.get(user_id, "")))
		if not friends:
			rpc_id(peer_id, "_client_room_error", "Private rooms are for friends only")
			return
	_server_remove_from_room(user_id)
	_assign_user_to_room(user_id, peer_id, code)
	_broadcast_room_state(code)

@rpc("any_peer", "call_remote", "reliable")
func _server_quick_match(mode: String = "ffa") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	_server_quick_match_for_peer(peer_id, _sanitize_mode(mode))

func _server_quick_match_for_peer(peer_id: int, mode: String = "ffa") -> void:
	var user_id := str(_peer_users.get(peer_id, ""))
	if user_id.is_empty():
		return
	_server_remove_from_room(user_id)
	var target := ""
	for code in _rooms.keys():
		var room: Dictionary = _rooms[code]
		if bool(room.is_public) and str(room.get("mode", "ffa")) == _sanitize_mode(mode) and not bool(room.round_finished) and room.members.size() < int(room.max_players):
			target = str(code)
			break
	if target.is_empty():
		target = _generate_room_code()
		_rooms[target] = _new_room(target, user_id, true, _sanitize_mode(mode))
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

func _new_room(code: String, owner_uid: String, public_room: bool, mode: String = "ffa") -> Dictionary:
	var availability := {}
	var respawn := {}
	for i in range(ORB_POSITIONS.size()):
		availability[i] = true
		respawn[i] = 0
	return {
		"code": code, "owner_uid": owner_uid, "is_public": public_room, "mode": _sanitize_mode(mode), "grenades": [],
		"max_players": ROOM_CAPACITY, "members": {}, "orb_available": availability,
		"orb_respawn": respawn, "event_id": "", "event_left": 0.0,
		"event_clock": EVENT_INTERVAL, "round_left": ROUND_SECONDS,
		"round_id": str(Time.get_unix_time_from_system()) + "-" + code,
		"started_at_ms": Time.get_ticks_msec(),
		"round_finished": false,
		"hill_control": 0.0,
		"hill_points_red": 0.0,
		"hill_points_blue": 0.0,
		"persisted": {}
	}

func _assign_user_to_room(user_id: String, peer_id: int, code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	room.members[user_id] = peer_id
	if _sanitize_mode(str(room.get("mode", "ffa"))) in ["team_deathmatch", "king_of_the_hill"]:
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
		var team_spawn_x := -10.0 if str(_server_players[peer_id].team_id) == "red" else (10.0 if str(_server_players[peer_id].team_id) == "blue" else 0.0)
		_server_players[peer_id].global_position = Vector3(team_spawn_x, 1.5, 6)
		_server_players[peer_id].velocity = Vector3.ZERO
		_server_players[peer_id].score = 0
		_server_players[peer_id].kills = 0
		_server_players[peer_id].kill_streak = 0
		_server_players[peer_id].best_kill_streak = 0
		_server_players[peer_id].blaster_mastery_xp = 0
		_server_players[peer_id].grenade_mastery_xp = 0
		_server_players[peer_id].health = 100.0
		_server_players[peer_id].is_dead = false
		_server_players[peer_id].respawn_left = 0.0
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
		for member_uid in room.members.keys():
			var member_peer := int(room.members[member_uid])
			if member_peer > 0 and member_peer != old_peer:
				rpc_id(member_peer, "_client_peer_left", old_peer)
	room.members.erase(user_id)
	_rooms[old_code] = room
	_user_rooms.erase(user_id)
	_broadcast_room_state(old_code)
	if room.members.is_empty():
		_rooms.erase(old_code)

func _generate_room_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in range(6):
		code += alphabet.substr(_rng.randi_range(0, alphabet.length() - 1), 1)
	while _rooms.has(code):
		code = _generate_room_code()
	return code

func _server_process_rooms(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for user_id in _sessions.keys():
		var session: Dictionary = _sessions[user_id]
		if now > int(session.expires):
			_persist_session_result(str(user_id), session)
			_sessions.erase(user_id)
			_user_rooms.erase(user_id)
			var code := str(session.get("room_code", ""))
			if _rooms.has(code):
				var room: Dictionary = _rooms[code]
				room.members.erase(user_id)
				_rooms[code] = room
				if room.members.is_empty():
					_rooms.erase(code)
				else:
					_broadcast_room_state(code)
	_snapshot_accumulator += delta
	for code in _rooms.keys():
		var room: Dictionary = _rooms[code]
		if bool(room.round_finished):
			_rooms[code] = room
			continue
		room = _server_step_grenades(str(code), room, delta)
		room.event_clock = float(room.event_clock) - delta
		room.event_left = maxf(0.0, float(room.event_left) - delta)
		room.round_left = maxf(0.0, float(room.round_left) - delta)
		if float(room.event_left) <= 0.0 and not str(room.event_id).is_empty():
			room.event_id = ""
			for uid in room.members.keys():
				var pid := int(room.members[uid])
				if pid > 0 and _server_players.has(pid):
					_server_players[pid].apply_event("")
		if float(room.event_clock) <= 0.0:
			room.event_id = EVENTS[_rng.randi_range(0, EVENTS.size() - 1)]
			room.event_left = EVENT_DURATION
			room.event_clock = EVENT_INTERVAL
			for uid in room.members.keys():
				var pid := int(room.members[uid])
				if pid > 0 and _server_players.has(pid):
					_server_players[pid].apply_event(str(room.event_id))
		for uid in room.members.keys():
			var respawn_peer := int(room.members[uid])
			if respawn_peer <= 0 or not _server_players.has(respawn_peer):
				continue
			var respawn_player = _server_players[respawn_peer]
			if respawn_player.is_dead:
				respawn_player.respawn_left = maxf(0.0, respawn_player.respawn_left - delta)
				if respawn_player.respawn_left <= 0.0:
					var spawn_offset := Vector3(float(respawn_peer % 4) * 1.6 - 2.4, 0.0, float(int(respawn_peer / 4) % 4) * 1.6)
					var team_spawn_x := -10.0 if str(respawn_player.team_id) == "red" else (10.0 if str(respawn_player.team_id) == "blue" else 0.0)
					respawn_player.respawn_at(Vector3(team_spawn_x, 1.5, 6) + spawn_offset)
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
		for orb_index in range(ORB_POSITIONS.size()):
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
					if player.global_position.distance_to(ORB_POSITIONS[orb_index]) <= 1.15:
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
			if str(room.mode) == "king_of_the_hill":
				red_kills = int(round(float(room.hill_points_red)))
				blue_kills = int(round(float(room.hill_points_blue)))
			for member_uid in room.members.keys():
				var member_peer := int(room.members[member_uid])
				var outcome := "draw"
				if str(room.mode) in ["team_deathmatch", "king_of_the_hill"]:
					if red_kills > blue_kills:
						outcome = "win" if _server_players.has(member_peer) and str(_server_players[member_peer].team_id) == "red" else "loss"
					elif blue_kills > red_kills:
						outcome = "win" if _server_players.has(member_peer) and str(_server_players[member_peer].team_id) == "blue" else "loss"
				elif member_peer != ffa_winner_peer:
					outcome = "loss"
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
	if persisted.has(user_id):
		return
	var saved := await _persist_user_result(user_id, player)
	if saved and _rooms.has(room_code):
		room = _rooms[room_code]
		persisted = room.get("persisted", {})
		persisted[user_id] = true
		room.persisted = persisted
		_rooms[room_code] = room

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
	if user_id.is_empty():
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

func _broadcast_snapshot(code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var states := {}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id <= 0 or not _server_players.has(peer_id):
			continue
		var player = _server_players[peer_id]
		states[peer_id] = {
			"position": player.global_position, "yaw": player.rotation.y,
			"display_name": str(_profiles.get(user_id, {}).get("display_name", "Player")),
			"color": _color_for_profile(_profiles.get(user_id, {})),
			"outfit_id": str(_profiles.get(user_id, {}).get("outfit_id", "outfit_default")),
			"team_id": str(player.team_id), "emote_id": str(player.emote_id), "is_swimming": bool(player.is_swimming),
			"score": player.score, "kills": player.kills, "deaths": player.deaths, "kill_streak": player.kill_streak, "best_kill_streak": player.best_kill_streak, "equipped_weapon_id": player.equipped_weapon_id, "blaster_mastery_xp": player.blaster_mastery_xp, "grenade_mastery_xp": player.grenade_mastery_xp, "shots_fired": player.shots_fired, "shots_hit": player.shots_hit, "damage_dealt": player.damage_dealt, "damage_received": player.damage_received, "xp": player.xp, "match_xp": player.match_xp, "stamina": player.stamina, "sliding": player.sliding_active,
			"health": player.health, "dead": player.is_dead, "respawn_left": player.respawn_left,
			"collections": player.collection_counts.duplicate(true), "secret_404_found": player.secret_404_found
		}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id > 0:
			rpc_id(peer_id, "_client_receive_snapshot", states, str(room.event_id),
				float(room.event_left), float(room.round_left), room.orb_available, str(room.code), str(room.mode), float(room.hill_control), float(room.hill_points_red), float(room.hill_points_blue))

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
	var state := {"code": code, "is_public": bool(room.is_public), "mode": str(room.get("mode", "ffa")), "members": roster, "max_players": int(room.max_players)}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id > 0:
			rpc_id(peer_id, "_client_room_state", state)

func _color_for_profile(profile: Dictionary) -> String:
	var colors := {"color_cyan": "#27D7E7", "color_violet": "#9B70FF", "color_orange": "#FF9B42", "color_lime": "#A7E34B"}
	return str(colors.get(str(profile.get("avatar_color_id", "color_cyan")), "#27D7E7"))

@rpc("authority", "call_remote", "reliable")
var session_restored_on_auth := false

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
func _client_receive_snapshot(states: Dictionary, event_id: String, event_left: float, round_left: float, orb_available: Dictionary, room_code: String, mode: String, hill_control: float, hill_points_red: float, hill_points_blue: float) -> void:
	if multiplayer.is_server():
		return
	for key in states.keys():
		var peer_id := int(key)
		var state: Dictionary = states[key]
		if peer_id == multiplayer.get_unique_id():
			local_state_received.emit(state)
		else:
			player_state_received.emit(peer_id, state)
	for key in states.keys():
		var incoming_peer := int(key)
		if incoming_peer != multiplayer.get_unique_id():
			_client_peer_ids[incoming_peer] = true
	for peer_id in _client_peer_ids.keys():
		if not states.has(peer_id):
			player_disconnected.emit(int(peer_id))
			_client_peer_ids.erase(peer_id)
	room_state_changed.emit({
		"code": room_code, "event_id": event_id, "event_left": event_left,
		"round_left": round_left, "orb_available": orb_available, "mode": mode,
		"hill_control": hill_control, "hill_points_red": hill_points_red, "hill_points_blue": hill_points_blue
	})

@rpc("authority", "call_remote", "reliable")
func _client_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		player_disconnected.emit(peer_id)

func _exit_tree() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
