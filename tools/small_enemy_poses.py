"""Walk and attack pose drawing for small enemies: bases, strides, per-family attack strokes and pose bias.

Moved out of small_enemy_frames.py unchanged; small_enemy_frames.py imports these names back."""
from __future__ import annotations
import math
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


FRAME_SIZE = 128


FRAME_COUNT = 8


ATTACK_STAGES = [
    "ready",
    "anticipation",
    "coil",
    "release",
    "impact",
    "follow_through",
    "recover",
    "settle",
]


ATTACK_POSES: dict[str, list[dict[str, float]]] = {
    "crawler": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -6, "dy": 1, "sx": 0.92, "sy": 1.08, "rot": -5},
        {"dx": -10, "dy": 2, "sx": 0.86, "sy": 1.14, "rot": -8},
        {"dx": 7, "dy": -2, "sx": 1.16, "sy": 0.92, "rot": 5},
        {"dx": 19, "dy": -4, "sx": 1.30, "sy": 0.84, "rot": 9},
        {"dx": 14, "dy": -2, "sx": 1.18, "sy": 0.90, "rot": 7},
        {"dx": 5, "dy": 0, "sx": 1.02, "sy": 0.98, "rot": 2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "flyer": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -5, "dy": -5, "sx": 0.96, "sy": 1.06, "rot": -10},
        {"dx": -8, "dy": -9, "sx": 0.92, "sy": 1.12, "rot": -18},
        {"dx": 7, "dy": -5, "sx": 1.14, "sy": 0.92, "rot": 18},
        {"dx": 20, "dy": 3, "sx": 1.26, "sy": 0.86, "rot": 28},
        {"dx": 14, "dy": 6, "sx": 1.12, "sy": 0.94, "rot": 20},
        {"dx": 4, "dy": 2, "sx": 1.02, "sy": 0.98, "rot": 8},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "shooter": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -4, "dy": 0, "sx": 0.96, "sy": 1.05, "rot": -3},
        {"dx": -7, "dy": 1, "sx": 0.90, "sy": 1.12, "rot": -5},
        {"dx": 1, "dy": -2, "sx": 1.05, "sy": 0.98, "rot": 2},
        {"dx": 8, "dy": -2, "sx": 1.12, "sy": 0.93, "rot": 4},
        {"dx": 3, "dy": 0, "sx": 1.02, "sy": 1.00, "rot": -3},
        {"dx": -2, "dy": 1, "sx": 0.98, "sy": 1.02, "rot": -2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "caster": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -2, "dy": -1, "sx": 0.98, "sy": 1.05, "rot": -2},
        {"dx": -4, "dy": -4, "sx": 0.94, "sy": 1.12, "rot": -4},
        {"dx": 0, "dy": -7, "sx": 1.03, "sy": 1.08, "rot": 1},
        {"dx": 7, "dy": -8, "sx": 1.10, "sy": 1.00, "rot": 5},
        {"dx": 5, "dy": -4, "sx": 1.05, "sy": 1.02, "rot": 3},
        {"dx": 1, "dy": -1, "sx": 1.01, "sy": 1.00, "rot": 1},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "charger": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -7, "dy": 1, "sx": 0.94, "sy": 1.08, "rot": -5},
        {"dx": -12, "dy": 2, "sx": 0.88, "sy": 1.14, "rot": -9},
        {"dx": 9, "dy": -1, "sx": 1.18, "sy": 0.92, "rot": 6},
        {"dx": 23, "dy": -2, "sx": 1.34, "sy": 0.86, "rot": 10},
        {"dx": 17, "dy": 0, "sx": 1.20, "sy": 0.92, "rot": 7},
        {"dx": 6, "dy": 1, "sx": 1.03, "sy": 0.98, "rot": 2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "duelist": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -5, "dy": 0, "sx": 0.94, "sy": 1.07, "rot": -7},
        {"dx": -9, "dy": 1, "sx": 0.88, "sy": 1.14, "rot": -12},
        {"dx": 4, "dy": -2, "sx": 1.10, "sy": 0.96, "rot": 8},
        {"dx": 16, "dy": -3, "sx": 1.24, "sy": 0.88, "rot": 16},
        {"dx": 11, "dy": -1, "sx": 1.14, "sy": 0.92, "rot": 18},
        {"dx": 3, "dy": 0, "sx": 1.02, "sy": 0.99, "rot": 6},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "heavy": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -4, "dy": -1, "sx": 0.98, "sy": 1.06, "rot": -4},
        {"dx": -8, "dy": -6, "sx": 0.94, "sy": 1.16, "rot": -10},
        {"dx": 1, "dy": -8, "sx": 1.06, "sy": 1.10, "rot": 7},
        {"dx": 13, "dy": -1, "sx": 1.20, "sy": 0.88, "rot": 13},
        {"dx": 10, "dy": 3, "sx": 1.14, "sy": 0.86, "rot": 9},
        {"dx": 3, "dy": 1, "sx": 1.02, "sy": 0.98, "rot": 2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
}


def trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    pad = 3
    return image.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(image.width, bbox[2] + pad), min(image.height, bbox[3] + pad)))


def dominant_region_color(image: Image.Image, region: tuple[int, int, int, int], fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    pixels = image.load()
    counts: dict[tuple[int, int, int], int] = {}
    x0, y0, x1, y1 = region
    for y in range(max(0, y0), min(image.height, y1)):
        for x in range(max(0, x0), min(image.width, x1)):
            r, g, b, a = pixels[x, y]
            if a <= 32:
                continue
            key = (r // 24 * 24, g // 24 * 24, b // 24 * 24)
            counts[key] = counts.get(key, 0) + int(a)
    if not counts:
        return fallback
    return max(counts.items(), key=lambda item: item[1])[0]


def draw_integrated_base_texture(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
    phase_seed: int,
) -> None:
    width = max(1, x1 - x0)
    for band in range(3):
        y = cut_y + 5 + band * max(3, (bottom_y - cut_y) // 4)
        inset = 4 + band * 2
        alpha = 82 - band * 12
        draw.line((x0 + inset, y, x1 - inset, y), fill=(*bright, alpha), width=1)
    for mark in range(9):
        x = x0 + 5 + (mark * 7 + phase_seed * 3) % max(8, width - 10)
        y = cut_y + 4 + (mark * 5 + phase_seed) % max(6, bottom_y - cut_y - 4)
        color = bright if mark % 3 == 0 else dark
        draw.rectangle((x, y, x + 2, y + 1), fill=(*color, 78))


def draw_continuous_root_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
    accent: tuple[int, int, int],
) -> None:
    top_w = max(20, int((x1 - x0) * 0.58))
    points = [
        (cx - top_w // 2, cut_y - 3),
        (cx + top_w // 2, cut_y - 3),
        (x1 - 2, bottom_y - 6),
        (x1 - 8, bottom_y),
        (x0 + 7, bottom_y),
        (x0 + 1, bottom_y - 6),
    ]
    draw.polygon(points, fill=(*base, 238))
    draw.line((x0 + 8, bottom_y - 1, x1 - 8, bottom_y - 1), fill=(*dark, 220), width=3)
    draw.line((x0 + 10, cut_y + 5, x1 - 10, cut_y + 5), fill=(*bright, 96), width=2)
    draw.line((x0 + 12, bottom_y - 7, x1 - 12, bottom_y - 7), fill=(*dark, 126), width=2)
    draw.arc((x0 + 5, bottom_y - 9, x1 - 5, bottom_y + 5), 190, 350, fill=(*accent, 94), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_armor_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    top_w = max(24, int((x1 - x0) * 0.62))
    draw.polygon(
        [
            (cx - top_w // 2, cut_y - 2),
            (cx + top_w // 2, cut_y - 2),
            (x1 - 4, bottom_y - 4),
            (x1 - 10, bottom_y),
            (x0 + 10, bottom_y),
            (x0 + 4, bottom_y - 4),
        ],
        fill=(*base, 242),
    )
    draw.rectangle((x0 + 9, bottom_y - 5, x1 - 9, bottom_y - 2), fill=(*dark, 210))
    draw.line((x0 + 12, cut_y + 8, x1 - 12, cut_y + 8), fill=(*bright, 118), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_hide_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    top_w = max(24, int((x1 - x0) * 0.56))
    draw.polygon(
        [
            (cx - top_w // 2, cut_y - 3),
            (cx + top_w // 2, cut_y - 3),
            (x1 - 4, bottom_y - 7),
            (x1 - 15, bottom_y),
            (cx + 3, bottom_y - 3),
            (x0 + 13, bottom_y),
            (x0 + 3, bottom_y - 7),
        ],
        fill=(*base, 236),
    )
    draw.line((x0 + 9, bottom_y - 2, x1 - 11, bottom_y - 2), fill=(*dark, 198), width=3)
    draw.line((x0 + 11, cut_y + 6, x1 - 11, cut_y + 6), fill=(*bright, 104), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_imp_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    top_w = max(18, int((x1 - x0) * 0.48))
    draw.polygon(
        [
            (cx - top_w // 2, cut_y - 3),
            (cx + top_w // 2, cut_y - 3),
            (x1 - 5, bottom_y - 6),
            (x1 - 14, bottom_y),
            (x0 + 13, bottom_y),
            (x0 + 5, bottom_y - 6),
        ],
        fill=(*base, 238),
    )
    draw.rectangle((x0 + 11, bottom_y - 5, x1 - 11, bottom_y - 2), fill=(*dark, 190))
    draw.line((x0 + 10, cut_y + 5, x1 - 10, cut_y + 5), fill=(*bright, 108), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_amphibian_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    draw.ellipse((x0 + 2, cut_y - 5, x1 - 2, bottom_y + 2), fill=(*base, 230))
    draw.arc((x0 + 6, cut_y - 2, x1 - 6, bottom_y + 2), 200, 340, fill=(*dark, 180), width=3)
    draw.line((cx - 9, cut_y + 1, cx + 10, cut_y + 4), fill=(*bright, 125), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def walk_pose_values(style: str, locomotion_plan: str, stride: float, phase: float) -> tuple[float, int, float, float, float, int]:
    if locomotion_plan == "snail_slide":
        return 0, int(math.cos(phase * 2) * 1), 0.96 - 0.025 * abs(stride), 1.04 + 0.035 * abs(stride), stride * 1.2, 8
    if locomotion_plan == "worm_slither":
        return -abs(stride) * 2, int(math.cos(phase * 2) * 2), 0.92 - 0.030 * abs(stride), 1.10 + 0.060 * abs(stride), stride * 4.5, 10
    if locomotion_plan == "winged_hover":
        return -abs(stride) * 4, int(math.cos(phase * 2) * 3), 0.98, 1.02 + 0.030 * abs(stride), stride * 8.0, 8
    if locomotion_plan == "tendril_float":
        return -abs(stride) * 2, int(math.cos(phase * 2) * 3), 0.97 - 0.020 * abs(stride), 1.04 + 0.035 * abs(stride), stride * 3.5, 7
    if locomotion_plan == "flame_wisp":
        return -abs(stride) * 3, int(math.cos(phase * 2) * 4), 0.95 - 0.035 * abs(stride), 1.08 + 0.050 * abs(stride), stride * 5.5, 8
    if locomotion_plan == "amphibian_hop":
        return -abs(stride) * 7, int(math.cos(phase * 2) * 2), 0.93 - 0.045 * abs(math.cos(phase * 2)), 1.08 + 0.060 * abs(stride), stride * 5.0, 10
    if locomotion_plan == "armored_biped":
        return -abs(stride) * 3, int(math.cos(phase * 2) * 1), 0.98 - 0.025 * abs(math.cos(phase * 2)), 1.03 + 0.030 * abs(stride), stride * 4.0, 7
    if locomotion_plan == "beast_biped":
        return -abs(stride) * 4, int(math.cos(phase * 2) * 2), 0.96 - 0.035 * abs(math.cos(phase * 2)), 1.06 + 0.045 * abs(stride), stride * 5.5, 9
    if locomotion_plan == "hunched_shambler":
        return -abs(stride) * 4, int(math.cos(phase * 2) * 2), 0.94 - 0.040 * abs(math.cos(phase * 2)), 1.07 + 0.050 * abs(stride), stride * 4.5, 8
    return -abs(stride) * (5 if style != "heavy" else 3), int(math.cos(phase * 2) * 2), 0.96, 1.05, stride * 5.0, 8


def apply_walk_pose(base: Image.Image, sx: float, sy: float, rotation: float) -> Image.Image:
    crop = trim_alpha(base)
    crop = crop.resize((max(1, round(crop.width * sx)), max(1, round(crop.height * sy))), Image.Resampling.NEAREST)
    if abs(rotation) > 0.1:
        crop = crop.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - crop.width) // 2
    y = FRAME_SIZE - 16 - crop.height
    canvas.alpha_composite(crop, (x, y))
    return canvas


def draw_shape_aware_walk_motion(frame: Image.Image, index: int, style: str, tint: tuple[int, int, int], sign: int, locomotion_plan: str) -> None:
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (44, 48, 84, 108)
    foot_y = min(116, bbox[3] - 2)
    cx = (bbox[0] + bbox[2]) // 2
    phase = index / FRAME_COUNT * math.tau
    bright = tuple(min(255, channel + 28) for channel in tint)
    dark = tuple(max(0, channel - 48) for channel in tint)

    if locomotion_plan == "snail_slide":
        draw_slug_trail(draw, bbox, tint, sign, phase)
        return

    if locomotion_plan == "worm_slither":
        draw_slug_trail(draw, bbox, tint, sign, phase)
        draw_slither_marks(draw, bbox, tint, phase)
        return

    if locomotion_plan == "winged_hover":
        draw_hover_shadow(draw, bbox, tint)
        return

    if locomotion_plan in {"tendril_float", "flame_wisp", "hunched_shambler"}:
        draw_tendril_sway(draw, bbox, tint, bright, dark, phase)
        if locomotion_plan == "hunched_shambler":
            draw_slug_trail(draw, bbox, tint, sign, phase)
        return

    if locomotion_plan == "amphibian_hop":
        draw_slug_trail(draw, bbox, tint, sign, phase)
        return

    draw_slug_trail(draw, bbox, tint, sign, phase)


def draw_slug_trail(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], sign: int, phase: float) -> None:
    y = min(116, bbox[3] - 2)
    for mark in range(4):
        x = bbox[0] - sign * (mark * 8 + int(math.sin(phase + mark) * 2))
        draw.ellipse((x, y + mark % 2, x + 10, y + 3 + mark % 2), fill=(*tint, 28))


def draw_slither_marks(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], phase: float) -> None:
    base_y = min(116, bbox[3] - 3)
    for mark in range(3):
        x = bbox[0] + 8 + mark * max(6, (bbox[2] - bbox[0]) // 4)
        y = base_y - int(abs(math.sin(phase + mark)) * 5)
        draw.arc((x - 7, y - 4, x + 8, y + 7), 180, 350, fill=(*tint, 88), width=2)


def draw_hover_shadow(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int]) -> None:
    draw.ellipse((bbox[0] + 14, bbox[3] + 5, bbox[2] - 12, bbox[3] + 8), fill=(*tint, 18))


def draw_tendril_sway(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], bright: tuple[int, int, int], dark: tuple[int, int, int], phase: float) -> None:
    cx = (bbox[0] + bbox[2]) // 2
    foot_y = min(116, bbox[3] - 2)
    hem_y = bbox[3] - 8
    for tendril in range(3):
        sway = int(math.sin(phase + tendril * 1.2) * 7)
        x0 = cx - 12 + tendril * 12
        color = bright if tendril % 2 == 0 else dark
        draw.ellipse((x0 + sway - 3, hem_y - 2, x0 + sway + 4, foot_y), fill=(*color, 62))


def tone_down_native_attack_pose(pose: dict[str, float], index: int) -> dict[str, float]:
    stage = ATTACK_STAGES[index]
    tuned = dict(pose)
    tuned["dx"] = {"ready": 0, "anticipation": -4, "coil": -7, "release": 7, "impact": 13, "follow_through": 8, "recover": 3, "settle": 0}[stage]
    tuned["dy"] = {"ready": 0, "anticipation": 1, "coil": 2, "release": -1, "impact": -2, "follow_through": -1, "recover": 0, "settle": 0}[stage]
    tuned["rot"] = float(tuned["rot"]) * 0.22
    tuned["sx"] = 1.0 + (float(tuned["sx"]) - 1.0) * 0.22
    tuned["sy"] = 1.0 + (float(tuned["sy"]) - 1.0) * 0.22
    return tuned


def draw_native_attack_readability(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 48, 86, 108)
    height = bbox[3] - bbox[1]
    mouth_y = bbox[1] + int(height * 0.42)
    ground_y = min(116, bbox[3] - 2)
    front_x = bbox[2] if sign > 0 else bbox[0]
    if stage in {"release", "impact", "follow_through"}:
        bright = tuple(min(255, channel + 42) for channel in tint)
        dark = tuple(max(0, channel - 62) for channel in tint)
        alpha = 122 if stage == "impact" else 78
        mark_x = front_x - sign * 6
        draw.ellipse((mark_x - 3, mouth_y - 4, mark_x + 3, mouth_y + 2), fill=(*bright, alpha))
        draw.ellipse((mark_x - 5, mouth_y + 1, mark_x + 2, mouth_y + 5), fill=(*dark, int(alpha * 0.54)))
        draw.ellipse((bbox[0] + 5, ground_y + 1, bbox[2] - 5, ground_y + 4), fill=(*tint, 26 if stage != "impact" else 42))


def draw_root_shambler_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (44, 42, 84, 112)
    root_y = min(116, bbox[3] - 3)
    front_x = bbox[2] if sign > 0 else bbox[0]
    back_x = bbox[0] if sign > 0 else bbox[2]
    width = bbox[2] - bbox[0]
    base = dominant_region_color(frame, (bbox[0], max(0, bbox[3] - 24), bbox[2], bbox[3]), tint)
    bright = tuple(min(255, channel + 38) for channel in base)
    dark = tuple(max(0, channel - 54) for channel in base)
    reach = {
        "ready": 4,
        "anticipation": -5,
        "coil": -9,
        "release": 11,
        "impact": 19,
        "follow_through": 15,
        "recover": 7,
        "settle": 3,
    }[stage]
    phase = index / FRAME_COUNT * math.tau
    draw.ellipse((bbox[0] + 4, root_y + 1, bbox[2] - 3, root_y + 5), fill=(*dark, 72))
    if stage in {"anticipation", "coil"}:
        for mark in range(3):
            x0 = back_x - sign * (4 + mark * 7)
            y0 = root_y - 2 - mark
            draw.ellipse((x0 - 4, y0 - 2, x0 + 4, y0 + 3), fill=(*dark, 54))
    for strand in range(3):
        start_x = front_x - sign * (4 + strand * max(3, width // 9))
        start_y = root_y - 5 - strand
        end_x = front_x + sign * (max(-3, min(9, reach)) + strand * 3)
        end_y = root_y - 3 + int(math.sin(phase + strand) * 2)
        if stage in {"ready", "settle"}:
            end_x = front_x + sign * (3 + strand * 3)
        color = bright if strand == 1 else base
        alpha = 138 if stage == "impact" else 104
        draw.polygon(
            [
                (start_x, start_y - 2),
                (end_x, end_y - 3),
                (end_x + sign * 3, end_y + 2),
                (start_x - sign * 2, start_y + 3),
            ],
            fill=(*color, alpha),
        )
        if stage == "impact" and strand == 1:
            draw.ellipse((end_x - 3, end_y - 4, end_x + 4, end_y + 3), fill=(*bright, 116))


def draw_worm_slither_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 54, 86, 112)
    front_x = bbox[2] if sign > 0 else bbox[0]
    mid_y = (bbox[1] + bbox[3]) // 2
    ground_y = min(116, bbox[3] - 2)
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 42) for channel in base)
    dark = tuple(max(0, channel - 60) for channel in base)
    reach = {
        "ready": 2,
        "anticipation": -4,
        "coil": -7,
        "release": 7,
        "impact": 13,
        "follow_through": 9,
        "recover": 4,
        "settle": 1,
    }[stage]
    trail_alpha = 52 if stage in {"release", "impact", "follow_through"} else 34
    for mark in range(3):
        x0 = bbox[0] - sign * (mark * 10 + index)
        draw.ellipse((x0, ground_y + mark % 2, x0 + 13, ground_y + 3 + mark % 2), fill=(*dark, trail_alpha))
    if stage in {"release", "impact", "follow_through"}:
        jaw_x = front_x + sign * reach
        upper_y = mid_y - 6
        lower_y = mid_y + 4
        alpha = 132 if stage == "impact" else 92
        draw.polygon(
            [
                (front_x - sign * 5, upper_y - 2),
                (jaw_x, mid_y - 2),
                (front_x - sign * 5, lower_y + 3),
                (front_x - sign * 9, mid_y + 1),
            ],
            fill=(*bright, alpha),
        )
        draw.ellipse((min(front_x, jaw_x) - 3, mid_y - 3, max(front_x, jaw_x) + 2, mid_y + 4), fill=(*dark, int(alpha * 0.44)))


def draw_snail_slide_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (40, 58, 90, 112)
    front_x = bbox[2] if sign > 0 else bbox[0]
    mid_y = (bbox[1] + bbox[3]) // 2
    foot_y = min(116, bbox[3] - 2)
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 36) for channel in base)
    dark = tuple(max(0, channel - 58) for channel in base)
    phase = index / FRAME_COUNT * math.tau
    draw_slug_trail(draw, bbox, tint, sign, phase)
    if stage in {"anticipation", "coil"}:
        draw.ellipse((bbox[0] + 4, foot_y + 1, bbox[2] - 4, foot_y + 5), fill=(*dark, 54))
    if stage in {"release", "impact", "follow_through"}:
        reach = {"release": 6, "impact": 12, "follow_through": 8}[stage]
        sip_x = front_x + sign * reach
        alpha = 118 if stage == "impact" else 82
        draw.ellipse((min(front_x - sign * 2, sip_x) - 3, mid_y - 6, max(front_x - sign * 2, sip_x) + 3, mid_y + 1), fill=(*bright, alpha))
        draw.ellipse((min(front_x - sign * 2, sip_x - sign * 2) - 2, mid_y + 1, max(front_x - sign * 2, sip_x - sign * 2) + 2, mid_y + 7), fill=(*dark, int(alpha * 0.56)))
        for droplet in range(2):
            x = front_x + sign * (4 + droplet * 5)
            y = mid_y + 7 + droplet
            draw.ellipse((x - 1, y - 1, x + 2, y + 1), fill=(*tint, 88))


def draw_winged_hover_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (38, 40, 90, 98)
    cy = (bbox[1] + bbox[3]) // 2
    front_x = bbox[2] if sign > 0 else bbox[0]
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 42) for channel in base)
    if stage in {"release", "impact", "follow_through"}:
        reach = {"release": 7, "impact": 13, "follow_through": 9}[stage]
        tip_x = front_x + sign * min(8, reach)
        tip_y = cy + (2 if stage == "impact" else 0)
        draw.ellipse((min(front_x - sign * 2, tip_x) - 2, tip_y - 3, max(front_x - sign * 2, tip_x) + 2, tip_y + 3), fill=(*bright, 44 if stage == "impact" else 28))
    draw_hover_shadow(draw, bbox, tint)


def draw_floating_body_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int, locomotion_plan: str) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 38, 86, 110)
    front_x = bbox[2] if sign > 0 else bbox[0]
    mid_y = (bbox[1] + bbox[3]) // 2
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 46) for channel in base)
    dark = tuple(max(0, channel - 56) for channel in base)
    phase = index / FRAME_COUNT * math.tau
    reach = {
        "ready": 3,
        "anticipation": -5,
        "coil": -8,
        "release": 10,
        "impact": 17,
        "follow_through": 12,
        "recover": 5,
        "settle": 2,
    }[stage]
    if locomotion_plan == "flame_wisp":
        for lick in range(3):
            start_x = front_x - sign * (8 + lick * 4)
            start_y = mid_y - 10 + lick * 8
            end_x = front_x + sign * (max(2, min(8, reach)) + lick * 2)
            end_y = start_y + int(math.sin(phase + lick) * 4)
            alpha = 130 if stage == "impact" else 88
            draw.ellipse((min(start_x, end_x) - 3, min(start_y, end_y) - 3, max(start_x, end_x) + 3, max(start_y, end_y) + 4), fill=(*bright, int(alpha * 0.62)))
            draw.ellipse((min(start_x - sign * 2, end_x - sign * 3) - 2, min(start_y + 2, end_y + 3) - 2, max(start_x - sign * 2, end_x - sign * 3) + 2, max(start_y + 2, end_y + 3) + 2), fill=(*dark, int(alpha * 0.36)))
    else:
        for tendril in range(4):
            start_x = front_x - sign * (4 + tendril * 3)
            start_y = bbox[1] + 16 + tendril * max(6, (bbox[3] - bbox[1]) // 7)
            local_reach = max(-3, min(8, reach))
            bend_x = start_x + sign * (local_reach // 2 + tendril)
            bend_y = start_y + int(math.sin(phase + tendril) * 5)
            end_x = front_x + sign * (max(2, local_reach) + tendril * 2)
            end_y = start_y + int(math.cos(phase + tendril) * 4)
            alpha = 124 if stage == "impact" else 86
            color = bright if tendril % 2 == 0 else dark
            draw.polygon(
                [
                    (start_x, start_y - 3),
                    (bend_x, bend_y - 4),
                    (end_x + sign * 2, end_y),
                    (bend_x, bend_y + 4),
                    (start_x - sign * 2, start_y + 3),
                ],
                fill=(*color, int(alpha * 0.74)),
            )
    draw.ellipse((bbox[0] + 8, bbox[3] + 2, bbox[2] - 8, bbox[3] + 6), fill=(*tint, 22))


def draw_source_biped_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int, locomotion_plan: str, style: str) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 34, 88, 116)
    front_x = bbox[2] if sign > 0 else bbox[0]
    hip_y = bbox[1] + int((bbox[3] - bbox[1]) * 0.66)
    base = dominant_region_color(frame, bbox, tint)
    dark = tuple(max(0, channel - 60) for channel in base)
    if stage in {"anticipation", "coil"}:
        draw.ellipse((front_x - sign * 13, hip_y - 4, front_x - sign * 5, hip_y + 2), fill=(*dark, 58))
    if stage in {"release", "impact", "follow_through"}:
        alpha = 74 if stage == "impact" else 46
        draw.ellipse((front_x - sign * 10, hip_y - 5, front_x + sign * 3, hip_y + 4), fill=(*base, alpha))
    draw.ellipse((bbox[0] + 8, min(116, bbox[3] - 1), bbox[2] - 8, min(120, bbox[3] + 3)), fill=(*tint, 20))


def draw_source_locked_fallback_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int, locomotion_plan: str, style: str) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 34, 88, 116)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    front_x = bbox[2] if sign > 0 else bbox[0]
    focus_y = bbox[1] + int(height * (0.50 if style in {"flyer", "caster"} else 0.62))
    base = dominant_region_color(frame, bbox, tint)
    dark = tuple(max(0, channel - 54) for channel in base)
    bright = tuple(min(255, channel + 34) for channel in base)
    if stage in {"anticipation", "coil"}:
        pull = 10 if stage == "coil" else 6
        draw.ellipse((front_x - sign * pull - 5, focus_y - 5, front_x - sign * pull + 5, focus_y + 5), fill=(*dark, 42))
    elif stage in {"release", "impact", "follow_through"}:
        push = {"release": 5, "impact": 9, "follow_through": 6}[stage]
        alpha = 66 if stage == "impact" else 42
        draw.ellipse((front_x - sign * 8, focus_y - 6, front_x + sign * push, focus_y + 6), fill=(*bright, alpha))
    shadow_pad = max(6, width // 7)
    shadow_y = min(117, bbox[3])
    draw.ellipse((bbox[0] + shadow_pad, shadow_y - 1, bbox[2] - shadow_pad, shadow_y + 4), fill=(*tint, 18))


def amplified_attack_pose(style: str, index: int) -> dict[str, float]:
    pose = dict(ATTACK_POSES.get(style, ATTACK_POSES["crawler"])[index])
    stage = ATTACK_STAGES[index]
    dx_factor = {
        "crawler": 1.42,
        "flyer": 1.38,
        "shooter": 1.62,
        "caster": 2.22,
        "charger": 1.34,
        "duelist": 1.46,
        "heavy": 1.52,
    }.get(style, 1.42)
    if stage in {"anticipation", "coil", "release", "impact", "follow_through"}:
        pose["dx"] = float(pose["dx"]) * dx_factor
        pose["rot"] = float(pose["rot"]) * 1.18
        pose["sx"] = 1.0 + (float(pose["sx"]) - 1.0) * 1.22
        pose["sy"] = 1.0 + (float(pose["sy"]) - 1.0) * 1.16
    if style == "flyer":
        pose["rot"] = float(pose["rot"]) * 0.62
        pose["sx"] = 1.0 + (float(pose["sx"]) - 1.0) * 0.58
        pose["sy"] = 1.0 + (float(pose["sy"]) - 1.0) * 0.58
    return pose


def apply_locomotion_attack_bias(pose: dict[str, float], locomotion_plan: str, index: int) -> dict[str, float]:
    stage = ATTACK_STAGES[index]
    biased = dict(pose)
    if locomotion_plan == "winged_hover" and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 5, "impact": 9, "follow_through": 6}[stage]
        biased["rot"] = float(biased["rot"]) + {"release": 2, "impact": 4, "follow_through": 2}[stage]
    elif locomotion_plan in {"tendril_float", "flame_wisp"} and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 6, "impact": 12, "follow_through": 8}[stage]
        biased["sy"] = 1.0 + (float(biased["sy"]) - 1.0) * 1.2
    elif locomotion_plan == "snail_slide" and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 8, "impact": 14, "follow_through": 10}[stage]
        biased["sx"] = 1.0 + (float(biased["sx"]) - 1.0) * 1.35
    elif locomotion_plan == "worm_slither" and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 7, "impact": 15, "follow_through": 9}[stage]
        biased["sx"] = 1.0 + (float(biased["sx"]) - 1.0) * 1.3
    elif locomotion_plan == "hunched_shambler":
        biased["dx"] = float(biased["dx"]) + {
            "ready": 0,
            "anticipation": -4,
            "coil": -7,
            "release": 4,
            "impact": 9,
            "follow_through": 6,
            "recover": 2,
            "settle": 0,
        }[stage]
        biased["rot"] = float(biased["rot"]) * 0.55
        biased["sx"] = 1.0 + (float(biased["sx"]) - 1.0) * 0.86
        biased["sy"] = 1.0 + (float(biased["sy"]) - 1.0) * 0.92
    return biased


def apply_attack_pose(base: Image.Image, pose: dict[str, float], sign: int) -> Image.Image:
    crop = trim_alpha(base)
    sx = max(0.70, float(pose["sx"]))
    sy = max(0.70, float(pose["sy"]))
    width = max(1, round(crop.width * sx))
    height = max(1, round(crop.height * sy))
    crop = crop.resize((width, height), Image.Resampling.NEAREST)
    rotation = float(pose["rot"]) * sign
    if abs(rotation) > 0.1:
        crop = crop.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - crop.width) // 2
    y = FRAME_SIZE - 16 - crop.height
    canvas.alpha_composite(crop, (x, y))
    return canvas


def draw_motion_dust(frame: Image.Image, index: int, tint: tuple[int, int, int], style: str, locomotion_plan: str) -> None:
    if locomotion_plan in {"winged_hover", "tendril_float", "flame_wisp"}:
        return
    draw = ImageDraw.Draw(frame, "RGBA")
    phase = index % 4
    alpha = 34 if locomotion_plan in {"snail_slide", "worm_slither"} else 55
    for dot in range(3):
        x = 38 + dot * 12 - phase * 2
        y = 112 + (dot % 2) * 2
        draw.ellipse((x, y, x + 4, y + 2), fill=(*tint, alpha))
