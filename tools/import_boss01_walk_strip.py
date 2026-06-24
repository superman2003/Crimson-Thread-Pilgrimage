from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses" / "boss_01_moss_bell_matriarch"
FRAMES_ROOT = BOSS_ROOT / "frames"
MANIFEST_PATH = BOSS_ROOT / "manifest.json"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes" / "boss_01_moss_bell_matriarch"
SOURCE_DIR = ARTIFACT_ROOT / "source" / "walk"
SOURCE_STRIP = SOURCE_DIR / "boss01_walk_strip_imagegen_magenta.png"
SOURCE_STRIP_16 = SOURCE_DIR / "boss01_walk_strip_16_imagegen_magenta.png"
SOURCE_GRID_16 = SOURCE_DIR / "boss01_walk_grid_2x8_imagegen_magenta.png"
ALPHA_STRIP = SOURCE_DIR / "boss01_walk_strip_alpha.png"
ALPHA_STRIP_16 = SOURCE_DIR / "boss01_walk_strip_16_alpha.png"
ALPHA_GRID_16 = SOURCE_DIR / "boss01_walk_grid_2x8_alpha.png"
ALPHA_TOOL_STRIP = SOURCE_DIR / "boss01_walk_strip_alpha_tool.png"
CONTACT_PATH = ARTIFACT_ROOT / "boss01_directional_contact.png"
WALK_CONTACT_PATH = ARTIFACT_ROOT / "boss01_walk_16f_contact.png"

DEFAULT_INPUT = Path(
    r"C:\Users\21120\.codex\generated_images\019ed598-d2c7-7ed3-be36-3a6947596ce0"
    r"\ig_0528c8340cbdfd44016a336e058030819b9d0c55ad096bc3be.png"
)

FRAME_SIZE = 256
FRAME_COUNT = 16
GRID_COLUMNS = 8
GRID_ROWS = 2
TARGET_BOTTOM = 246


def main() -> None:
    source = DEFAULT_INPUT
    if not source.exists():
        raise FileNotFoundError(source)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, SOURCE_GRID_16)

    if source == DEFAULT_INPUT:
        alpha_strip = remove_magenta(Image.open(SOURCE_GRID_16).convert("RGBA"))
    elif ALPHA_TOOL_STRIP.exists():
        alpha_strip = Image.open(ALPHA_TOOL_STRIP).convert("RGBA")
    else:
        strip = Image.open(SOURCE_GRID_16).convert("RGBA")
        alpha_strip = remove_magenta(strip)
    alpha_strip = clean_magenta_spill(alpha_strip)
    alpha_strip.save(ALPHA_GRID_16)
    alpha_strip.save(ALPHA_STRIP_16)
    alpha_strip.save(ALPHA_STRIP)

    right_frames = normalize_walk_frames(alpha_strip)
    left_frames = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in right_frames]
    write_frames("walk_left", left_frames)
    write_frames("walk_right", right_frames)

    update_manifest()
    render_contact_sheet()
    render_walk_contact_sheet(left_frames, right_frames)
    print(
        "BOSS01_WALK_STRIP_IMPORT_PASS "
        f"frames={FRAME_COUNT * 2} source={SOURCE_GRID_16.relative_to(ROOT).as_posix()} "
        f"contact={CONTACT_PATH.relative_to(ROOT).as_posix()} "
        f"walk_contact={WALK_CONTACT_PATH.relative_to(ROOT).as_posix()}"
    )


def remove_magenta(image: Image.Image) -> Image.Image:
    pixels = image.load()
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    dst = out.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            magenta_distance = abs(r - 244) + abs(g - 8) + abs(b - 244)
            magenta_like = r > 170 and b > 170 and g < 90 and abs(r - b) < 70
            if magenta_like:
                alpha = 0 if magenta_distance < 135 else int(clamp((magenta_distance - 135) / 115 * 255, 0, 255))
                if alpha < 28:
                    dst[x, y] = (0, 0, 0, 0)
                else:
                    dst[x, y] = (r, g, b, min(a, alpha))
                continue
            dst[x, y] = (r, g, b, a)
    alpha = out.getchannel("A").filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(0.35))
    out.putalpha(alpha)
    return out


def clean_magenta_spill(image: Image.Image) -> Image.Image:
    out = image.copy()
    pixels = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a <= 0:
                continue
            if not is_magenta_spill(r, g, b):
                continue
            if a < 150 or _touches_transparent_alpha(out, x, y):
                if a < 190:
                    pixels[x, y] = (0, 0, 0, 0)
                    continue
            lum = int(0.299 * r + 0.587 * g + 0.114 * b)
            pixels[x, y] = (
                clamp_int(lum * 0.45, 8, 92),
                clamp_int(max(g, lum * 0.78), 24, 132),
                clamp_int(lum * 0.38, 6, 82),
                a,
            )
    return out


def is_magenta_spill(r: int, g: int, b: int) -> bool:
    magenta_bias = (r + b) * 0.5 - g
    return r > 76 and b > 76 and g < 118 and abs(r - b) < 132 and magenta_bias > 28


def _touches_transparent_alpha(image: Image.Image, x: int, y: int) -> bool:
    alpha = image.getchannel("A")
    for ny in range(max(0, y - 1), min(image.height, y + 2)):
        for nx in range(max(0, x - 1), min(image.width, x + 2)):
            if alpha.getpixel((nx, ny)) < 32:
                return True
    return False


def normalize_walk_frames(strip: Image.Image) -> list[Image.Image]:
    slot_width = strip.width / GRID_COLUMNS
    slot_height = strip.height / GRID_ROWS
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        column = index % GRID_COLUMNS
        row = index // GRID_COLUMNS
        left = int(round(column * slot_width))
        right = int(round((column + 1) * slot_width))
        top = int(round(row * slot_height))
        bottom = int(round((row + 1) * slot_height))
        slot = strip.crop((left, top, right, bottom))
        crop = trim_alpha(slot)
        if crop.getchannel("A").getbbox() is None:
            raise RuntimeError(f"empty walk frame {index}")
        crop = clean_walk_islands(clean_magenta_spill(crop))
        crop = crop.filter(ImageFilter.UnsharpMask(radius=1.0, percent=105, threshold=2))
        crop = fit_subject(crop, max_width=238, max_height=238)
        crop = clean_walk_islands(clean_magenta_spill(crop))
        frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        bbox = crop.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
        assert bbox is not None
        x = FRAME_SIZE // 2 - crop.width // 2
        y = TARGET_BOTTOM - bbox[3]
        frame.alpha_composite(make_shadow(crop, index), (0, 0))
        frame.alpha_composite(crop, (x, y))
        frame = ensure_bottom(clean_walk_islands(clean_magenta_spill(frame)))
        frames.append(frame)
    return frames


def clean_walk_islands(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    binary = alpha.point(lambda value: 255 if value > 24 else 0)
    bbox = binary.getbbox()
    if bbox is None:
        return image

    components = alpha_components(binary)
    if not components:
        return image

    main_index = max(range(len(components)), key=lambda i: components[i]["count"])
    main = components[main_index]
    main_box = main["bbox"]
    keep_pixels: set[tuple[int, int]] = set(main["pixels"])

    for index, component in enumerate(components):
        if index == main_index:
            continue
        comp_box = component["bbox"]
        x_gap = max(0, max(main_box[0], comp_box[0]) - min(main_box[2], comp_box[2]))
        y_gap = max(0, max(main_box[1], comp_box[1]) - min(main_box[3], comp_box[3]))
        lower_root = component["count"] <= 180 and comp_box[1] > main_box[1] + (main_box[3] - main_box[1]) * 0.64 and x_gap <= 10 and y_gap <= 16
        tiny_body_gap = component["count"] <= 70 and x_gap <= 6 and y_gap <= 10
        if lower_root or tiny_body_gap:
            keep_pixels.update(component["pixels"])

    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src = image.load()
    dst = out.load()
    for x, y in keep_pixels:
        dst[x, y] = src[x, y]
    return out


def alpha_components(binary: Image.Image) -> list[dict[str, Any]]:
    pixels = binary.load()
    visited: set[tuple[int, int]] = set()
    components: list[dict[str, Any]] = []
    width, height = binary.size
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in visited:
                continue
            stack = [(x, y)]
            visited.add((x, y))
            points: list[tuple[int, int]] = []
            min_x = max_x = x
            min_y = max_y = y
            while stack:
                px, py = stack.pop()
                points.append((px, py))
                min_x = min(min_x, px)
                max_x = max(max_x, px + 1)
                min_y = min(min_y, py)
                max_y = max(max_y, py + 1)
                for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    if pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    stack.append((nx, ny))
            components.append({"pixels": points, "count": len(points), "bbox": (min_x, min_y, max_x, max_y)})
    return components


def fit_subject(image: Image.Image, max_width: int, max_height: int) -> Image.Image:
    width, height = image.size
    scale = min(max_width / max(1, width), max_height / max(1, height))
    next_size = (max(1, int(width * scale)), max(1, int(height * scale)))
    return image.resize(next_size, Image.Resampling.LANCZOS)


def make_shadow(subject: Image.Image, index: int) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cycle = index / max(1, FRAME_COUNT - 1)
    sway = int(round(-12.0 * cos_tau(cycle)))
    draw.ellipse((58 + sway, TARGET_BOTTOM - 8, 198 + sway, TARGET_BOTTOM + 9), fill=(8, 15, 8, 42))
    return layer.filter(ImageFilter.GaussianBlur(4.5))


def ensure_bottom(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return image
    delta = TARGET_BOTTOM - bbox[3]
    if delta == 0:
        return image
    shifted = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shifted.alpha_composite(image, (0, delta))
    return shifted


def write_frames(animation_name: str, frames: list[Image.Image]) -> None:
    out_dir = FRAMES_ROOT / animation_name
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"attack_{index:02d}.png")


def update_manifest() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    pack: dict[str, Any] = manifest.get("directional_asset_pack", {})
    pack["walk_frames_per_direction"] = FRAME_COUNT
    pack["walk_source_strip"] = SOURCE_GRID_16.relative_to(ROOT).as_posix()
    pack["walk_alpha_strip"] = ALPHA_GRID_16.relative_to(ROOT).as_posix()
    pack["walk_source_mode"] = "imagegen 16-frame 2x8 walk sheet, chroma-key removed and bottom-center normalized"
    pack["walk_pose_requirements"] = [
        "root feet alternate forward and back",
        "bell skirt weight shifts",
        "hanging bells and chains swing",
        "bottom anchor remains fixed",
    ]
    manifest["directional_asset_pack"] = pack
    _replace_animation_frames(manifest, "walk_left", FRAME_COUNT)
    _replace_animation_frames(manifest, "walk_right", FRAME_COUNT)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _replace_animation_frames(manifest: dict[str, Any], animation_name: str, frame_count: int) -> None:
    for animation in manifest.get("animations", []):
        if str(animation.get("name", "")) != animation_name:
            continue
        animation["fps"] = 10.0
        animation["loop"] = True
        animation["frames"] = [
            f"res://assets/sprites/bosses/boss_01_moss_bell_matriarch/frames/{animation_name}/attack_{index:02d}.png"
            for index in range(frame_count)
        ]
        return
    manifest.setdefault("animations", []).append(
        {
            "name": animation_name,
            "fps": 10.0,
            "loop": True,
            "frames": [
                f"res://assets/sprites/bosses/boss_01_moss_bell_matriarch/frames/{animation_name}/attack_{index:02d}.png"
                for index in range(frame_count)
            ],
        }
    )


def render_contact_sheet() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    rows: list[tuple[str, list[Image.Image]]] = []
    for animation in manifest.get("animations", []):
        name = str(animation.get("name", ""))
        if not name.endswith("_left") and not name.endswith("_right"):
            continue
        frames: list[Image.Image] = []
        for frame_path in animation.get("frames", []):
            frames.append(Image.open(res_to_path(str(frame_path))).convert("RGBA"))
        rows.append((name, frames))

    cell = 112
    label_w = 172
    row_h = 138
    margin = 16
    max_frames = max((len(frames) for _, frames in rows), default=FRAME_COUNT)
    width = label_w + max_frames * cell + margin * 2
    height = margin * 2 + len(rows) * row_h
    sheet = Image.new("RGB", (width, height), (12, 13, 16))
    draw = ImageDraw.Draw(sheet)
    for row_index, (name, frames) in enumerate(rows):
        y = margin + row_index * row_h
        draw.text((margin, y + 12), name, fill=(230, 224, 188))
        draw.text((margin, y + 34), f"{len(frames)} frames", fill=(143, 161, 151))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (cell, cell), (20, 23, 22, 255))
            thumb.alpha_composite(frame.resize((cell, cell), Image.Resampling.LANCZOS), (0, 0))
            x = label_w + frame_index * cell
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.text((x + 5, y + cell + 4), f"{frame_index:02d}", fill=(148, 158, 150))
    CONTACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_PATH)


def render_walk_contact_sheet(left_frames: list[Image.Image], right_frames: list[Image.Image]) -> None:
    cell = 112
    label_w = 150
    row_h = 138
    margin = 16
    rows = [("walk_left_16f", left_frames), ("walk_right_16f", right_frames)]
    sheet = Image.new("RGB", (label_w + FRAME_COUNT * cell + margin * 2, margin * 2 + row_h * 2), (12, 13, 16))
    draw = ImageDraw.Draw(sheet)
    for row_index, (name, frames) in enumerate(rows):
        y = margin + row_index * row_h
        draw.text((margin, y + 12), name, fill=(230, 224, 188))
        draw.text((margin, y + 34), f"{len(frames)} frames", fill=(143, 161, 151))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (cell, cell), (20, 23, 22, 255))
            thumb.alpha_composite(frame.resize((cell, cell), Image.Resampling.LANCZOS), (0, 0))
            x = label_w + frame_index * cell
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.text((x + 5, y + cell + 4), f"{frame_index:02d}", fill=(148, 158, 150))
    WALK_CONTACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(WALK_CONTACT_PATH)


def res_to_path(path: str) -> Path:
    if not path.startswith("res://"):
        raise ValueError(path)
    return GODOT_ROOT / path.removeprefix("res://")


def trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
    if bbox is None:
        return image
    return image.crop((max(0, bbox[0] - 3), max(0, bbox[1] - 3), min(image.width, bbox[2] + 3), min(image.height, bbox[3] + 3)))


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def clamp_int(value: float, low: int, high: int) -> int:
    return int(max(low, min(high, value)))


def cos_tau(value: float) -> float:
    import math

    return math.cos(value * math.tau)


if __name__ == "__main__":
    main()
