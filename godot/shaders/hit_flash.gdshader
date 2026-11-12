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

// Wing beat for hovering creatures whose redrawn loops hold the wings almost
// still (data/creature_wing_flap.json). The wing is the part of the drawing
// inside a sector around its root; it swings about the root as one sheet and
// bends a little towards the tip. Everything is in the frame's own canvas
// pixels, so a flipped sprite needs no special case. wing_swing = 0 is off.
uniform float wing_swing = 0.0;          // degrees, peak to peak
uniform float wing_center = 0.5;         // 0: drawn pose is one end of the beat, 0.5: the middle
uniform float wing_shorten = 1.0;        // wing length at the far end of the beat
uniform float wing_flex = 0.0;           // radians the tip lags behind the root
uniform float wing_phase = 0.0;
uniform vec2 wing_hinge = vec2(0.0);
uniform vec2 wing_sector = vec2(0.0, 0.0);      // degrees, 90 is up, 180 is behind
uniform vec3 wing_radius = vec3(8.0, 30.0, 100.0);  // rigid root, full swing from, wing length
uniform vec2 frame_origin = vec2(0.0);   // atlas pixel of the canvas origin
uniform vec4 frame_region = vec4(0.0);   // atlas pixels the frame owns

void vertex() {
    VERTEX = body_fit_pivot + (VERTEX - body_fit_pivot) * body_fit;
}

float wing_weight(float radius, float angle) {
    float a = mod(angle, 360.0);
    return smoothstep(wing_sector.x - 6.0, wing_sector.x + 6.0, a)
        * (1.0 - smoothstep(wing_sector.y - 6.0, wing_sector.y + 6.0, a))
        * (1.0 - smoothstep(wing_radius.z - 6.0, wing_radius.z, radius))
        * smoothstep(wing_radius.x, wing_radius.y, radius);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (wing_swing != 0.0) {
        vec2 canvas = UV / TEXTURE_PIXEL_SIZE - frame_origin;
        vec2 arm = vec2(canvas.x - wing_hinge.x, wing_hinge.y - canvas.y);
        float radius = length(arm);
        float angle = degrees(atan(arm.y, arm.x));
        float beat = 0.5 - 0.5 * cos(wing_phase - wing_flex * radius / wing_radius.z);
        float reach = 1.0 - (1.0 - wing_shorten) * beat;
        float source_radius = radius > wing_radius.x ? wing_radius.x + (radius - wing_radius.x) / reach : radius;
        float source_angle = angle - wing_swing * (beat - wing_center) * smoothstep(wing_radius.x, wing_radius.y, source_radius);
        vec2 source = wing_hinge + source_radius * vec2(cos(radians(source_angle)), -sin(radians(source_angle)));
        vec2 atlas = source + frame_origin;
        vec2 low = frame_region.xy + vec2(0.5);
        vec2 high = frame_region.xy + frame_region.zw - vec2(0.5);
        bool owned = atlas.x >= low.x && atlas.y >= low.y && atlas.x <= high.x && atlas.y <= high.y;
        vec4 wing = owned ? texture(TEXTURE, atlas * TEXTURE_PIXEL_SIZE) : vec4(0.0);
        wing.a *= wing_weight(source_radius, source_angle);
        float body_alpha = tex.a * (1.0 - wing_weight(radius, angle));
        float alpha = wing.a + body_alpha * (1.0 - wing.a);
        vec3 colour = alpha > 0.0001 ? (wing.rgb * wing.a + tex.rgb * body_alpha * (1.0 - wing.a)) / alpha : tex.rgb;
        tex = vec4(colour, alpha);
    }
    COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a * presentation_alpha * (hide_source ? 0.0 : 1.0));
}
