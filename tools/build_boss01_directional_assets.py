from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses" / "boss_01_moss_bell_matriarch"
FRAMES_ROOT = BOSS_ROOT / "frames"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes" / "boss_01_moss_bell_matriarch"
PREVIEW_PATH = ARTIFACT_ROOT / "boss01_directional_contact.png"
MANIFEST_PATH = BOSS_ROOT / "manifest.json"

FRAME_SIZE = 256
FRAME_COUNT = 8
TARGET_BOTTOM = 246


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
    Motion(0, -1.8, 1.00, 1.00, -7.0, 0.0, 0.04, 0.00, 0.0),
    Motion(5, 1.4, 0.99, 1.01, -4.0, -2.0, 0.06, 0.00, 2.0),
    Motion(0, 0.8, 1.02, 0.98, 0.0, -1.0, 0.08, 0.00, 4.0),
    Motion(5, 2.2, 1.00, 1.00, 5.0, 0.0, 0.06, 0.00, 2.0),
    Motion(0, 1.2, 0.99, 1.01, 7.0, 0.0, 0.05, 0.00, 0.0),
    Motion(5, -1.6, 1.01, 0.99, 4.0, -2.0, 0.07, 0.00, 2.0),
    Motion(0, -0.6, 1.02, 0.98, 0.0, -1.0, 0.08, 0.00, 4.0),
    Motion(5, -2.0, 1.00, 1.00, -5.0, 0.0, 0.05, 0.00, 2.0),
]

ATTACK_MOTIONS = [
    Motion(0, -4.0, 1.02, 0.98, 2.0, 0.0, 0.08, 0.00),
    Motion(0, -8.0, 1.06, 0.95, 8.0, -4.0, 0.16, 0.10),
    Motion(1, -10.0, 1.09, 0.93, 12.0, -5.0, 0.22, 0.20),
    Motion(2, -4.0, 1.12, 0.90, 18.0, -2.0, 0.34, 0.45),
    Motion(3, 5.0, 1.16, 0.87, 24.0, 2.0, 0.48, 0.95),
    Motion(4, 8.0, 1.10, 0.92, 17.0, 3.0, 0.30, 0.55),
    Motion(5, 3.0, 1.04, 0.97, 7.0, 1.0, 0.14, 0.18),
    Motion(5, -1.5, 1.00, 1.00, 0.0, 0.0, 0.05, 0.00),
]

MOTION_BY_ACTION = {
    "walk": WALK_MOTIONS,
    "attack": ATTACK_MOTIONS,
    "boss_01_atk_01": [
        Motion(0, -3.0, 1.02, 0.98, 0.0, 0.0, 0.10, 0.00),
        Motion(1, -6.0, 1.05, 0.95, 3.0, -7.0, 0.18, 0.14),
        Motion(2, -8.0, 1.10, 0.91, 7.0, -9.0, 0.28, 0.25),
        Motion(3, 0.0, 1.18, 0.86, 0.0, 5.0, 0.55, 1.00),
        Motion(4, 4.0, 1.14, 0.90, -2.0, 2.0, 0.42, 0.70),
        Motion(4, 7.0, 1.08, 0.95, 2.0, 1.0, 0.24, 0.28),
        Motion(5, 2.0, 1.03, 0.98, 1.0, 0.0, 0.12, 0.08),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.05, 0.00),
    ],
    "boss_01_atk_02": [
        Motion(0, -4.0, 1.02, 0.98, -5.0, 0.0, 0.10, 0.00),
        Motion(1, -8.0, 1.06, 0.95, -10.0, -5.0, 0.18, 0.10),
        Motion(2, -11.0, 1.10, 0.92, -15.0, -6.0, 0.28, 0.18),
        Motion(3, -2.0, 1.17, 0.86, 20.0, 2.0, 0.48, 0.85),
        Motion(4, 8.0, 1.14, 0.89, 27.0, 4.0, 0.42, 1.00),
        Motion(4, 6.0, 1.10, 0.93, 18.0, 3.0, 0.30, 0.50),
        Motion(5, 2.0, 1.04, 0.97, 8.0, 1.0, 0.15, 0.12),
        Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.06, 0.00),
    ],
    "boss_01_atk_03": [
        Motion(0, -2.0, 1.00, 1.00, 0.0, 0.0, 0.10, 0.00),
        Motion(1, -5.0, 1.03, 0.97, 4.0, -12.0, 0.24, 0.15),
        Motion(2, -6.0, 1.07, 0.94, 8.0, -18.0, 0.34, 0.22),
        Motion(3, 0.0, 1.12, 0.90, 0.0, -8.0, 0.56, 0.70),
        Motion(3, 4.0, 1.15, 0.88, 12.0, 2.0, 0.48, 0.95),
        Motion(4, 6.0, 1.09, 0.94, 9.0, 3.0, 0.30, 0.45),
        Motion(5, 2.0, 1.04, 0.97, 4.0, 1.0, 0.15, 0.10),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.06, 0.00),
    ],
}

ACTION_FPS = {
    "walk": 8.0,
    "attack": 12.0,
    "boss_01_atk_01": 12.0,
    "boss_01_atk_02": 12.0,
    "boss_01_atk_03": 12.0,
}

ACTION_LOOP = {
    "walk": True,
    "attack": False,
    "boss_01_atk_01": False,
    "boss_01_atk_02": False,
    "boss_01_atk_03": False,
}


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    sources = load_sources()
    rows: list[tuple[str, list[Image.Image]]] = []

    for action_name, motions in MOTION_BY_ACTION.items():
        if action_name not in sources:
            raise FileNotFoundError(f"missing source action: {action_name}")
        right_frames = build_action(action_name, sources[action_name], motions, "right")
        left_frames = build_action(action_name, sources[action_name], motions, "left")
        write_action_frames(action_name, "right", right_frames)
        write_action_frames(action_name, "left", left_frames)
        rows.append((action_name + "_left", left_frames))
        rows.append((action_name + "_right", right_frames))

    update_manifest(manifest)
    render_contact_sheet(rows, PREVIEW_PATH)
    print(
        "BOSS01_DIRECTIONAL_ASSETS_BUILT "
        f"animations={len(MOTION_BY_ACTION) * 2} frames={len(MOTION_BY_ACTION) * 2 * FRAME_COUNT} "
        f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()} "
        f"preview={PREVIEW_PATH.relative_to(ROOT).as_posix()}"
    )


def load_sources() -> dict[str, list[Image.Image]]:
    result: dict[str, list[Image.Image]] = {}
    for action in MOTION_BY_ACTION:
        source_dir = FRAMES_ROOT / ("attack" if action in ("walk", "attack") else action)
        frames = [Image.open(path).convert("RGBA") for path in sorted(source_dir.glob("attack_*.png"))]
        if len(frames) < 6:
            raise FileNotFoundError(f"{source_dir} needs at least 6 source frames")
        result[action] = frames
    return result


def build_action(action_name: str, sources: list[Image.Image], motions: list[Motion], direction_name: str) -> list[Image.Image]:
    source_faces_left = False
    want_right = direction_name == "right"
    frames: list[Image.Image] = []
    for index, motion in enumerate(motions):
        seed = stable_seed(action_name, direction_name, index)
        source = sources[min(motion.source_index, len(sources) - 1)]
        if want_right == source_faces_left:
            source = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frame = compose_frame(source, motion, action_name, direction_name, seed)
        frames.append(frame)
    return frames


def stable_seed(action_name: str, direction_name: str, index: int) -> int:
    value = 2166136261
    for byte in f"{action_name}:{direction_name}:{index}".encode("utf-8"):
        value ^= byte
        value = (value * 16777619) & 0xFFFFFFFF
    return value


def compose_frame(source: Image.Image, motion: Motion, action_name: str, direction_name: str, seed: int) -> Image.Image:
    rng = random.Random(seed)
    direction = 1 if direction_name == "right" else -1
    subject = normalize_subject(source, motion, direction)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    accent = (124, 198, 92, 255)

    if motion.glow > 0.0:
        canvas.alpha_composite(make_body_afterimage(subject, accent, motion.glow, -direction), (0, 0))
    if action_name == "walk":
        canvas.alpha_composite(make_root_step_vfx(motion, direction), (0, 0))
    if motion.arc > 0.0:
        if action_name == "boss_01_atk_01":
            canvas.alpha_composite(make_bell_ring_vfx(motion.arc, accent, rng), (0, 0))
        elif action_name == "boss_01_atk_03":
            canvas.alpha_composite(make_chime_rain_vfx(motion.arc, accent, rng), (0, 0))
        else:
            canvas.alpha_composite(make_directional_arc_vfx(motion.arc, direction, accent, rng), (0, 0))

    bbox = subject.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return canvas
    x = int(FRAME_SIZE * 0.5 - subject.width * 0.5 + motion.dx * direction)
    bottom_y = TARGET_BOTTOM - int(motion.step_lift)
    y = bottom_y - bbox[3]
    canvas.alpha_composite(subject, (x, y))
    canvas = add_ground_shadow(canvas, direction, motion)
    return ensure_bottom(canvas, TARGET_BOTTOM)


def normalize_subject(source: Image.Image, motion: Motion, direction: int) -> Image.Image:
    bbox = source.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return source
    crop = source.crop(expand_bbox(bbox, source.size, 4))
    crop = ImageEnhance.Contrast(crop).enhance(1.05)
    crop = ImageEnhance.Sharpness(crop).enhance(1.08)
    width, height = crop.size
    scale = min(222 / max(1, width), 232 / max(1, height))
    next_size = (
        max(1, int(width * scale * motion.scale_x)),
        max(1, int(height * scale * motion.scale_y)),
    )
    crop = crop.resize(next_size, Image.Resampling.LANCZOS)
    rotation = motion.rotation * direction
    if abs(rotation) > 0.01:
        crop = crop.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    return trim_alpha(crop)


def make_body_afterimage(subject: Image.Image, accent: tuple[int, int, int, int], amount: float, trail_direction: int) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    alpha = subject.getchannel("A").filter(ImageFilter.GaussianBlur(1.1))
    tinted = Image.new("RGBA", subject.size, (accent[0], accent[1], accent[2], 0))
    tinted.putalpha(alpha.point(lambda value: int(value * min(0.24, amount * 0.35))))
    for step in range(1, 3):
        x = int(FRAME_SIZE * 0.5 - subject.width * 0.5 + trail_direction * step * 9)
        y = TARGET_BOTTOM - subject.height - step
        layer.alpha_composite(tinted, (x, y))
    return layer


def make_directional_arc_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(160 * amount)
    wide = max(4, int(11 * amount))
    if direction > 0:
        boxes = [(88, 52, 270, 214), (102, 69, 256, 200)]
        starts = (-70, 70)
    else:
        boxes = [(-14, 52, 168, 214), (0, 69, 154, 200)]
        starts = (110, 250)
    draw.arc(boxes[0], start=starts[0], end=starts[1], fill=(accent[0], accent[1], accent[2], max(24, alpha // 2)), width=wide)
    draw.arc(boxes[1], start=starts[0] + 8, end=starts[1] - 8, fill=(230, 226, 158, alpha), width=max(2, wide // 3))
    for _ in range(max(2, int(7 * amount))):
        x = rng.randint(156, 238) if direction > 0 else rng.randint(18, 100)
        y = rng.randint(76, 206)
        draw.line((x, y, x + direction * rng.randint(8, 26), y + rng.randint(-8, 8)), fill=(accent[0], accent[1], accent[2], alpha), width=1)
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def make_bell_ring_vfx(amount: float, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(145 * amount)
    for radius in (52, 76, 98):
        draw.ellipse((128 - radius, 128 - radius, 128 + radius, 128 + radius), outline=(accent[0], accent[1], accent[2], max(20, alpha // 2)), width=3)
    for _ in range(max(3, int(10 * amount))):
        x = rng.randint(58, 198)
        y = rng.randint(70, 206)
        draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(226, 233, 143, alpha))
    return layer.filter(ImageFilter.GaussianBlur(0.4))


def make_chime_rain_vfx(amount: float, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(155 * amount)
    for _ in range(max(3, int(9 * amount))):
        x = rng.randint(48, 208)
        y = rng.randint(12, 166)
        draw.line((x, y, x + rng.randint(-4, 4), y + rng.randint(34, 72)), fill=(accent[0], accent[1], accent[2], alpha), width=2)
        draw.ellipse((x - 5, y + 70, x + 5, y + 78), outline=(226, 235, 150, max(20, alpha // 2)), width=1)
    return layer.filter(ImageFilter.GaussianBlur(0.35))


def make_root_step_vfx(motion: Motion, direction: int) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    if motion.step_lift <= 0:
        return layer
    draw = ImageDraw.Draw(layer)
    cx = int(128 + direction * motion.dx * 0.6)
    y = TARGET_BOTTOM - 6
    for index in range(3):
        x = cx + direction * (index * 8 - 8)
        draw.line((x, y, x + direction * 9, y - 10 - index * 2), fill=(103, 169, 74, 58), width=2)
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def add_ground_shadow(canvas: Image.Image, direction: int, motion: Motion) -> Image.Image:
    shadow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    cx = 128 + int(direction * motion.dx * 0.35)
    draw.ellipse((cx - 62, TARGET_BOTTOM - 8, cx + 66, TARGET_BOTTOM + 7), fill=(18, 27, 12, 35))
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
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"attack_{index:02d}.png")


def update_manifest(manifest: dict[str, Any]) -> None:
    animations = [animation for animation in manifest.get("animations", []) if animation.get("name") not in directional_animation_names()]
    for action_name in MOTION_BY_ACTION:
        for direction_name in ("left", "right"):
            name = f"{action_name}_{direction_name}"
            animations.append(
                {
                    "name": name,
                    "fps": ACTION_FPS[action_name],
                    "loop": ACTION_LOOP[action_name],
                    "frames": [
                        f"res://assets/sprites/bosses/boss_01_moss_bell_matriarch/frames/{name}/attack_{index:02d}.png"
                        for index in range(FRAME_COUNT)
                    ],
                }
            )
    manifest["frame_size"] = [FRAME_SIZE, FRAME_SIZE]
    manifest["anchor"] = "bottom-center"
    manifest["directional_asset_pack"] = {
        "frames_per_direction": FRAME_COUNT,
        "directional_animations": sorted(directional_animation_names()),
        "source_facing": "right",
        "left_frames": "mirrored from right-facing seed with per-frame action offsets",
        "right_frames": "right-facing seed with per-frame action offsets",
        "alpha_bottom_target": TARGET_BOTTOM,
    }
    manifest["animations"] = animations
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def directional_animation_names() -> set[str]:
    names: set[str] = set()
    for action_name in MOTION_BY_ACTION:
        names.add(f"{action_name}_left")
        names.add(f"{action_name}_right")
    return names


def render_contact_sheet(rows: list[tuple[str, list[Image.Image]]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cell = 112
    label_w = 172
    row_h = 138
    margin = 16
    width = label_w + FRAME_COUNT * cell + margin * 2
    height = margin * 2 + len(rows) * row_h
    sheet = Image.new("RGB", (width, height), (12, 13, 16))
    draw = ImageDraw.Draw(sheet)
    for row_index, (name, frames) in enumerate(rows):
        y = margin + row_index * row_h
        draw.text((margin, y + 12), name, fill=(230, 224, 188))
        draw.text((margin, y + 34), f"{len(frames)} frames", fill=(143, 161, 151))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (cell, cell), (20, 23, 22, 255))
            resized = frame.resize((cell, cell), Image.Resampling.LANCZOS)
            thumb.alpha_composite(resized, (0, 0))
            x = label_w + frame_index * cell
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.text((x + 5, y + cell + 4), f"{frame_index:02d}", fill=(148, 158, 150))
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
