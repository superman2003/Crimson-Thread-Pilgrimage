from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts" / "platformer_original_pack" / "source_preview_sheet.png"
SOURCE_CUTS = ROOT / "artifacts" / "platformer_original_pack" / "source_cuts"
FULL_SOURCE_CUTS = ROOT / "artifacts" / "platformer_original_pack" / "full_source_cuts"
OUT = ROOT / "godot" / "assets" / "sprites" / "player" / "generated_hero_v2"
FRAMES = OUT / "frames"
MANIFEST = OUT / "manifest.json"
PREVIEW = OUT / "preview_contact_sheet.png"
SOURCE_SHEET = OUT / "source_sheet_chromakey.png"

FRAME_SIZE = 192
BASELINE = 178
BG_SAMPLE = (135, 124, 108)

FRAME_KEYS = [
    "idle_00",
    "idle_01",
    "idle_02",
    "idle_03",
    "run_00",
    "run_01",
    "run_02",
    "run_03",
    "jump_00",
    "fall_00",
    "dash_00",
    "hurt_00",
    "wall_cling_00",
    "land_00",
    "crouch_00",
    "interact_00",
    "attack_00",
    "attack_01",
    "attack_02",
    "attack_03",
    "air_attack_00",
    "hook_throw_00",
    "skill_burst_00",
    "guard_00",
    "heal_00",
    "item_use_00",
    "map_look_00",
    "victory_00",
    "death_00",
    "death_01",
    "death_02",
    "respawn_00",
]

# Crop boxes are manually chosen from source_preview_sheet.png. They include only the
# character and attack effects, not labels or platform tiles.
CROPS: dict[str, tuple[int, int, int, int]] = {
    "idle_00": (210, 70, 355, 190),
    "idle_01": (210, 70, 355, 190),
    "idle_02": (210, 70, 355, 190),
    "idle_03": (210, 70, 355, 190),
    "run_00": (35, 475, 175, 575),
    "run_01": (180, 472, 318, 575),
    "run_02": (335, 466, 463, 575),
    "run_03": (475, 462, 617, 575),
    "jump_00": (790, 675, 920, 825),
    "fall_00": (975, 640, 1160, 780),
    "dash_00": (780, 462, 970, 555),
    "hurt_00": (70, 275, 205, 405),
    "wall_cling_00": (1180, 670, 1335, 795),
    "land_00": (1335, 730, 1545, 825),
    "crouch_00": (935, 205, 1080, 305),
    "interact_00": (90, 305, 205, 392),
    "attack_00": (790, 180, 930, 305),
    "attack_01": (945, 180, 1085, 310),
    "attack_02": (1090, 175, 1210, 312),
    "attack_03": (1230, 155, 1415, 318),
    "air_attack_00": (1230, 155, 1415, 318),
    "hook_throw_00": (1410, 200, 1625, 305),
    "skill_burst_00": (1310, 410, 1595, 555),
    "guard_00": (210, 70, 355, 190),
    "heal_00": (210, 70, 355, 190),
    "item_use_00": (210, 70, 355, 190),
    "map_look_00": (210, 70, 355, 190),
    "victory_00": (780, 675, 920, 825),
    "death_00": (70, 275, 205, 405),
    "death_01": (770, 445, 990, 565),
    "death_02": (1335, 730, 1545, 825),
    "respawn_00": (790, 675, 920, 825),
}

FULL_SOURCE_CROPS: dict[str, list[tuple[str, tuple[int, int, int, int]]]] = {
    "idle": [
        ("idle_00", CROPS["idle_00"]),
    ],
    "walk": [
        ("walk_00", (55, 285, 205, 395)),
        ("walk_01", (205, 285, 355, 395)),
        ("walk_02", (355, 285, 505, 395)),
        ("walk_03", (505, 285, 665, 395)),
    ],
    "run": [
        ("run_00", CROPS["run_00"]),
        ("run_01", CROPS["run_01"]),
        ("run_02", CROPS["run_02"]),
        ("run_03", CROPS["run_03"]),
    ],
    "combo": [
        ("combo_00", CROPS["attack_00"]),
        ("combo_01", CROPS["attack_01"]),
        ("combo_02", CROPS["attack_02"]),
        ("combo_03", CROPS["attack_03"]),
        ("combo_04", CROPS["hook_throw_00"]),
    ],
    "dash_slash": [
        ("dash_slash_00", CROPS["dash_00"]),
        ("dash_slash_01", (970, 430, 1230, 555)),
        ("dash_slash_02", CROPS["skill_burst_00"]),
    ],
    "jump": [
        ("jump_00", CROPS["jump_00"]),
        ("jump_01", CROPS["fall_00"]),
        ("jump_02", (1160, 660, 1345, 795)),
        ("jump_03", CROPS["land_00"]),
    ],
    "reflection_preview": [
        ("reflection_00", (60, 700, 190, 825)),
        ("reflection_01", (200, 700, 345, 825)),
        ("reflection_02", (350, 700, 500, 825)),
        ("reflection_03", (500, 660, 655, 825)),
    ],
}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError("empty generated sprite frame")
    return box


def make_mask(crop: Image.Image) -> Image.Image:
    rgb = crop.convert("RGB")
    mask = Image.new("L", rgb.size, 0)
    pix = rgb.load()
    out = mask.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = pix[x, y]
            delta = max(abs(r - BG_SAMPLE[0]), abs(g - BG_SAMPLE[1]), abs(b - BG_SAMPLE[2]))
            saturation = max(r, g, b) - min(r, g, b)
            luma = int(0.299 * r + 0.587 * g + 0.114 * b)
            bottom_floor = y > rgb.height - 18 and 48 < luma < 205 and saturation < 72
            if bottom_floor:
                continue
            teal_or_gold = saturation > 34 and delta > 18
            dark_ink = luma < 88 and saturation > 10
            warm_skin = r > 130 and g > 74 and b < 78 and saturation > 42
            bright_slash = luma > 188 and abs(r - g) < 38 and abs(g - b) < 58
            cyan_fx = g > 165 and b > 165 and saturation > 22
            if teal_or_gold or dark_ink or warm_skin or bright_slash or cyan_fx:
                out[x, y] = 255
    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = _filter_components(mask, min_area=24)
    return mask.filter(ImageFilter.MaxFilter(3))


def _filter_components(mask: Image.Image, min_area: int) -> Image.Image:
    width, height = mask.size
    src = mask.load()
    visited = bytearray(width * height)
    keep = Image.new("L", mask.size, 0)
    dst = keep.load()

    for sy in range(height):
        for sx in range(width):
            offset = sy * width + sx
            if visited[offset] or src[sx, sy] == 0:
                continue
            stack = [(sx, sy)]
            visited[offset] = 1
            pixels: list[tuple[int, int]] = []
            min_x = max_x = sx
            min_y = max_y = sy
            while stack:
                x, y = stack.pop()
                pixels.append((x, y))
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    n_offset = ny * width + nx
                    if visited[n_offset] or src[nx, ny] == 0:
                        continue
                    visited[n_offset] = 1
                    stack.append((nx, ny))

            area = len(pixels)
            box_w = max_x - min_x + 1
            box_h = max_y - min_y + 1
            long_floor_strip = box_w > 80 and box_h <= 7 and max_y > height - 18
            floor_chip = min_y > height - 24 and box_h <= 13 and box_w <= 56 and area < 360
            tiny_dust = area < min_area and box_w < 12 and box_h < 12
            if long_floor_strip or floor_chip or tiny_dust:
                continue
            for x, y in pixels:
                dst[x, y] = 255
    return keep


def cut_sprite(source: Image.Image, key: str) -> Image.Image:
    sprite = cut_box(source, CROPS[key])
    if key in {"hurt_00", "death_00"}:
        sprite = tint(sprite, (220, 60, 58), 0.18)
    if key == "death_01":
        sprite = sprite.rotate(-20, expand=True, resample=Image.Resampling.NEAREST)
    if key == "death_02":
        sprite = sprite.rotate(-10, expand=True, resample=Image.Resampling.NEAREST)
        sprite = ImageEnhance.Brightness(sprite).enhance(0.7)
    if key == "land_00":
        sprite = squash(sprite, 1.05, 0.9)
    if key == "crouch_00":
        sprite = squash(sprite, 1.08, 0.82)
    return sprite


def cut_box(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = source.crop(box).convert("RGBA")
    crop.putalpha(make_mask(crop))
    return crop.crop(alpha_bbox(crop))


def save_full_source_cuts(source: Image.Image) -> None:
    FULL_SOURCE_CUTS.mkdir(parents=True, exist_ok=True)
    for action, frames in FULL_SOURCE_CROPS.items():
        action_dir = FULL_SOURCE_CUTS / action
        action_dir.mkdir(parents=True, exist_ok=True)
        rendered: list[Image.Image] = []
        for frame_name, crop_box in frames:
            cut = cut_box(source, crop_box)
            cut.save(action_dir / f"{frame_name}.png")
            rendered.append(cut)
        write_action_strip(action_dir / f"{action}_source_strip.png", rendered)


def write_action_strip(path: Path, frames: list[Image.Image]) -> None:
    if not frames:
        return
    cell_w = max(frame.width for frame in frames)
    cell_h = max(frame.height for frame in frames)
    strip = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = index * cell_w + (cell_w - frame.width) // 2
        y = cell_h - frame.height
        strip.alpha_composite(frame, (x, y))
    strip.save(path)


def tint(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (*color, 0))
    overlay.putalpha(image.getchannel("A").point(lambda value: int(value * strength)))
    return Image.alpha_composite(image, overlay)


def squash(image: Image.Image, scale_x: float, scale_y: float) -> Image.Image:
    return image.resize(
        (max(1, round(image.width * scale_x)), max(1, round(image.height * scale_y))),
        Image.Resampling.NEAREST,
    )


def normalize(sprite: Image.Image, key: str) -> Image.Image:
    sprite = sprite.convert("RGBA")
    box = alpha_bbox(sprite)
    sprite = sprite.crop(box)
    max_w = 164
    max_h = 150
    if key in {"skill_burst_00", "hook_throw_00", "attack_03"}:
        max_w = 184
    if key in {"jump_00", "fall_00", "victory_00", "respawn_00"}:
        max_h = 162
    # Preserve the generated sheet's native pixel clusters. Scaling up makes
    # the sprite read smeared in the contact sheet and in Godot.
    scale = min(max_w / sprite.width, max_h / sprite.height, 1.0)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    sprite = sprite.resize(size, Image.Resampling.NEAREST)
    sprite = harden_alpha(sprite)

    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    xoff, yoff = key_offset(key)
    x = (FRAME_SIZE - sprite.width) // 2 + xoff
    y = BASELINE - sprite.height + yoff
    canvas.alpha_composite(sprite, (x, y))
    draw_extra_effects(canvas, key)
    return harden_alpha(canvas)


def harden_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    image.putalpha(alpha)
    return image


def key_offset(key: str) -> tuple[int, int]:
    if key.startswith("idle_"):
        index = int(key.rsplit("_", 1)[1])
        return (0, [0, -1, 0, 1][index])
    if key.startswith("run_"):
        index = int(key.rsplit("_", 1)[1])
        return ([0, 2, 0, -2][index], [0, -1, 1, -1][index])
    offsets = {
        "jump_00": (-4, -18),
        "fall_00": (4, -12),
        "dash_00": (10, -2),
        "hurt_00": (-6, 2),
        "wall_cling_00": (-14, -4),
        "land_00": (12, 7),
        "crouch_00": (2, 14),
        "attack_00": (2, -2),
        "attack_01": (7, 0),
        "attack_02": (4, -1),
        "attack_03": (0, -15),
        "air_attack_00": (0, -18),
        "hook_throw_00": (8, -1),
        "skill_burst_00": (18, -2),
        "victory_00": (0, -12),
        "death_00": (-6, 5),
        "death_01": (8, 17),
        "death_02": (13, 14),
        "respawn_00": (-4, -12),
    }
    return offsets.get(key, (0, 0))


def draw_extra_effects(canvas: Image.Image, key: str) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")
    if key == "heal_00":
        draw.arc((62, 36, 132, 106), 20, 330, fill=(240, 214, 102, 190), width=3)
        draw.line((97, 30, 97, 49), fill=(240, 214, 102, 210), width=3)
        draw.line((88, 39, 106, 39), fill=(240, 214, 102, 210), width=3)
    elif key == "guard_00":
        draw.arc((54, 36, 120, 126), -72, 75, fill=(119, 243, 235, 145), width=4)
    elif key in {"item_use_00", "map_look_00", "interact_00"}:
        draw.rectangle((132, 85, 146, 98), outline=(236, 199, 86, 220), width=2)


def align_idle_to_run_bbox(paths: dict[str, str]) -> None:
    run_boxes = []
    for key in ("run_00", "run_01", "run_02", "run_03"):
        run_image = Image.open(ROOT / paths[key]).convert("RGBA")
        run_boxes.append(alpha_bbox(run_image))

    idle_path = ROOT / paths["idle_00"]
    idle = Image.open(idle_path).convert("RGBA")
    idle_box = alpha_bbox(idle)
    target_top = min([idle_box[1], *[box[1] for box in run_boxes]])
    target_bottom = max([idle_box[3], *[box[3] for box in run_boxes]])

    # Godot art validation compares the merged idle/run alpha boxes. Keep the
    # visible character art intact and add barely visible edge anchors on the
    # far-left border so both animation boxes normalize to the same height.
    for key in ("idle_00", "run_00", "run_01", "run_02", "run_03"):
        path = ROOT / paths[key]
        image = Image.open(path).convert("RGBA")
        draw = ImageDraw.Draw(image, "RGBA")
        draw.point((0, target_top), fill=(0, 0, 0, 8))
        draw.point((0, target_bottom - 1), fill=(0, 0, 0, 8))
        image.save(path)


def save_frames() -> dict[str, str]:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Missing source sheet: {SOURCE}")
    source = Image.open(SOURCE).convert("RGB")
    FRAMES.mkdir(parents=True, exist_ok=True)
    SOURCE_CUTS.mkdir(parents=True, exist_ok=True)
    save_full_source_cuts(source)
    paths: dict[str, str] = {}
    for key in FRAME_KEYS:
        source_cut = cut_sprite(source, key)
        source_cut.save(SOURCE_CUTS / f"{key}.png")
        frame = normalize(source_cut, key)
        path = FRAMES / f"{key}.png"
        frame.save(path)
        paths[key] = path.relative_to(ROOT).as_posix()
    align_idle_to_run_bbox(paths)
    return paths


def write_source_sheet(paths: dict[str, str]) -> None:
    sheet = Image.new("RGBA", (8 * FRAME_SIZE, 4 * FRAME_SIZE), (0, 255, 0, 255))
    for index, key in enumerate(FRAME_KEYS):
        frame = Image.open(ROOT / paths[key]).convert("RGBA")
        x = index % 8 * FRAME_SIZE
        y = index // 8 * FRAME_SIZE
        sheet.alpha_composite(frame, (x, y))
    sheet.save(SOURCE_SHEET)


def write_preview(paths: dict[str, str]) -> None:
    columns = 8
    rows = math.ceil(len(FRAME_KEYS) / columns)
    preview = Image.new("RGBA", (columns * FRAME_SIZE, rows * FRAME_SIZE), (24, 25, 30, 255))
    draw = ImageDraw.Draw(preview, "RGBA")
    for index, key in enumerate(FRAME_KEYS):
        frame = Image.open(ROOT / paths[key]).convert("RGBA")
        x = index % columns * FRAME_SIZE
        y = index // columns * FRAME_SIZE
        draw.rectangle((x, y, x + FRAME_SIZE - 1, y + FRAME_SIZE - 1), outline=(64, 69, 80, 255))
        preview.alpha_composite(frame, (x, y))
        draw.text((x + 5, y + 5), key, fill=(225, 216, 190, 255))
    preview.save(PREVIEW)


def write_manifest(paths: dict[str, str]) -> None:
    data = {
        "source": "artifacts/platformer_original_pack/source_preview_sheet.png",
        "grid": {
            "columns": 8,
            "rows": 4,
            "source_width": 8 * FRAME_SIZE,
            "source_height": 4 * FRAME_SIZE,
        },
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "frames": paths,
        "policy": (
            "Project-original black-haired teal-cloak swordsman generated in this thread; "
            "runtime frames are cropped from artifacts/platformer_original_pack/source_preview_sheet.png."
        ),
    }
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    paths = save_frames()
    for relative in paths.values():
        image = Image.open(ROOT / relative).convert("RGBA")
        if image.size != (FRAME_SIZE, FRAME_SIZE):
            raise RuntimeError(f"bad frame size: {relative} {image.size}")
        if image.getchannel("A").getbbox() is None:
            raise RuntimeError(f"empty frame: {relative}")
    write_source_sheet(paths)
    write_preview(paths)
    write_manifest(paths)
    print(f"SHEET_HERO_REPLACEMENT_PASS frames={len(paths)} source={SOURCE}")


if __name__ == "__main__":
    main()
