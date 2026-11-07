shader_type canvas_item;
uniform bool upper_body = false;
uniform bool clean_caps = false;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float phase = 0.0;
uniform float shade = 1.0;
uniform float presentation_alpha = 1.0;
uniform float flash_amount = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
    vec2 uv = UV;
    if (upper_body) {
        float cloth = 1.0 - smoothstep(166.0, 190.0, UV.x * 384.0);
        uv.y += sin(phase * 6.2831853 + UV.x * 24.0) * cloth * 0.002;
    }
    vec4 tex = texture(TEXTURE, uv);
    if (clean_caps) {
        vec2 cell = (UV - region.xy) / region.zw;
        // Paint over the source's exposed cut-end ovals using its own fabric.
        // Joint pieces overlap; no ring or gap opens when the knee folds.
        float edge = min(cell.y, 1.0 - cell.y);
        if (edge < .17) {
            float sample_y = cell.y < .5 ? .24 : .76;
            tex.rgb = texture(TEXTURE, region.xy + vec2(cell.x, sample_y) * region.zw).rgb;
        }
    }
    if (upper_body) {
        vec2 p = uv * 384.0;
        // Follow the tunic hem around the pelvis instead of a rectangular cut.
        float hem = p.x < 174.0 ? 253.0 : (p.x < 185.0 ? 246.0 : (p.x < 205.0 ? 243.0 : 241.0));
        tex.a *= 1.0 - smoothstep(hem - 1.0, hem + 0.5, p.y);
    }
    COLOR = vec4(mix(tex.rgb * shade, flash_color.rgb, flash_amount), tex.a * presentation_alpha);
}
