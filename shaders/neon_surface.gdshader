shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.08, 0.55, 0.68, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.25;
uniform float pulse_speed : hint_range(0.1, 4.0) = 1.2;

void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 base = base_color.rgb;
	ALBEDO = base * (0.78 + fresnel * 0.28);
	ROUGHNESS = 0.38;
	METALLIC = 0.18;
	EMISSION = base * (effect_strength * pulse * (0.28 + fresnel * 1.5));
}
