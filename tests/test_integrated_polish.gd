extends SceneTree
const NET := preload("res://scripts/oxenwar_network.gd")
const BODY := preload("res://scripts/oxenwar_server_player.gd")
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const WEAPONS := preload("res://scripts/arcade_weapon_visuals.gd")
const VIEW := preload("res://scripts/weapon_viewmodel_anim.gd")
const SETTINGS := preload("res://scripts/user_settings.gd")
const BUSES := preload("res://scripts/audio_buses.gd")
const SCALED := preload("res://scripts/ui/scaled_root.gd")
const PAUSE := preload("res://scripts/pause_menu.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var net := NET.new()
	root.add_child(net)
	var body := BODY.new()
	root.add_child(body)
	net._server_players[0] = body
	net._peer_users[0] = "fixture"
	net._user_rooms["fixture"] = "TEST"
	net._rooms["TEST"] = net._new_room("TEST", "fixture", true, "ffa")
	for weapon: String in NET.ARCADE_WEAPONS:
		body.equipped_weapon_id = weapon
		body.reload_until_ms = 0
		var now := Time.get_ticks_msec()
		net._server_reload_weapon(weapon)
		var expected := VIEW.reload_duration(float(NET.ARCADE_WEAPONS[weapon].cooldown_ms) / 1000.0)
		check(absf(float(body.reload_until_ms - now) / 1000.0 - expected) < 0.1, weapon + " server duration matches local animation")
		var until: int = body.reload_until_ms
		net._server_reload_weapon(weapon)
		check(body.reload_until_ms == until, weapon + " duplicate reload cannot restart timer")
		var shots: int = body.shots_fired
		net._server_blaster_fire(weapon, Vector3.FORWARD)
		check(body.shots_fired == shots, weapon + " server rejects firing while reloading")
	body.respawn_at(Vector3.ZERO)
	check(body.reload_until_ms == 0, "respawn clears server reload")
	var remote := REMOTE.new()
	root.add_child(remote)
	remote.sync_weapon("ranger_rifle", true)
	remote.sync_reload(1.0)
	remote._process(0.1)
	check(remote._reload_left > 0.0, "remote reload progresses")
	remote.apply_network_state(Vector3.ZERO, 0.0, false, 0.0, true)
	check(remote._reload_left == 0.0, "death resets remote reload")
	for id: String in ["ranger_rifle", "heavy_sidearm", "longshot", "hand_cannon", "pulse_carbine", "aether"]:
		var model := WEAPONS.build_weapon(id, Color.CYAN)
		check(model.get_node_or_null("AuthoredBody") != null, id + " uses imported authored body")
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var uv_meshes := 0
		for mesh: MeshInstance3D in meshes:
			if mesh.mesh is ArrayMesh:
				var arrays := mesh.mesh.surface_get_arrays(0)
				if arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() > 0: uv_meshes += 1
		check(uv_meshes > 0, id + " imported geometry has UV coordinates")
		model.free()
	BUSES.ensure()
	for bus: String in [BUSES.WEAPONS, BUSES.FOOTSTEPS]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == BUSES.SFX, bus + " passes through shared room reverb")
		SETTINGS.apply_bus_volume(bus, 0.0)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " independently mutes")
		SETTINGS.apply_bus_volume(bus, 1.0)
	var menu := PAUSE.new()
	root.add_child(menu)
	for bus: String in BUSES.ALL:
		check(menu.find_child("Slider_volume_" + bus.to_lower(), true, false) != null, bus + " has settings control")
	var ui := SCALED.new()
	root.add_child(ui)
	ui.size = Vector2(1280,720)
	ui.force_profile({"touch":true,"scale":1.5,"target":60.0,"safe_rect":Rect2(80,20,1120,680)})
	check(ui.content.position == Vector2(80,20), "safe-area origin applied")
	check(ui.content.size.is_equal_approx(Vector2(1120,680) / 1.5), "notch inset and logical scaling agree")
	menu.free();ui.free();remote.free()
	net._server_players.clear();net.free();body.free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: 27 server reloads, remote death reset, imported UV geometry, audio mixing and notched layout")
	quit(0 if failures.is_empty() else 1)
