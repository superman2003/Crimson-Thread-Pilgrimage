shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float exposure : hint_range(0.5, 1.8) = 1.0;
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float warmth : hint_range(-0.3, 0.3) = 0.0;
void fragment() {
    vec4 source = texture(screen_texture, SCREEN_UV);
    float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 color = mix(vec3(luminance), source.rgb, saturation);
    color *= exposure;
    color += vec3(warmth, warmth * 0.25, -warmth);
    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a);
}
