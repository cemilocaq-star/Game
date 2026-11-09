extends CanvasLayer
signal play_requested(identity: Dictionary)

const I18N = preload("res://scripts/oxenwar_i18n.gd")
var backend: Node
var locale := "az"
var profile: Dictionary = {}
var authenticated := false
var is_admin := false
var active_tab := "play"
var email_input: LineEdit
var password_input: LineEdit
var display_input: LineEdit
var username_input: LineEdit
var message_label: Label
var content: VBoxContainer
var cosmetics: Dictionary = {}
var registration_notice := ""

const BG := Color("#07111F")
const PANEL := Color("#101F32")
const ACCENT := Color("#25D7C2")
const MUTED := Color("#91A5B8")

func configure(client: Node, restored: Dictionary = {}) -> void:
	backend = client
	if restored.get("ok", false):
		await _load_account()
	_build()

func _ready() -> void:
	pass

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
	email_input = _field(_t("email"), "name@example.com")
	form.add_child(email_input)
	password_input = _field(_t("password"), "••••••••", true)
	form.add_child(password_input)
	display_input = _field(_t("display_name"), "Player")
	form.add_child(display_input)
	username_input = _field(_t("username") + " (3–20)", "Player_01")
	form.add_child(username_input)
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
	if email_input.text.strip_edges().is_empty() or password_input.text.is_empty():
		message_label.text = _t("error") + ": " + _t("email") + " / " + _t("password")
		return
	message_label.text = "..."
	var result: Dictionary = await backend.sign_in(email_input.text, password_input.text)
	if not result.get("ok", false):
		message_label.text = _t("error") + ": " + str(result.get("message", ""))
		return
	registration_notice = ""
	await _load_account()
	_build()

func _on_register() -> void:
	if email_input.text.strip_edges().is_empty() or password_input.text.length() < 8:
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
	var result: Dictionary = await backend.sign_up(email_input.text, password_input.text, chosen_name, chosen_username, locale)
	if not result.get("ok", false):
		message_label.text = _t("error") + ": " + str(result.get("message", ""))
		return
	if result.get("needs_email_confirmation", false):
		message_label.text = _t("confirm_email")
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
	for child in content.get_children():
		child.queue_free()
	match active_tab:
		"play":
			var title := _large_label("OXENWAR")
			content.add_child(title)
			var desc := _label("Free-to-play parkour arena  •  Friends  •  Character style")
			content.add_child(desc)
			var start := _button(_t("start"), true)
			start.custom_minimum_size = Vector2(0, 64)
			start.pressed.connect(func():
				play_requested.emit({
					"display_name": str(profile.get("display_name", profile.get("username", "Player"))),
					"profile": profile,
					"is_admin": is_admin
				})
			)
			content.add_child(start)
			var logout := _button(_t("logout"), false)
			logout.pressed.connect(_on_logout)
			content.add_child(logout)
		"stats":
			await _render_stats()
		"friends":
			await _render_friends()
		"character":
			_render_character()

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
	if stats.is_empty():
		loading.text = _t("stats_empty")
		return
	loading.queue_free()
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
	content.add_child(_large_label(_t("character") + "  •  " + _t("free")))
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
	content.add_child(_label(_t("choose_color")))
	content.add_child(color_option)
	content.add_child(_label(_t("choose_outfit")))
	content.add_child(outfit_option)
	content.add_child(_label("Accessory"))
	content.add_child(accessory_option)
	if color_items.is_empty() or outfit_items.is_empty() or accessory_items.is_empty():
		content.add_child(_label("Free cosmetics will appear after your account has unlocked its starter inventory."))
		return
	for i in color_items.size():
		if str(color_items[i].get("id")) == str(profile.get("avatar_color_id", "")):
			color_option.select(i)
	for i in outfit_items.size():
		if str(outfit_items[i].get("id")) == str(profile.get("outfit_id", "")):
			outfit_option.select(i)
	for i in accessory_items.size():
		if str(accessory_items[i].get("id")) == str(profile.get("accessory_id", "")):
			accessory_option.select(i)
	var save := _button(_t("save"), true)
	save.pressed.connect(func():
		var saved: Dictionary = await backend.update_profile({
			"avatar_color_id": str(color_option.get_item_metadata(color_option.selected)),
			"outfit_id": str(outfit_option.get_item_metadata(outfit_option.selected)),
			"accessory_id": str(accessory_option.get_item_metadata(accessory_option.selected))
		})
		if saved.get("ok", false):
			profile = await backend.get_profile()
			save.text = _t("save") + " ✓"
		else:
			save.text = _t("error")
	)
	content.add_child(save)

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
