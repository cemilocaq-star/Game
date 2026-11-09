extends RefCounted
class_name GraphicsManager

const SHADER_PATH := "res://shaders/neon_surface.gdshader"
const SETTINGS_PATH := "user://game_settings.cfg"

var quality_setting := "AUTO"
var resolved_quality := "MEDIUM"
var environment: Environment
var sunlight: DirectionalLight3D

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		quality_setting = str(config.get_value("graphics", "quality", "AUTO")).to_upper()
	if quality_setting not in ["AUTO", "LOW", "MEDIUM", "HIGH", "ULTRA"]:
		quality_setting = "AUTO"
	_resolve_quality()

func set_quality(value: String) -> void:
	quality_setting = value.to_upper()
	if quality_setting not in ["AUTO", "LOW", "MEDIUM", "HIGH", "ULTRA"]:
		quality_setting = "AUTO"
	_resolve_quality()
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality_setting)
	config.save(SETTINGS_PATH)
	_apply_quality()

func configure(env: Environment, sun: DirectionalLight3D) -> void:
	environment = env
	sunlight = sun
	_apply_quality()

func _resolve_quality() -> void:
	if quality_setting != "AUTO":
		resolved_quality = quality_setting
		return
	var cores := OS.get_processor_count()
	var screen := DisplayServer.screen_get_size()
	if OS.has_feature("mobile"):
		if cores <= 4:
			resolved_quality = "LOW"
		elif cores >= 8 and screen.x >= 2400:
			resolved_quality = "HIGH"
		else:
			resolved_quality = "MEDIUM"
	elif cores >= 12 and screen.x >= 2560:
		resolved_quality = "ULTRA"
	elif cores >= 8:
		resolved_quality = "HIGH"
	elif cores >= 6:
		resolved_quality = "MEDIUM"
	else:
		resolved_quality = "LOW"

func _apply_quality() -> void:
	if is_instance_valid(sunlight):
		sunlight.shadow_enabled = resolved_quality in ["HIGH", "ULTRA"]
		sunlight.light_energy = 1.25 if resolved_quality in ["HIGH", "ULTRA"] else 1.0
	if is_instance_valid(environment):
		environment.ambient_light_energy = 0.78 if resolved_quality in ["HIGH", "ULTRA"] else 0.62

func make_material(color: Color) -> Material:
	if resolved_quality == "LOW":
		var basic := StandardMaterial3D.new()
		basic.albedo_color = color
		basic.roughness = 0.78
		return basic
	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = color
		return fallback
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color", color)
	var strength := 0.22
	match resolved_quality:
		"HIGH":
			strength = 0.48
		"ULTRA":
			strength = 0.75
		_:
			strength = 0.22
	material.set_shader_parameter("effect_strength", strength)
	return material
