shader_type spatial;
render_mode unshaded, blend_add; // O blend_add dá o efeito luminoso de fogo mágico

uniform vec3 core_color : source_color = vec3(3.0, 1.2, 0.1); // Núcleo brilhante (Amarelo/Branco)
uniform vec3 edge_color : source_color = vec3(1.0, 0.2, 0.0); // Bordas do fogo (Laranja/Vermelho)
uniform float emission_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float speed : hint_range(0.1, 5.0) = 1.5;

// Função simples de ruído para dar o aspecto orgânico de chamas se movendo
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    // Coordenadas UV distorcidas pelo tempo para simular o fogo subindo e tremeluzindo
    vec2 uv = UV;
    uv.y += TIME * speed; // Faz o fogo "subir" pela esfera
    
    // Aplicação de camadas de ruído para criar as línguas de chamas
    float n = noise(uv * 6.0 + vec2(0.0, TIME * 0.5));
    n += noise(uv * 12.0 - vec2(0.0, TIME * 1.0)) * 0.5;
    
    // Gradiente baseado na distância do centro da UV para arredondar a esfera
    float dist = length(UV - vec2(0.5)) * 2.0;
    float fire_mask = 1.0 - smoothstep(0.0, 1.0, dist);
    
    // Modula a máscara com o ruído gerado para criar recortes orgânicos nas chamas
    float final_mask = clamp(fire_mask * (n + 0.3), 0.0, 1.0);
    
    // Mistura as cores do núcleo e da borda com base na intensidade do ruído
    vec3 final_color = mix(edge_color, core_color, final_mask) * emission_intensity;
    
    ALBEDO = final_color;
    ALPHA = final_mask; // As bordas ficam transparentes suavemente
}