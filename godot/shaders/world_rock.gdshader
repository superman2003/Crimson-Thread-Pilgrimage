shader_type canvas_item;
render_mode unshaded;
uniform sampler2D stone_atlas : source_color, filter_linear, repeat_enable;
uniform vec2 tile_size = vec2(4096.0,4096.0);
// False is retained only for reproducible before/after rendering.
uniform bool mirror_repeat = true;
varying vec2 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
    vec2 uv = world_position/tile_size;
    if (mirror_repeat) {
        // GLSL mod also folds negative world positions into the same period.
        uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
        // Prevent linear filtering across the unrelated opposite atlas edge.
        vec2 half_texel = 0.5 / vec2(textureSize(stone_atlas, 0));
        uv = clamp(uv, half_texel, vec2(1.0) - half_texel);
    }
    // UVs never reset at collision or visible-draw subdivisions.
    COLOR = vec4(texture(stone_atlas,uv).rgb,1.0)*COLOR;
}
