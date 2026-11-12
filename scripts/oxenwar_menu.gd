extends CanvasLayer
signal play_requested(identity: Dictionary)

const I18N = preload("res://scripts/oxenwar_i18n.gd")
const CHARACTER_VISUALS = preload("res://scripts/character_visuals.gd")
const CHARACTER_MOTION_RIG = preload("res://scripts/character_motion_rig.gd")
var backend: Node
var locale := "az"
var profile: Dictionary = {}
var authenticated := false
var is_admin := false
var active_tab := "play"
var registration_mode := false
var password_input: LineEdit
var display_input: LineEdit
var username_input: LineEdit
var message_label: Label
var content: VBoxContainer
var cosmetics: Dictionary = {}
var registration_notice := ""
var preview_spin: Node3D
var preview_model: Node3D
var server_host := ""
var selected_game_mode := "ffa"
var room_code_field: LineEdit
var server_host_field: LineEdit
var lobby_notice_label: Label

const BG := Color("#07111F")
const PANEL := Color("#101F32")
const ACCENT := Color("#25D7C2")
const MUTED := Color("#91A5B8")

func configure(client: Node, restored: Dictionary = {}, configured_server_host: String = "") -> void:
	backend = client
	server_host = configured_server_host.strip_edges()
	if restored.get("ok", false):
		await _load_account()
	_build()

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if is_instance_valid(preview_spin):
		preview_spin.rotation.y += delta * 0.48

func _t(key: String) -> String:
	return I18N.text_for(key, locale)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	backdrop.add_child(margin)

	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _panel_style())
	margin.add_child(shell)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	shell.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var brand := Label.new()
	brand.text = "OXENWAR"
	brand.add_theme_font_size_override("font_size", 34)
	brand.add_theme_color_override("font_color", ACCENT)
	header.add_child(brand)
	var tagline := Label.new()
	tagline.text = "  //  " + _t("subtitle")
	tagline.add_theme_color_override("font_color", MUTED)
	tagline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tagline)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var language := OptionButton.new()
	for item in [["AZ","az"],["EN","en"],["TR","tr"],["RU","ru"]]:
		language.add_item(item[0])
		language.set_item_metadata(language.item_count - 1, item[1])
	language.select(["az","en","tr","ru"].find(locale))
	language.item_selected.connect(_on_language_selected)
	header.add_child(language)

	var line := ColorRect.new()
	line.custom_minimum_size.y = 2
	line.color = Color("#20354A")
	outer.add_child(line)

	if not authenticated:
		_build_auth(outer)
		return

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	outer.add_child(nav)
	for tab in ["play", "stats", "friends", "character"]:
		var button := _button(_t(tab), tab == active_tab)
		button.pressed.connect(_on_tab_pressed.bind(tab))
		nav.add_child(button)
	var account := Label.new()
	account.text = str(profile.get("username", "Player")) + "  •  " + ("ADMIN" if is_admin else "PLAYER")
	account.add_theme_color_override("font_color", ACCENT)
	account.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nav.add_child(account)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	outer.add_child(content)
	var heartbeat := Timer.new()
	heartbeat.name = "MenuPresenceHeartbeat"
	heartbeat.wait_time = 30.0
	heartbeat.autostart = true
	heartbeat.timeout.connect(_send_presence_heartbeat)
	add_child(heartbeat)
	_send_presence_heartbeat()
	_render_tab()
	if not registration_notice.is_empty():
		content.add_child(_label(registration_notice))

func _build_auth(parent: VBoxContainer) -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(360, 0)
	form.add_theme_constant_override("separation", 10)
	center.add_child(form)
	var heading := Label.new()
	heading.text = _t("auth_hint")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", MUTED)
	form.add_child(heading)
	username_input = _field(_t("username") + " (3–20)", "Player_01")
	form.add_child(username_input)
	password_input = _field(_t("password") + " (8+)", "••••••••", true)
	form.add_child(password_input)
	display_input = _field(_t("display_name"), "Player")
	display_input.visible = false
	form.add_child(display_input)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	form.add_child(actions)
	var login := _button(_t("login"), true)
	login.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login.pressed.connect(_on_login)
	actions.add_child(login)
	var register := _button(_t("register"), false)
	register.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register.pressed.connect(_on_register)
	actions.add_child(register)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color("#FFC36B"))
	form.add_child(message_label)

func _field(label_text: String, hint: String, secret: bool = false) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = label_text + " — " + hint
	field.secret = secret
	field.custom_minimum_size.y = 44
	field.add_theme_color_override("font_color", Color("#EAF4FF"))
	field.add_theme_stylebox_override("normal", _input_style())
	field.add_theme_stylebox_override("focus", _input_style(true))
	return field

func _button(label_text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = 44
	button.add_theme_color_override("font_color", Color("#04131D") if primary else Color("#DCEBFA"))
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if primary else Color("#1A3047")
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("#55E8D5") if primary else Color("#29445F")
	button.add_theme_stylebox_override("hover", hover)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color("#254158")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func _input_style(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0A1726")
	style.border_color = ACCENT if focused else Color("#29445B")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _on_language_selected(index: int) -> void:
	var option := get_node_or_null("..")
	var codes := ["az","en","tr","ru"]
	locale = codes[clampi(index, 0, 3)]
	if authenticated:
		await backend.update_profile({"locale": locale})
	_build()

func _on_login() -> void:
	registration_mode = false
	display_input.hide()
	if username_input.text.strip_edges().is_empty() or password_input.text.is_empty():
		message_label.text = _t("error") + ": " + _t("username") + " / " + _t("password")
		return
	message_label.text = "..."
	var result: Dictionary = await backend.sign_in(username_input.text, password_input.text)
	if not result.get("ok", false):
		message_label.text = _t("error") + ": " + str(result.get("message", ""))
		return
	registration_notice = ""
	await _load_account()
	_build()

func _on_register() -> void:
	if not registration_mode:
		registration_mode = true
		display_input.show()
		message_label.text = _t("register_hint")
		return
	if password_input.text.length() < 8:
		message_label.text = _t("error") + ": password must be at least 8 characters."
		return
	var chosen_name := display_input.text.strip_edges()
	var chosen_username := username_input.text.strip_edges()
	var username_regex := RegEx.new()
	username_regex.compile("^[A-Za-z0-9_]{3,20}$")
	if chosen_name.is_empty() or username_regex.search(chosen_username) == null:
		message_label.text = _t("error") + ": enter a display name and a player name using 3–20 letters, numbers or underscores."
		return
	message_label.text = "..."
	var result: Dictionary = await backend.sign_up(password_input.text, chosen_name, chosen_username, locale)
	if not result.get("ok", false):
		message_label.text = _t("error") + ": " + str(result.get("message", ""))
		return
	await _load_account()
	if str(profile.get("username", "")) != chosen_username:
		registration_notice = "That player name was already taken; your account received the available name " + str(profile.get("username", "Player")) + "."
	_build()

func _load_account() -> void:
	profile = await backend.get_profile()
	if profile.is_empty():
		return
	locale = str(profile.get("locale", locale))
	is_admin = await backend.get_role() == "admin"
	cosmetics = await backend.get_cosmetics()
	authenticated = true
	await backend.update_presence()

func _send_presence_heartbeat() -> void:
	if is_instance_valid(backend) and authenticated:
		await backend.update_presence()

func _on_tab_pressed(tab: String) -> void:
	active_tab = tab
	_render_tab()

func _render_tab() -> void:
	if not is_instance_valid(content):
		return
	preview_spin = null
	preview_model = null
	for child in content.get_children():
		child.queue_free()
	match active_tab:
		"play":
			_render_play_tab()
		"stats":
			await _render_stats()
		"friends":
			await _render_friends()
		"character":
			_render_character()

func _render_play_tab() -> void:
	content.add_child(_large_label("OXENWAR"))
	content.add_child(_label(_t("online_arena")))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	content.add_child(mode_row)
	var mode_label := _label(_t("game_mode"))
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(mode_label)
	var mode_select := OptionButton.new()
	mode_select.custom_minimum_size = Vector2(220, 44)
	mode_select.add_item(_t("mode_ffa"))
	mode_select.set_item_metadata(0, "ffa")
	mode_select.add_item(_t("mode_tdm"))
	mode_select.set_item_metadata(1, "team_deathmatch")
	mode_select.add_item(_t("mode_koth"))
	mode_select.set_item_metadata(2, "king_of_the_hill")
	mode_select.add_item("BOMB RUSH • PLANT / DEFUSE")
	mode_select.set_item_metadata(3, "demolition")
	mode_select.item_selected.connect(func(index: int): selected_game_mode = str(mode_select.get_item_metadata(index)))
	mode_row.add_child(mode_select)

	var server_panel := PanelContainer.new()
	server_panel.add_theme_stylebox_override("panel", _panel_style())
	content.add_child(server_panel)
	var server_stack := VBoxContainer.new()
	server_stack.add_theme_constant_override("separation", 8)
	server_panel.add_child(server_stack)
	server_stack.add_child(_label(_t("server_title") + "  •  WSS / UDP 2456"))
	server_host_field = _field(_t("server_address"), _t("server_hint"))
	server_host_field.text = server_host
	server_stack.add_child(server_host_field)
	var initial_valid := _is_server_address_valid(server_host)
	lobby_notice_label = _label(_t("server_ready") if initial_valid else (_t("server_missing") if server_host.is_empty() else _t("server_invalid")))
	lobby_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_notice_label.add_theme_color_override("font_color", ACCENT if initial_valid else Color("#FFC36B"))
	server_stack.add_child(lobby_notice_label)

	var start := _button(_t("start_match"), true)
	start.custom_minimum_size = Vector2(0, 58)
	start.disabled = not initial_valid
	start.pressed.connect(_launch_game.bind("quick_match"))
	content.add_child(start)

	var room_row := HBoxContainer.new()
	room_row.add_theme_constant_override("separation", 10)
	var create := _button(_t("create_room"), false)
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.custom_minimum_size.y = 52
	create.disabled = not initial_valid
	create.pressed.connect(_launch_game.bind("create_room"))
	room_row.add_child(create)
	content.add_child(room_row)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	room_code_field = _field(_t("room_code"), "A1B2C3")
	room_code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(room_code_field)
	var join := _button(_t("join_room"), false)
	join.custom_minimum_size = Vector2(130, 44)
	join.disabled = not initial_valid
	join.pressed.connect(_launch_game.bind("join_room"))
	join_row.add_child(join)
	content.add_child(join_row)
	server_host_field.text_changed.connect(func(value: String):
		var valid := _is_server_address_valid(value)
		start.disabled = not valid
		create.disabled = not valid
		join.disabled = not valid
		lobby_notice_label.text = _t("server_ready") if valid else (_t("server_missing") if value.strip_edges().is_empty() else _t("server_invalid"))
		lobby_notice_label.add_theme_color_override("font_color", ACCENT if valid else Color("#FFC36B"))
	)

	var logout := _button(_t("logout"), false)
	logout.pressed.connect(_on_logout)
	content.add_child(logout)

func _is_server_address_valid(value: String) -> bool:
	var address := value.strip_edges()
	if address.is_empty() or address.length() > 512:
		return false
	if address.contains(" ") or address.contains("\n") or address.contains("\t"):
		return false
	if address.begins_with("wss://") or address.begins_with("ws://"):
		var scheme_length := 6 if address.begins_with("wss://") else 5
		var endpoint := address.substr(scheme_length)
		var hostname := endpoint.get_slice("/", 0)
		return not hostname.is_empty() and not hostname.contains("?") and not hostname.contains("#")
	if address.contains("://") or address.contains("/") or address.contains("?") or address.contains("#"):
		return false
	return address == "localhost" or address.is_valid_ip_address() or address.contains(".")

func _is_valid_room_code(value: String) -> bool:
	var code := value.strip_edges().to_upper()
	const ROOM_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	if code.length() != 6:
		return false
	for index in range(code.length()):
		if not ROOM_CODE_ALPHABET.contains(code.substr(index, 1)):
			return false
	return true

func _launch_game(action: String) -> void:
	var host := server_host_field.text.strip_edges() if is_instance_valid(server_host_field) else server_host
	if not _is_server_address_valid(host):
		if is_instance_valid(lobby_notice_label):
			lobby_notice_label.text = _t("server_invalid") if not host.is_empty() else _t("server_missing")
		return
	var room_code := room_code_field.text.strip_edges().to_upper() if is_instance_valid(room_code_field) else ""
	if action == "join_room" and not _is_valid_room_code(room_code):
		if is_instance_valid(lobby_notice_label):
			lobby_notice_label.text = _t("room_code_invalid")
		return
	play_requested.emit({
		"display_name": str(profile.get("display_name", profile.get("username", "Player"))),
		"profile": profile,
		"is_admin": is_admin,
		"launch_action": action,
		"game_mode": selected_game_mode,
		"room_code": room_code,
		"server_host": host
	})

func _render_weapon_mastery() -> void:
	content.add_child(_large_label("WEAPON MASTERY"))
	var loading := _label("Loading weapon mastery...")
	content.add_child(loading)
	var result: Dictionary = await backend.get_weapon_mastery()
	if not is_instance_valid(loading):
		return
	loading.queue_free()
	if not result.get("ok", false):
		content.add_child(_label("Weapon mastery is currently unavailable."))
		return
	var mastery: Dictionary = result.get("data", {})
	for weapon in [
		{"id": "blaster", "name": "AETHER BLASTER", "xp": int(mastery.get("blaster_xp", 0))},
		{"id": "grenade", "name": "GRENADE", "xp": int(mastery.get("grenade_xp", 0))}
	]:
		var xp := int(weapon.xp)
		var rank := "GOLD" if xp >= 600 else ("SILVER" if xp >= 300 else ("BRONZE" if xp >= 100 else "RECRUIT"))
		var row := HBoxContainer.new()
		var name_label := _label(str(weapon.name) + "  •  " + rank)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var xp_label := _label("%d XP" % xp)
		xp_label.add_theme_color_override("font_color", ACCENT)
		row.add_child(xp_label)
		content.add_child(row)
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 12)
		progress.max_value = 600
		progress.value = mini(xp, 600)
		progress.show_percentage = false
		content.add_child(progress)
	content.add_child(_label("Mastery XP is saved to your account after each match. Weapon skins are not yet connected to this progression."))

func _render_stats() -> void:
	content.add_child(_large_label(_t("career_title")))
	var loading := _label(_t("stats_loading"))
	content.add_child(loading)
	var result: Dictionary = await backend.get_player_stats()
	if not is_instance_valid(loading):
		return
	if not result.get("ok", false):
		loading.text = _t("stats_unavailable")
		return
	var stats: Dictionary = result.get("data", {})
	loading.queue_free()
	var total_xp := maxi(0, int(stats.get("total_xp", 0)))
	_render_rank_progress(total_xp)
	await _render_weapon_mastery()
	if stats.is_empty():
		content.add_child(_label(_t("stats_empty")))
		return
	var kills := int(stats.get("total_kills", 0))
	var deaths := int(stats.get("total_deaths", 0))
	var matches := int(stats.get("matches_played", 0))
	var wins := int(stats.get("matches_won", 0))
	var losses := int(stats.get("matches_lost", 0))
	var draws := int(stats.get("matches_drawn", 0))
	var shots := int(stats.get("total_shots_fired", 0))
	var hits := int(stats.get("total_shots_hit", 0))
	var accuracy := 100.0 * float(hits) / float(shots) if shots > 0 else 0.0
	var kd := float(kills) / float(maxi(1, deaths))
	var playtime := int(stats.get("total_playtime_seconds", 0))
	var hours := int(playtime / 3600)
	var minutes := int((playtime % 3600) / 60)
	var cards := [
		[_t("stat_matches"), str(matches)], [_t("stat_record"), "%d / %d / %d" % [wins, losses, draws]],
		[_t("stat_kills"), str(kills)], [_t("stat_deaths"), str(deaths)],
		[_t("stat_kd"), "%.2f" % kd], [_t("stat_accuracy"), "%.1f%%" % accuracy],
		[_t("stat_best_score"), str(int(stats.get("best_score", 0)))], [_t("stat_best_kills"), str(int(stats.get("best_kills", 0)))],
		[_t("stat_best_damage"), "%.0f" % float(stats.get("best_damage", 0.0))],
		[_t("stat_total_damage"), "%.0f" % float(stats.get("total_damage_dealt", 0.0))],
		[_t("stat_playtime"), "%dh %02dm" % [hours, minutes]]
	]
	for index in range(cards.size()):
		var row := HBoxContainer.new()
		var key_label := _label(str(cards[index][0]))
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key_label)
		var value_label := _label(str(cards[index][1]))
		value_label.add_theme_color_override("font_color", ACCENT)
		row.add_child(value_label)
		content.add_child(row)

const RANKS := [
	{"id":"bronze", "minimum":0, "color":Color("#B87945")},
	{"id":"silver", "minimum":500, "color":Color("#B9C5D1")},
	{"id":"gold", "minimum":1500, "color":Color("#F0C65A")},
	{"id":"platinum", "minimum":3500, "color":Color("#58D6D0")},
	{"id":"diamond", "minimum":7000, "color":Color("#65AFFF")},
	{"id":"master", "minimum":12000, "color":Color("#C18AFF")}
]

func _rank_for_xp(total_xp: int) -> Dictionary:
	var current: Dictionary = RANKS[0]
	var next_rank: Dictionary = {}
	for index in range(RANKS.size()):
		var candidate: Dictionary = RANKS[index]
		if total_xp >= int(candidate.minimum):
			current = candidate
			next_rank = RANKS[index + 1] if index + 1 < RANKS.size() else {}
		else:
			break
	var floor_xp := int(current.minimum)
	var ceiling_xp := int(next_rank.minimum) if not next_rank.is_empty() else floor_xp
	var progress := 1.0 if next_rank.is_empty() else clampf(float(total_xp - floor_xp) / float(maxi(1, ceiling_xp - floor_xp)), 0.0, 1.0)
	return {"current":current, "next":next_rank, "progress":progress, "remaining":maxi(0, ceiling_xp - total_xp)}

func _render_rank_progress(total_xp: int) -> void:
	var rank_data := _rank_for_xp(total_xp)
	var current: Dictionary = rank_data.current
	var next_rank: Dictionary = rank_data.next
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	content.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var rank_label := _large_label(_t("rank_" + str(current.id)))
	rank_label.add_theme_color_override("font_color", current.color)
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(rank_label)
	var xp_label := _label("%s XP" % _format_number(total_xp))
	xp_label.add_theme_color_override("font_color", ACCENT)
	header.add_child(xp_label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = float(rank_data.progress) * 100.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#1B2D42")
	track.corner_radius_top_left = 8
	track.corner_radius_top_right = 8
	track.corner_radius_bottom_left = 8
	track.corner_radius_bottom_right = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = current.color
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	stack.add_child(bar)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	var progress_label := _label("%s XP" % _format_number(total_xp - int(current.minimum)))
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(progress_label)
	if next_rank.is_empty():
		footer.add_child(_label(_t("rank_max")))
	else:
		footer.add_child(_label("%s: %s XP" % [_t("rank_next"), _format_number(int(next_rank.minimum) - total_xp)]))
	stack.add_child(_label(_t("rank_total") + ": %s XP" % _format_number(total_xp)))

func _format_number(value: int) -> String:
	var raw := str(maxi(0, value))
	var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			formatted += ","
		formatted += raw.substr(index, 1)
	return formatted

func _render_friends() -> void:
	content.add_child(_large_label(_t("friends")))
	var search_row := HBoxContainer.new()
	var search_field := _field(_t("search"), "Cemil_123")
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(search_field)
	var search_button := _button(_t("search"), true)
	search_button.pressed.connect(func(): await _search_players(search_field.text))
	search_row.add_child(search_button)
	content.add_child(search_row)
	var requests_title := _label(_t("requests"))
	content.add_child(requests_title)
	var requests: Dictionary = await backend.get_friend_requests()
	if requests.get("ok", false):
		for request in requests.get("data", []):
			var incoming := str(request.get("receiver_id")) == str(backend.user_id)
			var row := HBoxContainer.new()
			var other_id := str(request.get("sender_id", "") if incoming else request.get("receiver_id", ""))
			var other_profile: Dictionary = await backend.get_profile_by_id(other_id)
			var other_name := str(other_profile.get("username", other_id.substr(0, 8)))
			row.add_child(_label(("From " if incoming else "To ") + other_name))
			if incoming:
				var accept := _button(_t("accept"), true)
				accept.pressed.connect(func():
					await backend.respond_friend_request(str(request.get("id")), true)
					await _render_friends()
				)
				row.add_child(accept)
				var reject := _button(_t("reject"), false)
				reject.pressed.connect(func():
					await backend.respond_friend_request(str(request.get("id")), false)
					await _render_friends()
				)
				row.add_child(reject)
			else:
				row.add_child(_label(_t("pending")))
			content.add_child(row)
	var friends_title := _label(_t("friends"))
	content.add_child(friends_title)
	var friends: Dictionary = await backend.get_friends()
	if friends.get("ok", false):
		var friend_rows: Array = friends.get("data", [])
		var friend_ids := PackedStringArray()
		for friend in friend_rows:
			friend_ids.append(str(friend.get("id", "")))
		var presence_result: Dictionary = await backend.get_friend_presence(friend_ids)
		var presence_by_id := {}
		if presence_result.get("ok", false):
			for presence in presence_result.get("data", []):
				presence_by_id[str(presence.get("user_id"))] = str(presence.get("last_seen_at", ""))
		for friend in friend_rows:
			var friend_id := str(friend.get("id", ""))
			var last_seen := str(presence_by_id.get(friend_id, ""))
			var online := false
			if not last_seen.is_empty():
				var last_seen_unix := Time.get_unix_time_from_datetime_string(last_seen)
				online = int(Time.get_unix_time_from_system()) - last_seen_unix <= 90
			var status_text := _t("online") if online else _t("offline")
			content.add_child(_label(str(friend.get("username", "Player")) + "  •  " + status_text))
		if friends.get("data", []).is_empty():
			content.add_child(_label(_t("no_results")))
	else:
		content.add_child(_label(str(friends.get("message", ""))))

func _search_players(query: String) -> void:
	var result: Dictionary = await backend.search_players(query)
	if not result.get("ok", false):
		content.add_child(_label(str(result.get("message", ""))))
		return
	var rows: Array = result.get("data", [])
	if rows.is_empty():
		content.add_child(_label(_t("no_results")))
		return
	for player_row in rows:
		var row := HBoxContainer.new()
		row.add_child(_label(str(player_row.get("username", "")) + "  •  " + str(player_row.get("display_name", ""))))
		var add := _button(_t("add"), true)
		add.pressed.connect(func():
			var sent: Dictionary = await backend.send_friend_request(str(player_row.get("id")))
			add.disabled = true
			add.text = _t("pending") if sent.get("ok", false) else _t("error")
		)
		row.add_child(add)
		content.add_child(row)

func _render_character() -> void:
	content.add_child(_large_label(_t("character") + "  •  3D PREVIEW"))
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	content.add_child(layout)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(280, 220)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _panel_style())
	layout.add_child(preview_panel)
	var preview_container := SubViewportContainer.new()
	preview_container.stretch = true
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview_container)
	var preview_viewport := SubViewport.new()
	preview_viewport.size = Vector2i(512, 384)
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.msaa_3d = Viewport.MSAA_2X
	preview_container.add_child(preview_viewport)
	_build_character_preview_stage(preview_viewport)

	var controls_panel := PanelContainer.new()
	controls_panel.custom_minimum_size = Vector2(230, 0)
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_panel.add_theme_stylebox_override("panel", _panel_style())
	layout.add_child(controls_panel)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 9)
	controls_panel.add_child(controls)

	var color_option := OptionButton.new()
	var outfit_option := OptionButton.new()
	var accessory_option := OptionButton.new()
	var color_items: Array = []
	var outfit_items: Array = []
	var accessory_items: Array = []
	var unlocked := {}
	for item in cosmetics.get("inventory", []):
		unlocked[str(item.get("cosmetic_id"))] = true
	for item in cosmetics.get("catalog", []):
		if not unlocked.has(str(item.get("id"))):
			continue
		if str(item.get("slot")) == "avatar_color":
			color_items.append(item)
		elif str(item.get("slot")) == "outfit":
			outfit_items.append(item)
		elif str(item.get("slot")) == "accessory":
			accessory_items.append(item)
	for item in color_items:
		color_option.add_item(str(item.get("name_key")).replace("cosmetic.color.", "").capitalize())
		color_option.set_item_metadata(color_option.item_count - 1, str(item.get("id")))
	for item in outfit_items:
		outfit_option.add_item(str(item.get("name_key")).replace("cosmetic.outfit.", "").capitalize())
		outfit_option.set_item_metadata(outfit_option.item_count - 1, str(item.get("id")))
	for item in accessory_items:
		accessory_option.add_item(str(item.get("name_key")).replace("cosmetic.accessory.", "").capitalize())
		accessory_option.set_item_metadata(accessory_option.item_count - 1, str(item.get("id")))

	for i in color_items.size():
		if str(color_items[i].get("id")) == str(profile.get("avatar_color_id", "color_cyan")):
			color_option.select(i)
	for i in outfit_items.size():
		if str(outfit_items[i].get("id")) == str(profile.get("outfit_id", "outfit_default")):
			outfit_option.select(i)
	for i in accessory_items.size():
		if str(accessory_items[i].get("id")) == str(profile.get("accessory_id", "accessory_cap")):
			accessory_option.select(i)
	if color_option.item_count > 0 and color_option.selected < 0:
		color_option.select(0)
	if outfit_option.item_count > 0 and outfit_option.selected < 0:
		outfit_option.select(0)
	if accessory_option.item_count > 0 and accessory_option.selected < 0:
		accessory_option.select(0)

	controls.add_child(_label(_t("choose_color")))
	controls.add_child(color_option)
	controls.add_child(_label(_t("choose_outfit")))
	controls.add_child(outfit_option)
	controls.add_child(_label("Accessory"))
	controls.add_child(accessory_option)
	_refresh_character_preview(
		_selected_cosmetic_id(color_option, "color_cyan"),
		_selected_cosmetic_id(outfit_option, "outfit_default"),
		_selected_cosmetic_id(accessory_option, "accessory_cap")
	)
	color_option.item_selected.connect(func(_index: int):
		_refresh_character_preview(
			_selected_cosmetic_id(color_option, "color_cyan"),
			_selected_cosmetic_id(outfit_option, "outfit_default"),
			_selected_cosmetic_id(accessory_option, "accessory_cap")
		)
	)
	outfit_option.item_selected.connect(func(_index: int):
		_refresh_character_preview(
			_selected_cosmetic_id(color_option, "color_cyan"),
			_selected_cosmetic_id(outfit_option, "outfit_default"),
			_selected_cosmetic_id(accessory_option, "accessory_cap")
		)
	)
	accessory_option.item_selected.connect(func(_index: int):
		_refresh_character_preview(
			_selected_cosmetic_id(color_option, "color_cyan"),
			_selected_cosmetic_id(outfit_option, "outfit_default"),
			_selected_cosmetic_id(accessory_option, "accessory_cap")
		)
	)

	if color_items.is_empty() or outfit_items.is_empty() or accessory_items.is_empty():
		controls.add_child(_label("Some cosmetic slots are locked or not available yet. The 3D preview still shows your current/default character."))
		return
	var save := _button(_t("save"), true)
	save.pressed.connect(func():
		var saved: Dictionary = await backend.update_profile({
			"avatar_color_id": _selected_cosmetic_id(color_option, "color_cyan"),
			"outfit_id": _selected_cosmetic_id(outfit_option, "outfit_default"),
			"accessory_id": _selected_cosmetic_id(accessory_option, "accessory_cap")
		})
		if saved.get("ok", false):
			profile = await backend.get_profile()
			save.text = _t("save") + " ✓"
		else:
			save.text = _t("error")
	)
	controls.add_child(save)

func _selected_cosmetic_id(option: OptionButton, fallback: String) -> String:
	if not is_instance_valid(option) or option.item_count == 0 or option.selected < 0:
		return fallback
	return str(option.get_item_metadata(option.selected))

func _build_character_preview_stage(viewport: SubViewport) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0A1728")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#B7D8F2")
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var stage := Node3D.new()
	stage.name = "CharacterPreviewStage"
	viewport.add_child(stage)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34, -28, 0)
	key_light.light_color = Color("#E5F4FF")
	key_light.light_energy = 1.45
	stage.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.6, -1.4)
	fill_light.light_color = ACCENT
	fill_light.light_energy = 0.65
	fill_light.omni_range = 5.0
	stage.add_child(fill_light)

	var camera := Camera3D.new()
	camera.position = Vector3(2.35, 1.95, -4.25)
	camera.fov = 34.0
	camera.near = 0.05
	camera.look_at(Vector3(0, 0.96, 0), Vector3.UP)
	camera.current = true
	stage.add_child(camera)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.78
	pedestal_mesh.bottom_radius = 0.84
	pedestal_mesh.height = 0.12
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = -0.06
	var pedestal_material := StandardMaterial3D.new()
	pedestal_material.albedo_color = Color("#1A3148")
	pedestal_material.metallic = 0.62
	pedestal_material.roughness = 0.3
	pedestal.material_override = pedestal_material
	stage.add_child(pedestal)

	preview_spin = Node3D.new()
	preview_spin.name = "RotatingCharacterPreview"
	stage.add_child(preview_spin)

func _refresh_character_preview(color_id: String, outfit_id: String, accessory_id: String) -> void:
	if not is_instance_valid(preview_spin):
		return
	for child in preview_spin.get_children():
		child.queue_free()
	preview_model = Node3D.new()
	preview_model.name = "CharacterPreviewModel"
	preview_spin.add_child(preview_model)

	var color_map := {
		"color_cyan": Color("#27D7E7"),
		"color_violet": Color("#9B70FF"),
		"color_orange": Color("#FF9B42"),
		"color_lime": Color("#A7E34B")
	}
	var avatar_color: Color = color_map.get(color_id, Color("#27D7E7"))
	var suit_color: Color = CHARACTER_VISUALS.suit_color_for(outfit_id, avatar_color)
	if outfit_id == "outfit_iron_vanguard":
		suit_color = Color("#A92332")
	elif outfit_id == "outfit_web_sentinel":
		suit_color = Color("#B52D3D")
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	body.material_override = _preview_material(suit_color)
	preview_model.add_child(body)
	CHARACTER_VISUALS.apply_body_shape(body, outfit_id)
	CHARACTER_VISUALS.build(body, outfit_id, avatar_color)
	# Same limb rig as in-game so the preview shows arms, legs and footwear too.
	CHARACTER_MOTION_RIG.build(body, suit_color, outfit_id)
	_add_preview_accessory(preview_model, accessory_id, avatar_color)

	# Same hero armor as in-game, fitted to the slim torso.
	CHARACTER_VISUALS.add_hero_details(body, outfit_id)

func _add_preview_accessory(parent: Node3D, accessory_id: String, avatar_color: Color) -> void:
	if accessory_id == "accessory_cap":
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.24
		cap_mesh.height = 0.18
		cap.mesh = cap_mesh
		cap.position = Vector3(0, 1.82, 0)
		cap.material_override = _preview_material(avatar_color.lightened(0.25))
		parent.add_child(cap)
		var brim := MeshInstance3D.new()
		var brim_mesh := CylinderMesh.new()
		brim_mesh.top_radius = 0.22
		brim_mesh.bottom_radius = 0.22
		brim_mesh.height = 0.035
		brim.mesh = brim_mesh
		brim.position = Vector3(0, 1.75, -0.12)
		brim.material_override = _preview_material(avatar_color.darkened(0.2))
		parent.add_child(brim)
	elif accessory_id == "accessory_headphones":
		for side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var ear_mesh := SphereMesh.new()
			ear_mesh.radius = 0.105
			ear_mesh.height = 0.22
			ear.mesh = ear_mesh
			ear.position = Vector3(side * 0.31, 1.70, 0)
			ear.material_override = _preview_material(avatar_color)
			parent.add_child(ear)

func _preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.18
	return material

func _on_logout() -> void:
	await backend.sign_out()
	authenticated = false
	profile.clear()
	is_admin = false
	_build()

func _large_label(value: String) -> Label:
	var label := _label(value)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", ACCENT)
	return label

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", Color("#DCEBFA"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
