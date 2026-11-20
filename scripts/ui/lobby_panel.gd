extends RefCounted
## The lobby overlay: server connection, rooms, quick match, friends, game mode and graphics quality.
## These controls used to sit on the HUD all the time; now they open from the Lobby icon. Every button
## here is wired by main.gd to the same handlers as before.

const THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := preload("res://scripts/ui/ui_icons.gd")
const HUD := preload("res://scripts/ui/game_hud.gd")
const BUTTON := preload("res://scripts/ui/icon_button.gd")


static func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


static func _wide(parent: Container, widget_name: String, icon: String, caption: String, tint: Color, height: float, width: float = 0.0) -> Button:
	var result := HUD.button(parent, widget_name, icon, caption, "", tint, Vector2(width, height))
	result.custom_minimum_size = Vector2(width, height)
	if width <= 0.0:
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


static func _section(parent: Container, icon: String, text: String) -> void:
	var row := _row(parent)
	row.add_child(ICONS.make(icon, 18.0, THEME.ACCENT))
	var title := HUD.label(row, text, THEME.SIZE_S, THEME.ACCENT, "bold")
	title.add_theme_constant_override("outline_size", 0)


static func _input(parent: Container, widget_name: String, placeholder: String, height: float) -> LineEdit:
	var result := LineEdit.new()
	result.name = widget_name
	result.placeholder_text = placeholder
	result.custom_minimum_size = Vector2(0.0, height)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result


## `row_height` is the tap height (44 on PC, the touch target on a phone).
static func build(root: Control, row_height: float, options: Dictionary) -> Dictionary:
	var w: Dictionary = {}
	var width := 520.0
	var height := minf(500.0, maxf(root.size.y - 24.0, 240.0))
	var panel: Control = HUD.plate(root, "LobbyPanel", 0.5, 0.5, -width * 0.5, -height * 0.5, width, height, THEME.ACCENT)
	panel.fill = THEME.PANEL_DEEP
	panel.visible = false
	panel.z_index = 25
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	w.panel = panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	# The form scrolls when the screen is short (a phone in landscape is only about 480 logical px tall).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	var header := _row(column)
	header.add_child(ICONS.make("lobby", 30.0, THEME.ACCENT))
	var title := HUD.label(header, "LOBBY", THEME.SIZE_L, THEME.INK, "bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.close_button = _wide(header, "LobbyClose", "close", "", THEME.MUTED, row_height, row_height)
	w.network_status_label = HUD.label(column, "Connecting...", THEME.SIZE_S, THEME.MUTED, "semibold")

	_section(column, "connect", "SERVER")
	var host_row := _row(column)
	w.network_host_input = _input(host_row, "HostInput", "Dedicated server host • UDP 2456", row_height)
	w.connect_button = _wide(host_row, "ConnectButton", "connect", "Connect", THEME.ACCENT, row_height, 150.0)

	_section(column, "play", "MATCH")
	var mode_row := _row(column)
	w.mode_select = OptionButton.new()
	w.mode_select.custom_minimum_size = Vector2(0.0, row_height)
	w.mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in options.get("modes", []):
		w.mode_select.add_item(str(item[0]))
		w.mode_select.set_item_metadata(w.mode_select.item_count - 1, str(item[1]))
	mode_row.add_child(w.mode_select)
	w.quick_match_button = _wide(mode_row, "QuickMatchButton", "quick_match", "Quick match", THEME.OK, row_height, 170.0)
	var code_row := _row(column)
	w.room_code_input = _input(code_row, "RoomCodeInput", "Room code", row_height)
	w.join_button = _wide(code_row, "JoinRoomButton", "join_room", "Join", THEME.ACCENT, row_height, 110.0)
	w.create_room_button = _wide(code_row, "CreateRoomButton", "create_room", "Create", THEME.ACCENT, row_height, 130.0)
	w.room_status_label = HUD.label(column, "LOBBY • Sign in to play online", THEME.SIZE_S, THEME.MUTED, "semibold")
	w.room_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_section(column, "invite", "FRIENDS")
	var friend_row := _row(column)
	w.friend_name_input = _input(friend_row, "FriendInput", "Friend username", row_height)
	w.invite_button = _wide(friend_row, "InviteFriendButton", "invite", "Invite", THEME.ACCENT, row_height, 130.0)

	_section(column, "graphics", "GRAPHICS")
	w.graphics_option = OptionButton.new()
	w.graphics_option.custom_minimum_size = Vector2(0.0, row_height)
	for quality_name in options.get("qualities", []):
		w.graphics_option.add_item(str(quality_name))
	column.add_child(w.graphics_option)
	return w
