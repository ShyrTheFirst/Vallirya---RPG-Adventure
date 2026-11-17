shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// 0 = Círculo, 1 = Cone, 2 = Retângulo
uniform int shape_type : hint_range(0, 2) = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float cone_angle : hint_range(10.0, 360.0) = 90.0;

uniform vec4 base_color : source_color = vec4(1.0, 0.1, 0.1, 0.25);
uniform vec4 fill_color : source_color = vec4(1.0, 0.15, 0.15, 0.65);
uniform vec4 border_color : source_color = vec4(1.0, 0.8, 0.2, 0.95);
uniform float border_width : hint_range(0.005, 0.1) = 0.03;

void fragment() {
	// Converte o UV de (0..1) para (-1..1) com o centro em (0,0)
	vec2 uv = UV * 2.0 - 1.0;
	
	float dist = 0.0;
	float fill_dist = 0.0;
	bool inside_angle = true;
	
	if (shape_type == 0) { // CÍRCULO (Cresce do centro para fora)
		dist = length(uv);
		fill_dist = dist;
	} 
	else if (shape_type == 1) { // CONE (Aponta para a frente do Boss: -Y no UV / -Z no 3D)
		dist = length(uv);
		fill_dist = dist;
		// Calcula o ângulo a partir do vetor frontal (0, -1)
		float angle = degrees(acos(dot(normalize(uv), vec2(0.0, -1.0))));
		if (angle > cone_angle * 0.5) {
			inside_angle = false;
		}
	} 
	else if (shape_type == 2) { // RETÂNGULO (Preenche de trás para frente)
		dist = max(abs(uv.x), abs(uv.y));
		fill_dist = 1.0 - ((uv.y + 1.0) * 0.5); // Vai de 0 na base até 1 na ponta
	}
	
	// Corta fora o que estiver fora da forma geométrica
	if (dist > 1.0 || !inside_angle) {
		discard;
	}
	
	// Desenha o fundo, a área preenchida pelo cast e a borda externa
	vec4 final_color = base_color;
	
	// Preenchimento do tempo de cast (progress)
	if (fill_dist <= progress && progress > 0.0) {
		final_color = fill_color;
		// Linha brilhante na ponta do progresso
		if ( abs(fill_dist - progress) < border_width * 0.8 ) {
			final_color = border_color;
		}
	}
	
	// Borda externa fixa do Telegraph
	if (dist >= 1.0 - border_width) {
		final_color = border_color;
	}
	// Borda lateral caso seja um Cone
	if (shape_type == 1 && dist <= 1.0) {
		float angle = degrees(acos(dot(normalize(uv), vec2(0.0, -1.0))));
		if (abs(angle - (cone_angle * 0.5)) < 2.5) {
			final_color = border_color;
		}
	}
	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}