extends SceneTree
const HUD := preload("res://scripts/ui/game_hud.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for admin in [false,true]:
		for width in [640.0,711.0,800.0,1000.0]:
			var content := Control.new()
			root.add_child(content)
			content.size = Vector2(width,450)
			HUD.build(content,true,50.0,{"admin":admin})
			await process_frame
			var score := content.get_node("ScorePlate") as Control
			var timer := content.get_node("RoundPlate") as Control
			var nav := content.get_node("SystemBar") as Control
			for neighbor in [score,nav]:
				if timer.get_rect().intersects(neighbor.get_rect()):failures.append("timer overlaps top HUD at width %s admin=%s" % [width,admin])
			if not Rect2(Vector2.ZERO,content.size).encloses(timer.get_rect()):failures.append("timer outside content")
			content.size.x += 50.0
			await process_frame
			if timer.get_rect().intersects(nav.get_rect()):failures.append("timer not reflowed after resize")
			content.free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: touch clock avoids score/navigation at four widths, admin mode and resize")
	quit(0 if failures.is_empty() else 1)
