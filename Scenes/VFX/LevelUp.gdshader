shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.85, 0.2, 0.9);
uniform float vertical_speed = 3.5;

void fragment() {
    // Gradiente vertical para o feixe dissipar no topo
    float vertical_fade = pow(1.0 - UV.y, 1.4);
    
    // Linhas verticais subindo ao redor do cilindro
    float stripes = 0.8 + 0.2 * sin((UV.y * 12.0) - (TIME * vertical_speed));
    
    ALBEDO = beam_color.rgb;
    ALPHA = beam_color.a * vertical_fade * stripes;
}