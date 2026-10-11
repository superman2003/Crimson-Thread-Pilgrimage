shader_type canvas_item;
render_mode unshaded;
uniform sampler2D stone_atlas : source_color, filter_linear;
uniform vec4 sample_rect;
uniform vec2 tile_size = vec2(256.0,208.0);
varying vec2 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
}
vec3 stone_sample(vec2 uv) {
    return texture(stone_atlas,sample_rect.xy+uv*sample_rect.zw).rgb;
}
void fragment() {
    // Four periodic samples crossfade at the crop edges. No mirrored rocks or
    // flipped tile segments, and no UV reset at rectangle/ramp subdivisions.
    vec2 uv = fract(world_position/tile_size);
    vec2 shifted = fract(uv+0.5);
    vec2 weight = pow(sin(uv*3.14159265),vec2(2.0));
    vec3 a = mix(stone_sample(vec2(shifted.x,uv.y)),stone_sample(uv),weight.x);
    vec3 b = mix(stone_sample(shifted),stone_sample(vec2(uv.x,shifted.y)),weight.x);
    vec3 stone = mix(b,a,weight.y);
    COLOR = vec4(stone*0.82,1.0)*COLOR;
}
