shader_type canvas_item;
render_mode unshaded;
// Reconcile the painted ornament with the same stone sample as its host wall.
uniform sampler2D stone_atlas : source_color, filter_linear, repeat_enable;
uniform vec2 tile_size = vec2(1254.0);
varying vec2 stone_position;
varying vec4 item_tint;
void vertex() {
    stone_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    item_tint = COLOR;
}
// ROCK_SAMPLE_BEGIN — keep byte-identical in world_rock.gdshader,
// ink_cave_edge.gdshader and passage_support.gdshader (world_material checks
// this) so rims and passage pilasters join the body they sit on.
// V03: the plain two-tile mirror fold hides atlas seams but shows four-way
// kaleidoscope axes on large masses. Blend two differently shifted mirror
// layers under low-frequency world noise and bend the axes with a gentle warp.
// Every term is continuous in world space, so no new seams appear.
float rock_lattice(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
float rock_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 t = fract(point);
    t = t * t * (3.0 - 2.0 * t);
    float a = rock_lattice(cell);
    float b = rock_lattice(cell + vec2(1.0, 0.0));
    float c = rock_lattice(cell + vec2(0.0, 1.0));
    float d = rock_lattice(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}
// Offsets span the whole two-tile mirror period.
vec2 rock_layer_offset(float level) {
    return fract(sin(vec2(level * 12.9898 + 1.31, level * 78.233 + 4.17)) * 43758.5453) * 2.0;
}
vec3 rock_mirrored(sampler2D atlas, vec2 uv) {
    // GLSL mod also folds negative world positions into the same period.
    uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
    // Prevent linear filtering across the unrelated opposite atlas edge.
    vec2 half_texel = 0.5 / vec2(textureSize(atlas, 0));
    uv = clamp(uv, half_texel, vec2(1.0) - half_texel);
    return texture(atlas, uv).rgb;
}
vec3 rock_stone(sampler2D atlas, vec2 world, vec2 tile) {
    vec2 uv = world / tile;
    float level = rock_noise(world / (tile * 0.62)) * 8.0;
    float base = floor(level);
    vec2 warp_point = world / (tile * 0.9);
    vec2 warp = (vec2(rock_noise(warp_point + vec2(3.1, 0.0)), rock_noise(warp_point + vec2(0.0, 7.7))) - 0.5) * 0.12;
    vec3 first = rock_mirrored(atlas, uv + warp + rock_layer_offset(base));
    vec3 second = rock_mirrored(atlas, uv + warp + rock_layer_offset(base + 1.0));
    // Luminance bias keeps ink strokes of one layer intact instead of ghosting.
    float bias = dot(first - second, vec3(0.3333));
    return mix(first, second, smoothstep(0.36, 0.64, fract(level) - 0.25 * bias));
}
// ROCK_SAMPLE_END
void fragment() {
    vec4 paint = texture(TEXTURE, UV);
    float value = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
    // Remove the bright cyan cast while retaining relief and carved details.
    vec3 mineral = mix(paint.rgb, vec3(value), 0.88) * vec3(0.48, 0.50, 0.35);
    vec3 rock = rock_stone(stone_atlas, stone_position, tile_size);
    // Match the rear wall's dark palette rather than the foreground stone.
    vec3 wall = rock * vec3(0.24, 0.32, 0.30);
    vec3 carving = wall * mix(0.70, 1.65, clamp(value * 2.8, 0.0, 1.0));
    COLOR = vec4(mix(carving, mineral * 0.55, 0.25), paint.a) * item_tint;
}
