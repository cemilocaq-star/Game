extends RefCounted
## Shared idempotent default bindings for gameplay and standalone player scenes.
static func ensure() -> void:
	_add_key_action("throw_grenade", KEY_G)
	_add_key_action("objective_interact", KEY_F)
	_add_key_action("weapon_next", KEY_E)
	_add_key_action("weapon_prev", KEY_R)
	_add_key_action("toggle_view", KEY_C)
	_add_key_action("reload", KEY_T)
	_add_key_action("emote_griddy", KEY_B)
	_add_key_action("emote_goofy", KEY_N)
	_add_key_action("emote_robot", KEY_M)
	_add_key_action("emote_wave", KEY_J)
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("slide", KEY_CTRL)
	_add_key_action("dash", KEY_Q)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	var fire_mouse := InputEventMouseButton.new()
	fire_mouse.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("fire", fire_mouse):
		InputMap.action_add_event("fire", fire_mouse)
	_add_key_action("move_forward", KEY_UP)
	_add_key_action("move_back", KEY_DOWN)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_RIGHT)

static func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

