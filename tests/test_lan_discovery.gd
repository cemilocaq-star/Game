extends SceneTree
## LAN discovery: a Responder answers a broadcast query with its port, player count and room codes; the scan
## finds it, finds a server by room code, and picks the best server. Real UDP sockets on this machine.

const LAN := preload("res://scripts/lan_discovery.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)


func _run() -> void:
	var test_port := 24571
	var responder := LAN.Responder.new()
	_check(responder.start(test_port) == OK, "responder binds its UDP port")
	var info := {"port": 2456, "players": 2, "max": 32, "rooms": ["AB23CD", "ZZ99XY"]}
	process_frame.connect(func(): responder.poll(info))

	var targets: Array = LAN.query_targets()
	_check(targets.has("255.255.255.255") and targets.has("127.0.0.1"), "queries go to the broadcast address and to this device")

	var servers: Array = await LAN.scan(self, 1.5, test_port)
	_check(servers.size() >= 1, "scan finds the server (found %d)" % servers.size())
	if servers.size() >= 1:
		var first: Dictionary = servers[0]
		_check(int(first.port) == 2456 and int(first.players) == 2 and int(first.max) == 32, "reply carries port and player counts")
		_check((first.rooms as Array).has("AB23CD"), "reply lists the room codes")
	var by_code: Dictionary = LAN.find_room(servers, "zz99xy")
	_check(not by_code.is_empty(), "a server is found by room code (case-insensitive)")
	_check(LAN.find_room(servers, "NOPE22").is_empty(), "an unknown room code finds nothing")
	var started := Time.get_ticks_msec()
	var early: Array = await LAN.scan(self, 5.0, test_port, "AB23CD")
	_check(not early.is_empty() and Time.get_ticks_msec() - started < 3000, "scan ends early once the wanted room is found")

	# A port nobody listens on: nothing is found and the scan still returns.
	var none: Array = await LAN.scan(self, 0.4, test_port + 1)
	_check(none.is_empty(), "no server, no result")

	var fake: Array = [
		{"host": "10.0.0.2", "port": 2456, "players": 5, "max": 32, "rooms": []},
		{"host": "10.0.0.3", "port": 2456, "players": 31, "max": 32, "rooms": ["QQ22WW"]},
		{"host": "10.0.0.4", "port": 3000, "players": 32, "max": 32, "rooms": []},
	]
	_check(str(LAN.best_server(fake).host) == "10.0.0.3", "best server is the fullest one that still has room")
	_check(LAN.best_server([]).is_empty(), "no servers, no best server")
	_check(LAN.address_of(fake[0]) == "10.0.0.2" and LAN.address_of(fake[2]) == "10.0.0.4:3000", "address includes a non-default port")
	_check(str(LAN.find_room(fake, "QQ22WW").host) == "10.0.0.3", "room code maps to its server")

	responder.stop()
	if failures.is_empty():
		print("PASS: LAN discovery responder, scan, room lookup and best server")
		quit(0)
	else:
		quit(1)
