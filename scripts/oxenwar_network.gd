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
const EVENTS := ["DUCK_PARADE", "PINK_SKY", "GOLDEN_ORB_RUSH", "CONFETTI_STORM", "LOW_GRAVITY", "BONK_MODE", "NPC_MODE", "DUCK_EXE", "METEOR_SHOWER", "ICE_WORLD", "DOUBLE_XP"]

var is_dedicated_server := false
var is_authenticated := false
var local_player: Node3D
var local_player_name := "Player"
var local_player_color := Color("#27D7E7")
var _access_token := ""
var _last_send_ms := 0
var _snapshot_accumulator := 0.0
var _server_players: Dictionary = {} # peer id -> CharacterBody3D
var _client_peer_ids: Dictionary = {}
var _peer_users: Dictionary = {} # peer id -> Supabase user id
var _user_peers: Dictionary = {} # Supabase user id -> peer id
var _profiles: Dictionary = {}
var _tokens: Dictionary = {} # server memory only; never persisted/logged
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
	_server_secret = OS.get_environment("OXENWAR_SERVER_SECRET")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		push_error("OxenWar server could not bind UDP %d: %s" % [PORT, error_string(error)])
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("OxenWar authoritative server listening on UDP %d" % PORT)
	return true

func connect_to_server(host: String, access_token: String) -> void:
	_access_token = access_token
	_last_host = host.strip_edges()
	_reconnect_attempts = 0
	_connect_now()

func _connect_now() -> void:
	if _last_host.is_empty() or _access_token.is_empty():
		connection_status_changed.emit("Sign in and enter a server address.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(_last_host, PORT)
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
	connection_status_changed.emit("Connecting to " + _last_host + ":" + str(PORT))

func set_local_player(player: Node3D, display_name: String, color: Color) -> void:
	local_player = player
	local_player_name = display_name.substr(0, 24)
	local_player_color = color

func request_create_room(private_room: bool = true) -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_create_room", private_room)

func request_join_room(code: String) -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_join_room", code.strip_edges().to_upper())

func request_quick_match() -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_quick_match")

func request_leave_room() -> void:
	if is_authenticated and not is_dedicated_server:
		rpc_id(1, "_server_leave_room")

func request_invite_friend(friend_user_id: String) -> void:
	if is_authenticated and not is_dedicated_server and not friend_user_id.is_empty():
		rpc_id(1, "_server_invite_friend", friend_user_id)

func _process(delta: float) -> void:
	if is_dedicated_server:
		_server_process_rooms(delta)
		return
	if not is_authenticated or local_player == null or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var now := Time.get_ticks_msec()
	if now - _last_send_ms < 50:
		return
	_last_send_ms = now
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("dash")
	var sprint := Input.is_action_pressed("sprint")
	var slide := Input.is_action_pressed("slide")
	rpc_id(1, "_server_submit_input", move, local_player.rotation.y, jump, sprint, slide, dash)

func _on_connected_to_server() -> void:
	_reconnect_attempts = 0
	connection_status_changed.emit("Connected • verifying Supabase account")
	rpc_id(1, "_server_authenticate", _access_token)

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
		_reconnect_timer.timeout.connect(_connect_now)
	if _reconnect_timer.is_stopped():
		_reconnect_attempts += 1
		_reconnect_timer.wait_time = minf(15.0, 1.5 * pow(1.6, minf(_reconnect_attempts, 5)))
		_reconnect_timer.start()

func _on_peer_connected(peer_id: int) -> void:
	print("OxenWar incoming peer: ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var user_id := str(_peer_users.get(peer_id, ""))
	if user_id.is_empty():
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
			"collections": _collection_list(_server_players[peer_id]) if _server_players.has(peer_id) else []
		}
		if _server_players.has(peer_id):
			_server_players[peer_id].queue_free()
		_server_players.erase(peer_id)
	_peer_users.erase(peer_id)
	_user_peers.erase(user_id)
	_tokens.erase(user_id)
	_broadcast_room_state(room_code)
	print("OxenWar peer disconnected: ", peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_authenticate(token: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if token.length() < 40 or token.length() > 4096:
		rpc_id(peer_id, "_client_auth_result", false, "Invalid access token")
		return
	var identity := await _verify_supabase_token(token)
	if not identity.get("ok", false):
		rpc_id(peer_id, "_client_auth_result", false, "Supabase authentication failed")
		return
	var user_id := str(identity.user_id)
	if _user_peers.has(user_id):
		var old_peer := int(_user_peers[user_id])
		if old_peer != peer_id:
			multiplayer.multiplayer_peer.disconnect_peer(old_peer)
	var profile: Dictionary = identity.profile
	_peer_users[peer_id] = user_id
	_user_peers[user_id] = peer_id
	_profiles[user_id] = profile
	_tokens[user_id] = token
	var player := _create_server_player(peer_id, profile, identity.get("stats", {}))
	var restored: Dictionary = _sessions.get(user_id, {})
	if not restored.is_empty() and int(restored.get("expires", 0)) >= Time.get_ticks_msec():
		player.global_position = restored.get("position", Vector3(0, 1.5, 6))
		player.score = int(restored.get("score", 0))
		player.xp = int(restored.get("xp", player.xp))
		player.match_xp = int(restored.get("match_xp", 0))
		player.collection_counts = restored.get("collections", {})
		var old_room := str(restored.get("room_code", ""))
		if _rooms.has(old_room):
			var room: Dictionary = _rooms[old_room]
			room.members[user_id] = peer_id
			_rooms[old_room] = room
			_user_rooms[user_id] = old_room
			_last_room_code = old_room
			_broadcast_room_state(old_room)
	_sessions.erase(user_id)
	rpc_id(peer_id, "_client_auth_result", true, "Authenticated", user_id, str(profile.get("display_name", "Player")), str(profile.get("avatar_color_id", "color_cyan")))
	if not _user_rooms.has(user_id):
		_server_quick_match_for_peer(peer_id)

func _verify_supabase_token(token: String) -> Dictionary:
	var auth_response := await _http_json(HTTPClient.METHOD_GET, SUPABASE_URL + "/auth/v1/user", PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + token
	]))
	if not auth_response.get("ok", false):
		return {"ok": false}
	var user: Dictionary = auth_response.get("data", {})
	var user_id := str(user.get("id", ""))
	if user_id.is_empty():
		return {"ok": false}
	var headers := PackedStringArray(["apikey: " + SUPABASE_KEY, "Authorization: Bearer " + token])
	var profile_response := await _http_json(HTTPClient.METHOD_GET,
		SUPABASE_URL + "/rest/v1/profiles?select=id,username,display_name,avatar_color_id,outfit_id,accessory_id&id=eq." + user_id.uri_encode() + "&limit=1", headers)
	if not profile_response.get("ok", false):
		return {"ok": false}
	var profiles: Array = profile_response.get("data", [])
	if profiles.is_empty():
		return {"ok": false}
	var stats_response := await _http_json(HTTPClient.METHOD_GET,
		SUPABASE_URL + "/rest/v1/player_stats?select=total_xp,best_score,total_score,matches_played&user_id=eq." + user_id.uri_encode() + "&limit=1", headers)
	var stats: Dictionary = {}
	if stats_response.get("ok", false):
		var stats_rows: Array = stats_response.get("data", [])
		if not stats_rows.is_empty():
			stats = stats_rows[0]
	return {"ok": true, "user_id": user_id, "profile": profiles[0], "stats": stats}

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
	var color_id := str(profile.get("avatar_color_id", "color_cyan"))
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
	var player = _server_players[peer_id]
	player.input_vector = move.limit_length(1.0)
	player.look_yaw = wrapf(yaw, -PI, PI)
	player.jump_requested = player.jump_requested or jump
	player.sprinting = sprint
	player.sliding = slide
	player.dash_requested = player.dash_requested or dash

@rpc("any_peer", "call_remote", "reliable")
func _server_create_room(private_room: bool = true) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	var user_id := str(_peer_users[peer_id])
	_server_remove_from_room(user_id)
	var code := _generate_room_code()
	_rooms[code] = _new_room(code, user_id, not private_room)
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
	if room.members.size() >= int(room.max_players) and not room.members.has(user_id):
		rpc_id(peer_id, "_client_room_error", "Room is full")
		return
	if not bool(room.is_public) and str(room.owner_uid) != user_id:
		var friends := await _server_are_friends(user_id, str(room.owner_uid), str(_tokens.get(user_id, "")))
		if not friends:
			rpc_id(peer_id, "_client_room_error", "Private rooms are for friends only")
			return
	_server_remove_from_room(user_id)
	_assign_user_to_room(user_id, peer_id, code)
	_broadcast_room_state(code)

@rpc("any_peer", "call_remote", "reliable")
func _server_quick_match() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _peer_users.has(peer_id):
		return
	_server_quick_match_for_peer(peer_id)

func _server_quick_match_for_peer(peer_id: int) -> void:
	var user_id := str(_peer_users.get(peer_id, ""))
	if user_id.is_empty():
		return
	_server_remove_from_room(user_id)
	var target := ""
	for code in _rooms.keys():
		var room: Dictionary = _rooms[code]
		if bool(room.is_public) and room.members.size() < int(room.max_players):
			target = str(code)
			break
	if target.is_empty():
		target = _generate_room_code()
		_rooms[target] = _new_room(target, user_id, true)
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
	if not await _server_are_friends(user_id, friend_user_id, str(_tokens.get(user_id, ""))):
		rpc_id(peer_id, "_client_room_error", "You can invite friends only")
		return
	var friend_peer := int(_user_peers[friend_user_id])
	rpc_id(friend_peer, "_client_room_invite", str(_profiles[user_id].get("display_name", "Friend")), room_code)

func _server_are_friends(user_id: String, other_id: String, token: String) -> bool:
	var low := user_id if user_id < other_id else other_id
	var high := other_id if user_id < other_id else user_id
	var url := SUPABASE_URL + "/rest/v1/friendships?select=user_a&user_a=eq." + low + "&user_b=eq." + high + "&limit=1"
	var result := await _http_json(HTTPClient.METHOD_GET, url, PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + token
	]))
	return result.get("ok", false) and result.get("data", []) is Array and not result.data.is_empty()

func _new_room(code: String, owner_uid: String, public_room: bool) -> Dictionary:
	var availability := {}
	var respawn := {}
	for i in range(ORB_POSITIONS.size()):
		availability[i] = true
		respawn[i] = 0
	return {
		"code": code, "owner_uid": owner_uid, "is_public": public_room,
		"max_players": ROOM_CAPACITY, "members": {}, "orb_available": availability,
		"orb_respawn": respawn, "event_id": "", "event_left": 0.0,
		"event_clock": EVENT_INTERVAL, "round_left": ROUND_SECONDS,
		"round_id": str(Time.get_unix_time_from_system()) + "-" + code,
		"round_finished": false,
		"persisted": {}
	}

func _assign_user_to_room(user_id: String, peer_id: int, code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	room.members[user_id] = peer_id
	_rooms[code] = room
	_user_rooms[user_id] = code
	_last_room_code = code
	if _server_players.has(peer_id):
		_server_players[peer_id].global_position = Vector3(0, 1.5, 6)
		_server_players[peer_id].velocity = Vector3.ZERO
		_server_players[peer_id].score = 0
		_server_players[peer_id].match_xp = 0
		_server_players[peer_id].collection_counts.clear()
		_server_players[peer_id].secret_404_found = false

func _server_remove_from_room(user_id: String) -> void:
	var old_code := str(_user_rooms.get(user_id, ""))
	if old_code.is_empty() or not _rooms.has(old_code):
		_user_rooms.erase(user_id)
		return
	var room: Dictionary = _rooms[old_code]
	var old_peer := int(room.members.get(user_id, 0))
	if old_peer > 0 and _server_players.has(old_peer):
		_persist_room_member_result(old_code, user_id, _server_players[old_peer])
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
		for orb_index in range(ORB_POSITIONS.size()):
			if not bool(room.orb_available[orb_index]) and now >= int(room.orb_respawn[orb_index]):
				room.orb_available[orb_index] = true
			if bool(room.orb_available[orb_index]):
				for uid in room.members.keys():
					var pid := int(room.members[uid])
					if pid <= 0 or not _server_players.has(pid):
						continue
					var player = _server_players[pid]
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
			for uid in room.members.keys():
				var finished_peer := int(room.members[uid])
				if finished_peer > 0 and _server_players.has(finished_peer):
					var finished_player = _server_players[finished_peer]
					finished_player.input_vector = Vector2.ZERO
					finished_player.velocity = Vector3.ZERO
					_persist_room_member_result(str(code), str(uid), finished_player)
		_rooms[code] = room
	if _snapshot_accumulator >= SNAPSHOT_INTERVAL:
		_snapshot_accumulator = 0.0
		for code in _rooms.keys():
			_broadcast_snapshot(str(code))
	if int(now / 1000) % 10 == 0:
		pass

func _collection_list(player) -> Array[String]:
	var result: Array[String] = []
	for collection_id in player.collection_counts.keys():
		var quantity := mini(512 - result.size(), int(player.collection_counts[collection_id]))
		for i in range(maxi(0, quantity)):
			result.append(str(collection_id))
	return result

func _persist_room_member_result(room_code: String, user_id: String, player) -> void:
	if not _rooms.has(room_code):
		return
	var room: Dictionary = _rooms[room_code]
	var persisted: Dictionary = room.get("persisted", {})
	if persisted.has(user_id):
		return
	persisted[user_id] = true
	room.persisted = persisted
	_rooms[room_code] = room
	_persist_user_result(user_id, player)

func _persist_user_result(user_id: String, player) -> void:
	if user_id.is_empty() or (player.score <= 0 and player.match_xp <= 0 and player.collection_counts.is_empty()):
		return
	var token := str(_tokens.get(user_id, ""))
	if token.is_empty():
		return
	if _server_secret.is_empty():
		push_warning("OXENWAR_SERVER_SECRET is not configured; match results remain server-side for this session.")
		return
	var payload := {
		"score": clampi(player.score, 0, 20000),
		"xp": clampi(player.match_xp, 0, 50000),
		"collections": _collection_list(player)
	}
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
		"x-oxenwar-server-secret: " + _server_secret
	])
	var result := await _http_json(HTTPClient.METHOD_POST, SUPABASE_URL + "/functions/v1/oxenwar-server-sync", headers, payload)
	if not result.get("ok", false):
		push_warning("OxenWar result sync failed with HTTP status %d" % int(result.get("status", 0)))

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
			"score": player.score, "xp": player.xp, "stamina": player.stamina
		}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id > 0:
			rpc_id(peer_id, "_client_receive_snapshot", states, str(room.event_id),
				float(room.event_left), float(room.round_left), room.orb_available, str(room.code))

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
			"online": peer_id > 0
		})
	var state := {"code": code, "is_public": bool(room.is_public), "members": roster, "max_players": int(room.max_players)}
	for user_id in room.members.keys():
		var peer_id := int(room.members[user_id])
		if peer_id > 0:
			rpc_id(peer_id, "_client_room_state", state)

func _color_for_profile(profile: Dictionary) -> String:
	var colors := {"color_cyan": "#27D7E7", "color_violet": "#9B70FF", "color_orange": "#FF9B42", "color_lime": "#A7E34B"}
	return str(colors.get(str(profile.get("avatar_color_id", "color_cyan")), "#27D7E7"))

@rpc("authority", "call_remote", "reliable")
func _client_auth_result(ok: bool, message: String, user_id: String = "", display_name: String = "", color_id: String = "") -> void:
	if multiplayer.is_server():
		return
	is_authenticated = ok
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
func _client_receive_snapshot(states: Dictionary, event_id: String, event_left: float, round_left: float, orb_available: Dictionary, room_code: String) -> void:
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
		"round_left": round_left, "orb_available": orb_available
	})

@rpc("authority", "call_remote", "reliable")
func _client_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		player_disconnected.emit(peer_id)

func _exit_tree() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
