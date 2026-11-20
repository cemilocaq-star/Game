extends SceneTree

const MENU := preload("res://scripts/oxenwar_menu.gd")
class ScoreboardFixture extends "res://scripts/main.gd":
	var refreshes := 0
	func _ready() -> void:
		pass
	func _refresh_scoreboard() -> void:
		refreshes += 1

class ProfileFixture extends Node:
	var user_id := "fixture"
	var writes: Array[Dictionary] = []
	func update_profile(changes: Dictionary) -> Dictionary:
		writes.append(changes)
		await get_tree().process_frame
		return {"ok": true}
	func update_presence() -> Dictionary:
		return {"ok": true}

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var game := ScoreboardFixture.new()
	root.add_child(game)
	game.scoreboard_panel = Control.new()
	game.add_child(game.scoreboard_panel)
	game._update_player_match_stats("Same name", {"kills": 1})
	game._update_player_match_stats("Same name", {"kills": 2}, 17)
	check(game.match_stats.size() == 2 and game.match_stats[0].is_local and not game.match_stats[17].is_local, "same display name preserves separate stats and local highlight")
	await process_frame
	check(game.refreshes == 1, "one scoreboard rebuild for a batch of updates")
	game._on_remote_player_left(17)
	await process_frame
	check(game.match_stats.size() == 1 and game.refreshes == 2, "departure removes the correct row and refreshes once")
	game.free()

	var backend := ProfileFixture.new()
	root.add_child(backend)
	var menu := MENU.new()
	root.add_child(menu)
	menu.backend = backend
	menu.authenticated = true
	menu.locale = "en"
	menu.active_tab = "character"
	menu.profile = {"outfit_id": "outfit_default", "avatar_color_id": "color_cyan"}
	menu.cosmetics = {
		"catalog": [{"id": "color_violet", "slot": "avatar_color", "name_key": "cosmetic.color.violet"}],
		"inventory": [{"cosmetic_id": "color_violet"}],
	}
	menu._build()
	await process_frame
	var save := menu.find_child("SaveCosmeticsButton", true, false) as Button
	if save == null:
		check(false, "cosmetic save exists")
	else:
		save.pressed.emit()
		save.pressed.emit()
		check(backend.writes == [{"avatar_color_id": "color_violet"}], "save is serialized and does not overwrite unavailable slots")
		menu._render_tab()
		await process_frame
		await process_frame
		check(menu.profile.get("avatar_color_id") == "color_violet" and menu.profile.get("outfit_id") == "outfit_default", "successful save survives a tab rebuild")
	menu.free()
	backend.free()
	for child in root.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()
	await create_timer(0.15).timeout

	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("PASS: scoreboard identity and update batching, cosmetic save in flight during rebuild")
	quit(0 if failures.is_empty() else 1)
