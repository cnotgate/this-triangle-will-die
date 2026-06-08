shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.3, 0.3, 0.3, 1.0); // Warna dasar platform
uniform vec4 grain_color : source_color = vec4(0.25, 0.25, 0.25, 1.0); // Warna bintik tekstur
uniform float grain_size = 120.0;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Kita pake SCREEN_UV biar teksturnya "nempel" di dunia
    // Jadi pas player jalan teksturnya berasa diem di tempat
    vec2 grid_uv = floor(UV * grain_size);
    float noise = random(grid_uv);
    
    // Campur warna dasar sama tekstur bintik
    vec4 final_color = mix(base_color, grain_color, noise * 0.3);
    COLOR = final_color;
}