extends SceneTree
## Exercises the exact input-state transitions used by the mobile analog joystick.

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const MENU_SCRIPT := preload("res://scripts/oxenwar_menu.gd")
const MOVE_ACTIONS := [
	"move_left",
	"move_right",
	"move_forward",
	"move_back"
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	for action in MOVE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)

	var harness := Node3D.new()
	harness.set_script(MAIN_SCRIPT)

	harness.call("_set_mobile_move_input", Vector2(-1.0, 0.0))
	_assert_pressed("direct left input", {
		"move_left": true,
		"move_right": false,
		"move_forward": false,
		"move_back": false
	})

	harness.call("_set_mobile_move_input", Vector2(0.8, 0.0))
	_assert_pressed("left-to-right reversal", {
		"move_left": false,
		"move_right": true,
		"move_forward": false,
		"move_back": false
	})
	_assert_strength("right analog strength", "move_right", 0.8)

	harness.call("_set_mobile_move_input", Vector2(0.0, -0.65))
	_assert_pressed("forward input", {
		"move_left": false,
		"move_right": false,
		"move_forward": true,
		"move_back": false
	})
	_assert_strength("forward analog strength", "move_forward", 0.65)

	harness.call("_set_mobile_move_input", Vector2(0.0, 0.75))
	_assert_pressed("forward-to-back reversal", {
		"move_left": false,
		"move_right": false,
		"move_forward": false,
		"move_back": true
	})

	harness.call("_set_mobile_move_input", Vector2(-0.4, -0.6))
	_assert_pressed("diagonal input", {
		"move_left": true,
		"move_right": false,
		"move_forward": true,
		"move_back": false
	})

	harness.call("_set_mobile_move_input", Vector2.ZERO)
	_assert_pressed("return to neutral", {
		"move_left": false,
		"move_right": false,
		"move_forward": false,
		"move_back": false
	})

	var menu_harness := CanvasLayer.new()
	menu_harness.set_script(MENU_SCRIPT)
	_assert_true("valid WSS URL", bool(menu_harness.call("_is_server_address_valid", "wss://oxenwar.example.onrender.com")))
	_assert_true("valid UDP hostname", bool(menu_harness.call("_is_server_address_valid", "game.example.com")))
	_assert_true("valid IPv4 address", bool(menu_harness.call("_is_server_address_valid", "192.0.2.10")))
	_assert_true("valid localhost address", bool(menu_harness.call("_is_server_address_valid", "localhost")))
	_assert_false("reject HTTPS scheme", bool(menu_harness.call("_is_server_address_valid", "https://oxenwar.example.com")))
	_assert_false("reject empty WSS host", bool(menu_harness.call("_is_server_address_valid", "wss://")))
	_assert_false("reject whitespace in address", bool(menu_harness.call("_is_server_address_valid", "game server.example.com")))
	_assert_true("valid room code", bool(menu_harness.call("_is_valid_room_code", "AB234C")))
	_assert_false("reject ambiguous room-code characters", bool(menu_harness.call("_is_valid_room_code", "ABO01C")))
	_assert_false("reject short room code", bool(menu_harness.call("_is_valid_room_code", "ABC12")))

	menu_harness.free()
	harness.free()
	for action in MOVE_ACTIONS:
		Input.action_release(action)

	if failures.is_empty():
		print("PASS: joystick reversals, analog strengths, diagonal/neutral input, server address validation and room-code validation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert_pressed(label: String, expected: Dictionary) -> void:
	for action in MOVE_ACTIONS:
		var wanted := bool(expected.get(action, false))
		var actual := Input.is_action_pressed(action)
		if actual != wanted:
			failures.append("%s: %s expected pressed=%s, got %s" % [label, action, wanted, actual])


func _assert_strength(label: String, action: String, expected: float) -> void:
	var actual := Input.get_action_strength(action)
	if absf(actual - expected) > 0.02:
		failures.append("%s: expected strength %.2f, got %.2f" % [label, expected, actual])

func _assert_true(label: String, actual: bool) -> void:
	if not actual:
		failures.append("%s: expected true" % label)


func _assert_false(label: String, actual: bool) -> void:
	if actual:
		failures.append("%s: expected false" % label)
