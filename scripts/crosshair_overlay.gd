extends Control
## Client-only combat feedback drawn on top of the 3D view: crosshair, hit marker and a
## red edge flash when the local player takes damage. It never touches gameplay state.

const CROSSHAIR_COLOR := Color(0.88, 1.0, 0.96, 0.92)
const CROSSHAIR_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const HIT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const KILL_COLOR := Color(1.0, 0.32, 0.30, 1.0)
const HIT_DURATION := 0.22
const DAMAGE_DURATION := 0.55

var _hit_left := 0.0
var _hit_was_kill := false
var _damage_left := 0.0
var _damage_strength := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 5

## Short "X" marker around the crosshair when one of our shots was confirmed by the server.
func flash_hit(is_kill: bool = false) -> void:
	_hit_left = HIT_DURATION
	_hit_was_kill = is_kill
	queue_redraw()

## Red edge flash; `lost_health` (HP) scales how strong it is.
func flash_damage(lost_health: float = 20.0) -> void:
	_damage_strength = clampf(lost_health / 40.0, 0.25, 1.0)
	_damage_left = DAMAGE_DURATION
	queue_redraw()

func _process(delta: float) -> void:
	if _hit_left > 0.0 or _damage_left > 0.0:
		_hit_left = maxf(0.0, _hit_left - delta)
		_damage_left = maxf(0.0, _damage_left - delta)
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	# Crosshair: four short ticks around a small gap plus a dot.
	var gap := 6.0
	var length := 9.0
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from_point: Vector2 = center + direction * gap
		var to_point: Vector2 = center + direction * (gap + length)
		draw_line(from_point + Vector2(1, 1), to_point + Vector2(1, 1), CROSSHAIR_SHADOW, 3.0)
		draw_line(from_point, to_point, CROSSHAIR_COLOR, 2.0)
	draw_circle(center, 1.8, CROSSHAIR_COLOR)
	if _hit_left > 0.0:
		var alpha := clampf(_hit_left / HIT_DURATION, 0.0, 1.0)
		var marker_color := KILL_COLOR if _hit_was_kill else HIT_COLOR
		marker_color.a = alpha
		var inner := 8.0
		var outer := 17.0 if _hit_was_kill else 14.0
		for diagonal in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var normalized: Vector2 = diagonal.normalized()
			draw_line(center + normalized * inner, center + normalized * outer, marker_color, 2.5)
	if _damage_left > 0.0:
		var fade := clampf(_damage_left / DAMAGE_DURATION, 0.0, 1.0) * _damage_strength
		var layers := 7
		for layer in range(layers):
			var thickness := 10.0 + float(layer) * 10.0
			var layer_alpha := fade * 0.34 * (1.0 - float(layer) / float(layers))
			var tint := Color(0.95, 0.06, 0.12, layer_alpha)
			draw_rect(Rect2(0.0, 0.0, size.x, thickness), tint)
			draw_rect(Rect2(0.0, size.y - thickness, size.x, thickness), tint)
			draw_rect(Rect2(0.0, 0.0, thickness, size.y), tint)
			draw_rect(Rect2(size.x - thickness, 0.0, thickness, size.y), tint)
