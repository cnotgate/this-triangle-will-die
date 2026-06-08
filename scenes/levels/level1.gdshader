shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 star_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float speed = 0.05;
uniform float star_density = 0.98;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // Bikin gerak ke kanan dengan smooth
    uv.x += TIME * speed;
    
    // Set warna dasar
    COLOR = bg_color;
    
    vec2 grid = floor(uv * 150.0);
    float noise = random(grid);
    
    // Kalo nemu bintang langsung tembak warna bintangnya secara statis
    if (noise > star_density) {
        COLOR = star_color;
    }
}