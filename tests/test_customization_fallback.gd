extends SceneTree
const MENU := preload("res://scripts/oxenwar_menu.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:failures.append(message)
func run() -> void:
	var menu := MENU.new()
	root.add_child(menu)
	menu.authenticated = true
	menu.locale = "en"
	menu.profile = {"display_name":"Fixture", "outfit_id":"outfit_ghost_ops", "avatar_color_id":"color_violet", "accessory_id":"accessory_headphones"}
	menu.cosmetics = {"inventory":[],"catalog":[]}
	menu.active_tab = "character"
	menu._build()
	await process_frame
	for entry in [["OutfitOption","outfit_ghost_ops"],["ColorOption","color_violet"],["AccessoryOption","accessory_headphones"]]:
		var option := menu.find_child(entry[0],true,false) as OptionButton
		check(option != null and option.disabled,"unavailable slot is explicitly read-only")
		if option != null:check(menu._selected_cosmetic_id(option,"bad") == entry[1],"unavailable inventory retains equipped " + entry[1])
	check(menu.preview_model != null,"current character still previews")
	var skeletons := menu.preview_model.find_children("*","Skeleton3D",true,false)
	check(not skeletons.is_empty(),"equipped Ghost costume uses skeletal attachment rig in preview")
	var cameras := menu.find_children("*","Camera3D",true,false)
	check(not cameras.is_empty(),"preview camera exists")
	for camera: Camera3D in cameras:
		var target := Vector3(0,.96,0)
		check((-camera.global_basis.z).dot((target-camera.global_position).normalized()) > .99,"preview camera actually aims at character after entering tree")
	menu.free()
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: current appearance survives missing inventory and preview camera targets character")
	quit(0 if failures.is_empty() else 1)
