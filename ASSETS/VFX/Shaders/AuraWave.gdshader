shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec3 aura_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float emission_intensity : hint_range(0.0, 10.0) = 4.0;
uniform float wave_speed : hint_range(0.1, 5.0) = 3.0;
uniform float wave_height : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    vec2 uv = UV;
    
    // Inverte o eixo Y para que o efeito de onda e topo fiquem na parte superior correta do cilindro
    float local_y = 1.0 - uv.y;
    
    // Multiplica por TAU (6.283) na coordenada horizontal para fechar a onda perfeitamente em anel (sem corte seco)
    float circle_wave = sin(uv.x * 6.28318530718 * 3.0 + TIME * wave_speed) * wave_height;
    
    // Define a altura limite do topo com a ondulação aplicada
    float top_limit = 0.85 + circle_wave;
    
    // Fade suave no topo ondulado e na base colada no chão
    float fade_top = 1.0 - smoothstep(top_limit - 0.2, top_limit, local_y);
    float fade_bottom = smoothstep(0.0, 0.25, local_y);
    
    float final_alpha = fade_top * fade_bottom;
    final_alpha = clamp(final_alpha, 0.0, 1.0);
    
    vec3 final_color = aura_color * emission_intensity;
    
    ALBEDO = final_color;
    ALPHA = final_alpha;
}