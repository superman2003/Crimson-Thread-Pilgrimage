shader_type canvas_item;
// Colour-vision assist: move the part of the picture a viewer with the chosen
// deficiency cannot tell apart into channels they can (daltonisation).
// mode 1 = red-weak (protan), 2 = green-weak (deutan).
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform int mode = 0;

const mat3 RGB_TO_LMS = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
const mat3 LMS_TO_RGB = mat3(vec3(0.0809444479, -0.0102485335, -0.000365296938), vec3(-0.130504409, 0.0540193266, -0.00412161469), vec3(0.116721066, -0.113614708, 0.693511405));

void fragment() {
    vec3 colour = texture(screen, SCREEN_UV).rgb;
    vec3 lms = RGB_TO_LMS * colour;
    vec3 seen = lms;
    if (mode == 1) {
        seen.x = 2.02344 * lms.y - 2.52581 * lms.z;
    } else if (mode == 2) {
        seen.y = 0.494207 * lms.x + 1.24827 * lms.z;
    }
    vec3 lost = colour - LMS_TO_RGB * seen;
    vec3 shifted = colour;
    if (mode != 0) {
        // Red/green-weak viewers keep blue and brightness.
        shifted.g += 0.7 * lost.r;
        shifted.b += 0.7 * lost.r + lost.b;
    }
    COLOR = vec4(clamp(shifted, 0.0, 1.0), 1.0);
}
