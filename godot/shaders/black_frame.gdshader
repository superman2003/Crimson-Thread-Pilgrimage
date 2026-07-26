shader_type canvas_item;

// 受击黑屏帧：全屏压暗，只在受击点留一个径向亮孔。
uniform vec2 hole_center_px = vec2(640.0, 360.0);
uniform float hole_radius_px = 90.0;
uniform vec4 tint : source_color = vec4(0.078, 0.063, 0.118, 0.85);

void fragment() {
    float dist = distance(FRAGCOORD.xy, hole_center_px);
    float shade = smoothstep(hole_radius_px * 0.35, hole_radius_px, dist);
    COLOR = vec4(tint.rgb, tint.a * shade);
}
