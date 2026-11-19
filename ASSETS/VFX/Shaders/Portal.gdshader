shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.05, 0.25, 0.65, 0.95);
uniform vec4 swirl_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);

uniform float swirl_speed : hint_range(-5.0, 5.0) = 1.2;
uniform float swirl_twist : hint_range(0.0, 15.0) = 4.5;
uniform float energy_intensity : hint_range(1.0, 8.0) = 3.2;
uniform float rim_power : hint_range(0.5, 6.0) = 2.2;

// Função de ruído procedural leve (não precisa de textura externa)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Centraliza as UVs de -1.0 a 1.0
	vec2 uv = (UV - 0.5) * 2.0;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);
	
	// Distorção espiral puxando para o centro
	float twist = angle + (1.0 - clamp(dist, 0.0, 1.0)) * swirl_twist - (TIME * swirl_speed);
	vec2 swirl_uv = vec2(cos(twist), sin(twist)) * (dist * 3.0);
	
	// Duas camadas de névoa mística em velocidades diferentes
	float n1 = fbm(swirl_uv + vec2(TIME * 0.25, -TIME * 0.15));
	float n2 = fbm(swirl_uv * 1.8 - vec2(TIME * 0.35, TIME * 0.2));
	float energy = smoothstep(0.25, 0.85, n1 * n2 * 2.2);
	
	// Brilho nas bordas do arco (Fresnel + proximidade da borda UV)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float edge_glow = smoothstep(0.55, 0.98, dist);
	
	// Mistura as cores
	vec3 base = mix(core_color.rgb, swirl_color.rgb, energy);
	vec3 final_color = mix(base, rim_color.rgb, clamp(fresnel + edge_glow * 0.6, 0.0, 1.0));
	
	// Pulso suave no núcleo do portal
	float pulse = 0.85 + 0.15 * sin(TIME * 2.5 - dist * 5.0);
	
	// Suaviza a transição bem na borda extrema para não cortar seco na pedra
	float alpha_mask = 1.0 - smoothstep(0.92, 1.0, dist);
	
	ALBEDO = final_color * energy_intensity * pulse;
	ALPHA = clamp((0.55 + energy * 0.45 + edge_glow * 0.3) * alpha_mask, 0.0, 1.0) * core_color.a;
}