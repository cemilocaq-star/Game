extends SceneTree
## Real ENet transport; only ticket redemption and persistence use test fixtures.
const NET := preload("res://tests/online/network_under_test.gd")
const STUB := preload("res://tests/online/stub_player.gd")
var net
var body
var role := ""
var room: Dictionary = {}
var others: Dictionary = {}
var samples := 0
var moved := false
var start := Vector3.ZERO
var got_start := false
var saw_reload := false
var saw_remote_reload := false
var seen_rooms: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	for action in ["move_left","move_right","move_forward","move_back","jump","sprint","slide","dash"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	net = NET.new()
	net.name = "OxenWarNetwork"
	root.add_child(net)
	body = STUB.new()
	root.add_child(body)
	net.set_local_player(body, "Capacity" + role, Color.CYAN)
	net.room_state_changed.connect(func(value: Dictionary):
		room = value
		if not str(value.get("code", "")).is_empty(): seen_rooms[str(value.code)] = true)
	net.player_state_received.connect(func(peer: int, state: Dictionary):
		others[peer] = state
		if float(state.get("reload_left", 0.0)) > 0.0: saw_remote_reload = true)
	net.local_state_received.connect(func(state: Dictionary):
		samples += 1
		if float(state.get("reload_left", 0.0)) > 0.0: saw_reload = true
		if not got_start:
			start = state.position
			got_start = true
		elif Vector2(state.position.x - start.x, state.position.z - start.z).length() > 0.15: moved = true)
	net._last_host = "127.0.0.1"
	net._game_ticket = "TESTTICKET-capacity%s-%s" % [role,"x".repeat(40)]
	net._connect_now()
	var deadline := Time.get_ticks_msec() + 12000
	while not net.is_authenticated and Time.get_ticks_msec() < deadline: await process_frame
	if net.is_authenticated: net.request_quick_match("ffa", 4)
	# Keep all clients connected for the same window, collect stable membership.
	await create_timer(5.0).timeout
	net.request_reload("aether")
	Input.action_press("move_right")
	await create_timer(0.8).timeout
	Input.action_release("move_right")
	await create_timer(1.0).timeout
	var result := {"role":role,"authenticated":net.is_authenticated,"room":room,"others":others.size(),"snapshots":samples,"moved":moved,"reload":saw_reload,"remote_reload":saw_remote_reload,"room_count":seen_rooms.size()}
	var f := FileAccess.open(OS.get_environment("OXENWAR_CAPACITY_DIR").path_join(role + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	print("CAPACITY_RESULT " + JSON.stringify(result))
	# Parent orchestrator terminates all processes after collecting all nine reports.
	await create_timer(35.0).timeout
	quit()
