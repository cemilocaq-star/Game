extends RefCounted
class_name UserSettings
## Small persisted settings store shared by the pause menu, graphics and input code.
## Everything lives in the same ConfigFile as GraphicsManager so a write never discards
## another section: values are always loaded first, changed, then saved.

const PATH := "user://game_settings.cfg"
const DEFAULT_LOOK_SENSITIVITY := 0.0022
const MIN_LOOK_SENSITIVITY := 0.0008
const MAX_LOOK_SENSITIVITY := 0.0060

static func read_value(section: String, key: String, fallback: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	return config.get_value(section, key, fallback)

static func write_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	# A missing/corrupt file is fine: we simply start a fresh one.
	config.load(PATH)
	config.set_value(section, key, value)
	config.save(PATH)

static func look_sensitivity() -> float:
	return clampf(float(read_value("input", "look_sensitivity", DEFAULT_LOOK_SENSITIVITY)), MIN_LOOK_SENSITIVITY, MAX_LOOK_SENSITIVITY)

static func master_volume() -> float:
	return clampf(float(read_value("audio", "master_volume", 1.0)), 0.0, 1.0)

## Applies the master volume to the default audio bus (linear 0..1).
static func apply_master_volume(linear: float) -> void:
	var value := clampf(linear, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.001)))
