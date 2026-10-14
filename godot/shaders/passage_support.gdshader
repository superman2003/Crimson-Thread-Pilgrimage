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
void fragment() {
    vec4 paint = texture(TEXTURE, UV);
    float value = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
    // Remove the bright cyan cast while retaining relief and carved details.
    vec3 mineral = mix(paint.rgb, vec3(value), 0.88) * vec3(0.48, 0.50, 0.35);
    vec2 uv = 1.0 - abs(mod(stone_position / tile_size, 2.0) - 1.0);
    vec2 half_texel = 0.5 / vec2(textureSize(stone_atlas, 0));
    vec3 rock = texture(stone_atlas, clamp(uv, half_texel, vec2(1.0) - half_texel)).rgb;
    // Match the rear wall's dark palette rather than the foreground stone.
    vec3 wall = rock * vec3(0.24, 0.32, 0.30);
    vec3 carving = wall * mix(0.70, 1.65, clamp(value * 2.8, 0.0, 1.0));
    COLOR = vec4(mix(carving, mineral * 0.55, 0.25), paint.a) * item_tint;
}
