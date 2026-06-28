from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS_ID = "boss_03"
BOSS_NAME = "boss_03_ash_crowned_mantis_warlord"
BOSS_ZH = "灰冠螳将"
BOSS_EN = "Ash-Crowned Mantis Warlord"
BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses" / BOSS_NAME
FRAMES_ROOT = BOSS_ROOT / "frames"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes" / BOSS_NAME
PREVIEW_PATH = ARTIFACT_ROOT / "boss03_directional_contact.png"
MANIFEST_PATH = BOSS_ROOT / "manifest.json"

FRAME_SIZE = 256
TARGET_BOTTOM = 246
ATTACK_FRAME_COUNT = 8
WALK_FRAME_COUNT = 16
SOURCE_FACES_LEFT = False
ACTION_NAMES = [
    "walk",
    "attack",
    "boss_03_atk_01",
    "boss_03_atk_02",
    "boss_03_atk_03",
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
    Motion(0, -2.0, 1.00, 1.00, -10.0, 0.0, 0.03, 0.00, 0.0),
    Motion(0, -1.2, 1.03, 0.98, -8.0, -2.0, 0.04, 0.00, 2.0),
    Motion(5, 0.6, 1.05, 0.96, -5.0, -3.0, 0.05, 0.00, 5.0),
    Motion(5, 1.4, 1.02, 0.99, -1.0, -3.0, 0.04, 0.00, 4.0),
    Motion(0, 1.0, 1.00, 1.00, 4.0, -1.0, 0.04, 0.00, 2.0),
    Motion(0, 0.2, 0.98, 1.02, 8.0, 0.0, 0.03, 0.00, 0.0),
    Motion(5, -0.8, 1.03, 0.98, 10.0, -2.0, 0.04, 0.00, 2.0),
    Motion(5, -1.7, 1.05, 0.96, 7.0, -3.0, 0.05, 0.00, 5.0),
    Motion(0, -1.0, 1.01, 0.99, 3.0, -3.0, 0.04, 0.00, 4.0),
    Motion(0, 0.4, 0.98, 1.02, -2.0, -1.0, 0.03, 0.00, 2.0),
    Motion(5, 1.2, 1.03, 0.98, -7.0, 0.0, 0.04, 0.00, 0.0),
    Motion(5, 1.8, 1.05, 0.96, -10.0, -2.0, 0.05, 0.00, 2.0),
    Motion(0, 0.7, 1.02, 0.99, -6.0, -3.0, 0.04, 0.00, 5.0),
    Motion(0, -0.4, 0.99, 1.01, -1.0, -3.0, 0.03, 0.00, 4.0),
    Motion(5, -1.5, 1.03, 0.98, 5.0, -1.0, 0.04, 0.00, 2.0),
    Motion(5, -0.7, 1.00, 1.00, 9.0, 0.0, 0.03, 0.00, 0.0),
]


MOTION_BY_ACTION = {
    "walk": WALK_MOTIONS,
    "attack": [
        Motion(0, -3.0, 1.00, 1.00, -2.0, 0.0, 0.06, 0.00),
        Motion(0, -8.0, 1.04, 0.96, 5.0, -4.0, 0.10, 0.10),
        Motion(1, -11.0, 1.09, 0.92, 12.0, -5.0, 0.15, 0.28),
        Motion(2, -5.0, 1.13, 0.88, 20.0, -2.0, 0.24, 0.52),
        Motion(3, 5.0, 1.18, 0.84, 27.0, 2.0, 0.34, 0.92),
        Motion(4, 8.0, 1.10, 0.92, 18.0, 3.0, 0.22, 0.48),
        Motion(5, 3.0, 1.04, 0.97, 7.0, 1.0, 0.10, 0.16),
        Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
    "boss_03_atk_01": [
        Motion(0, -2.0, 1.00, 1.00, 0.0, 0.0, 0.08, 0.00),
        Motion(1, -6.0, 1.04, 0.96, 1.0, -6.0, 0.14, 0.18),
        Motion(2, -10.0, 1.08, 0.93, 5.0, -8.0, 0.22, 0.35),
        Motion(3, 0.0, 1.16, 0.86, 0.0, 1.0, 0.34, 1.00),
        Motion(4, 6.0, 1.14, 0.90, -2.0, 2.0, 0.26, 0.72),
        Motion(4, 9.0, 1.08, 0.95, 2.0, 1.0, 0.18, 0.38),
        Motion(5, 2.0, 1.03, 0.98, 1.0, 0.0, 0.10, 0.12),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
    "boss_03_atk_02": [
        Motion(0, -5.0, 1.00, 1.00, -10.0, -2.0, 0.08, 0.00),
        Motion(1, -12.0, 1.05, 0.95, -18.0, -13.0, 0.16, 0.15),
        Motion(2, -14.0, 1.10, 0.91, -10.0, -28.0, 0.24, 0.35),
        Motion(2, -6.0, 1.12, 0.89, 6.0, -12.0, 0.30, 0.58),
        Motion(4, 8.0, 1.18, 0.84, 27.0, 4.0, 0.36, 1.00),
        Motion(4, 5.0, 1.11, 0.91, 19.0, 3.0, 0.24, 0.58),
        Motion(5, 1.0, 1.04, 0.97, 8.0, 1.0, 0.12, 0.18),
        Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
    "boss_03_atk_03": [
        Motion(0, -1.0, 1.00, 1.00, 0.0, 0.0, 0.08, 0.00),
        Motion(1, -4.0, 1.03, 0.97, 3.0, -8.0, 0.16, 0.20),
        Motion(2, -7.0, 1.08, 0.93, 7.0, -11.0, 0.24, 0.40),
        Motion(3, 0.0, 1.13, 0.89, 0.0, -2.0, 0.38, 0.95),
        Motion(3, 4.0, 1.16, 0.86, 10.0, 2.0, 0.30, 1.00),
        Motion(4, 7.0, 1.10, 0.92, 8.0, 3.0, 0.22, 0.58),
        Motion(5, 2.0, 1.04, 0.97, 4.0, 1.0, 0.12, 0.18),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.04, 0.00),
    ],
}

ACTION_FPS = {
    "walk": 9.0,
    "attack": 12.0,
    "boss_03_atk_01": 12.0,
    "boss_03_atk_02": 12.0,
    "boss_03_atk_03": 12.0,
}

ACTION_LOOP = {
    "walk": True,
    "attack": False,
    "boss_03_atk_01": False,
    "boss_03_atk_02": False,
    "boss_03_atk_03": False,
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
        "BOSS03_DIRECTIONAL_ASSETS_BUILT "
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
    cleaned = remove_tiny_alpha_components(cleaned, min_pixels=240 if strict else 150)
    cleaned = ImageEnhance.Contrast(cleaned).enhance(1.08)
    cleaned = ImageEnhance.Sharpness(cleaned).enhance(1.12)
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
    accent = (202, 194, 163, 255)

    if motion.glow > 0.0:
        canvas.alpha_composite(make_body_afterimage(subject, accent, motion.glow, -direction), (0, 0))
    if action_name == "walk":
        canvas.alpha_composite(make_ash_step_vfx(motion, direction), (0, 0))
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
    scale = min(232 / max(1, width), 236 / max(1, height))
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
        if g > 80 and green_bias > 24:
            if green_bias > 35 or (g > 128 and r < 160):
                pixels.append((r, g, b, 0))
            else:
                pixels.append((min(255, int(r * 1.08) + 16), int(g * 0.48), min(255, int(b * 0.78) + 12), int(a * 0.60)))
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
    tinted.putalpha(alpha.point(lambda value: int(value * min(0.20, amount * 0.32))))
    for step in range(1, 3):
        x = int(FRAME_SIZE * 0.5 - subject.width * 0.5 + trail_direction * step * 9)
        y = TARGET_BOTTOM - subject.height - step
        layer.alpha_composite(tinted, (x, y))
    return layer


def make_action_vfx(action_name: str, amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    if action_name == "boss_03_atk_01":
        return make_cross_scythe_vfx(amount, direction, accent, rng)
    if action_name == "boss_03_atk_02":
        return make_banner_leap_vfx(amount, direction, accent, rng)
    if action_name == "boss_03_atk_03":
        return make_legion_blades_vfx(amount, direction, accent, rng)
    return make_directional_scythe_arc(amount, direction, accent, rng)


def make_directional_scythe_arc(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(150 * amount)
    width = max(3, int(10 * amount))
    if direction > 0:
        boxes = [(82, 42, 272, 222), (101, 61, 250, 202)]
        start, end = -78, 72
        spark_x = (150, 238)
    else:
        boxes = [(-16, 42, 174, 222), (6, 61, 155, 202)]
        start, end = 108, 258
        spark_x = (18, 106)
    draw.arc(boxes[0], start=start, end=end, fill=(accent[0], accent[1], accent[2], max(20, alpha // 2)), width=width)
    draw.arc(boxes[1], start=start + 8, end=end - 8, fill=(242, 238, 218, alpha), width=max(2, width // 3))
    add_ash_sparks(draw, rng, spark_x, (64, 214), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def make_cross_scythe_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(158 * amount)
    cx = 132 + direction * 34
    draw.line((cx - direction * 82, 72, cx + direction * 86, 198), fill=(242, 238, 218, alpha), width=4)
    draw.line((cx - direction * 80, 198, cx + direction * 86, 72), fill=(242, 238, 218, alpha), width=4)
    draw.line((cx - direction * 78, 72, cx + direction * 82, 198), fill=(164, 158, 134, max(24, alpha // 2)), width=9)
    draw.line((cx - direction * 76, 198, cx + direction * 82, 72), fill=(164, 158, 134, max(24, alpha // 2)), width=9)
    add_ash_sparks(draw, rng, (34, 226), (58, 210), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.30))


def make_banner_leap_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(148 * amount)
    for index in range(max(4, int(9 * amount))):
        y = 74 + index * 11 + rng.randint(-4, 5)
        x0 = 112 - direction * rng.randint(18, 42)
        x1 = x0 + direction * rng.randint(42, 96)
        draw.line((x0, y, x1, y + rng.randint(5, 22)), fill=(112, 72, 58, max(20, alpha - index * 6)), width=2)
    cx = 128 + direction * 30
    draw.ellipse((cx - 62, 178, cx + 62, 218), outline=(accent[0], accent[1], accent[2], max(28, alpha // 2)), width=3)
    add_ash_sparks(draw, rng, (28, 228), (136, 222), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.35))


def make_legion_blades_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(140 * amount)
    origin = (128 - direction * 18, 210)
    for angle in (-48, -25, 0, 25, 48):
        length = 92 + rng.randint(-10, 16)
        tip = (
            origin[0] + direction * int(length * 0.85),
            origin[1] - int(length * (0.25 + abs(angle) / 120.0)),
        )
        base = (origin[0] + direction * rng.randint(-8, 10), origin[1] + rng.randint(-4, 5))
        draw.line((base[0], base[1], tip[0], tip[1]), fill=(accent[0], accent[1], accent[2], max(22, alpha // 2)), width=7)
        draw.line((base[0], base[1], tip[0], tip[1]), fill=(242, 238, 218, alpha), width=2)
    add_ash_sparks(draw, rng, (24, 232), (86, 214), direction, alpha, amount)
    return layer.filter(ImageFilter.GaussianBlur(0.28))


def add_ash_sparks(
    draw: ImageDraw.ImageDraw,
    rng: random.Random,
    x_range: tuple[int, int],
    y_range: tuple[int, int],
    direction: int,
    alpha: int,
    amount: float,
) -> None:
    for _ in range(max(3, int(10 * amount))):
        x = rng.randint(*x_range)
        y = rng.randint(*y_range)
        draw.line((x, y, x + direction * rng.randint(6, 24), y + rng.randint(-8, 10)), fill=(210, 203, 174, max(22, alpha)), width=1)


def make_ash_step_vfx(motion: Motion, direction: int) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    if motion.step_lift <= 0:
        return layer
    draw = ImageDraw.Draw(layer)
    cx = int(128 + direction * motion.dx * 0.55)
    y = TARGET_BOTTOM - 5
    for index in range(4):
        x = cx + direction * (index * 7 - 9)
        draw.line((x, y, x + direction * 9, y - 5 - index), fill=(190, 183, 154, 46), width=1)
    return layer.filter(ImageFilter.GaussianBlur(0.22))


def add_ground_shadow(canvas: Image.Image, direction: int, motion: Motion) -> Image.Image:
    shadow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    cx = 128 + int(direction * motion.dx * 0.32)
    draw.ellipse((cx - 64, TARGET_BOTTOM - 8, cx + 66, TARGET_BOTTOM + 6), fill=(16, 15, 12, 34))
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
    spec_names = {spec[0] for spec in animation_specs}
    for name, fps, loop, frames in animation_specs:
        animations.append({"name": name, "fps": fps, "loop": loop, "frames": frames})

    for name, animation in old_by_name.items():
        if name in spec_names or name in directional_animation_names():
            continue
        animations.append(animation)

    manifest["id"] = BOSS_ID
    manifest["name_zh"] = BOSS_ZH
    manifest["name_en"] = BOSS_EN
    manifest["source_concept"] = f"artifacts/boss_concepts/images/{BOSS_NAME}.png"
    manifest["frame_size"] = [FRAME_SIZE, FRAME_SIZE]
    manifest["anchor"] = "bottom-center"
    manifest["style"] = "high quality dark fantasy non-pixel hand-painted generated directional keyframes"
    manifest["directional_asset_pack"] = {
        "source": f"20 high-fidelity boss concept pack, {BOSS_NAME}",
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
    for action_name in ("boss_03_atk_01", "boss_03_atk_02", "boss_03_atk_03"):
        specs.append((action_name, ACTION_FPS[action_name], False, frame_paths(f"{action_name}_right", range(ATTACK_FRAME_COUNT))))
    for action_name in ACTION_NAMES:
        count = WALK_FRAME_COUNT if action_name == "walk" else ATTACK_FRAME_COUNT
        for direction_name in ("left", "right"):
            name = f"{action_name}_{direction_name}"
            specs.append((name, ACTION_FPS[action_name], ACTION_LOOP[action_name], frame_paths(name, range(count))))
    return specs


def update_attack_metadata(manifest: dict[str, Any]) -> None:
    names = {
        "boss_03_atk_01": ("灰冠交镰", "Ash-Crown Cross Scythe", "灰冠交镰", "Ash-Crown Cross Scythe"),
        "boss_03_atk_02": ("战旗虫跃", "Banner Leaping Cleave", "战旗灰跃", "Ash Banner Leap"),
        "boss_03_atk_03": ("败军镰阵", "Fallen Legion Blades", "败军镰影", "Fallen Legion Blades"),
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
        draw.text((margin, y + 14), name, fill=(232, 228, 205))
        draw.text((margin, y + 40), f"{len(frames)} frames", fill=(151, 145, 128))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (cell, cell), (22, 21, 18, 255))
            resized = frame.resize((cell, cell), Image.Resampling.LANCZOS)
            thumb.alpha_composite(resized, (0, 0))
            x = label_w + frame_index * (cell + gap)
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), outline=(68, 64, 55))
            draw.text((x + 5, y + cell + 6), f"{frame_index:02d}", fill=(148, 144, 130))
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
