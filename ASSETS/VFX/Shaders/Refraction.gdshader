shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap;

uniform float refraction_strength : hint_range(0.0, 0.25) = 0.04;
uniform float noise_scale : hint_range(0.1, 10.0) = 1.5;
uniform float flow_speed : hint_range(-5.0, 5.0) = 0.6;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.002;

uniform vec4 tint_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.15;
uniform float rim_boost : hint_range(0.0, 3.0) = 0.4;
uniform float rim_power : hint_range(0.5, 6.0) = 2.5;

void fragment() {
	// Ruído volumétrico baseado na normal para evitar costura em esferas/malhas 3D
	vec3 n_pos = NORMAL * noise_scale + vec3(TIME * flow_speed, -TIME * flow_speed * 0.7, TIME * flow_speed * 0.5);
	float nx = texture(noise_texture, n_pos.yz).r;
	float ny = texture(noise_texture, n_pos.xz).r;
	float nz = texture(noise_texture, n_pos.xy).r;
	float noise_val = ((nx + ny + nz) / 3.0) * 2.0 - 1.0; // [-1.0, 1.0]

	// Direção de refração baseada na normal da superfície + variação do ruído
	vec2 normal_offset = NORMAL.xy * refraction_strength + (vec2(noise_val) * refraction_strength * 0.6);
	vec2 refracted_uv = clamp(SCREEN_UV + normal_offset, vec2(0.001), vec2(0.999));

	// Separação leve RGB (opcional) para dar aspecto de lente/energia densa
	vec2 ca_vec = normalize(normal_offset + vec2(0.0001)) * chromatic_aberration;
	float r = texture(screen_texture, clamp(refracted_uv + ca_vec, vec2(0.001), vec2(0.999))).r;
	float g = texture(screen_texture, refracted_uv).g;
	float b = texture(screen_texture, clamp(refracted_uv - ca_vec, vec2(0.001), vec2(0.999))).b;
	vec3 refracted_col = vec3(r, g, b);

	// Tinta sutil e brilho de borda (Fresnel) para destacar o contorno da distorção
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 final_col = mix(refracted_col, refracted_col * tint_color.rgb, tint_mix);
	final_col += tint_color.rgb * fresnel * rim_boost;

	ALBEDO = final_col;
}