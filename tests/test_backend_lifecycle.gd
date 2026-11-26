extends SceneTree

class FixtureBackend extends "res://scripts/oxenwar_supabase.gd":
	var calls := 0
	var response := {"ok": false, "status": 503}
	func _request(_method: int, _path: String, _payload: Variant = null, _authenticated: bool = false, _extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return response.duplicate()
	func _accept_auth_response(data: Dictionary) -> void:
		access_token = str(data.access_token)
		refresh_token = str(data.refresh_token)

class FixtureNetwork extends "res://scripts/oxenwar_network.gd":
	var saves := 0
	func _persist_user_result(_user_id: String, _player) -> bool:
		saves += 1
		await get_tree().process_frame
		return true

var failures: Array[String] = []
var refresh_results: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func collect_refresh(backend: Node) -> void:
	refresh_results.append(await backend.refresh_session())

func run() -> void:
	var backend := FixtureBackend.new()
	root.add_child(backend)
	backend.refresh_token = "original"
	backend.access_token = "expired"
	collect_refresh(backend)
	collect_refresh(backend)
	await process_frame
	await process_frame
	check(backend.calls == 1 and refresh_results.size() == 2, "parallel callers share one refresh request")
	check(backend.refresh_token == "original", "transient HTTP failure preserves the refresh token")
	backend.response = {"ok": true, "data": {"access_token": "renewed", "refresh_token": "rotated"}}
	var result := await backend.refresh_session()
	check(result.ok and backend.refresh_token == "rotated", "retry accepts rotated session")
	collect_refresh(backend)
	backend.refresh_token = "different"
	await process_frame
	await process_frame
	check(backend.refresh_token == "different" and not refresh_results.back().ok, "a stale response cannot replace a newer session")
	backend.free()

	var net := FixtureNetwork.new()
	root.add_child(net)
	net._rooms["SAVE"] = net._new_room("SAVE", "user", true)
	net._persist_room_member_result("SAVE", "user", null)
	net._persist_room_member_result("SAVE", "user", null)
	await process_frame
	await process_frame
	check(net.saves == 1 and net._rooms["SAVE"].persisted.has("user"), "one in-flight result write per room member")
	net.free()
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("PASS: shared refresh, retry, stale session guard, and one in-flight result write")
	quit(0 if failures.is_empty() else 1)
