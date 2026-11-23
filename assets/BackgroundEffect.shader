shader_type canvas_item;

uniform float time;
uniform float intensity = 0.0;

void fragment() {
    vec2 uv = UV;
    float wave = sin(uv.y * 40.0 + time * 5.0) * 0.02;
    uv.x += wave * intensity;
    COLOR = vec4(uv.x, uv.y, 0.2 + 0.3 * intensity + 0.5 * sin(time), 1.0);
}
