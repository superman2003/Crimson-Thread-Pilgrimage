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
        vec2 body_uv = 1.0-abs(mod(world_position/vec2(textureSize(body_atlas,0)),2.0)-1.0);
        vec2 body_half = 0.5/vec2(textureSize(body_atlas,0));
        vec3 body = texture(body_atlas,clamp(body_uv,body_half,vec2(1.0)-body_half)).rgb;
        float join = smoothstep(join_depth*0.4,join_depth,depth);
        paint.rgb = mix(paint.rgb,body,join);
        alpha = mix(alpha,1.0,join);
    }
    COLOR = vec4(paint.rgb*stone_tint,alpha)*COLOR;
}
