extends RefCounted
## The match scoreboard: a plate with a column header (kills, deaths, score as icons) and one row per
## player. The local player's row is highlighted.

const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")
const HUD := preload("res://scripts/ui/game_hud.gd")

const NAME_COLUMN := 230.0
const NUMBER_COLUMN := 70.0


static func _header_cell(parent: Container, icon: String, tint: Color) -> void:
	var cell := CenterContainer.new()
	cell.custom_minimum_size = Vector2(NUMBER_COLUMN, 22.0)
	cell.add_child(ICONS.make(icon, 20.0, tint))
	parent.add_child(cell)


static func build(root: Control) -> Dictionary:
	var w: Dictionary = {}
	var height := minf(440.0, maxf(root.size.y - 24.0, 240.0))
	var panel: Control = HUD.plate(root, "MatchScoreboard", 0.5, 0.5, -270.0, -height * 0.5, 540.0, height, THEME.ACCENT)
	panel.fill = THEME.PANEL_DEEP
	panel.visible = false
	panel.z_index = 22
	w.panel = panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	column.add_child(title_row)
	title_row.add_child(ICONS.make("scoreboard", 30.0, THEME.ACCENT))
	HUD.label(title_row, "SCOREBOARD", THEME.SIZE_L, THEME.INK, "bold")
	w.local_stats = HUD.label(column, "", THEME.SIZE_S, THEME.MUTED, "semibold")
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	column.add_child(header)
	var player_title := HUD.label(header, "PLAYER", THEME.SIZE_XS, THEME.FAINT, "bold")
	player_title.custom_minimum_size = Vector2(NAME_COLUMN + 34.0, 22.0)
	_header_cell(header, "kill", THEME.DANGER)
	_header_cell(header, "death", THEME.MUTED)
	_header_cell(header, "trophy", THEME.WARM)
	var rule := ColorRect.new()
	rule.color = Color(THEME.ACCENT_DIM.r, THEME.ACCENT_DIM.g, THEME.ACCENT_DIM.b, 0.6)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	column.add_child(rule)
	w.rows = VBoxContainer.new()
	w.rows.add_theme_constant_override("separation", 3)
	column.add_child(w.rows)
	return w


## `entries`: [{"name", "kills", "deaths", "score"}] already sorted, best first.
static func fill(rows: VBoxContainer, entries: Array, local_name: String) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		var empty := HUD.label(rows, "No players on the board yet", THEME.SIZE_S, THEME.FAINT, "semibold", HORIZONTAL_ALIGNMENT_CENTER)
		empty.custom_minimum_size = Vector2(0.0, 40.0)
	for index in range(mini(entries.size(), 8)):
		var entry: Dictionary = entries[index]
		var is_local := str(entry.name) == local_name
		var row_panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(THEME.ACCENT.r, THEME.ACCENT.g, THEME.ACCENT.b, 0.16) if is_local else Color(1.0, 1.0, 1.0, 0.03 if index % 2 == 0 else 0.0)
		style.set_corner_radius_all(3)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		row_panel.add_theme_stylebox_override("panel", style)
		rows.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row_panel.add_child(row)
		var rank_color := THEME.WARM if index == 0 else THEME.MUTED
		var rank := HUD.label(row, str(index + 1), THEME.SIZE_M, rank_color, "bold", HORIZONTAL_ALIGNMENT_CENTER)
		rank.custom_minimum_size = Vector2(34.0, 0.0)
		var name_label := HUD.label(row, str(entry.name), THEME.SIZE_M, THEME.INK if is_local else Color("#AFC4D4"), "bold")
		name_label.custom_minimum_size = Vector2(NAME_COLUMN, 0.0)
		name_label.clip_text = true
		for key in ["kills", "deaths", "score"]:
			var cell := HUD.label(row, str(int(entry[key])), THEME.SIZE_M, THEME.INK if is_local else Color("#AFC4D4"), "semibold", HORIZONTAL_ALIGNMENT_CENTER)
			cell.custom_minimum_size = Vector2(NUMBER_COLUMN, 0.0)
