"""Frame banks, frame clean-up and the idle, walk, attack, hurt and death poses for small enemies.

Moved out of build_small_enemy_runtime_assets.py unchanged; build_small_enemy_runtime_assets.py imports these names back."""
from __future__ import annotations
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps
from small_enemy_poses import (ATTACK_POSES, ATTACK_STAGES, FRAME_COUNT, FRAME_SIZE,
    amplified_attack_pose, apply_attack_pose, apply_locomotion_attack_bias, apply_walk_pose,
    dominant_region_color, draw_continuous_amphibian_base, draw_continuous_armor_base,
    draw_continuous_hide_base, draw_continuous_imp_base, draw_continuous_root_base,
    draw_floating_body_attack, draw_hover_shadow, draw_integrated_base_texture, draw_motion_dust,
    draw_native_attack_readability, draw_root_shambler_attack, draw_shape_aware_walk_motion,
    draw_slither_marks, draw_slug_trail, draw_snail_slide_attack, draw_source_biped_attack,
    draw_source_locked_fallback_attack, draw_tendril_sway, draw_winged_hover_attack,
    draw_worm_slither_attack, tone_down_native_attack_pose, trim_alpha, walk_pose_values)


PREVIEW_GAP = 40


SOURCE_SEQUENCE_OVERRIDES: dict[str, dict[str, list[int]]] = {
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png": {
        "walk": [5, 3, 1, 0, 5, 3, 1, 0],
        "attack": [5, 6, 8, 9, 7, 8, 6, 5],
    },
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png": {
        "walk": [5, 3, 1, 0, 5, 3, 1, 0],
        "attack": [5, 6, 8, 9, 7, 8, 6, 5],
    },
    "surt-emceeflesher-spitsnail-alpha_0.png": {
        "walk": [0, 1, 2, 3, 0, 1, 2, 3],
        "attack": [10, 11, 12, 13, 14, 15, 16, 17],
    },
}


CONNECTED_COMPONENT_SOURCES = {
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png",
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png",
}


CHROMA_KEY_SOURCES = {
    "redshrike-emceeflesher-eyewasp-alpha.png",
    "redshrike-emceeflesher-skullwasp-alpha.png",
    "redshrike-emceeflesher-wasp.png",
}


DETACHED_THIN_ARTIFACT_SOURCES = {
    "calciumtrice-emceeflesher-worm-alpha.png",
}


FOOTLESS_RESHAPE_PLANS = {
    "hunched_shambler",
    "amphibian_hop",
    "armored_biped",
    "beast_biped",
    "biped_imp",
}


def expand_frames(frames: list[Image.Image], count: int) -> list[Image.Image]:
    result: list[Image.Image] = []
    for index in range(count):
        source = frames[index % len(frames)]
        result.append(source.copy())
    return result


def build_frame_bank(source_name: str, image: Image.Image, cell_w: int, cell_h: int) -> list[Image.Image]:
    if source_name in CONNECTED_COMPONENT_SOURCES:
        return build_connected_component_frame_bank(image)
    frames: list[Image.Image] = []
    for y in range(0, image.height, cell_h):
        for x in range(0, image.width, cell_w):
            if x + cell_w > image.width or y + cell_h > image.height:
                continue
            frame = image.crop((x, y, x + cell_w, y + cell_h))
            if source_name in CHROMA_KEY_SOURCES:
                frame = remove_flat_source_background(frame)
            if source_name in DETACHED_THIN_ARTIFACT_SOURCES:
                frame = remove_detached_thin_source_artifacts(frame)
            if frame.getchannel("A").getbbox() is not None:
                frames.append(frame)
            else:
                frames.append(Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0)))
    return frames


def remove_flat_source_background(image: Image.Image) -> Image.Image:
    frame = image.convert("RGBA")
    pixels = frame.load()
    candidates: dict[tuple[int, int, int], int] = {}
    for x in range(frame.width):
        for y in (0, frame.height - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_likely_flat_sheet_background(red, green, blue):
                candidates[(red, green, blue)] = candidates.get((red, green, blue), 0) + 1
    for y in range(frame.height):
        for x in (0, frame.width - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_likely_flat_sheet_background(red, green, blue):
                candidates[(red, green, blue)] = candidates.get((red, green, blue), 0) + 1
    if not candidates:
        return frame
    key = max(candidates.items(), key=lambda item: item[1])[0]
    for y in range(frame.height):
        for x in range(frame.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and color_distance_sq((red, green, blue), key) <= 28 * 28:
                pixels[x, y] = (red, green, blue, 0)
    return frame


def remove_detached_thin_source_artifacts(image: Image.Image) -> Image.Image:
    frame = image.convert("RGBA")
    pixels = frame.load()
    for area, bbox, points in connected_components_for_image(frame):
        x0, y0, x1, y1 = bbox
        width = x1 - x0
        height = y1 - y0
        aspect = width / max(1, height)
        if area <= 80 and width >= 18 and height <= 3 and aspect >= 6 and y0 < frame.height * 0.72:
            for x, y in points:
                red, green, blue, _alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    return frame


def is_likely_flat_sheet_background(red: int, green: int, blue: int) -> bool:
    strong_blue = blue > 170 and red < 80 and green < 110
    purple = blue > 85 and red > 45 and red < 135 and green < 60
    return strong_blue or purple


def color_distance_sq(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((left[index] - right[index]) ** 2 for index in range(3))


def build_connected_component_frame_bank(image: Image.Image) -> list[Image.Image]:
    components = connected_components_for_image(image)
    frames: list[Image.Image] = []
    for _area, bbox, points in components:
        x0, y0, x1, y1 = bbox
        pad = 4
        crop_box = (max(0, x0 - pad), max(0, y0 - pad), min(image.width, x1 + pad), min(image.height, y1 + pad))
        crop = Image.new("RGBA", (crop_box[2] - crop_box[0], crop_box[3] - crop_box[1]), (0, 0, 0, 0))
        source = image.load()
        target = crop.load()
        for x, y in points:
            if crop_box[0] <= x < crop_box[2] and crop_box[1] <= y < crop_box[3]:
                target[x - crop_box[0], y - crop_box[1]] = source[x, y]
        frames.append(crop)
    return frames


def connected_components_for_image(image: Image.Image) -> list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]]:
    pixels = image.load()
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    result: list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]] = []
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or pixels[x, y][3] <= 0:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            points: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                points.append((px, py))
                for nx in (px - 1, px, px + 1):
                    for ny in (py - 1, py, py + 1):
                        if nx < 0 or ny < 0 or nx >= width or ny >= height:
                            continue
                        if (nx, ny) in seen or pixels[nx, ny][3] <= 0:
                            continue
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(points) < 20:
                continue
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
            result.append((len(points), bbox, points))
    return sorted(result, key=lambda item: (item[1][1], item[1][0]))


def select_source_frames(source_name: str, frame_bank: list[Image.Image], track: str, preferred_index: int, count: int) -> list[Image.Image]:
    override = SOURCE_SEQUENCE_OVERRIDES.get(source_name, {}).get(track)
    if override:
        selected = [
            frame_bank[index].copy()
            for index in override
            if 0 <= index < len(frame_bank) and frame_bank[index].getchannel("A").getbbox() is not None
        ]
        if selected:
            return expand_frames(selected, count)
    fallback = build_frames_from_bank(frame_bank, preferred_index)
    return expand_frames(fallback, count)


def build_frames_from_bank(frame_bank: list[Image.Image], preferred_index: int) -> list[Image.Image]:
    tiles: list[tuple[int, Image.Image, int, tuple[int, int, int, int]]] = []
    for index, frame in enumerate(frame_bank):
        bbox = frame.getchannel("A").getbbox()
        if bbox is None:
            continue
        if looks_like_label_tile(frame):
            continue
        tiles.append((index, frame, alpha_area(frame), bbox))
    if not tiles:
        return []
    tiles = filter_actor_tiles(tiles)
    after = [frame for index, frame, _area, _bbox in tiles if index >= preferred_index]
    before = [frame for index, frame, _area, _bbox in tiles if index < preferred_index]
    ordered = after + before
    while len(ordered) < 6:
        ordered.extend(ordered)
    return [frame.copy() for frame in ordered[:8]]


def filter_actor_tiles(tiles: list[tuple[int, Image.Image, int, tuple[int, int, int, int]]]) -> list[tuple[int, Image.Image, int, tuple[int, int, int, int]]]:
    max_area = max(area for _index, _frame, area, _bbox in tiles)
    max_width = max(bbox[2] - bbox[0] for _index, _frame, _area, bbox in tiles)
    max_height = max(bbox[3] - bbox[1] for _index, _frame, _area, bbox in tiles)
    min_area = max(18, int(max_area * 0.24))
    min_width = max(4, int(max_width * 0.25))
    min_height = max(4, int(max_height * 0.25))
    filtered = [
        tile for tile in tiles
        if tile[2] >= min_area
        and tile[3][2] - tile[3][0] >= min_width
        and tile[3][3] - tile[3][1] >= min_height
    ]
    return filtered or tiles


def looks_like_label_tile(frame: Image.Image) -> bool:
    tile = frame.convert("RGBA")
    pixels = tile.load()
    opaque_count = 0
    white = 0
    pale = 0
    colored = 0
    for y in range(tile.height):
        for x in range(tile.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= 0:
                continue
            opaque_count += 1
            if red > 215 and green > 215 and blue > 215:
                white += 1
            if red > 175 and green > 175 and blue > 175:
                pale += 1
            if max(red, green, blue) - min(red, green, blue) > 45:
                colored += 1
    if opaque_count == 0:
        return False
    white_ratio = white / opaque_count
    pale_ratio = pale / opaque_count
    colored_ratio = colored / opaque_count
    return white_ratio > 0.34 and pale_ratio > 0.48 and colored_ratio < 0.34


def alpha_area(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    if hasattr(alpha, "get_flattened_data"):
        return sum(1 for value in alpha.get_flattened_data() if value > 0)
    return sum(1 for value in alpha.getdata() if value > 0)


def normalize_frame(source: Image.Image, tint: tuple[int, int, int], style: str, index: int, rng: random.Random) -> Image.Image:
    crop = trim_alpha(source)
    crop = ImageEnhance.Contrast(crop).enhance(1.08)
    crop = ImageEnhance.Color(crop).enhance(1.10)
    crop = tint_image(crop, tint, 0.16 + (index % 3) * 0.025)
    bbox = crop.getbbox()
    if bbox is None:
        return Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    max_w, max_h = max_dimensions(style)
    scale = min(max_w / max(1, crop.width), max_h / max(1, crop.height))
    scale *= 0.96 + rng.random() * 0.04
    crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - crop.width) // 2
    y = FRAME_SIZE - 16 - crop.height
    canvas.alpha_composite(crop, (x, y))
    return add_edge_light(canvas, tint)


def max_dimensions(style: str) -> tuple[int, int]:
    if style == "heavy":
        return (76, 84)
    if style in {"caster", "charger"}:
        return (70, 82)
    if style == "flyer":
        return (72, 64)
    if style == "crawler":
        return (72, 56)
    return (68, 74)


def tint_image(image: Image.Image, tint: tuple[int, int, int], strength: float) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            pixels[x, y] = (
                int(r * (1 - strength) + tint[0] * strength),
                int(g * (1 - strength) + tint[1] * strength),
                int(b * (1 - strength) + tint[2] * strength),
                a,
            )
    return rgba


def add_edge_light(image: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    alpha = image.getchannel("A")
    glow = alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    edge = Image.new("RGBA", image.size, (*tint, 0))
    edge.putalpha(glow.point(lambda value: min(90, value // 3)))
    result = Image.alpha_composite(edge, image)
    return result


def reshape_footless_frame(image: Image.Image, locomotion_plan: str, tint: tuple[int, int, int], style: str, index: int) -> Image.Image:
    if locomotion_plan not in FOOTLESS_RESHAPE_PLANS:
        return image
    frame = image.copy()
    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        return frame

    body_cx = weighted_alpha_center_x(frame, bbox)
    ratio = {
        "hunched_shambler": 0.72,
        "amphibian_hop": 0.58,
        "armored_biped": 0.62,
        "beast_biped": 0.58,
        "biped_imp": 0.60,
    }.get(locomotion_plan, 0.64)
    max_erase = {
        "hunched_shambler": 18,
        "amphibian_hop": 24,
        "armored_biped": 27,
        "beast_biped": 30,
        "biped_imp": 28,
    }.get(locomotion_plan, 24)
    height = bbox[3] - bbox[1]
    cut_y = max(bbox[1] + int(height * ratio), bbox[3] - max_erase)
    cut_y = min(cut_y, bbox[3] - 8)
    bottom_y = min(FRAME_SIZE - 4, bbox[3] + 1)
    band_w = footless_band_width(bbox, locomotion_plan)
    x0 = max(2, body_cx - band_w // 2)
    x1 = min(FRAME_SIZE - 3, body_cx + band_w // 2)

    alpha = frame.getchannel("A")
    alpha_draw = ImageDraw.Draw(alpha)
    alpha_draw.rectangle((x0, cut_y - 2, x1, min(FRAME_SIZE - 1, bottom_y + 4)), fill=0)
    frame.putalpha(alpha)

    draw = ImageDraw.Draw(frame, "RGBA")
    base = dominant_region_color(image, (max(0, x0 - 4), max(0, cut_y - 18), min(FRAME_SIZE, x1 + 4), max(cut_y, bottom_y)), tint)
    bright = tuple(min(255, channel + 34) for channel in base)
    dark = tuple(max(0, channel - 58) for channel in base)
    accent = tuple(min(255, channel + 18) for channel in tint)
    sway = int(math.sin(index / FRAME_COUNT * math.tau) * 3)

    if locomotion_plan == "hunched_shambler":
        draw_continuous_root_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark, accent)
    elif locomotion_plan == "armored_biped":
        draw_continuous_armor_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    elif locomotion_plan == "beast_biped":
        draw_continuous_hide_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    elif locomotion_plan == "biped_imp":
        draw_continuous_imp_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    elif locomotion_plan == "amphibian_hop":
        draw_continuous_amphibian_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    return frame


def weighted_alpha_center_x(image: Image.Image, bbox: tuple[int, int, int, int]) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    top = bbox[1]
    bottom = bbox[1] + int((bbox[3] - bbox[1]) * 0.72)
    total = 0
    weighted = 0
    for y in range(top, max(top + 1, bottom)):
        for x in range(bbox[0], bbox[2]):
            value = pixels[x, y]
            if value <= 24:
                continue
            total += value
            weighted += x * value
    if total == 0:
        return (bbox[0] + bbox[2]) // 2
    return int(weighted / total)


def footless_band_width(bbox: tuple[int, int, int, int], locomotion_plan: str) -> int:
    width = bbox[2] - bbox[0]
    factor = {
        "hunched_shambler": 0.84,
        "amphibian_hop": 0.76,
        "armored_biped": 0.88,
        "beast_biped": 0.86,
        "biped_imp": 0.82,
    }.get(locomotion_plan, 0.72)
    return max(30, min(62, int(width * factor)))


def make_idle_frame(base: Image.Image, index: int, tint: tuple[int, int, int]) -> Image.Image:
    y = int(math.sin(index / 4 * math.tau) * 2)
    return offset_frame(base, 0, y, tint, 0.10)


def make_walk_frame(base: Image.Image, index: int, direction: str, style: str, tint: tuple[int, int, int], locomotion_plan: str) -> Image.Image:
    phase = index / FRAME_COUNT * math.tau
    stride = math.sin(phase)
    sign = 1 if direction == "right" else -1
    lift, bob, squash, stretch, lean, walk_stride = walk_pose_values(style, locomotion_plan, stride, phase)
    body = apply_walk_pose(base, stretch, squash, lean * sign)
    x = int(stride * walk_stride) * sign
    frame = offset_frame(body, x, int(lift + bob), tint, 0.14)
    draw_shape_aware_walk_motion(frame, index, style, tint, sign, locomotion_plan)
    draw_motion_dust(frame, index, tint, style, locomotion_plan)
    return contain_alpha(sharpen_alpha(frame), 3)


def make_attack_frame(base: Image.Image, index: int, direction: str, style: str, tint: tuple[int, int, int], locomotion_plan: str, native_attack: bool = False) -> Image.Image:
    pose = apply_locomotion_attack_bias(amplified_attack_pose(style, index), locomotion_plan, index)
    if native_attack:
        pose = tone_down_native_attack_pose(pose, index)
    sign = 1 if direction == "right" else -1
    body = apply_attack_pose(base, pose, sign)
    frame = offset_frame(body, int(pose["dx"]) * sign, int(pose["dy"]), tint, 0.22)
    if native_attack:
        draw_native_attack_readability(frame, index, tint, sign)
    elif locomotion_plan == "hunched_shambler":
        draw_root_shambler_attack(frame, index, tint, sign)
    elif locomotion_plan == "worm_slither":
        draw_worm_slither_attack(frame, index, tint, sign)
    elif locomotion_plan == "snail_slide":
        draw_snail_slide_attack(frame, index, tint, sign)
    elif locomotion_plan == "winged_hover":
        draw_winged_hover_attack(frame, index, tint, sign)
    elif locomotion_plan in {"tendril_float", "flame_wisp"}:
        draw_floating_body_attack(frame, index, tint, sign, locomotion_plan)
    elif locomotion_plan in {"armored_biped", "beast_biped", "biped_imp"}:
        draw_source_biped_attack(frame, index, tint, sign, locomotion_plan, style)
    else:
        draw_source_locked_fallback_attack(frame, index, tint, sign, locomotion_plan, style)
    return contain_alpha(sharpen_alpha(frame), 2)


def sharpen_alpha(frame: Image.Image) -> Image.Image:
    alpha = frame.getchannel("A")
    frame.putalpha(alpha.point(lambda value: 0 if value < 8 else value))
    return frame


def contain_alpha(frame: Image.Image, margin: int) -> Image.Image:
    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        return frame
    content = frame.crop(bbox)
    max_w = FRAME_SIZE - margin * 2
    max_h = FRAME_SIZE - margin * 2
    if content.width > max_w or content.height > max_h:
        scale = min(max_w / content.width, max_h / content.height)
        content = content.resize((max(1, int(content.width * scale)), max(1, int(content.height * scale))), Image.Resampling.NEAREST)
        bbox = (bbox[0], bbox[1], bbox[0] + content.width, bbox[1] + content.height)
    x = min(max(margin, bbox[0]), FRAME_SIZE - margin - content.width)
    y = min(max(margin, bbox[1]), FRAME_SIZE - margin - content.height)
    result = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    result.alpha_composite(content, (x, y))
    return result


def make_hurt_frame(base: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    frame = offset_frame(tint_image(base, (255, 90, 80), 0.28), -4, -2, tint, 0.0)
    draw = ImageDraw.Draw(frame, "RGBA")
    draw.line((36, 34, 50, 48), fill=(255, 80, 60, 190), width=3)
    draw.line((48, 34, 34, 48), fill=(255, 80, 60, 190), width=3)
    return frame


def make_death_frame(base: Image.Image, index: int, tint: tuple[int, int, int]) -> Image.Image:
    frame = tint_image(base, (70, 70, 76), 0.18 + index * 0.11)
    frame = offset_frame(frame, index * 2, index * 3, tint, 0.0)
    alpha = frame.getchannel("A").point(lambda value: int(value * max(0.18, 1.0 - index * 0.2)))
    frame.putalpha(alpha)
    return frame


def offset_frame(base: Image.Image, dx: int, dy: int, tint: tuple[int, int, int], shadow_alpha: float) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    if shadow_alpha > 0:
        shadow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow, "RGBA")
        shadow_draw.ellipse((42 + dx // 2, 106, 86 + dx // 2, 118), fill=(*tint, int(80 * shadow_alpha)))
        canvas.alpha_composite(shadow)
    canvas.alpha_composite(base, (dx, dy))
    return canvas


def save_animation_frames(frames_dir: Path, animation_name: str, frames: list[Image.Image]) -> list[Path]:
    out_dir = frames_dir / animation_name
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for index, frame in enumerate(frames):
        path = out_dir / f"{animation_name}_{index:02d}.png"
        frame.save(path)
        paths.append(path)
    return paths


def save_strip(path: Path, frames: list[Image.Image]) -> None:
    strip = Image.new("RGBA", (FRAME_COUNT * FRAME_SIZE + (FRAME_COUNT - 1) * PREVIEW_GAP, FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * (FRAME_SIZE + PREVIEW_GAP), 0))
    strip.save(path)
