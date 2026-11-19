shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 Color : source_color = vec4(1.0, 0.35, 0.15, 1.0);
uniform float Gradient_1_slider : hint_range(0.0, 1.0) = 0.0;
uniform float Gradient_2_slider : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Máscara de varredura ao longo do arco (UV.x):
	// Gradient_1_slider revela a ponta; Gradient_2_slider esmaece a cauda
	float head = 1.0 - smoothstep(Gradient_1_slider - 0.15, Gradient_1_slider + 0.02, UV.x);
	float tail = smoothstep(Gradient_2_slider - 0.05, Gradient_2_slider + 0.25, UV.x);
	float arc_mask = clamp(head * tail, 0.0, 1.0);

	// Perfil transversal suave (UV.y) com núcleo mais fino e brilhante no centro
	float edge_fade = sin(UV.y * PI);
	float blade_width = pow(clamp(edge_fade, 0.0, 1.0), 1.6);
	float core_mask = pow(clamp(edge_fade, 0.0, 1.0), 5.0);

	// Esmaecimento geral conforme o corte termina
	float global_fade = 1.0 - smoothstep(0.65, 1.0, Gradient_2_slider);
	float alpha = arc_mask * blade_width * global_fade;

	// Cor brilhante com núcleo branco incandescente
	vec3 glow_color = Color.rgb * 2.8 + vec3(1.0, 0.95, 0.9) * core_mask * 2.2;
	ALBEDO = glow_color;
	ALPHA = alpha;
}
