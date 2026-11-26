extends RefCounted
## Builds the in-game HUD into a ScaledRoot's content and returns every widget the game updates.
## main.gd keeps the game logic and connects the handlers; this file is only layout and look.
##
## Layout (logical pixels, anchors keep it right on any aspect ratio):
##   top left      score, level and XP
##   top centre    round clock, event chip, objective, kill streak
##   top right     system icons (scoreboard, arsenal, lobby, menu, admin) and the kill feed under them
##   bottom left   health, stamina, team (PC). On touch these move under the score, because the
##                 movement stick lives at the bottom left.
##   bottom centre weapon card: icon, name, role, mastery, grenade chip with its cooldown

const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")
const PLATE := preload("res://scripts/ui/hud_plate.gd")
const BUTTON := preload("res://scripts/ui/icon_button.gd")
const BAR := preload("res://scripts/ui/stat_bar.gd")


static func label(parent: Control, text: String, size: int, color: Color = THEME.INK, weight: String = "semibold", align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = align as HorizontalAlignment
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", THEME.font(weight))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	result.add_theme_constant_override("outline_size", 3)
	parent.add_child(result)
	return result


## Anchors `control` to a corner/edge point of its parent and gives it an exact box.
## (ax, ay) is the anchor (0..1); `left`/`top` are offsets from it.
static func place(control: Control, ax: float, ay: float, left: float, top: float, width: float, height: float) -> void:
	control.anchor_left = ax
	control.anchor_right = ax
	control.anchor_top = ay
	control.anchor_bottom = ay
	control.offset_left = left
	control.offset_top = top
	control.offset_right = left + width
	control.offset_bottom = top + height


static func plate(parent: Control, plate_name: String, ax: float, ay: float, left: float, top: float, width: float, height: float, accent: Color = THEME.ACCENT) -> Control:
	var result: Control = PLATE.new()
	result.name = plate_name
	result.accent = accent
	place(result, ax, ay, left, top, width, height)
	parent.add_child(result)
	return result


static func button(parent: Control, button_name: String, icon: String, caption: String, key: String, tint: Color, box: Vector2) -> Button:
	var result: Button = BUTTON.new()
	result.name = button_name
	result.icon_name = icon
	result.caption = caption
	result.key_hint = key
	result.tint = tint
	result.custom_minimum_size = box
	result.size = box
	parent.add_child(result)
	return result


## `touch` is true on a phone or tablet; `target` is the smallest comfortable touch size in logical px.
static func build(root: Control, touch: bool, target: float, options: Dictionary) -> Dictionary:
	var w: Dictionary = {}
	var side := maxf(target, 44.0) if touch else 44.0

	# --- top left: score and level ---------------------------------------------------------------
	var score_plate := plate(root, "ScorePlate", 0.0, 0.0, 12.0, 8.0, 236.0, 78.0, THEME.ACCENT)
	var score_icon := ICONS.make("trophy", 26.0, THEME.WARM)
	score_icon.position = Vector2(14.0, 8.0)
	score_plate.add_child(score_icon)
	w.score_label = label(score_plate, "SCORE 0000", THEME.SIZE_L, THEME.INK, "bold")
	w.score_label.position = Vector2(46.0, 2.0)
	w.level_label = label(score_plate, "LEVEL 1", THEME.SIZE_S, THEME.MUTED)
	w.level_label.position = Vector2(14.0, 36.0)
	w.xp_bar = BAR.new()
	w.xp_bar.icon_name = "xp"
	w.xp_bar.bar_color = THEME.XP
	w.xp_bar.show_number = false
	w.xp_bar.segments = 8
	w.xp_bar.low_fraction = -1.0
	w.xp_bar.maximum = 100.0
	w.xp_bar.trail_enabled = false
	w.xp_bar.value = 0.0
	w.xp_bar._trail = 0.0
	w.xp_bar.position = Vector2(14.0, 54.0)
	w.xp_bar.size = Vector2(208.0, 18.0)
	score_plate.add_child(w.xp_bar)

	# --- vitals ---------------------------------------------------------------------------------
	var vitals_height := 104.0
	var vitals: Control
	if touch:
		vitals = plate(root, "VitalsPanel", 0.0, 0.0, 12.0, 92.0, 236.0, vitals_height, THEME.OK)
	else:
		vitals = plate(root, "VitalsPanel", 0.0, 1.0, 12.0, -(vitals_height + 12.0), 300.0, vitals_height, THEME.OK)
	var bar_width := vitals.size.x - 28.0
	w.health_bar = BAR.new()
	w.health_bar.icon_name = "health"
	w.health_bar.bar_color = THEME.OK
	w.health_bar.position = Vector2(14.0, 8.0)
	w.health_bar.size = Vector2(bar_width, 30.0)
	vitals.add_child(w.health_bar)
	w.stamina_bar = BAR.new()
	w.stamina_bar.icon_name = "stamina"
	w.stamina_bar.bar_color = THEME.WARM
	w.stamina_bar.low_fraction = -1.0
	w.stamina_bar.segments = 8
	w.stamina_bar.position = Vector2(14.0, 44.0)
	w.stamina_bar.size = Vector2(bar_width, 24.0)
	vitals.add_child(w.stamina_bar)
	var team_icon := ICONS.make("team", 18.0, THEME.MUTED)
	team_icon.position = Vector2(14.0, 76.0)
	vitals.add_child(team_icon)
	w.team_label = label(vitals, "TEAM FREE", THEME.SIZE_XS, THEME.MUTED, "bold")
	w.team_label.position = Vector2(36.0, 74.0)
	w.collectibles_label = label(vitals, "ORBS 0  •  404 HIDDEN", THEME.SIZE_XS, THEME.WARM, "bold", HORIZONTAL_ALIGNMENT_RIGHT)
	w.collectibles_label.position = Vector2(vitals.size.x - 174.0, 74.0)
	w.collectibles_label.size = Vector2(160.0, 18.0)

	# --- top centre: clock, event chip, objective, streak -----------------------------------------
	var clock := plate(root, "RoundPlate", 0.5, 0.0, -170.0, 8.0, 340.0, 70.0, THEME.ACCENT)
	var timer_icon := ICONS.make("timer", 24.0, THEME.ACCENT)
	timer_icon.position = Vector2(14.0, 8.0)
	clock.add_child(timer_icon)
	w.round_label = label(clock, "05:00", THEME.SIZE_XL, THEME.INK, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	w.round_label.position = Vector2(0.0, -4.0)
	w.round_label.size = Vector2(clock.size.x, 40.0)
	w.event_icon = ICONS.make("e_golden_orb_rush", 22.0, THEME.WARM)
	w.event_icon.position = Vector2(14.0, 42.0)
	clock.add_child(w.event_icon)
	w.event_label = label(clock, "COLLECT THE ORBS", THEME.SIZE_S, THEME.INK, "bold")
	w.event_label.position = Vector2(44.0, 41.0)
	w.event_label.size = Vector2(clock.size.x - 58.0, 22.0)
	w.event_label.clip_text = true
	w.event_plate = clock
	w.status_label = label(root, "PARKOUR ARENA", THEME.SIZE_XS, THEME.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	place(w.status_label, 0.5, 0.0, -170.0, 82.0, 340.0, 16.0)
	w.objective_label = label(root, "HILL NEUTRAL", THEME.SIZE_M, THEME.WARM, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	place(w.objective_label, 0.5, 0.0, -300.0, 100.0, 600.0, 24.0)
	w.objective_label.visible = false
	w.killstreak_label = label(root, "", THEME.SIZE_L, THEME.WARM, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	place(w.killstreak_label, 0.5, 0.0, -300.0, 128.0, 600.0, 32.0)
	w.killstreak_label.visible = false

	# --- top right: system icons + kill feed ------------------------------------------------------
	var system_keys := [
		["ScoreboardButton", "scoreboard", "Scores", "TAB", THEME.ACCENT],
		["ArsenalButton", "arsenal", "Arsenal", "V", THEME.ACCENT],
		["LobbyButton", "lobby", "Lobby", "", THEME.ACCENT],
		["PauseMenuButton", "menu", "Menu", "ESC", THEME.ACCENT],
	]
	if bool(options.get("admin", false)):
		system_keys.append(["AdminButton", "admin", "Admin", "F8", THEME.WARM])
	var box := Vector2(side + 14.0, side + 8.0)
	var gap := 6.0
	var total := system_keys.size() * box.x + (system_keys.size() - 1) * gap
	var system_bar := Control.new()
	system_bar.name = "SystemBar"
	system_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(system_bar, 1.0, 0.0, -(total + 12.0), 8.0, total, box.y)
	root.add_child(system_bar)
	var index := 0
	for spec in system_keys:
		var system_button := button(system_bar, str(spec[0]), str(spec[1]), str(spec[2]), "" if touch else str(spec[3]), spec[4] as Color, box)
		system_button.position = Vector2(index * (box.x + gap), 0.0)
		w[str(spec[0])] = system_button
		index += 1
	w.lobby_button = w.LobbyButton
	w.lobby_button.badge = THEME.WARM
	w.kill_feed_container = VBoxContainer.new()
	w.kill_feed_container.name = "KillFeed"
	w.kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.kill_feed_container.add_theme_constant_override("separation", 4)
	w.kill_feed_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	place(w.kill_feed_container, 1.0, 0.0, -352.0, 8.0 + box.y + 10.0, 340.0, 190.0)
	root.add_child(w.kill_feed_container)

	# Fit the timer into the space between score and navigation on small screens.
	# It must be recalculated after safe-area or orientation changes.
	if touch:
		var arrange_clock := func():
			var left := 254.0
			var right := root.size.x - total - 18.0
			var width := right - left
			var top := 8.0
			if width < 150.0:
				width = minf(240.0, maxf(150.0, root.size.x - left - 12.0))
				top = 92.0
			place(clock, 0.0, 0.0, left, top, width, 70.0)
			w.round_label.size.x = width
			w.event_label.size.x = maxf(0.0, width - 58.0)
			timer_icon.visible = width >= 200.0
			place(w.status_label, 0.0, 0.0, left, top + 74.0, width, 16.0)
			place(w.objective_label, 0.0, 0.0, left, top + 94.0, width, 24.0)
			place(w.killstreak_label, 0.0, 0.0, left, top + 122.0, width, 32.0)
			if top > 8.0:
				w.kill_feed_container.position.y = top + 94.0
			else:
				w.kill_feed_container.position.y = 8.0 + box.y + 10.0
		root.resized.connect(arrange_clock)
		arrange_clock.call()

	# --- bottom centre: weapon card ---------------------------------------------------------------
	var card_width := 300.0 if touch else 384.0
	var card_height := 84.0
	var card := plate(root, "WeaponCard", 0.5, 1.0, -card_width * 0.5, -(card_height + 12.0), card_width, card_height, THEME.WARM)
	w.weapon_icon = ICONS.make("w_aether", 58.0, THEME.INK)
	w.weapon_icon.position = Vector2(14.0, 13.0)
	card.add_child(w.weapon_icon)
	w.equipped_weapon_label = label(card, "AETHER BLASTER", THEME.SIZE_M, THEME.INK, "bold")
	w.equipped_weapon_label.position = Vector2(82.0, 6.0)
	w.equipped_weapon_label.size = Vector2(card_width - 82.0 - (side + 24.0), 24.0)
	w.equipped_weapon_label.clip_text = true
	w.weapon_role_label = label(card, "", THEME.SIZE_XS, THEME.WARM, "bold")
	w.weapon_role_label.position = Vector2(82.0, 30.0)
	w.weapon_role_label.size = Vector2(card_width - 82.0 - (side + 24.0), 18.0)
	w.weapon_role_label.clip_text = true
	w.weapon_mastery_label = label(card, "BLASTER LEVEL 0  •  GRENADE LEVEL 0", THEME.SIZE_XS, THEME.XP, "bold")
	w.weapon_mastery_label.position = Vector2(82.0, 52.0)
	w.weapon_mastery_label.size = Vector2(card_width - 82.0 - (side + 24.0), 18.0)
	w.weapon_mastery_label.clip_text = true
	w.weapon_mastery_label.visible = not touch
	var grenade_box := Vector2(side + 6.0, side + 6.0)
	w.grenade_button = button(card, "GrenadeButton", "grenade", "", "" if touch else "G", THEME.WARM, grenade_box)
	w.grenade_button.position = Vector2(card_width - grenade_box.x - 10.0, (card_height - grenade_box.y) * 0.5)

	# --- death banner -----------------------------------------------------------------------------
	w.death_label = label(root, "", THEME.SIZE_XL, THEME.DANGER, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	place(w.death_label, 0.5, 0.5, -300.0, -60.0, 600.0, 60.0)
	w.death_label.visible = false
	return w
