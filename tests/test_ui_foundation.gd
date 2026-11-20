extends SceneTree
## UI foundation: every icon the game names exists, scale/target maths, controls behave.

const ICONS := preload("res://scripts/ui/ui_icons.gd")
const THEME := preload("res://scripts/ui/ui_theme.gd")
const PLATFORM := preload("res://scripts/ui/ui_platform.gd")
const SCALED_ROOT := preload("res://scripts/ui/scaled_root.gd")
const ICON_BUTTON := preload("res://scripts/ui/icon_button.gd")
const STAT_BAR := preload("res://scripts/ui/stat_bar.gd")
const HUD_PLATE := preload("res://scripts/ui/hud_plate.gd")

var _checks := 0
var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: ", message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Icons
	var missing: Array[String] = []
	# The weapon list lives in main.gd; read it from there so a new weapon without an icon fails here.
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var found := RegEx.create_from_string("const WEAPON_ORDER := \\[(.*?)\\]").search(source)
	_check(found != null, "found WEAPON_ORDER in main.gd")
	var weapon_ids: Array[String] = []
	if found != null:
		for id in found.get_string(1).split(","):
			weapon_ids.append(id.strip_edges().trim_prefix('"').trim_suffix('"'))
	_check(weapon_ids.size() >= 27, "read %d weapon ids" % weapon_ids.size())
	for weapon_id in weapon_ids:
		if not ICONS.has(ICONS.weapon_name(weapon_id)):
			missing.append(ICONS.weapon_name(weapon_id))
	_check(missing.is_empty(), "every weapon has an icon (missing: %s)" % str(missing))
	for name in ["grenade", "reload", "jump", "sprint", "slide", "dash", "interact", "emote", "settings", "inventory", "scoreboard", "arsenal", "lobby", "health", "stamina", "kill", "headshot", "assist", "damage", "hit", "timer", "e_duck_parade", "e_meteor_shower"]:
		_check(ICONS.has(name) and ICONS.texture(name) != null, "icon %s loads" % name)
	_check(ICONS.texture("no_such_icon") == null, "an unknown icon gives null, not a crash")
	_check(ICONS.all_names().size() >= 90, "the library lists %d icons" % ICONS.all_names().size())

	# Theme
	var theme := THEME.make_theme()
	_check(theme.default_font != null and theme.default_font_size == THEME.SIZE_M, "theme has a default font")
	_check(THEME.font("bold").get_string_size("Oxen").x > 10.0, "font measures text")
	_check(THEME.chamfer_points(Rect2(0, 0, 100, 40), 8.0).size() == 6, "plate outline has 6 corners")
	_check(THEME.rarity_color("Legendary") != THEME.rarity_color("Common"), "rarities have different colours")

	# Platform scaling
	_check(PLATFORM.ui_scale(false, 420.0, Vector2(2400, 1080)) == 1.0, "PC scale is 1")
	var phone := PLATFORM.ui_scale(true, 420.0, Vector2(2400, 1080))
	_check(phone >= 1.3 and phone <= 1.8, "reference phone scale %.2f is between 1.3 and 1.8" % phone)
	_check(PLATFORM.ui_scale(true, 0.0, Vector2(1280, 720)) == 1.4, "unknown density falls back to 1.4")
	var tablet := PLATFORM.ui_scale(true, 240.0, Vector2(2560, 1600))
	_check(tablet >= 1.0 and tablet <= phone + 0.001, "a tablet is scaled no more than a phone (%.2f)" % tablet)
	var target := PLATFORM.touch_target(44.0, true, 420.0, Vector2(2400, 1080))
	var inches := PLATFORM.inches_per_pixel(420.0, Vector2(2400, 1080)) * phone * target
	_check(inches >= 0.28, "a touch target on the reference phone is %.2f inch (at least 0.28)" % inches)
	_check(PLATFORM.touch_target(44.0, false, 96.0, Vector2(1920, 1080)) == 44.0, "PC target is the base size")

	# Controls
	var root := SCALED_ROOT.new()
	get_root().add_child(root)
	root.size = Vector2(2400, 1080)
	root.force_profile({"touch": true, "dpi": 420.0, "scale": 1.5, "target": 60.0})
	_check(is_equal_approx(root.content.size.x, 1600.0), "scaled content is 2400/1.5 wide (%.0f)" % root.content.size.x)
	var button := ICON_BUTTON.new()
	button.icon_name = "jump"
	button.caption = "Jump"
	button.size = Vector2(80, 80)
	root.content.add_child(button)
	var events: Array = []
	button.touch_pressed_changed.connect(func(v: bool): events.append(v))
	button.button_down.emit()
	_check(button.touch_down and events == [true], "touch_down follows button_down")
	button.release()
	_check(not button.touch_down and events == [true, false], "release() lets go")
	button.release()
	_check(events.size() == 2, "release() twice does not fire twice")
	button.cooldown = 2.0
	_check(button.cooldown == 1.0, "cooldown is clamped to 0..1")
	var bar := STAT_BAR.new()
	bar.size = Vector2(200, 26)
	root.content.add_child(bar)
	bar.set_value(100.0)
	bar.set_value(40.0)
	_check(is_equal_approx(bar.fraction(), 0.4), "bar fraction 0.4")
	_check(bar._trail > bar.value, "damage leaves a trail")
	for i in range(80):
		bar._process(0.05)
	_check(is_equal_approx(bar._trail, bar.value), "the trail drains")
	bar.set_value(900.0)
	_check(bar.value == bar.maximum, "value is clamped to the maximum")
	var plate := HUD_PLATE.new()
	plate.size = Vector2(120, 50)
	root.content.add_child(plate)
	await process_frame
	_check(plate.size.x == 120.0, "plate keeps its size")

	print("UI_FOUNDATION %s checks=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
