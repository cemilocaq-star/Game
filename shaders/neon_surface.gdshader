shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.08, 0.55, 0.68, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.25;
uniform float pulse_speed : hint_range(0.1, 4.0) = 1.2;
uniform float surface_detail : hint_range(0.0, 1.0) = 0.72;
float hash_2d(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash_2d(i);
	float b = hash_2d(i + vec2(1.0, 0.0));
	float c = hash_2d(i + vec2(0.0, 1.0));
	float d = hash_2d(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);
	float broad_grain = value_noise(UV * vec2(18.0, 18.0));
	float fine_grain = hash_2d(floor(UV * vec2(120.0, 120.0)));
	float grain = mix(broad_grain, fine_grain, 0.16) - 0.5;
	vec3 base = base_color.rgb;
	float surface_variation = 1.0 + grain * surface_detail * 0.16;
	ALBEDO = base * surface_variation * (0.82 + fresnel * 0.24);
	ROUGHNESS = clamp(0.58 - broad_grain * 0.12, 0.28, 0.78);
	METALLIC = 0.12 + broad_grain * 0.08;
	EMISSION = base * (effect_strength * pulse * (0.16 + fresnel * 1.35));
}
