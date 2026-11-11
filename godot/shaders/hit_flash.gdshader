shader_type canvas_item;

uniform float presentation_alpha : hint_range(0.0, 1.0) = 1.0;
uniform bool hide_source = false;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Per-frame body size correction (frame_fit.json): scales the drawn frame about
// the feet so a frame drawn slightly too large or small does not pulse. The
// node's own scale and position stay untouched.
uniform float body_fit = 1.0;
uniform vec2 body_fit_pivot = vec2(0.0);

void vertex() {
    VERTEX = body_fit_pivot + (VERTEX - body_fit_pivot) * body_fit;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a * presentation_alpha * (hide_source ? 0.0 : 1.0));
}
