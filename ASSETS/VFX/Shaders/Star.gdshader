shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 star_color : source_color = vec4(1.0, 0.9, 0.5, 1.0); // Dourado/branco estelar
uniform float brightness : hint_range(1.0, 6.0) = 3.5;
uniform float twinkle_speed : hint_range(0.0, 15.0) = 6.0;
uniform float star_sharpness : hint_range(1.0, 10.0) = 4.0;

void vertex() {
	// Faz o quad sempre olhar para a câmera (billboard) mantendo rotação própria
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
	vec2 uv = (UV - 0.5) * 2.0; // -1.0 a 1.0
	float dist = length(uv);
	
	// Brilho central circular suave
	float core = smoothstep(1.0, 0.0, dist);
	
	// Raios em cruz (efeito de estrela/brilho estelar)
	float cross_x = exp(-abs(uv.y) * star_sharpness * 4.0) * smoothstep(1.0, 0.0, abs(uv.x));
	float cross_y = exp(-abs(uv.x) * star_sharpness * 4.0) * smoothstep(1.0, 0.0, abs(uv.y));
	float rays = max(cross_x, cross_y) * 0.75;
	
	float shape = clamp(core * 0.6 + rays, 0.0, 1.0);
	
	// Cintilação usando o offset da instância (COLOR ou posição) + tempo
	float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].y + MODEL_MATRIX[3].z) * 3.7;
	float twinkle = 0.55 + 0.45 * sin(TIME * twinkle_speed + phase);
	
	float final_mask = shape * twinkle * COLOR.a;
	
	ALBEDO = star_color.rgb * COLOR.rgb * brightness * final_mask;
	ALPHA = clamp(final_mask, 0.0, 1.0);
}