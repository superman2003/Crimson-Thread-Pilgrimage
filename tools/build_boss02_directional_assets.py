from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS_NAME = "boss_02_crimson_thread_scissor_apostle"
BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses" / BOSS_NAME
FRAMES_ROOT = BOSS_ROOT / "frames"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes" / BOSS_NAME
PREVIEW_PATH = ARTIFACT_ROOT / "boss02_directional_contact.png"
MANIFEST_PATH = BOSS_ROOT / "manifest.json"

FRAME_SIZE = 256
TARGET_BOTTOM = 246
ATTACK_FRAME_COUNT = 8
WALK_FRAME_COUNT = 16
SOURCE_FACES_LEFT = False
ACTION_NAMES = [
    "walk",
    "attack",
    "boss_02_atk_01",
    "boss_02_atk_02",
    "boss_02_atk_03",
]


@dataclass(frozen=True)
class Motion:
    source_index: int
    rotation: float
    scale_x: float
    scale_y: float
    dx: float
    dy: float
    glow: float
    arc: float
    step_lift: float = 0.0


WALK_MOTIONS = [
    Motion(0, -1.0, 1.00, 1.00, -8.0, 0.0, 0.03, 0.00, 0.0),
    Motion(0, -0.4, 1.01, 0.99, -6.0, -1.0, 0.04, 0.00, 1.0),
    Motion(5, 0.7, 1.02, 0.98, -4.0, -2.0, 0.05, 0.00, 3.0),
    Motion(5, 1.2, 1.01, 0.99, -1.0, -2.0, 0.04, 0.00, 4.0),
    Motion(0, 1.0, 1.00, 1.00, 2.0, -1.0, 0.04, 0.00, 2.0),
    Motion(0, 0.4, 0.99, 1.01, 5.0, 0.0, 0.03, 0.00, 0.0),
    Motion(5, -0.5, 1.01, 0.99, 7.0, -1.0, 0.04, 0.00, 1.0),
    Motion(5, -1.0, 1.02, 0.98, 5.0, -2.0, 0.05, 0.00, 3.0),
    Motion(0, -0.8, 1.00, 1.00, 2.0, -2.0, 0.04, 0.00, 4.0),
    Motion(0, 0.0, 0.99, 1.01, -1.0, -1.0, 0.03, 0.00, 2.0),
    Motion(5, 0.9, 1.01, 0.99, -5.0, 0.0, 0.04, 0.00, 0.0),
    Motion(5, 1.4, 1.02, 0.98, -7.0, -1.0, 0.05, 0.00, 1.0),
    Motion(0, 0.6, 1.00, 1.00, -4.0, -2.0, 0.04, 0.00, 3.0),
    Motion(0, -0.5, 0.99, 1.01, 0.0, -2.0, 0.03, 0.00, 4.0),
    Motion(5, -1.2, 1.01, 0.99, 4.0, -1.0, 0.04, 0.00, 2.0),
    Motion(5, -0.6, 1.00, 1.00, 7.0, 0.0, 0.03, 0.00, 0.0),
]


MOTION_BY_ACTION = {
    "walk": WALK_MOTIONS,
    "attack": [
        Motion(0, -3.0, 1.00, 1.00, 0.0, 0.0, 0.06, 0.00),
        Motion(0, -6.0, 1.04, 0.96, 5.0, -3.0, 0.10, 0.08),
        Motion(1, -9.0, 1.08, 0.93, 10.0, -4.0, 0.14, 0.22),
        Motion(2, -5.0, 1.12, 0.90, 18.0, -2.0, 0.22, 0.42),
        Motion(3, 4.0, 1.16, 0.87, 25.0, 1.0, 0.32, 0.85),
        Motion(4, 8.0, 1.10, 0.92, 18.0, 2.0, 0.22, 0.44),
        Motion(5, 3.0, 1.04, 0.97, 8.0, 1.0, 0.10, 0.16),
        Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
    "boss_02_atk_01": [
        Motion(0, -2.0, 1.00, 1.00, 0.0, 0.0, 0.08, 0.00),
        Motion(1, -5.0, 1.03, 0.97, 2.0, -5.0, 0.14, 0.12),
        Motion(2, -7.0, 1.08, 0.94, 6.0, -8.0, 0.22, 0.25),
        Motion(3, 0.0, 1.15, 0.88, 0.0, 0.0, 0.34, 0.95),
        Motion(4, 5.0, 1.11, 0.92, -2.0, 2.0, 0.24, 0.55),
        Motion(4, 8.0, 1.07, 0.95, 2.0, 1.0, 0.18, 0.28),
        Motion(5, 2.0, 1.03, 0.98, 1.0, 0.0, 0.10, 0.10),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
    "boss_02_atk_02": [
        Motion(0, -3.0, 1.00, 1.00, -6.0, 0.0, 0.08, 0.00),
        Motion(1, -7.0, 1.04, 0.96, -12.0, -4.0, 0.14, 0.15),
        Motion(2, -8.0, 1.08, 0.93, -18.0, -5.0, 0.22, 0.32),
        Motion(3, -2.0, 1.13, 0.89, 6.0, -2.0, 0.30, 0.70),
        Motion(4, 6.0, 1.16, 0.86, 24.0, 2.0, 0.34, 1.00),
        Motion(4, 5.0, 1.10, 0.92, 18.0, 2.0, 0.24, 0.55),
        Motion(5, 1.0, 1.04, 0.97, 8.0, 1.0, 0.12, 0.18),
        Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
    "boss_02_atk_03": [
        Motion(0, -1.0, 1.00, 1.00, 0.0, 0.0, 0.08, 0.00),
        Motion(1, -4.0, 1.03, 0.97, 4.0, -8.0, 0.16, 0.18),
        Motion(2, -6.0, 1.07, 0.94, 8.0, -14.0, 0.24, 0.35),
        Motion(3, 0.0, 1.12, 0.90, 0.0, -6.0, 0.38, 0.95),
        Motion(3, 4.0, 1.14, 0.88, 12.0, 2.0, 0.30, 1.00),
        Motion(4, 6.0, 1.09, 0.93, 8.0, 3.0, 0.22, 0.50),
        Motion(5, 2.0, 1.04, 0.97, 4.0, 1.0, 0.12, 0.18),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
}

ACTION_FPS = {
    "walk": 9.0,
    "attack": 12.0,
    "boss_02_atk_01": 12.0,
    "boss_02_atk_02": 12.0,
    "boss_02_atk_03": 12.0,
}

ACTION_LOOP = {
    "walk": True,
    "attack": False,
    "boss_02_atk_01": False,
    "boss_02_atk_02": False,
    "boss_02_atk_03": False,
}


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    sources = load_sources()
    rows: list[tuple[str, list[Image.Image]]] = []

    for action_name, motions in MOTION_BY_ACTION.items():
        right_frames = build_action(action_name, sources[action_name], motions, "right")
        left_frames = build_action(action_name, sources[action_name], motions, "left")
        write_action_frames(action_name, "right", right_frames)
        write_action_frames(action_name, "left", left_frames)
        rows.append((action_name + "_left", left_frames))
        rows.append((action_name + "_right", right_frames))

    update_manifest(manifest)
    render_contact_sheet(rows, PREVIEW_PATH)
    total_frames = WALK_FRAME_COUNT * 2 + ATTACK_FRAME_COUNT * 8
    print(
        "BOSS02_DIRECTIONAL_ASSETS_BUILT "
        f"animations={len(ACTION_NAMES) * 2} frames={total_frames} "
        f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()} "
        f"preview={PREVIEW_PATH.relative_to(ROOT).as_posix()}"
    )


def load_sources() -> dict[str, list[Image.Image]]:
    result: dict[str, list[Image.Image]] = {}
    for action in ACTION_NAMES:
        source_dir = FRAMES_ROOT / ("attack" if action in ("walk", "attack") else action)
        frames = [Image.open(path).convert("RGBA") for path in sorted(source_dir.glob("attack_*.png"))]
        if len(frames) < 6:
            raise FileNotFoundError(f"{source_dir} needs at least 6 source frames")
        result[action] = [prepare_source_frame(frame, strict=action == "walk") for frame in frames]
    return result


def prepare_source_frame(image: Image.Image, strict: bool) -> Image.Image:
    cleaned = remove_green_spill(image)
    cleaned = remove_tiny_alpha_components(cleaned, min_pixels=220 if strict else 140)
    cleaned = ImageEnhance.Contrast(cleaned).enhance(1.08)
    cleaned = ImageEnhance.Sharpness(cleaned).enhance(1.10)
    return cleaned


def build_action(action_name: str, sources: list[Image.Image], motions: list[Motion], direction_name: str) -> list[Image.Image]:
    want_right = direction_name == "right"
    frames: list[Image.Image] = []
    for index, motion in enumerate(motions):
        seed = stable_seed(action_name, index)
        source = sources[min(motion.source_index, len(sources) - 1)]
        if want_right == SOURCE_FACES_LEFT:
            source = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frames.append(compose_frame(source, motion, action_name, direction_name, seed))
    return frames


def stable_seed(action_name: str, index: int) -> int:
    value = 2166136261
    for byte in f"{action_name}:{index}".encode("utf-8"):
        value ^= byte
        value = (value * 16777619) & 0xFFFFFFFF
    return value


def compose_frame(source: Image.Image, motion: Motion, action_name: str, direction_name: str, seed: int) -> Image.Image:
    rng = random.Random(seed)
    direction = 1 if direction_name == "right" else -1
    subject = normalize_subject(source, motion, direction)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    accent = (218, 42, 62, 255)

    if motion.glow > 0.0:
        canvas.alpha_composite(make_body_afterimage(subject, accent, motion.glow, -direction), (0, 0))
    if action_name == "walk":
        canvas.alpha_composite(make_thread_step_vfx(motion, direction), (0, 0))
    elif motion.arc > 0.0:
        canvas.alpha_composite(make_action_vfx(action_name, motion.arc, direction, accent, rng), (0, 0))

    bbox = subject.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return canvas
    x = int(FRAME_SIZE * 0.5 - subject.width * 0.5 + motion.dx * direction)
    bottom_y = TARGET_BOTTOM - int(motion.step_lift) + int(motion.dy)
    y = bottom_y - bbox[3]
    canvas.alpha_composite(subject, (x, y))
    canvas = add_ground_shadow(canvas, direction, motion)
    canvas = remove_tiny_alpha_components(canvas, min_pixels=36)
    return ensure_bottom(canvas, TARGET_BOTTOM)


def normalize_subject(source: Image.Image, motion: Motion, direction: int) -> Image.Image:
    bbox = source.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return source
    crop = source.crop(expand_bbox(bbox, source.size, 4))
    width, height = crop.size
    scale = min(226 / max(1, width), 236 / max(1, height))
    next_size = (
        max(1, int(width * scale * motion.scale_x)),
        max(1, int(height * scale * motion.scale_y)),
    )
    crop = crop.resize(next_size, Image.Resampling.LANCZOS)
    rotation = motion.rotation * direction
    if abs(rotation) > 0.01:
        crop = crop.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    return trim_alpha(crop)


def remove_green_spill(image: Image.Image) -> Image.Image:
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels: list[tuple[int, int, int, int]] = []
    for r, g, b, a in image.getdata():
        if a <= 0:
            pixels.append((0, 0, 0, 0))
            continue
        green_bias = g - max(r, b)
        if g > 82 and green_bias > 22:
            if green_bias > 34 or (g > 128 and r < 155):
                pixels.append((r, g, b, 0))
            else:
                pixels.append((min(255, int(r * 1.05) + 18), int(g * 0.45), min(255, int(b * 0.72) + 16), int(a * 0.58)))
        else:
            pixels.append((r, g, b, a))
    result.putdata(pixels)
    return result


def remove_tiny_alpha_components(image: Image.Image, min_pixels: int) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 255 if value > 24 else 0)
    pixels = alpha.load()
    width, height = alpha.size
    visited: set[tuple[int, int]] = set()
    keep_mask = Image.new("L", alpha.size, 0)
    keep_pixels = keep_mask.load()

    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in visited:
                continue
            stack = [(x, y)]
            visited.add((x, y))
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for nx in (px - 1, px, px + 1):
                    for ny in (py - 1, py, py + 1):
                        if nx == px and ny == py:
                            continue
                        if nx < 0 or ny < 0 or nx >= width or ny >= height or (nx, ny) in visited:
                            continue
                        if pixels[nx, ny] == 0:
                            continue
                        visited.add((nx, ny))
                        stack.append((nx, ny))
            if len(component) >= min_pixels:
                for px, py in component:
                    keep_pixels[px, py] = 255

    filtered = Image.new("RGBA", image.size, (0, 0, 0, 0))
    filtered.alpha_composite(image, (0, 0))
    filtered.putalpha(Image.composite(image.getchannel("A"), Image.new("L", image.size, 0), keep_mask))
    return filtered


def make_body_afterimage(subject: Image.Image, accent: tuple[int, int, int, int], amount: float, trail_direction: int) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    alpha = subject.getchannel("A").filter(ImageFilter.GaussianBlur(1.2))
    tinted = Image.new("RGBA", subject.size, (accent[0], accent[1], accent[2], 0))
    tinted.putalpha(alpha.point(lambda value: int(value * min(0.22, amount * 0.35))))
    for step in range(1, 3):
        x = int(FRAME_SIZE * 0.5 - subject.width * 0.5 + trail_direction * step * 8)
        y = TARGET_BOTTOM - subject.height - step
        layer.alpha_composite(tinted, (x, y))
    return layer


def make_action_vfx(action_name: str, amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    if action_name == "boss_02_atk_01":
        return make_twin_shear_vfx(amount, direction, accent, rng)
    if action_name == "boss_02_atk_02":
        return make_thread_pull_vfx(amount, direction, accent, rng)
    if action_name == "boss_02_atk_03":
        return make_saint_wheel_vfx(amount, direction, accent, rng)
    return make_directional_shear_arc(amount, direction, accent, rng)


def make_directional_shear_arc(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(148 * amount)
    width = max(3, int(9 * amount))
    if direction > 0:
        boxes = [(82, 48, 270, 218), (96, 66, 252, 201)]
        start, end = -68, 72
        spark_x = (150, 236)
    else:
        boxes = [(-14, 48, 174, 218), (4, 66, 160, 201)]
        start, end = 108, 248
        spark_x = (20, 106)
    draw.arc(boxes[0], start=start, end=end, fill=(accent[0], accent[1], accent[2], max(18, alpha // 2)), width=width)
    draw.arc(boxes[1], start=start + 7, end=end - 7, fill=(245, 214, 202, alpha), width=max(2, width // 3))
    add_crimson_sparks(draw, rng, spark_x, (70, 210), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def make_twin_shear_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(156 * amount)
    cx = 136 + direction * 38
    for y_offset in (-16, 18):
        draw.line((cx - direction * 84, 128 + y_offset, cx + direction * 94, 102 - y_offset), fill=(245, 218, 210, alpha), width=4)
        draw.line((cx - direction * 76, 130 + y_offset, cx + direction * 86, 106 - y_offset), fill=(accent[0], accent[1], accent[2], max(22, alpha // 2)), width=8)
    add_crimson_sparks(draw, rng, (42, 224), (72, 198), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.28))


def make_thread_pull_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(150 * amount)
    origin_x = 130 - direction * 12
    target_x = 222 if direction > 0 else 34
    for index in range(max(5, int(12 * amount))):
        y0 = 72 + index * 9 + rng.randint(-5, 5)
        y1 = 92 + index * 5 + rng.randint(-18, 18)
        draw.line((origin_x, y0, target_x, y1), fill=(accent[0], accent[1], accent[2], max(28, alpha - index * 5)), width=1 + (index % 2))
    draw.ellipse((target_x - 7, 123, target_x + 7, 137), outline=(245, 218, 210, alpha), width=2)
    return layer.filter(ImageFilter.GaussianBlur(0.22))


def make_saint_wheel_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(138 * amount)
    cx = 128 + direction * 12
    cy = 126
    for radius, width in ((66, 6), (88, 4), (104, 2)):
        draw.arc((cx - radius, cy - radius, cx + radius, cy + radius), 20, 330, fill=(accent[0], accent[1], accent[2], max(20, alpha)), width=width)
        draw.arc((cx - radius + 10, cy - radius + 10, cx + radius - 10, cy + radius - 10), 42, 295, fill=(245, 218, 210, max(18, alpha // 2)), width=max(1, width // 2))
    add_crimson_sparks(draw, rng, (32, 224), (42, 210), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.30))


def add_crimson_sparks(
    draw: ImageDraw.ImageDraw,
    rng: random.Random,
    x_range: tuple[int, int],
    y_range: tuple[int, int],
    direction: int,
    alpha: int,
    amount: float,
) -> None:
    for _ in range(max(2, int(8 * amount))):
        x = rng.randint(*x_range)
        y = rng.randint(*y_range)
        draw.line((x, y, x + direction * rng.randint(8, 24), y + rng.randint(-8, 8)), fill=(226, 45, 66, max(24, alpha)), width=1)


def make_thread_step_vfx(motion: Motion, direction: int) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    if motion.step_lift <= 0:
        return layer
    draw = ImageDraw.Draw(layer)
    cx = int(128 + direction * motion.dx * 0.55)
    y = TARGET_BOTTOM - 5
    for index in range(3):
        x = cx + direction * (index * 8 - 8)
        draw.line((x, y, x + direction * 11, y - 7 - index * 2), fill=(200, 35, 52, 52), width=1)
    return layer.filter(ImageFilter.GaussianBlur(0.18))


def add_ground_shadow(canvas: Image.Image, direction: int, motion: Motion) -> Image.Image:
    shadow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    cx = 128 + int(direction * motion.dx * 0.32)
    draw.ellipse((cx - 58, TARGET_BOTTOM - 8, cx + 62, TARGET_BOTTOM + 6), fill=(26, 10, 13, 34))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4.0))
    shadow.alpha_composite(canvas, (0, 0))
    return shadow


def ensure_bottom(image: Image.Image, target_bottom: int) -> Image.Image:
    bbox = image.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return image
    delta = target_bottom - bbox[3]
    if delta == 0:
        return image
    shifted = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shifted.alpha_composite(image, (0, delta))
    return shifted


def write_action_frames(action_name: str, direction_name: str, frames: list[Image.Image]) -> None:
    out_dir = FRAMES_ROOT / f"{action_name}_{direction_name}"
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("attack_*.png"):
        stale.unlink()
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"attack_{index:02d}.png")


def update_manifest(manifest: dict[str, Any]) -> None:
    animation_specs = build_animation_specs()
    old_by_name = {
        animation.get("name"): animation
        for animation in manifest.get("animations", [])
        if isinstance(animation, dict) and isinstance(animation.get("name"), str)
    }
    animations: list[dict[str, Any]] = []
    for name, fps, loop, frames in animation_specs:
        animations.append({"name": name, "fps": fps, "loop": loop, "frames": frames})

    for name, animation in old_by_name.items():
        if name in {spec[0] for spec in animation_specs}:
            continue
        if name in directional_animation_names():
            continue
        animations.append(animation)

    manifest["id"] = "boss_02"
    manifest["name_zh"] = "绯线执剪者"
    manifest["name_en"] = "Crimson Thread Scissor Apostle"
    manifest["source_concept"] = "artifacts/boss_concepts/images/boss_02_crimson_thread_scissor_apostle.png"
    manifest["frame_size"] = [FRAME_SIZE, FRAME_SIZE]
    manifest["anchor"] = "bottom-center"
    manifest["style"] = "high quality dark fantasy non-pixel hand-painted generated directional keyframes"
    manifest["directional_asset_pack"] = {
        "source": "20 high-fidelity boss concept pack, boss_02_crimson_thread_scissor_apostle",
        "source_facing": "right",
        "walk_frames_per_direction": WALK_FRAME_COUNT,
        "attack_frames_per_direction": ATTACK_FRAME_COUNT,
        "directional_animations": sorted(directional_animation_names()),
        "alpha_bottom_target": TARGET_BOTTOM,
        "cutout_cleanup": "green spill removal plus small detached alpha component filtering",
        "contact_sheet": PREVIEW_PATH.relative_to(ROOT).as_posix(),
    }
    manifest["animations"] = animations
    update_attack_metadata(manifest)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_animation_specs() -> list[tuple[str, float, bool, list[str]]]:
    specs: list[tuple[str, float, bool, list[str]]] = [
        ("idle", 6.0, True, frame_paths("walk_right", [0, 4, 8, 12])),
        ("walk", ACTION_FPS["walk"], True, frame_paths("walk_right", range(WALK_FRAME_COUNT))),
        ("attack", ACTION_FPS["attack"], False, frame_paths("attack_right", range(ATTACK_FRAME_COUNT))),
        ("hurt", 10.0, False, frame_paths("attack_right", [5])),
        ("death", 8.0, False, frame_paths("attack_right", [7])),
    ]
    for action_name in ("boss_02_atk_01", "boss_02_atk_02", "boss_02_atk_03"):
        specs.append((action_name, ACTION_FPS[action_name], False, frame_paths(f"{action_name}_right", range(ATTACK_FRAME_COUNT))))
    for action_name in ACTION_NAMES:
        count = WALK_FRAME_COUNT if action_name == "walk" else ATTACK_FRAME_COUNT
        for direction_name in ("left", "right"):
            name = f"{action_name}_{direction_name}"
            specs.append((name, ACTION_FPS[action_name], ACTION_LOOP[action_name], frame_paths(name, range(count))))
    return specs


def update_attack_metadata(manifest: dict[str, Any]) -> None:
    names = {
        "boss_02_atk_01": ("双剪断誓", "Twin Shear Oathbreak", "绯红剪切弧", "Crimson Shear Arc"),
        "boss_02_atk_02": ("缝魂牵引", "Soul Stitch Pull", "缝魂红线", "Soul Stitch Threads"),
        "boss_02_atk_03": ("裁衣圣轮", "Tailor Saint Wheel", "裁衣圣轮", "Tailor Saint Wheel"),
    }
    attacks: list[dict[str, Any]] = []
    for attack in manifest.get("attacks", []):
        if not isinstance(attack, dict):
            continue
        attack_id = str(attack.get("id", ""))
        if attack_id not in names:
            attacks.append(attack)
            continue
        name_zh, name_en, vfx_zh, vfx_en = names[attack_id]
        attack["name"] = attack_id
        attack["name_zh"] = name_zh
        attack["name_en"] = name_en
        attack["fps"] = ACTION_FPS[attack_id]
        attack["loop"] = False
        attack["frames"] = frame_paths(f"{attack_id}_right", range(ATTACK_FRAME_COUNT))
        attack["directional_frames"] = {
            "left": frame_paths(f"{attack_id}_left", range(ATTACK_FRAME_COUNT)),
            "right": frame_paths(f"{attack_id}_right", range(ATTACK_FRAME_COUNT)),
        }
        for vfx in attack.get("vfx", []):
            if isinstance(vfx, dict):
                vfx["name_zh"] = vfx_zh
                vfx["name_en"] = vfx_en
        attacks.append(attack)
    manifest["attacks"] = attacks


def frame_paths(animation_name: str, indexes) -> list[str]:
    return [
        f"res://assets/sprites/bosses/{BOSS_NAME}/frames/{animation_name}/attack_{int(index):02d}.png"
        for index in indexes
    ]


def directional_animation_names() -> set[str]:
    names: set[str] = set()
    for action_name in ACTION_NAMES:
        names.add(f"{action_name}_left")
        names.add(f"{action_name}_right")
    return names


def render_contact_sheet(rows: list[tuple[str, list[Image.Image]]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cell = 128
    gap = 24
    label_w = 250
    row_h = 174
    margin = 24
    max_frames = max(len(frames) for _, frames in rows)
    width = label_w + max_frames * cell + max(0, max_frames - 1) * gap + margin * 2
    height = margin * 2 + len(rows) * row_h
    sheet = Image.new("RGB", (width, height), (13, 12, 15))
    draw = ImageDraw.Draw(sheet)
    for row_index, (name, frames) in enumerate(rows):
        y = margin + row_index * row_h
        draw.text((margin, y + 14), name, fill=(238, 220, 205))
        draw.text((margin, y + 40), f"{len(frames)} frames", fill=(174, 127, 130))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (cell, cell), (22, 18, 20, 255))
            resized = frame.resize((cell, cell), Image.Resampling.LANCZOS)
            thumb.alpha_composite(resized, (0, 0))
            x = label_w + frame_index * (cell + gap)
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), outline=(70, 48, 52))
            draw.text((x + 5, y + cell + 6), f"{frame_index:02d}", fill=(154, 135, 135))
    sheet.save(out_path)


def trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return image
    return image.crop(expand_bbox(bbox, image.size, 2))


def expand_bbox(box: tuple[int, int, int, int], size: tuple[int, int], padding: int) -> tuple[int, int, int, int]:
    return (
        max(0, box[0] - padding),
        max(0, box[1] - padding),
        min(size[0], box[2] + padding),
        min(size[1], box[3] + padding),
    )


if __name__ == "__main__":
    main()
