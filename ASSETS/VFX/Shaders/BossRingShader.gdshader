shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 ring_color : source_color = vec4(1.0, 0.3, 0.1, 1.0); // Laranja avermelhado épico (mude para roxo/dourado se preferir)
uniform float emission_intensity = 3.0;
uniform float rotation_speed = 0.5;
uniform int flare_points = 8; // Número de pontas da estrela/anel

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0; // Distância do centro (0 a 1)
	
	// Calcula o ângulo para criar as pontas (flares) usando seno/cosseno
	float angle = atan(uv.y, uv.x);
	float flare = sin(angle * float(flare_points) + TIME * rotation_speed);
	
	// Modula o raio externo com base nas pontas para criar os bicos pontiagudos
	float outer_radius = 0.8 + (flare * 0.15);
	float inner_radius = 0.55;
	
	// Cria o formato de anel oco com bordas suaves
	float ring = smoothstep(inner_radius, inner_radius + 0.05, dist) * (1.0 - smoothstep(outer_radius - 0.05, outer_radius, dist));
	
	// Adiciona um brilho extra pulsante no centro do anel
	float pulse = sin(TIME * 3.0) * 0.2 + 0.8;
	
	vec3 final_emission = ring_color.rgb * ring * emission_intensity * pulse;
	
	ALBEDO = final_emission;
	ALPHA = ring * ring_color.a;
}