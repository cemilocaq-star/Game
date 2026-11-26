extends RefCounted
## Finds OxenWar servers on the local network with no typed address.
##
## An "open" server (OxenWar --server --open) runs a Responder on UDP DISCOVERY_PORT. A client sends one
## broadcast query and every server that hears it answers with a small JSON note: the ENet port, how many
## players are connected and which room codes it hosts. Joining by room code then only needs the code:
## the server whose reply lists that code is the one to connect to.

const PORT := 2457
const QUERY := "OXENWAR_DISCOVER_V1"
const MAGIC := "oxenwar"


## Server side: answers discovery queries. Call poll() every frame with the current server facts.
class Responder extends RefCounted:
	var running := false
	var _udp := PacketPeerUDP.new()

	func start(port: int = PORT) -> Error:
		var error := _udp.bind(port)
		running = error == OK
		return error

	## `info` is copied into every reply, for example {"port": 2456, "players": 3, "max": 32, "rooms": ["AB23CD"]}.
	func poll(info: Dictionary) -> int:
		var answered := 0
		while running and _udp.get_available_packet_count() > 0:
			var packet := _udp.get_packet()
			var from_ip := _udp.get_packet_ip()
			var from_port := _udp.get_packet_port()
			if packet.get_string_from_utf8() != QUERY:
				continue
			var reply := info.duplicate()
			reply["g"] = MAGIC
			_udp.set_dest_address(from_ip, from_port)
			_udp.put_packet(JSON.stringify(reply).to_utf8_buffer())
			answered += 1
		return answered

	func stop() -> void:
		_udp.close()
		running = false


## Addresses a query is sent to: the limited broadcast, this device (a server started on the same PC) and
## the /24 broadcast of every private IPv4 address of this device (some phones drop 255.255.255.255).
static func query_targets(extra: Array = []) -> Array:
	var targets: Array = ["255.255.255.255", "127.0.0.1"]
	for address in IP.get_local_addresses():
		var parts := str(address).split(".")
		if parts.size() != 4:
			continue
		var first := int(parts[0])
		var second := int(parts[1])
		var is_private := first == 10 or (first == 192 and second == 168) or (first == 172 and second >= 16 and second <= 31)
		if is_private:
			var subnet := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if not targets.has(subnet):
				targets.append(subnet)
	for item in extra:
		if not targets.has(str(item)):
			targets.append(str(item))
	return targets


## Sends one query and collects replies for `timeout` seconds. Returns an Array of Dictionaries:
## {host, port, players, max, rooms}. Ends early when `want_code` is listed by a server that answered.
static func scan(tree: SceneTree, timeout: float = 1.2, port: int = PORT, want_code: String = "", extra_targets: Array = []) -> Array:
	var found: Array = []
	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	if udp.bind(0) != OK:
		return found
	var packet := QUERY.to_utf8_buffer()
	for target in query_targets(extra_targets):
		udp.set_dest_address(str(target), port)
		udp.put_packet(packet)
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	var wanted := want_code.strip_edges().to_upper()
	while Time.get_ticks_msec() < end:
		await tree.create_timer(0.05).timeout
		while udp.get_available_packet_count() > 0:
			var raw := udp.get_packet().get_string_from_utf8()
			var host := udp.get_packet_ip()
			var parsed: Variant = JSON.parse_string(raw)
			if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("g", "")) != MAGIC:
				continue
			var server_port := int(parsed.get("port", 2456))
			var duplicate := false
			for existing in found:
				if str(existing.host) == host and int(existing.port) == server_port:
					duplicate = true
			if duplicate:
				continue
			var rooms: Array = []
			for code in parsed.get("rooms", []):
				rooms.append(str(code).to_upper())
			found.append({
				"host": host, "port": server_port,
				"players": int(parsed.get("players", 0)), "max": int(parsed.get("max", 0)),
				"rooms": rooms
			})
		if not wanted.is_empty() and not find_room(found, wanted).is_empty():
			break
	udp.close()
	return found


## The server in `servers` that hosts room `code`, or {}.
static func find_room(servers: Array, code: String) -> Dictionary:
	var wanted := code.strip_edges().to_upper()
	for server in servers:
		if (server.rooms as Array).has(wanted):
			return server
	return {}


## The fullest server that still has room, otherwise any server, otherwise {}.
static func best_server(servers: Array) -> Dictionary:
	var best: Dictionary = {}
	for server in servers:
		var has_room := int(server.max) <= 0 or int(server.players) < int(server.max)
		if best.is_empty():
			best = server
			continue
		var best_has_room := int(best.max) <= 0 or int(best.players) < int(best.max)
		if has_room and (not best_has_room or int(server.players) > int(best.players)):
			best = server
	return best


## "host" for the default ENet port, "host:port" for another one.
static func address_of(server: Dictionary) -> String:
	if int(server.get("port", 2456)) == 2456:
		return str(server.host)
	return "%s:%d" % [server.host, int(server.port)]
