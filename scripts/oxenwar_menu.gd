extends CanvasLayer

const COMPETITIVE_THEME := preload("res://scripts/competitive_theme.gd")
const FPS_UI := preload("res://scripts/fps_ui.gd")
const USER_SETTINGS := preload("res://scripts/user_settings.gd")
const SCALED_ROOT := preload("res://scripts/ui/scaled_root.gd")
signal play_requested(identity: Dictionary)

const I18N = preload("res://scripts/oxenwar_i18n.gd")
const ARENA_LAYOUT = preload("res://scripts/arena_layout.gd")
const LAN_DISCOVERY := preload("res://scripts/lan_discovery.gd")
const CHARACTER_VISUALS = preload("res://scripts/character_visuals.gd")
const CHARACTER_MOTION_RIG = preload("res://scripts/character_motion_rig.gd")
const SKELETAL_AVATAR = preload("res://scripts/skeletal_avatar.gd")
var backend: Node
var locale := "az"
var profile: Dictionary = {}
var authenticated := false
## Guest: signed in with a name only. No account tabs, nothing is saved online.
var is_guest := false
var guest_input: LineEdit
## Looks for open servers on the local network. Off in headless runs (tests, dedicated servers).
var lan_scan_enabled := DisplayServer.get_name() != "headless"
var is_admin := false
var active_tab := "play"
var registration_mode := false
var password_input: LineEdit
var display_input: LineEdit
var username_input: LineEdit
var message_label: Label
var content: VBoxContainer
var content_scroll: ScrollContainer
# Bumped on every tab render so slow network awaits from an older render can bail out.
var _render_id := 0
var _player_search_id := 0
var cosmetics: Dictionary = {}
var registration_notice := ""
var preview_spin: Node3D
var preview_model: Node3D
var server_host := ""
var selected_game_mode := "ffa"
var selected_map_index := 4
var room_code_field: LineEdit
## Typed room code survives tab switches and language changes (the fields are rebuilt).
var room_code_text := ""
var server_host_field: LineEdit
var lobby_notice_label: Label
var nav_box: HBoxContainer
## Scales the whole menu for the device (phone or PC).
var scaled_root: Control
## True on a narrow screen (a phone): the top bar drops the player chip and tightens its buttons.
var compact_layout := false
const COMPACT_WIDTH := 1100.0
var notice_panel: PanelContainer
var notice_label: Label
var _notice_tween: Tween
var mode_buttons: Dictionary = {}
var map_buttons: Dictionary = {}
var server_dot: Panel
var server_status_label: Label
var start_button: Button
var create_button: Button
var join_button: Button
var advanced_button: Button
## "unknown" / "checking" / "online" / "none": result of the automatic server lookup (Supabase directory).
var auto_server_state := "unknown"
var auto_server_players := 0
var auto_server_capacity := 0

const BG := FPS_UI.BG
const PANEL := FPS_UI.PANEL
const ACCENT := FPS_UI.ACCENT
const MUTED := FPS_UI.MUTED

const MODE_IDS := ["ffa", "team_deathmatch", "king_of_the_hill", "demolition"]
const MODE_COLORS := {
	"ffa": Color("#25D7C2"),
	"team_deathmatch": Color("#4DA3FF"),
	"king_of_the_hill": Color("#FFC36B"),
	"demolition": Color("#FF4D5E")
}
## One accent color per map, in the same order as ArenaLayout.MAP_NAMES.
const MAP_COLORS := [
	Color("#D9A441"), Color("#B65CFF"), Color("#5B8CFF"), Color("#FF6FA8"),
	Color("#25D7C2"), Color("#58C46A"), Color("#E0653D")
]

func configure(client: Node, restored: Dictionary = {}, configured_server_host: String = "") -> void:
	backend = client
	server_host = configured_server_host.strip_edges()
	if server_host.is_empty():
		# Remember the last address the player used so it only has to be typed once.
		server_host = str(USER_SETTINGS.read_value("network", "server_host", "")).strip_edges()
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
	_render_id += 1
	preview_spin = null
	preview_model = null
	mode_buttons.clear()
	map_buttons.clear()
	nav_box = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# The whole menu is laid out in logical pixels inside a scaled root: 1.0 on PC, larger on a phone so
	# text is readable and every button is a comfortable touch target (see scripts/ui/ui_platform.gd).
	scaled_root = SCALED_ROOT.new()
	add_child(scaled_root)
	compact_layout = scaled_root.content.size.x < COMPACT_WIDTH
	scaled_root.layout_changed.connect(_on_layout_changed)
	var root_control := Control.new()
	root_control.name = "MenuRoot"
	root_control.theme = COMPETITIVE_THEME.create()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scaled_root.content.add_child(root_control)
	var base := ColorRect.new()
	base.color = BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(base)
	var art := FPS_UI.MenuBackdrop.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(art)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	root_control.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.add_theme_stylebox_override("panel", _top_bar_style())
	outer.add_child(top_bar)
	var header := HBoxContainer.new()
	top_bar.add_child(header)
	header.add_theme_constant_override("separation", 10 if compact_layout else 18)
	header.add_child(_build_brand())
	if authenticated and not is_guest:
		nav_box = HBoxContainer.new()
		nav_box.name = "MainNav"
		nav_box.add_theme_constant_override("separation", 4)
		header.add_child(nav_box)
		_refresh_nav()
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	if authenticated:
		if not compact_layout:
			header.add_child(_build_player_chip())
		var sign_out := FPS_UI.button(_t("guest_sign_in") if is_guest else _t("logout"), "ghost", 40, 14)
		sign_out.name = "SignOutButton"
		if compact_layout:
			_tighten_button(sign_out, 14, 8)
		sign_out.pressed.connect(_on_logout)
		header.add_child(sign_out)
	var language := OptionButton.new()
	language.custom_minimum_size = Vector2(70 if compact_layout else 84, 40)
	for item in [["AZ","az"],["EN","en"],["TR","tr"],["RU","ru"]]:
		language.add_item(item[0])
		language.set_item_metadata(language.item_count - 1, item[1])
	language.select(["az","en","tr","ru"].find(locale))
	language.item_selected.connect(_on_language_selected)
	header.add_child(language)

	# Floating banner for errors and hints. It sits above everything so a message is never hidden.
	notice_panel = PanelContainer.new()
	notice_panel.name = "MenuNotice"
	notice_panel.visible = false
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.anchor_left = 0.5
	notice_panel.anchor_right = 0.5
	notice_panel.anchor_top = 0.0
	notice_panel.anchor_bottom = 0.0
	notice_panel.offset_left = -310.0
	notice_panel.offset_right = 310.0
	notice_panel.offset_top = 92.0
	notice_panel.offset_bottom = 92.0
	notice_panel.grow_vertical = Control.GROW_DIRECTION_END
	notice_label = Label.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_panel.add_child(notice_label)
	root_control.add_child(notice_panel)

	if not authenticated:
		_build_auth(outer)
		_add_footer(outer)
		return

	# Tabs can be taller than a phone-landscape viewport, so they scroll vertically.
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(content_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	content_scroll.add_child(content)
	_add_footer(outer)
	if not is_guest:
		var heartbeat := Timer.new()
		heartbeat.name = "MenuPresenceHeartbeat"
		heartbeat.wait_time = 30.0
		heartbeat.autostart = true
		heartbeat.timeout.connect(_send_presence_heartbeat)
		add_child(heartbeat)
		_send_presence_heartbeat()
	_render_tab()
	if not registration_notice.is_empty():
		content.add_child(_paragraph(registration_notice))

func _top_bar_style() -> StyleBoxFlat:
	var style := FPS_UI.flat_box(Color(PANEL.r, PANEL.g, PANEL.b, 0.9), FPS_UI.EDGE, 1)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 2
	style.content_margin_left = 20
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

## Smaller type and side padding for a button, for a narrow screen. The styles are per-button copies.
func _tighten_button(button: Button, font_size: int, side_padding: float) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style != null and button.has_theme_stylebox_override(state):
			style.content_margin_left = side_padding
			style.content_margin_right = side_padding

## The window or device changed shape (rotation, a resized window): rebuild only if the top bar
## has to switch between the wide and the compact layout.
func _on_layout_changed(content_size: Vector2, _ui_scale: float) -> void:
	var compact := content_size.x < COMPACT_WIDTH
	if compact != compact_layout and is_inside_tree():
		call_deferred("_rebuild_for_layout")

func _rebuild_for_layout() -> void:
	if is_instance_valid(scaled_root) and (scaled_root.content.size.x < COMPACT_WIDTH) != compact_layout:
		_build()

func _build_brand() -> Control:
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	var first := Label.new()
	first.text = "OXEN"
	first.add_theme_font_size_override("font_size", 26 if compact_layout else 34)
	first.add_theme_color_override("font_color", FPS_UI.TEXT)
	brand.add_child(first)
	var second := Label.new()
	second.text = "WAR"
	second.add_theme_font_size_override("font_size", 26 if compact_layout else 34)
	second.add_theme_color_override("font_color", ACCENT)
	brand.add_child(second)
	return brand

func _build_player_chip() -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 10)
	var badge := ColorRect.new()
	badge.color = ACCENT
	badge.custom_minimum_size = Vector2(5, 34)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(badge)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	chip.add_child(stack)
	var name_label := Label.new()
	name_label.text = str(profile.get("username", "Player"))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", FPS_UI.TEXT)
	stack.add_child(name_label)
	var role_label := Label.new()
	role_label.text = "ADMIN" if is_admin else (_t("guest_badge") if is_guest else "PLAYER")
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", FPS_UI.GOLD if is_admin else MUTED)
	stack.add_child(role_label)
	return chip

func _refresh_nav() -> void:
	if not is_instance_valid(nav_box):
		return
	for child in nav_box.get_children():
		nav_box.remove_child(child)
		child.queue_free()
	for tab in ["play", "stats", "friends", "character"]:
		var button := FPS_UI.nav_button(_t(tab), tab == active_tab)
		button.name = "Nav_" + tab
		if compact_layout:
			_tighten_button(button, 16, 10)
		button.pressed.connect(_on_tab_pressed.bind(tab))
		nav_box.add_child(button)

func _add_footer(parent: VBoxContainer) -> void:
	# Keyboard hints mean nothing on a touch screen, so the strip is only drawn with a keyboard.
	if DisplayServer.is_touchscreen_available():
		return
	var hint := Label.new()
	hint.text = _t("footer_hint")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#5E7791"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hint)

## kind: "error" (red), "warn" (amber) or "info" (accent).
func _show_notice(text: String, kind: String = "error") -> void:
	if not is_instance_valid(notice_panel) or not is_instance_valid(notice_label):
		return
	var tint := FPS_UI.DANGER
	if kind == "warn":
		tint = FPS_UI.GOLD
	elif kind == "info":
		tint = ACCENT
	var box := FPS_UI.flat_box(Color(0.04, 0.07, 0.11, 0.97), tint, 2)
	box.border_width_left = 8
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	notice_panel.add_theme_stylebox_override("panel", box)
	notice_label.text = text
	notice_label.add_theme_color_override("font_color", FPS_UI.TEXT)
	notice_panel.modulate = Color(1, 1, 1, 0)
	notice_panel.show()
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_property(notice_panel, "modulate:a", 1.0, 0.15)
	_notice_tween.tween_interval(4.5)
	_notice_tween.tween_property(notice_panel, "modulate:a", 0.0, 0.35)
	_notice_tween.tween_callback(notice_panel.hide)

func _build_auth(parent: VBoxContainer) -> void:
	# The form is rebuilt on logout/language change with the display-name field hidden.
	registration_mode = false
	var scroll := ScrollContainer.new()
	scroll.name = "AuthScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	card.add_theme_stylebox_override("panel", FPS_UI.panel_style(0.95))
	center.add_child(card)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	card.add_child(form)
	# The quickest way in is first: a name and one button, no account.
	var guest_title := Label.new()
	guest_title.text = _t("guest_play")
	guest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guest_title.add_theme_font_size_override("font_size", 22)
	guest_title.add_theme_color_override("font_color", FPS_UI.TEXT)
	form.add_child(guest_title)
	var guest_hint := _paragraph(_t("guest_hint"))
	guest_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guest_hint.add_theme_color_override("font_color", MUTED)
	form.add_child(guest_hint)
	guest_input = _field(_t("guest_name"), "Player")
	guest_input.name = "GuestNameField"
	guest_input.max_length = 20
	guest_input.text = str(USER_SETTINGS.read_value("guest", "name", ""))
	guest_input.text_submitted.connect(func(_value: String): _on_guest_play())
	form.add_child(guest_input)
	var guest_button := _button(_t("guest_play"), true)
	guest_button.name = "GuestPlayButton"
	guest_button.custom_minimum_size.y = 56
	guest_button.pressed.connect(_on_guest_play)
	form.add_child(guest_button)
	form.add_child(HSeparator.new())
	var title := Label.new()
	title.text = _t("login_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", MUTED)
	form.add_child(title)
	var heading := _paragraph(_t("auth_hint"))
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
	# Pressing Enter/Go on the keyboard submits the form (login, or register once the name field is shown).
	password_input.text_submitted.connect(_on_auth_submitted)
	display_input.text_submitted.connect(_on_auth_submitted)
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
	message_label = _paragraph("")
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", FPS_UI.GOLD)
	form.add_child(message_label)

func _field(label_text: String, hint: String, secret: bool = false) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = label_text + " — " + hint
	field.secret = secret
	field.custom_minimum_size.y = 46
	field.add_theme_color_override("font_color", FPS_UI.TEXT)
	field.add_theme_color_override("font_placeholder_color", Color("#5E7791"))
	field.add_theme_stylebox_override("normal", _input_style())
	field.add_theme_stylebox_override("focus", _input_style(true))
	return field

func _button(label_text: String, primary: bool) -> Button:
	return FPS_UI.button(label_text, "primary" if primary else "secondary", 48.0, 17)

func _panel_style() -> StyleBoxFlat:
	return FPS_UI.panel_style(0.9)

func _input_style(focused: bool = false) -> StyleBoxFlat:
	return FPS_UI.input_style(focused)

## Play with only a name: no account, no Supabase, nothing saved online.
func _on_guest_play() -> void:
	var chosen := guest_input.text.strip_edges() if is_instance_valid(guest_input) else ""
	if chosen.is_empty():
		chosen = "Player%d" % randi_range(100, 999)
	USER_SETTINGS.write_value("guest", "name", chosen)
	is_guest = true
	is_admin = false
	cosmetics = {}
	profile = {
		"username": chosen, "display_name": chosen, "locale": locale, "guest": true,
		"avatar_color_id": "color_cyan", "outfit_id": "outfit_default", "accessory_id": "accessory_cap"
	}
	authenticated = true
	active_tab = "play"
	_build()

func _on_auth_submitted(_text: String) -> void:
	if registration_mode:
		_on_register()
	else:
		_on_login()

func _on_language_selected(index: int) -> void:
	var codes := ["az","en","tr","ru"]
	locale = codes[clampi(index, 0, 3)]
	# Rebuilding the menu recreates the login form; keep what the player already typed.
	var typed_username := username_input.text if is_instance_valid(username_input) else ""
	var typed_password := password_input.text if is_instance_valid(password_input) else ""
	var typed_display := display_input.text if is_instance_valid(display_input) else ""
	var was_registering := registration_mode
	if is_instance_valid(server_host_field):
		server_host = server_host_field.text.strip_edges()
	if authenticated and not is_guest:
		await backend.update_profile({"locale": locale})
	_build()
	if not authenticated and is_instance_valid(username_input):
		username_input.text = typed_username
		password_input.text = typed_password
		display_input.text = typed_display
		if was_registering:
			registration_mode = true
			display_input.show()

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
	if is_instance_valid(backend) and authenticated and not is_guest:
		await backend.update_presence()

func _on_tab_pressed(tab: String) -> void:
	active_tab = tab
	_refresh_nav()
	_render_tab()

func _render_tab() -> void:
	if not is_instance_valid(content):
		return
	preview_spin = null
	preview_model = null
	_render_id += 1
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if is_instance_valid(content_scroll):
		content_scroll.scroll_vertical = 0
	match active_tab:
		"play":
			_render_play_tab()
		"stats":
			await _render_stats()
		"friends":
			await _render_friends()
		"character":
			_render_character()

func _mode_title(mode_id: String) -> String:
	match mode_id:
		"ffa":
			return _t("mode_ffa")
		"team_deathmatch":
			return _t("mode_tdm")
		"king_of_the_hill":
			return _t("mode_koth")
		"demolition":
			# Same wording as the in-game Bomb Rush objective: BOMB RUSH • PLANT / DEFUSE.
			return _t("mode_bomb")
	return mode_id.to_upper()

func _mode_description(mode_id: String) -> String:
	match mode_id:
		"ffa":
			return _t("mode_desc_ffa")
		"team_deathmatch":
			return _t("mode_desc_tdm")
		"king_of_the_hill":
			return _t("mode_desc_koth")
		"demolition":
			return _t("mode_desc_bomb")
	return ""

func _render_play_tab() -> void:
	mode_buttons.clear()
	map_buttons.clear()
	var columns := HBoxContainer.new()
	columns.name = "PlayColumns"
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)

	# Left: game mode cards (like the queue list in most competitive shooters).
	var left := VBoxContainer.new()
	left.name = "ModeColumn"
	left.custom_minimum_size = Vector2(270 if compact_layout else 300, 0)
	if compact_layout:
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(FPS_UI.section_header(_t("game_mode")))
	for mode_id in MODE_IDS:
		left.add_child(_build_mode_card(mode_id))

	# Middle: the player's own character on a rotating stage. A phone has no room for it next to the
	# mode list and the start controls; the Character tab still shows the full preview.
	if not compact_layout:
		var middle := VBoxContainer.new()
		middle.name = "HeroColumn"
		middle.custom_minimum_size = Vector2(240, 0)
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.add_theme_constant_override("separation", 8)
		columns.add_child(middle)
		_build_hero(middle)

	# Right: map picker, server, one large START button and the room controls.
	var right := VBoxContainer.new()
	right.name = "StartColumn"
	right.custom_minimum_size = Vector2(360 if compact_layout else 390, 0)
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	_build_play_controls(right)
	_refresh_selection_styles()
	_refresh_server_state(server_host)
	_check_auto_server()

func _build_mode_card(mode_id: String) -> Button:
	var card := Button.new()
	card.name = "Mode_" + mode_id
	card.custom_minimum_size = Vector2(0, 86)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("margin_left", 22)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_top", 8)
	inner.add_theme_constant_override("margin_bottom", 8)
	card.add_child(inner)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	inner.add_child(stack)
	var title := Label.new()
	title.text = _mode_title(mode_id)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", FPS_UI.TEXT)
	stack.add_child(title)
	var description := Label.new()
	description.text = _mode_description(mode_id)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", MUTED)
	stack.add_child(description)
	card.pressed.connect(_on_mode_selected.bind(mode_id))
	mode_buttons[mode_id] = card
	return card

func _build_hero(parent: VBoxContainer) -> void:
	var stage_panel := PanelContainer.new()
	stage_panel.name = "HeroStage"
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_theme_stylebox_override("panel", FPS_UI.flat_box(Color("#0A1728"), FPS_UI.EDGE, 1))
	parent.add_child(stage_panel)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(220, 400)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 640)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Phones run the lobby at a lower cost: no multisampling on touch devices.
	viewport.msaa_3d = Viewport.MSAA_DISABLED if DisplayServer.is_touchscreen_available() else Viewport.MSAA_2X
	container.add_child(viewport)
	_build_character_preview_stage(viewport)
	_refresh_character_preview(
		str(profile.get("avatar_color_id", "color_cyan")),
		str(profile.get("outfit_id", "outfit_default")),
		str(profile.get("accessory_id", "accessory_cap"))
	)
	var plate := Label.new()
	plate.name = "HeroNamePlate"
	plate.text = str(profile.get("display_name", profile.get("username", "Player"))).to_upper()
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_theme_font_size_override("font_size", 24)
	plate.add_theme_color_override("font_color", FPS_UI.TEXT)
	parent.add_child(plate)

func _build_play_controls(right: VBoxContainer) -> void:
	# The action buttons are never disabled: pressing one with a missing server explains what to do.
	start_button = FPS_UI.button(_t("start_match"), "primary", 68.0, 22)
	start_button.name = "StartButton"
	start_button.pressed.connect(_launch_game.bind("quick_match"))
	right.add_child(start_button)

	var room_row := HBoxContainer.new()
	room_row.add_theme_constant_override("separation", 10)
	right.add_child(room_row)
	create_button = _button(_t("create_room"), false)
	create_button.name = "CreateRoomButton"
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.custom_minimum_size.y = 52
	create_button.pressed.connect(_launch_game.bind("create_room"))
	room_row.add_child(create_button)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	right.add_child(join_row)
	room_code_field = _field(_t("room_code"), "A1B2C3")
	room_code_field.name = "RoomCodeField"
	room_code_field.max_length = 6
	room_code_field.text = room_code_text
	room_code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_code_field.text_changed.connect(_on_room_code_changed)
	room_code_field.text_submitted.connect(func(_value: String): _launch_game("join_room"))
	join_row.add_child(room_code_field)
	join_button = _button(_t("join_room"), false)
	join_button.name = "JoinRoomButton"
	join_button.custom_minimum_size = Vector2(140, 46)
	join_button.pressed.connect(_launch_game.bind("join_room"))
	join_row.add_child(join_button)

	var server_panel := PanelContainer.new()
	server_panel.add_theme_stylebox_override("panel", _panel_style())
	right.add_child(server_panel)
	var server_stack := VBoxContainer.new()
	server_stack.add_theme_constant_override("separation", 8)
	server_panel.add_child(server_stack)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	server_stack.add_child(status_row)
	server_dot = FPS_UI.status_dot(MUTED)
	status_row.add_child(server_dot)
	server_status_label = Label.new()
	server_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_status_label.add_theme_font_size_override("font_size", 14)
	status_row.add_child(server_status_label)
	# The server is found automatically. A custom address (own server, LAN test) is an advanced option.
	advanced_button = FPS_UI.button(_t("custom_server"), "ghost", 32.0, 12)
	advanced_button.name = "CustomServerToggle"
	advanced_button.pressed.connect(_on_custom_server_toggled)
	status_row.add_child(advanced_button)
	server_host_field = _field(_t("server_address"), _t("server_hint"))
	server_host_field.name = "ServerAddressField"
	server_host_field.text = server_host
	server_host_field.visible = not server_host.is_empty()
	server_host_field.text_changed.connect(_refresh_server_state)
	server_stack.add_child(server_host_field)
	lobby_notice_label = _paragraph("")
	lobby_notice_label.add_theme_font_size_override("font_size", 13)
	server_stack.add_child(lobby_notice_label)

	right.add_child(FPS_UI.section_header(_t("map")))
	var grid := GridContainer.new()
	grid.name = "MapGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	for map_index in range(ARENA_LAYOUT.MAP_COUNT):
		var tile := Button.new()
		tile.name = "Map_%d" % map_index
		tile.text = ARENA_LAYOUT.map_name(map_index)
		tile.custom_minimum_size = Vector2(0, 52)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tile.clip_text = true
		tile.focus_mode = Control.FOCUS_ALL
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.add_theme_font_size_override("font_size", 15)
		tile.add_theme_color_override("font_color", FPS_UI.TEXT)
		tile.pressed.connect(_on_map_selected.bind(map_index))
		map_buttons[map_index] = tile
		grid.add_child(tile)

func _on_mode_selected(mode_id: String) -> void:
	selected_game_mode = mode_id
	_refresh_selection_styles()

func _on_map_selected(map_index: int) -> void:
	selected_map_index = ARENA_LAYOUT.sanitize_map(map_index)
	_refresh_selection_styles()

func _refresh_selection_styles() -> void:
	for mode_id in mode_buttons.keys():
		var card: Button = mode_buttons[mode_id]
		if is_instance_valid(card):
			FPS_UI.style_card(card, MODE_COLORS.get(mode_id, ACCENT), str(mode_id) == selected_game_mode)
	for map_index in map_buttons.keys():
		var tile: Button = map_buttons[map_index]
		if is_instance_valid(tile):
			FPS_UI.style_card(tile, MAP_COLORS[int(map_index) % MAP_COLORS.size()], int(map_index) == selected_map_index)

func _on_room_code_changed(value: String) -> void:
	var upper := value.to_upper()
	if is_instance_valid(room_code_field) and upper != value:
		var caret := room_code_field.caret_column
		room_code_field.text = upper
		room_code_field.caret_column = caret
	room_code_text = upper

func _on_custom_server_toggled() -> void:
	if not is_instance_valid(server_host_field):
		return
	server_host_field.visible = not server_host_field.visible
	if server_host_field.visible:
		server_host_field.grab_focus()

## Looks for a server without any typed address: the Supabase directory (signed-in players), then open
## servers on this network. Runs every time the play tab is shown.
func _check_auto_server() -> void:
	var render_token := _render_id
	if auto_server_state == "unknown":
		auto_server_state = "checking"
		_refresh_server_state(server_host)
	var found: Dictionary = {}
	if backend != null and backend.has_method("find_server"):
		found = await backend.find_server()
		if render_token != _render_id or not is_instance_valid(server_dot):
			return
	if found.get("ok", false):
		auto_server_state = "online"
		auto_server_players = int(found.get("player_count", 0))
		auto_server_capacity = int(found.get("max_players", 0))
		_refresh_server_state(server_host)
		return
	auto_server_state = "none"
	_refresh_server_state(server_host)
	if not lan_scan_enabled or not is_inside_tree():
		return
	var servers: Array = await LAN_DISCOVERY.scan(get_tree(), 1.0)
	if render_token != _render_id or not is_instance_valid(server_dot):
		return
	if not servers.is_empty():
		var best: Dictionary = LAN_DISCOVERY.best_server(servers)
		auto_server_state = "lan"
		auto_server_players = int(best.get("players", 0))
		auto_server_capacity = int(best.get("max", 0))
		_refresh_server_state(server_host)

## Updates the status light, helper text and START label from the custom address or the automatic lookup.
func _refresh_server_state(value: String) -> void:
	var address := value.strip_edges()
	server_host = address
	var state_color: Color = MUTED
	var status_text := ""
	var hint_text := ""
	if not address.is_empty():
		if _is_server_address_valid(address):
			state_color = ACCENT
			status_text = _t("server_custom")
			hint_text = _t("server_ready")
		else:
			state_color = FPS_UI.DANGER
			status_text = _t("server_status_bad")
			hint_text = _t("server_invalid")
	elif auto_server_state == "online":
		state_color = ACCENT
		status_text = _t("server_auto_online")
		if auto_server_capacity > 0:
			status_text += "  •  %d/%d" % [auto_server_players, auto_server_capacity]
		hint_text = _t("auto_hint")
	elif auto_server_state == "lan":
		state_color = ACCENT
		status_text = _t("server_lan_online")
		if auto_server_capacity > 0:
			status_text += "  •  %d/%d" % [auto_server_players, auto_server_capacity]
		hint_text = _t("auto_hint")
	elif auto_server_state == "none":
		state_color = FPS_UI.GOLD
		status_text = _t("server_auto_none")
		hint_text = _t("auto_none_hint")
	else:
		status_text = _t("server_auto_checking")
		hint_text = _t("auto_hint")
	FPS_UI.set_status_dot(server_dot, state_color)
	if is_instance_valid(server_status_label):
		server_status_label.text = status_text
		server_status_label.add_theme_color_override("font_color", state_color)
	if is_instance_valid(lobby_notice_label):
		lobby_notice_label.text = hint_text
		lobby_notice_label.add_theme_color_override("font_color", MUTED if state_color != FPS_UI.DANGER else state_color)
	if is_instance_valid(start_button):
		start_button.text = _t("start_training") if (address.is_empty() and auto_server_state == "none") else _t("start_match")

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

func _focus_field(field: LineEdit) -> void:
	if is_instance_valid(field):
		field.grab_focus()

func _launch_game(action: String) -> void:
	var host := server_host_field.text.strip_edges() if is_instance_valid(server_host_field) else server_host
	var room_code := room_code_field.text.strip_edges().to_upper() if is_instance_valid(room_code_field) else room_code_text
	if not host.is_empty() and not _is_server_address_valid(host):
		_show_notice(_t("server_invalid"), "error")
		server_host_field.show()
		_focus_field(server_host_field)
		return
	# With no custom address the game finds the server itself. When the lookup already found nothing,
	# rooms cannot work; START still opens the offline training arena.
	if action == "join_room" and not _is_valid_room_code(room_code):
		_show_notice(_t("room_code_invalid"), "error")
		_focus_field(room_code_field)
		return
	# Nothing blocks CREATE ROOM or JOIN any more: the game looks for a server itself, finds an open one on
	# this network by room code, and CREATE ROOM hosts the room on this device when nothing else exists.
	# An empty value clears an old custom address so the automatic lookup is used again.
	USER_SETTINGS.write_value("network", "server_host", host)
	play_requested.emit({
		"display_name": str(profile.get("display_name", profile.get("username", "Player"))),
		"profile": profile,
		"is_admin": is_admin,
		"launch_action": action,
		"game_mode": selected_game_mode,
		"map_index": selected_map_index,
		"room_code": room_code,
		"server_host": host,
		"guest": is_guest
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
	var my_render := _render_id
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
	if my_render != _render_id or not is_instance_valid(content):
		return
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
	var stat_grid := GridContainer.new()
	stat_grid.columns = 3
	stat_grid.add_theme_constant_override("h_separation", 10)
	stat_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(stat_grid)
	for index in range(cards.size()):
		stat_grid.add_child(_stat_tile(str(cards[index][0]), str(cards[index][1])))

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
	var my_render := _render_id
	content.add_child(_large_label(_t("friends")))
	var search_row := HBoxContainer.new()
	var search_field := _field(_t("search"), "Cemil_123")
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(search_field)
	var search_button := _button(_t("search"), true)
	var search_results := VBoxContainer.new()
	search_button.pressed.connect(func(): await _search_players(search_field.text, search_results))
	search_row.add_child(search_button)
	content.add_child(search_row)
	content.add_child(search_results)
	var requests_title := _label(_t("requests"))
	content.add_child(requests_title)
	var requests: Dictionary = await backend.get_friend_requests()
	if my_render != _render_id or not is_instance_valid(content):
		return
	if requests.get("ok", false):
		for request in requests.get("data", []):
			var incoming := str(request.get("receiver_id")) == str(backend.user_id)
			var row := HBoxContainer.new()
			var other_id := str(request.get("sender_id", "") if incoming else request.get("receiver_id", ""))
			var other_profile: Dictionary = await backend.get_profile_by_id(other_id)
			if my_render != _render_id or not is_instance_valid(content):
				return
			var other_name := str(other_profile.get("username", other_id.substr(0, 8)))
			var who := _label(("From " if incoming else "To ") + other_name)
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(who)
			if incoming:
				var accept := _button(_t("accept"), true)
				accept.pressed.connect(func():
					await backend.respond_friend_request(str(request.get("id")), true)
					if active_tab == "friends":
						_render_tab()
				)
				row.add_child(accept)
				var reject := _button(_t("reject"), false)
				reject.pressed.connect(func():
					await backend.respond_friend_request(str(request.get("id")), false)
					if active_tab == "friends":
						_render_tab()
				)
				row.add_child(reject)
			else:
				row.add_child(_label(_t("pending")))
			content.add_child(row)
	var friends_title := _label(_t("friends"))
	content.add_child(friends_title)
	var friends: Dictionary = await backend.get_friends()
	if my_render != _render_id or not is_instance_valid(content):
		return
	if friends.get("ok", false):
		var friend_rows: Array = friends.get("data", [])
		var friend_ids := PackedStringArray()
		for friend in friend_rows:
			friend_ids.append(str(friend.get("id", "")))
		var presence_result: Dictionary = await backend.get_friend_presence(friend_ids)
		if my_render != _render_id or not is_instance_valid(content):
			return
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
			content.add_child(_presence_row(str(friend.get("username", "Player")), online, status_text))
		if friends.get("data", []).is_empty():
			content.add_child(_label(_t("no_results")))
	else:
		content.add_child(_label(str(friends.get("message", ""))))

func _search_players(query: String, target: VBoxContainer) -> void:
	_player_search_id += 1
	var search_id := _player_search_id
	var render_id := _render_id
	var result: Dictionary = await backend.search_players(query.strip_edges())
	if search_id != _player_search_id or render_id != _render_id or not is_instance_valid(target):
		return
	# Replace the previous search results instead of piling new rows below them.
	for old_row in target.get_children():
		target.remove_child(old_row)
		old_row.queue_free()
	if not result.get("ok", false):
		target.add_child(_label(str(result.get("message", ""))))
		return
	var rows: Array = result.get("data", [])
	if rows.is_empty():
		target.add_child(_label(_t("no_results")))
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
		target.add_child(row)

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
	color_option.name = "ColorOption"
	var outfit_option := OptionButton.new()
	outfit_option.name = "OutfitOption"
	var accessory_option := OptionButton.new()
	accessory_option.name = "AccessoryOption"
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

	# Failed/empty inventory must retain the actual equipped appearance in the preview.
	# A read-only current value also explains why a slot cannot be changed yet.
	_current_cosmetic_fallback(color_option, "avatar_color_id", "color_cyan")
	_current_cosmetic_fallback(outfit_option, "outfit_id", "outfit_default")
	_current_cosmetic_fallback(accessory_option, "accessory_id", "accessory_cap")
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
		# Keep the Save button: an empty slot simply keeps the value already on the profile.
		controls.add_child(_label("Some cosmetic slots are locked or not available yet. The 3D preview still shows your current/default character."))
	var save := _button(_t("save"), true)
	save.name = "SaveCosmeticsButton"
	save.disabled = color_option.disabled and outfit_option.disabled and accessory_option.disabled
	save.pressed.connect(func():
		if not is_instance_valid(backend) or save.disabled:
			return
		var changes := {}
		if not color_option.disabled:
			changes["avatar_color_id"] = _selected_cosmetic_id(color_option, "color_cyan")
		if not outfit_option.disabled:
			changes["outfit_id"] = _selected_cosmetic_id(outfit_option, "outfit_default")
		if not accessory_option.disabled:
			changes["accessory_id"] = _selected_cosmetic_id(accessory_option, "accessory_cap")
		save.disabled = true
		var account_id := str(backend.user_id)
		var saved: Dictionary = await backend.update_profile(changes)
		if not authenticated or not is_instance_valid(backend) or str(backend.user_id) != account_id:
			return
		if saved.get("ok", false):
			profile.merge(changes, true)
		if is_instance_valid(save):
			save.disabled = false
			save.text = _t("save") + " ✓" if saved.get("ok", false) else _t("error")
	)
	controls.add_child(save)

func _current_cosmetic_fallback(option: OptionButton, key: String, default_id: String) -> void:
	if option.item_count > 0:
		return
	var value: Variant = profile.get(key, default_id)
	var current := default_id if value == null or str(value).is_empty() else str(value)
	option.add_item(current.replace("outfit_", "").replace("color_", "").replace("accessory_", "").replace("_", " ").capitalize() + " (current)")
	option.set_item_metadata(0, current)
	option.select(0)
	option.disabled = true
	option.tooltip_text = "Current equipment. Inventory is unavailable or this slot has no unlocked alternatives."


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
	camera.current = true
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.96, 0), Vector3.UP)

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
		preview_spin.remove_child(child)
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
	_add_preview_accessory(body, accessory_id, avatar_color)

	# Same hero armor as in-game, fitted to the slim torso.
	CHARACTER_VISUALS.add_hero_details(body, outfit_id)

	# The skinned in-game character (looping Idle clip). The procedural body above stays in the tree but is
	# given no render layer, so the preview shows exactly what other players see.
	var avatar := SKELETAL_AVATAR.new()
	if avatar.build(outfit_id, avatar_color):
		preview_model.add_child(avatar)
		for node in body.find_children("*", "VisualInstance3D", true, false):
			(node as VisualInstance3D).layers = 0
		body.layers = 0
	else:
		avatar.free()

func _add_preview_accessory(body: Node3D, accessory_id: String, avatar_color: Color) -> void:
	# Same head-fitted accessory as in-game.
	CHARACTER_VISUALS.add_accessory(body, accessory_id, avatar_color)

func _preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.18
	return material

func _on_logout() -> void:
	if not is_guest:
		await backend.sign_out()
	is_guest = false
	authenticated = false
	profile.clear()
	is_admin = false
	_build()

func _large_label(value: String) -> Label:
	var label := _label(value)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", ACCENT)
	return label

## Short text stays on one line. A wrapping label inside a row collapses to a sliver, so only long
## text (notices, explanations) wraps, and rows of short labels do not.
func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", FPS_UI.TEXT)
	if value.length() > 48:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

## Always wraps; use it directly inside a vertical container, never as a bare child of a row.
func _paragraph(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", FPS_UI.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _stat_tile(key_text: String, value_text: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := FPS_UI.panel_style(0.9)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	tile.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	tile.add_child(stack)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 30)
	value_label.add_theme_color_override("font_color", ACCENT)
	stack.add_child(value_label)
	var key_label := Label.new()
	key_label.text = key_text
	key_label.clip_text = true
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", MUTED)
	stack.add_child(key_label)
	return tile

func _presence_row(name_text: String, online: bool, status_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(FPS_UI.status_dot(ACCENT if online else Color("#4B5C6D")))
	var name_label := Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", FPS_UI.TEXT)
	row.add_child(name_label)
	var status_label := Label.new()
	status_label.text = status_text
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", ACCENT if online else MUTED)
	row.add_child(status_label)
	return row
