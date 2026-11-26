extends SceneTree

const MAIN := preload("res://scripts/main.gd")
const CHARACTER := preload("res://scripts/character_visuals.gd")
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const MAP := preload("res://scripts/map_world_builder.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	for index in range(7):
		var visual := MAP.build(host, index)
		var collision := MAP.build(host, index, false)
		var node_name: String = MAP.LANDMARKS[index][1]
		var landmark := visual.get_node_or_null(node_name)
		_check(landmark != null and not landmark.find_children("*", "MeshInstance3D", true, false).is_empty(), "map landmark %s" % node_name)
		_check(not collision.has_node(node_name), "landmark absent on server %s" % node_name)
		visual.free()
		collision.free()
	var pilot := CHARACTER.build(host, "outfit_runner", Color.WHITE)
	var riot := CHARACTER.build(host, "outfit_neon", Color.WHITE)
	for piece in [pilot.get_node("PilotScarfTailMesh"), riot.get_node("RiotShield")]:
		_check(not piece.find_children("*", "MeshInstance3D", true, false).is_empty(), "imported costume part")
	var game := MAIN.new()
	var ui := Control.new()
	host.add_child(ui)
	game.call("_build_arsenal_panel", ui)
	game.call("_preview_arsenal_weapon", "ranger_rifle")
	var preview: Control = game.get("_arsenal_preview")
	_check(preview.find_child("ArcadeWeapon_ranger_rifle", true, false) != null, "Ranger model in arsenal")
	game.call("_preview_arsenal_weapon", "longshot")
	_check(preview.find_child("ArcadeWeapon_ranger_rifle", true, false) == null, "previous preview released")
	_check(preview.find_child("ArcadeWeapon_longshot", true, false) != null, "Longshot model in arsenal")
	var remote := REMOTE.new()
	host.add_child(remote)
	var avatar: Node3D = remote.get("_visual")
	remote.apply_network_state(Vector3.ZERO, 0.0, false, 0.0, true)
	remote.call("_process", 0.15)
	_check(avatar.visible and avatar.rotation.x < -0.05, "K.O. animation starts while visible")
	remote.call("_process", 0.30)
	_check(not avatar.visible, "K.O. animation hides finished model")
	remote.apply_network_state(Vector3.ZERO, 0.0)
	_check(avatar.visible and avatar.rotation == Vector3.ZERO, "respawn resets pose")
	game.free()
	host.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: all seven map landmarks, imported costume parts, shared arsenal models and K.O. transitions")
	quit(0 if failures.is_empty() else 1)
