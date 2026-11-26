extends SceneTree
## Actual remote avatars, staged locally. This is a visual fixture, not an online match.
const REMOTE := preload("res://scripts/oxenwar_remote_player.gd")
const IDS := ["outfit_default","outfit_runner","outfit_ghost_ops","outfit_neon","outfit_iron_vanguard","outfit_web_sentinel","outfit_ghost_ops","outfit_runner"]
const WEAPONS := ["aether","ranger_rifle","longshot","heavy_sidearm","rotary_arc","comet_bow","pulse_carbine","hand_cannon"]
var world: Node3D
var camera: Camera3D
var actors: Array[Node3D] = []
func _initialize() -> void:
	call_deferred("run")
func save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("OXENWAR_CAPTURE_DIR").path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(1440,900)
	world = Node3D.new();root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#172431")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new();world.add_child(sun)
	sun.rotation_degrees = Vector3(-40,-25,0);sun.light_energy = 0.9
	var floor_mesh := MeshInstance3D.new();world.add_child(floor_mesh)
	floor_mesh.mesh = BoxMesh.new();floor_mesh.mesh.size = Vector3(20,.2,8)
	floor_mesh.position.y = -0.1
	var material := StandardMaterial3D.new();material.albedo_color=Color("#253A4A");material.roughness=.9
	floor_mesh.material_override = material
	for i in range(8):
		var actor := REMOTE.new();world.add_child(actor)
		actor.set_player_identity("P%d fixture" % (i+1),Color("#27D7E7"),IDS[i],"accessory_none")
		actor.sync_weapon(WEAPONS[i],true)
		actor.position = Vector3((float(i)-3.5)*1.7,0,0)
		actor.rotation.y = PI
		actor.apply_network_state(actor.position, PI)
		actor.set_process(false)
		actor.set_aim_pitch(0.0)
		actor._process(.1)
		actors.append(actor)
	camera = Camera3D.new();world.add_child(camera)
	camera.fov = 35.0
	camera.position = Vector3(0,4.2,13);camera.look_at(Vector3(0,1,0));camera.current=true
	await save("remote_eight_front")
	camera.position=Vector3(9,5,12);camera.look_at(Vector3(0,1,0))
	for actor in actors: actor.sync_reload(0.7);actor._process(.15)
	await save("remote_eight_reload")
	camera.position=Vector3(0,4,-13);camera.look_at(Vector3(0,1,0))
	await save("remote_eight_back")
	actors[2].apply_network_state(actors[2].position,PI,false,0.0,true)
	actors[2]._process(.3)
	camera.position=Vector3(0,4.2,13);camera.look_at(Vector3(0,1,0))
	await save("remote_eight_death")
	actors[2].apply_network_state(actors[2].position,PI,false,100.0,false)
	actors[2]._process(.3)
	await save("remote_eight_respawn")
	actors.clear()
	world.free()
	await process_frame
	quit()
