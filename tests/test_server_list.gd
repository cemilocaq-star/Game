extends SceneTree

const SERVER_LIST := preload("res://scripts/server_list.gd")

func _init() -> void:
	var failures: Array[String] = []
	var ok := SERVER_LIST.parse('{"servers": ["wss://oxenwar-game-server.onrender.com", "10.0.0.5:2456", "play.example.com"]}')
	if ok.size() != 3: failures.append("valid addresses kept, got %d" % ok.size())
	var bad := SERVER_LIST.parse('{"servers": ["javascript:alert(1)", "a b", "wss://x", "http://evil.com", "host/path", 5, "ok.example.com", "ok.example.com"]}')
	if bad != PackedStringArray(["ok.example.com"]): failures.append("bad addresses rejected and deduplicated: " + str(bad))
	if not SERVER_LIST.parse("not json").is_empty(): failures.append("garbage ignored")
	if not SERVER_LIST.parse('{"servers": "x"}').is_empty(): failures.append("wrong type ignored")
	var shipped := SERVER_LIST.parse(FileAccess.get_file_as_string("res://servers.json"))
	if shipped.is_empty(): failures.append("shipped servers.json has a valid server")
	if failures.is_empty():
		print("PASS: server list parsing accepts valid addresses, rejects malformed ones, and the shipped servers.json is valid")
		quit(0)
	else:
		for f in failures: push_error(f)
		quit(1)
