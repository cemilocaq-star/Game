extends Node
class_name ProgressionManager

signal xp_changed(current_xp: int, required_xp: int, current_level: int)
signal level_up(new_level: int, reward: String)

const SAVE_PATH := "user://progression.cfg"
var level := 1
var xp := 0
var total_xp := 0
var best_score := 0
var secret_404_found := false
var unlocked_rewards: Array[String] = []

func _ready() -> void:
	_load_progress()

func xp_for_next_level() -> int:
	return 100 + (level - 1) * 50

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	total_xp += amount
	while xp >= xp_for_next_level():
		xp -= xp_for_next_level()
		level += 1
		var reward := _reward_for_level(level)
		if not reward.is_empty() and not unlocked_rewards.has(reward):
			unlocked_rewards.append(reward)
		level_up.emit(level, reward if not reward.is_empty() else "NEW LEVEL")
	_save_progress()
	xp_changed.emit(xp, xp_for_next_level(), level)

func _reward_for_level(value: int) -> String:
	match value:
		3:
			return "MEME TRAIL"
		5:
			return "NEON AURA"
		10:
			return "PARKOUR LEGEND TITLE"
		20:
			return "COSMIC CHAMPION TITLE"
		_:
			return ""

func discover_secret() -> bool:
	if secret_404_found:
		return false
	secret_404_found = true
	add_xp(100)
	_save_progress()
	return true

func record_score(value: int) -> void:
	if value > best_score:
		best_score = value
	_save_progress()

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	level = maxi(1, int(config.get_value("progress", "level", 1)))
	xp = maxi(0, int(config.get_value("progress", "xp", 0)))
	total_xp = maxi(0, int(config.get_value("progress", "total_xp", 0)))
	best_score = maxi(0, int(config.get_value("progress", "best_score", 0)))
	secret_404_found = bool(config.get_value("secrets", "secret_404_found", false))
	var saved_rewards: Variant = config.get_value("progress", "unlocked_rewards", [])
	for item in saved_rewards:
		unlocked_rewards.append(str(item))

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "level", level)
	config.set_value("progress", "xp", xp)
	config.set_value("progress", "total_xp", total_xp)
	config.set_value("progress", "best_score", best_score)
	config.set_value("progress", "unlocked_rewards", unlocked_rewards)
	config.set_value("secrets", "secret_404_found", secret_404_found)
	config.save(SAVE_PATH)
