from __future__ import annotations

import json
import math
from pathlib import Path
from statistics import median
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = Path(r"D:\CrimsonThreadOdysseyAssets_v2\01_characters_redesign_split")
OUT_ROOT = ROOT / "godot" / "assets" / "sprites" / "lumen"
FRAMES_DIR = OUT_ROOT / "frames"
SHEETS_DIR = OUT_ROOT / "sheets"
MANIFEST = OUT_ROOT / "lumen_animations_manifest.json"
PREVIEW = OUT_ROOT / "lumen_animation_preview.png"

FRAME_SIZE = 128
SAFE_CROP = (18, 16, 482, 504)
BASELINE_Y = 124

POSE_FILES = {
    "idle": "lumen_01_idle.png",
    "run": "lumen_02_run.png",
    "jump": "lumen_03_jump.png",
    "wall_slide": "lumen_04_wall_cling.png",
    "attack": "lumen_05_thread_chakram_attack.png",
}

ANIMATIONS: list[dict[str, Any]] = [
    {"name": "idle", "pose": "idle", "frames": 6, "fps": 8, "loop": True},
    {"name": "run", "pose": "run", "frames": 8, "fps": 12, "loop": True},
    {"name": "jump_start", "pose": "jump", "frames": 4, "fps": 12, "loop": False},
    {"name": "jump_loop", "pose": "jump", "frames": 3, "fps": 8, "loop": True},
    {"name": "fall", "pose": "jump", "frames": 4, "fps": 8, "loop": True},
    {"name": "land", "pose": "idle", "frames": 4, "fps": 12, "loop": False},
    {"name": "dash", "pose": "run", "frames": 6, "fps": 14, "loop": False},
    {"name": "wall_slide", "pose": "wall_slide", "frames": 4, "fps": 8, "loop": True},
    {"name": "attack_1", "pose": "attack", "frames": 6, "fps": 14, "loop": False},
    {"name": "attack_2", "pose": "attack", "frames": 7, "fps": 14, "loop": False},
    {"name": "air_attack", "pose": "attack", "frames": 6, "fps": 14, "loop": False},
    {"name": "hook_throw", "pose": "attack", "frames": 7, "fps": 12, "loop": False},
    {"name": "hurt", "pose": "idle", "frames": 4, "fps": 10, "loop": False},
    {"name": "death", "pose": "idle", "frames": 8, "fps": 8, "loop": False},
]


def _background_color(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    samples: list[tuple[int, int, int]] = []
    for x0, y0 in ((0, 0), (width - 20, 0), (0, height - 20), (width - 20, height - 20)):
        for x in range(max(0, x0), min(width, x0 + 20)):
            for y in range(max(0, y0), min(height, y0 + 20)):
                samples.append(rgb.getpixel((x, y)))
    return tuple(int(median(channel)) for channel in zip(*samples))


def _foreground_mask(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    bg = _background_color(rgb)
    mask = Image.new("L", rgb.size, 0)
    px = rgb.load()
    out = mask.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = px[x, y]
            luma = 0.299 * r + 0.587 * g + 0.114 * b
            saturation = max(r, g, b) - min(r, g, b)
            delta = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            if (delta > 16 and (luma > 18 or saturation > 10)) or luma > 42 or saturation > 42:
                out[x, y] = 255

    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = mask.filter(ImageFilter.MaxFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))
    return mask.point(lambda value: 255 if value > 20 else 0)


def _expand_box(box: tuple[int, int, int, int], width: int, height: int, pad: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = box
    return max(0, left - pad), max(0, top - pad), min(width, right + pad), min(height, bottom + pad)


def _cutout_pose(source_path: Path) -> Image.Image:
    if not source_path.exists():
        raise FileNotFoundError(f"Missing character source pose: {source_path}")
    source = Image.open(source_path).convert("RGB").crop(SAFE_CROP)
    source = ImageEnhance.Color(source).enhance(1.04)
    source = ImageEnhance.Contrast(source).enhance(1.08)
    mask = _foreground_mask(source)
    box = mask.getbbox()
    if box is None:
        raise ValueError(f"Could not isolate character from {source_path}")

    box = _expand_box(box, source.width, source.height, 10)
    rgba = source.convert("RGBA")
    rgba.putalpha(mask.filter(ImageFilter.GaussianBlur(0.45)))
    return rgba.crop(box)


def _fit_pose(pose: Image.Image, animation: str) -> Image.Image:
    max_height = 92
    max_width = 110 if "attack" in animation or animation == "hook_throw" else 92
    if animation == "dash":
        max_width = 104
    scale = min(max_width / pose.width, max_height / pose.height)
    size = (max(1, round(pose.width * scale)), max(1, round(pose.height * scale)))
    return pose.resize(size, Image.Resampling.LANCZOS)


def _transform_pose(pose: Image.Image, animation: str, frame: int, total: int) -> tuple[Image.Image, int, int]:
    t = frame / max(1, total - 1)
    wave = math.sin(t * math.tau)
    angle = 0.0
    offset_x = 0
    offset_y = 0
    scale_x = 1.0
    scale_y = 1.0

    if animation == "idle":
        offset_y = round(wave * 1.5)
    elif animation == "run":
        offset_y = -2 if frame % 2 else 1
        offset_x = round(math.sin(t * math.tau) * 2)
    elif animation == "jump_start":
        scale_y = [0.94, 0.98, 1.02, 1.0][frame]
        scale_x = [1.06, 1.03, 0.98, 1.0][frame]
        offset_y = [4, 2, -3, -5][frame]
    elif animation == "jump_loop":
        offset_y = -5 + round(wave * 2)
        angle = -2 + frame * 2
    elif animation == "fall":
        offset_y = -3 + frame * 2
        angle = 4
    elif animation == "land":
        scale_y = [0.92, 0.88, 0.96, 1.0][frame]
        scale_x = [1.07, 1.1, 1.03, 1.0][frame]
        offset_y = [6, 8, 4, 0][frame]
    elif animation == "dash":
        angle = -7
        scale_x = 1.12
        scale_y = 0.94
        offset_x = 8
        offset_y = -3
    elif animation == "wall_slide":
        angle = -4
        offset_x = -5
        offset_y = round(wave * 2)
    elif animation == "attack_1":
        angle = [-6, -2, 4, 7, 3, 0][frame]
        offset_x = [0, 2, 7, 9, 5, 1][frame]
    elif animation == "attack_2":
        angle = [-10, -6, 5, 11, 9, 3, 0][frame]
        offset_x = [-2, 0, 7, 12, 11, 5, 1][frame]
    elif animation == "air_attack":
        angle = [-8, -3, 5, 12, 8, 0][frame]
        offset_x = [1, 5, 9, 11, 6, 1][frame]
        offset_y = -8 + round(wave * 2)
    elif animation == "hook_throw":
        angle = [-4, -2, 0, 2, 0, -1, 0][frame]
        offset_x = [0, 2, 6, 10, 12, 7, 2][frame]
    elif animation == "hurt":
        angle = [-7, -11, -5, 0][frame]
        offset_x = [-4, -7, -3, 0][frame]
    elif animation == "death":
        if frame >= 3:
            angle = -82
            scale_x = 1.06
            scale_y = 0.9
            offset_y = 18
        else:
            angle = -frame * 8
            offset_y = frame * 4

    if scale_x != 1.0 or scale_y != 1.0:
        pose = pose.resize((max(1, round(pose.width * scale_x)), max(1, round(pose.height * scale_y))), Image.Resampling.LANCZOS)
    if angle:
        pose = pose.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
    return pose, offset_x, offset_y


def _tint(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (*color, 0))
    alpha = image.getchannel("A").point(lambda value: int(value * strength))
    overlay.putalpha(alpha)
    return Image.alpha_composite(image, overlay)


def _draw_action_effects(canvas: Image.Image, animation: str, frame: int, total: int) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")
    if animation == "dash":
        for i, alpha in enumerate((80, 50, 28)):
            draw.line((18 - i * 9, 70, 60 - i * 9, 63), fill=(100, 236, 218, alpha), width=3)
            draw.line((15 - i * 9, 88, 54 - i * 9, 83), fill=(236, 188, 92, alpha), width=2)
    elif animation in {"attack_1", "attack_2", "air_attack"}:
        start = -58 + frame * 12
        end = 74 + frame * 7
        draw.arc((54, 26, 126, 100), start, end, fill=(107, 239, 221, 210), width=4)
        draw.arc((60, 32, 122, 94), start, end, fill=(225, 231, 214, 190), width=2)
    elif animation == "hook_throw":
        reach = 76 + min(frame, 4) * 10
        draw.line((76, 58, reach, 47), fill=(105, 238, 220, 220), width=3)
        draw.arc((reach - 4, 37, reach + 18, 59), -95, 145, fill=(229, 232, 211, 230), width=3)
    elif animation == "hurt":
        draw.line((36, 38, 26, 24), fill=(241, 76, 63, 210), width=3)
        draw.line((47, 35, 39, 20), fill=(241, 76, 63, 160), width=2)
    elif animation == "death" and frame >= total - 3:
        fade = 1.0 - (frame - (total - 3)) / 3.0
        draw.line((34, 103, 102, 107), fill=(102, 236, 218, int(150 * fade)), width=2)


def _compose_frame(pose: Image.Image, animation: str, frame: int, total: int) -> Image.Image:
    fitted = _fit_pose(pose, animation)
    transformed, offset_x, offset_y = _transform_pose(fitted, animation, frame, total)
    if animation == "hurt":
        transformed = _tint(transformed, (230, 54, 45), 0.22)
    if animation == "death" and frame >= 4:
        transformed = ImageEnhance.Brightness(transformed).enhance(max(0.42, 1.0 - frame * 0.07))

    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = round((FRAME_SIZE - transformed.width) / 2) + offset_x
    y = BASELINE_Y - transformed.height + offset_y
    canvas.alpha_composite(transformed, (x, y))
    _draw_action_effects(canvas, animation, frame, total)
    return canvas


def _write_preview(rows: list[tuple[str, list[Path]]]) -> None:
    max_frames = max(len(paths) for _, paths in rows)
    preview = Image.new("RGBA", (max_frames * FRAME_SIZE, len(rows) * FRAME_SIZE), (17, 18, 20, 255))
    for row, (_name, paths) in enumerate(rows):
        for col, path in enumerate(paths):
            frame = Image.open(path).convert("RGBA")
            preview.alpha_composite(frame, (col * FRAME_SIZE, row * FRAME_SIZE))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW)


def _alpha_bounds(path: Path) -> tuple[int, int, int, int] | None:
    image = Image.open(path).convert("RGBA")
    return image.getchannel("A").getbbox()


def main() -> None:
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)
    SHEETS_DIR.mkdir(parents=True, exist_ok=True)

    source_poses = {
        pose_name: _cutout_pose(SOURCE_ROOT / file_name)
        for pose_name, file_name in POSE_FILES.items()
    }
    manifest: dict[str, Any] = {
        "character": "lumen_spoolwright_original",
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "anchor": "bottom_center",
        "source": str(SOURCE_ROOT),
        "origin_note": "Frames are generated from the D-drive independent Lumen pose art and normalized for Godot Player.tscn.",
        "animations": [],
    }
    preview_rows: list[tuple[str, list[Path]]] = []
    frame_total = 0

    for spec in ANIMATIONS:
        name = spec["name"]
        count = int(spec["frames"])
        action_dir = FRAMES_DIR / name
        action_dir.mkdir(parents=True, exist_ok=True)
        frame_paths: list[Path] = []
        sheet = Image.new("RGBA", (FRAME_SIZE * count, FRAME_SIZE), (0, 0, 0, 0))
        pose = source_poses[str(spec["pose"])]

        for frame_index in range(count):
            image = _compose_frame(pose, name, frame_index, count)
            frame_path = action_dir / f"{name}_{frame_index:02d}.png"
            image.save(frame_path)
            sheet.alpha_composite(image, (frame_index * FRAME_SIZE, 0))
            frame_paths.append(frame_path)

        sheet_path = SHEETS_DIR / f"chr_player_lumen-spoolwright_{name}_sheet_v002.png"
        sheet.save(sheet_path)
        preview_rows.append((name, frame_paths))
        frame_total += count
        manifest["animations"].append(
            {
                "name": name,
                "fps": spec["fps"],
                "loop": spec["loop"],
                "frame_count": count,
                "sheet": f"res://assets/sprites/lumen/sheets/{sheet_path.name}",
                "frames": [
                    f"res://assets/sprites/lumen/frames/{name}/{path.name}"
                    for path in frame_paths
                ],
            }
        )

    _write_preview(preview_rows)
    empty_alpha = [str(path) for _, paths in preview_rows for path in paths if _alpha_bounds(path) is None]
    if empty_alpha:
        raise RuntimeError(f"Generated transparent-only frames: {empty_alpha[:3]}")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"LUMEN_ANIMATION_FRAMES_PASS source=formal_pose_art animations={len(ANIMATIONS)} frames={frame_total}")


if __name__ == "__main__":
    main()
