extends RefCounted
## One line of the kill feed: killer, weapon icon, victim. Lines that involve the local player get an
## accent edge (cyan when you got the kill, red when you were eliminated).

const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")
const HUD := preload("res://scripts/ui/game_hud.gd")
const PLATE := preload("res://scripts/ui/hud_plate.gd")


## `icon` is an icon library name ("w_aether", "grenade", ...).
static func build(killer: String, victim: String, icon: String, local_name: String) -> Control:
	var holder := HBoxContainer.new()
	holder.name = "KillFeedEntry"
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var mine := killer == local_name
	var lost := victim == local_name
	style.bg_color = Color(0.02, 0.045, 0.075, 0.82)
	if mine:
		style.border_color = THEME.ACCENT
	elif lost:
		style.border_color = THEME.DANGER
	else:
		style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	holder.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var killer_label := HUD.label(row, killer, THEME.SIZE_M, THEME.ACCENT if mine else THEME.INK, "bold")
	killer_label.add_theme_constant_override("outline_size", 0)
	row.add_child(ICONS.make(icon if ICONS.has(icon) else "kill", 24.0, THEME.WARM))
	var victim_label := HUD.label(row, victim, THEME.SIZE_M, THEME.DANGER if lost else THEME.INK, "bold")
	victim_label.add_theme_constant_override("outline_size", 0)
	return holder
