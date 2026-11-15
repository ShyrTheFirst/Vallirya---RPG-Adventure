shader_type spatial;
render_mode unshaded, blend_add, cull_disabled; // Cull disabled faz aparecer por dentro e por fora

uniform vec3 aura_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float emission_intensity : hint_range(0.0, 10.0) = 4.0;
uniform float wave_speed : hint_range(0.1, 5.0) = 2.0;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;

void fragment() {
    // Coordenadas UV do cilindro/anel
    vec2 uv = UV;
    
    // Cria o efeito ondulante nas laterais usando senoide e o tempo
    float wave = sin(uv.y * wave_frequency + TIME * wave_speed) * 0.5 + 0.5;
    
    // Gradiente vertical para apagar (dar fade) o topo e o fundo do anel
    // smoothstep(edge0, edge1, x) suaviza as bordas superior e inferior
    float vertical_fade = smoothstep(0.0, 0.3, uv.y) * (1.0 - smoothstep(0.7, 1.0, uv.y));
    
    // Combina a onda com o fade vertical
    float final_alpha = vertical_fade * (wave * 0.5 + 0.5);
    
    // Cor final com brilho estourado (Bloom)
    vec3 final_color = aura_color * emission_intensity;
    
    ALBEDO = final_color;
    ALPHA = final_alpha;
}