extends SceneTree
## CI-only visual check: renders every signature costume (plus the default
## character) from three angles and saves PNGs plus one contact sheet.
##
## Needs a display, so CI runs it under xvfb with software OpenGL. It is a
## screenshot generator, not an assertion test: it exits non-zero only when no
## usable image could be captured.
##
## Output: $PREVIEW_DIR/<outfit>_<view>.png and contact_sheet.png
## (rows: default, Golden Pilot, Ghost-Ops, Neon Cyan Riot; columns: front,
## three-quarter, back, run pose).

const CHARACTER_VISUALS := preload("res://scripts/character_visuals.gd")
const CHARACTER_MOTION_RIG := preload("res://scripts/character_motion_rig.gd")

const OUTFITS := ["outfit_default", "outfit_runner", "outfit_ghost_ops", "outfit_neon"]
# The camera looks down -Z from +Z and a character faces -Z, so yaw 180 turns the
# face toward the camera ("front") and yaw 0 shows the back.
# "run" is a three-quarter view with the run-cycle pose applied to the limb rig.
const VIEWS := {"front": 180.0, "three_quarter": 140.0, "back": 0.0, "run": 140.0}
const SHOT_SIZE := Vector2i(420, 620)
const SETTLE_FRAMES := 4
const AVATAR_COLOR := Color("#27D7E7")

var _viewport: SubViewport
var _model: Node3D
var _shots: Array = []
var _shot_index := 0
var _frames_waited := 0
var _out_dir := ""
var _images: Array[Image] = []
var _failed := false


func _initialize() -> void:
	# CI passes a directory outside the project so screenshots never end up in exports.
	_out_dir = OS.get_environment("PREVIEW_DIR")
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("res://build/character_previews")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	for outfit in OUTFITS:
		for view_name in VIEWS.keys():
			_shots.append([outfit, view_name, VIEWS[view_name]])

	_viewport = SubViewport.new()
	_viewport.size = SHOT_SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8FA3B5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.9
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_energy = 1.15
	_viewport.add_child(sun)

	# A ground disc at y = 0 shows whether feet sit on, above or below the floor.
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2
	disc.bottom_radius = 2.2
	disc.height = 0.02
	floor_mesh.mesh = disc
	floor_mesh.position = Vector3(0.0, -0.01, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#5B6B58")
	floor_material.roughness = 0.95
	floor_mesh.material_override = floor_material
	_viewport.add_child(floor_mesh)

	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.current = true
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.15, 4.6), Vector3(0.0, 0.98, 0.0), Vector3.UP)

	_show_shot(0)


func _show_shot(index: int) -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	var shot: Array = _shots[index]
	var outfit: String = shot[0]
	var yaw: float = shot[2]

	_model = Node3D.new()
	_model.rotation_degrees.y = yaw
	_viewport.add_child(_model)

	var suit_color: Color = CHARACTER_VISUALS.suit_color_for(outfit, AVATAR_COLOR)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = suit_color
	body_material.metallic = 0.08
	body_material.roughness = 0.62
	body.material_override = body_material
	_model.add_child(body)
	CHARACTER_VISUALS.apply_body_shape(body, outfit)
	CHARACTER_VISUALS.build(body, outfit, AVATAR_COLOR)
	var rig: Node3D = CHARACTER_MOTION_RIG.build(body, suit_color, outfit)
	if str(shot[1]) == "run":
		CHARACTER_MOTION_RIG.animate(rig, 0.37, 6.0, true, false, "", 1.0)
	_frames_waited = 0


func _process(_delta: float) -> bool:
	if _failed:
		return true
	_frames_waited += 1
	if _frames_waited < SETTLE_FRAMES:
		return false

	var shot: Array = _shots[_shot_index]
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("render_character_previews: viewport returned no image for %s/%s" % [shot[0], shot[1]])
		_failed = true
		quit(1)
		return true
	image.convert(Image.FORMAT_RGB8)
	_images.append(image)
	var file_path := "%s/%s_%s.png" % [_out_dir, str(shot[0]).trim_prefix("outfit_"), shot[1]]
	var save_error := image.save_png(file_path)
	if save_error != OK:
		push_error("render_character_previews: could not save %s (error %d)" % [file_path, save_error])
		_failed = true
		quit(1)
		return true
	print("saved ", file_path)

	_shot_index += 1
	if _shot_index >= _shots.size():
		_write_contact_sheet()
		print("PASS: rendered %d character screenshots" % _images.size())
		quit(0)
		return true
	_show_shot(_shot_index)
	return false


func _write_contact_sheet() -> void:
	var columns := VIEWS.size()
	var rows := OUTFITS.size()
	var sheet := Image.create(SHOT_SIZE.x * columns, SHOT_SIZE.y * rows, false, Image.FORMAT_RGB8)
	for index in range(_images.size()):
		var column := index % columns
		var row := floori(float(index) / float(columns))
		sheet.blit_rect(_images[index], Rect2i(Vector2i.ZERO, SHOT_SIZE), Vector2i(column * SHOT_SIZE.x, row * SHOT_SIZE.y))
	var sheet_path := _out_dir + "/contact_sheet.png"
	if sheet.save_png(sheet_path) == OK:
		print("saved ", sheet_path)
