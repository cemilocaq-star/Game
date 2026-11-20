extends SubViewportContainer
## One shared model uses the same builder as the first-person weapon.

const WEAPON_VISUALS := preload("res://scripts/arcade_weapon_visuals.gd")
var _viewport := SubViewport.new()
var _stage := Node3D.new()
var _camera := Camera3D.new()
var _model: Node3D


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_viewport.add_child(_stage)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_stage.add_child(_camera)
	for direction: Vector3 in [Vector3(-35, -38, 0), Vector3(-15, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = direction
		light.light_energy = 1.05
		_stage.add_child(light)


func show_weapon(weapon_id: String, tint: Color) -> void:
	if is_instance_valid(_model):
		_model.free()
	_model = WEAPON_VISUALS.build_weapon(weapon_id, tint)
	_stage.add_child(_model)
	var bounds := AABB()
	var first := true
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		var part := piece.global_transform * piece.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	var center := bounds.get_center()
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	_camera.size = maxf(0.5, extent * 1.30)
	_camera.position = center + Vector3(2.4, 1.1, -1.5)
	_camera.look_at(center)


func rotate_model() -> void:
	if is_instance_valid(_model):
		_model.rotate_y(PI / 2.0)
