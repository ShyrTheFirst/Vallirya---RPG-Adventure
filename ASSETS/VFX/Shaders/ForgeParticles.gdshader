shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float noise_scale : hint_range(0.5, 6.0) = 2.0;
uniform float scroll_speed : hint_range(-5.0, 5.0) = 1.5;
uniform float softness : hint_range(0.5, 4.0) = 1.8;

void vertex() {
	// Billboard mantendo escala e rotação da partícula
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	vec2 centered = (UV - 0.5) * 2.0;
	float dist = length(centered);
	
	// Máscara circular suave para evitar corte quadrado
	float radial = pow(clamp(1.0 - dist, 0.0, 1.0), softness);
	
	// Ruído animando para dar aspecto orgânico de chama ou fumaça
	vec2 n_uv = UV * noise_scale + vec2(0.0, -TIME * scroll_speed);
	float n = texture(noise_texture, n_uv).r;
	
	float mask = radial * mix(0.55, 1.15, n) * COLOR.a;
	
	ALBEDO = tint_color.rgb * COLOR.rgb;
	ALPHA = clamp(mask, 0.0, 1.0);
}