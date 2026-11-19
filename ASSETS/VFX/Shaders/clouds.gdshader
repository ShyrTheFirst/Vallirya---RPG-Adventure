shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D noise_texture;
uniform vec4 cloud_color : source_color = vec4(0.92, 0.94, 0.97, 0.85);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Cor do brilho nas bordas
uniform float rim_power = 2.5; // Intensidade/Espessura do brilho de borda
uniform float speed = 0.015;

varying float vertex_y;

void vertex() {
	// Pega a altura do vértice para o fade da base
	vertex_y = VERTEX.y;
}

void fragment() {
	// Desloca o ruído suavemente com o vento
	vec2 scrolled_uv = UV + (TIME * speed * vec2(0.08, 0.03));
	float noise = texture(noise_texture, scrolled_uv).r;
	
	// Recorte orgânico do formato da nuvem
	float alpha = smoothstep(0.2, 0.6, noise);
	
	// Fade suave na parte de baixo da semi-esfera
	float bottom_fade = smoothstep(-1.0, 0.2, vertex_y);
	
	// Efeito Fresnel para iluminar as bordas da nuvem (olhando de perfil)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	
	// Mistura a cor base da nuvem com o brilho nas bordas
	vec3 final_color = mix(cloud_color.rgb, rim_color.rgb, fresnel * 0.6);
	
	ALBEDO = final_color;
	ALPHA = cloud_color.a * alpha * bottom_fade;
}