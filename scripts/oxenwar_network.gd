extends Node
## ENet relay for shared OxenWar sessions.
## The server validates movement bounds and speed before relaying snapshots.
## It does not yet simulate collisions or authenticate Supabase JWTs.

signal player_state_received(peer_id: int, state: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_status_changed(message: String)

const PORT := 2456
const MAX_CLIENTS := 32
const SEND_INTERVAL_MS := 50
const MAX_SPEED := 24.0
const WORLD_LIMIT := 100.0

var is_dedicated_server := false
var local_player: Node3D
var local_player_name := "Player"
var local_player_color := Color("#27D7E7")
var _last_send_ms := 0
var _server_states: Dictionary = {}

func start_server() -> bool:
	is_dedicated_server = true
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		push_error("OxenWar server could not bind UDP port %d: %s" % [PORT, error_string(error)])
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("OxenWar ENet server listening on UDP %d (max %d players)" % [PORT, MAX_CLIENTS])
	return true

func connect_to_server(host: String) -> void:
	if host.strip_edges().is_empty():
		connection_status_changed.emit("Enter a server address.")
		return
	disconnect_from_server()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host.strip_edges(), PORT)
	if error != OK:
		connection_status_changed.emit("Could not start connection: " + error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	connection_status_changed.emit("Connecting to " + host.strip_edges() + ":" + str(PORT) + "...")

func set_local_player(player: Node3D, display_name: String, color: Color) -> void:
	local_player = player
	local_player_name = display_name.substr(0, 24)
	local_player_color = color

func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer != null and not is_dedicated_server:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _process(_delta: float) -> void:
	if is_dedicated_server or local_player == null or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var now := Time.get_ticks_msec()
	if now - _last_send_ms < SEND_INTERVAL_MS:
		return
	_last_send_ms = now
	rpc_id(1, "_server_receive_state", local_player.global_position, local_player.rotation.y, local_player_name, local_player_color.to_html(false))

func _on_connected_to_server() -> void:
	connection_status_changed.emit("Connected • waiting for players")

func _on_connection_failed() -> void:
	connection_status_changed.emit("Connection failed. Check address and UDP port 2456.")

func _on_server_disconnected() -> void:
	for peer_id in _server_states.keys():
		player_disconnected.emit(int(peer_id))
	_server_states.clear()
	connection_status_changed.emit("Server disconnected")

func _on_peer_connected(peer_id: int) -> void:
	print("OxenWar peer connected: ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_server_states.erase(peer_id)
	for other_peer in multiplayer.get_peers():
		rpc_id(other_peer, "_client_peer_left", peer_id)
	print("OxenWar peer disconnected: ", peer_id)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _server_receive_state(position: Vector3, yaw: float, display_name: String, color_html: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or absf(position.x) > WORLD_LIMIT or absf(position.z) > WORLD_LIMIT or position.y < -30.0 or position.y > 80.0:
		return
	var now := Time.get_ticks_msec()
	var previous: Dictionary = _server_states.get(sender, {})
	if not previous.is_empty():
		var elapsed := maxf(0.05, float(now - int(previous.get("tick", now))) / 1000.0)
		var old_position: Vector3 = previous.get("position", position)
		if old_position.distance_to(position) > 2.5 + MAX_SPEED * elapsed:
			return
	var safe_name := display_name.strip_edges().substr(0, 24)
	if safe_name.is_empty():
		safe_name = "Player " + str(sender)
	var safe_color := Color.from_string(color_html, Color("#27D7E7"))
	var state := {
		"position": position,
		"yaw": wrapf(yaw, -PI, PI),
		"display_name": safe_name,
		"color": safe_color.to_html(false),
		"tick": now
	}
	var is_new := previous.is_empty()
	_server_states[sender] = state
	if is_new:
		for peer_id in multiplayer.get_peers():
			if peer_id == sender:
				continue
			var existing: Dictionary = _server_states.get(peer_id, {})
			if not existing.is_empty():
				rpc_id(sender, "_client_receive_state", peer_id, existing.position, existing.yaw, existing.display_name, existing.color)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender:
			rpc_id(peer_id, "_client_receive_state", sender, position, state.yaw, safe_name, state.color)

@rpc("authority", "call_remote", "unreliable_ordered")
func _client_receive_state(peer_id: int, position: Vector3, yaw: float, display_name: String, color_html: String) -> void:
	if multiplayer.is_server():
		return
	player_state_received.emit(peer_id, {
		"position": position,
		"yaw": yaw,
		"display_name": display_name,
		"color": color_html
	})

@rpc("authority", "call_remote", "reliable")
func _client_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		player_disconnected.emit(peer_id)

func _exit_tree() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
