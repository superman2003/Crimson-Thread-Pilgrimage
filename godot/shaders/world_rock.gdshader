shader_type canvas_item;
render_mode unshaded;
uniform sampler2D stone_atlas : source_color, filter_linear, repeat_enable;
uniform vec2 tile_size = vec2(4096.0,4096.0);
varying vec2 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
    // One complete mural, one sample. UVs never reset at collision subdivisions.
    COLOR = vec4(texture(stone_atlas,world_position/tile_size).rgb,1.0)*COLOR;
}
