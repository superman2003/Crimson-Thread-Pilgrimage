shader_type canvas_item;
render_mode unshaded;
uniform sampler2D edge_atlas : source_color, filter_linear, repeat_enable;
uniform sampler2D edge_curve : filter_linear, repeat_disable;
uniform float silhouette_relief = 0.18;
uniform sampler2D body_atlas : source_color, filter_linear, repeat_enable;
uniform bool join_body = false;
uniform float join_depth = 64.0;
uniform vec2 surface_origin;
uniform float slope = 0.0;
uniform float art_height = 600.0;
uniform float anchor_v = 0.3;
uniform vec3 stone_tint = vec3(1.0);
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
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
    vec2 dimensions = vec2(textureSize(edge_atlas,0));
    float u = 1.0 - abs(mod(world_position.x / dimensions.x,2.0)-1.0);
    float boundary = surface_origin.y + (world_position.x-surface_origin.x)*slope;
    // Follow the authored contour to keep its visual rim near collision.
    float authored_anchor = texture(edge_curve,vec2(u,0.5)).r;
    float aligned_anchor = mix(authored_anchor,anchor_v,silhouette_relief);
    float v = (world_position.y-boundary)/art_height+aligned_anchor;
    vec2 half_texel = 0.5/dimensions;
    vec4 paint = texture(edge_atlas,clamp(vec2(u,v),half_texel,vec2(1.0)-half_texel));
    float alpha = smoothstep(0.2,0.8,paint.a);
    if (join_body) {
        float depth = (world_position.y-boundary)*(anchor_v>0.55 ? -1.0 : 1.0);
        // Same sampling as the world_rock body it joins.
        vec3 body = rock_stone(body_atlas,world_position,vec2(textureSize(body_atlas,0)));
        float join = smoothstep(join_depth*0.4,join_depth,depth);
        paint.rgb = mix(paint.rgb,body,join);
        alpha = mix(alpha,1.0,join);
    }
    COLOR = vec4(paint.rgb*stone_tint,alpha)*COLOR;
}
