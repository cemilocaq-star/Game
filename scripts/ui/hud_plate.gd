extends Control
## A dark glass plate with two chamfered corners and a thin accent edge. Used behind every HUD group
## so text and icons stay readable over any map.

const THEME := preload("res://scripts/ui/ui_theme.gd")

@export var fill: Color = THEME.PANEL:
	set(value):
		fill = value
		queue_redraw()
@export var edge: Color = THEME.ACCENT_DIM:
	set(value):
		edge = value
		queue_redraw()
@export var cut: float = THEME.CHAMFER:
	set(value):
		cut = value
		queue_redraw()
## A short bright bar along the left side, in the plate's meaning colour (team, rarity, event).
@export var accent: Color = Color.TRANSPARENT:
	set(value):
		accent = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var points := THEME.chamfer_points(rect, cut)
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, edge, 1.5, true)
	if accent.a > 0.01:
		draw_rect(Rect2(0.0, cut, 3.0, maxf(size.y - cut * 2.0, 4.0)), accent)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
