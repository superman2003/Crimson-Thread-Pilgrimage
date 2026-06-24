from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CONCEPT_INDEX = ROOT / "artifacts" / "boss_concepts" / "boss_concepts_index.json"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes"
GODOT_ROOT = ROOT / "godot"
GODOT_BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"
FRAME_COUNT = 6
ARTIFACT_FRAME_SIZE = 384
GODOT_FRAME_SIZE = 256


def main() -> None:
    parser = argparse.ArgumentParser(description="Import generated non-pixel boss attack strips into transparent keyframes.")
    parser.add_argument("--boss-id", help="Process only one boss id, for example boss_01.")
    parser.add_argument("--source", help="Source generated chroma strip for --boss-id.")
    parser.add_argument("--all", action="store_true", help="Process all bosses that already have source/generated_attack_strip_chroma.png.")
    parser.add_argument("--rebuild-indexes", action="store_true", help="Only rebuild indexes and previews from existing frame assets.")
    parser.add_argument("--layout", choices=["auto", "strip-6", "grid-3x2"], default="auto", help="Source layout for generated attack frames.")
    args = parser.parse_args()

    entries = json.loads(CONCEPT_INDEX.read_text(encoding="utf-8"))["entries"]
    selected: list[dict[str, Any]]
    if args.boss_id:
        selected = [entry for entry in entries if entry["id"] == args.boss_id]
        if not selected:
            raise SystemExit(f"Unknown boss id: {args.boss_id}")
    elif args.all or args.rebuild_indexes:
        selected = entries
    else:
        raise SystemExit("Use --boss-id with --source, --all, or --rebuild-indexes.")

    imported: list[dict[str, Any]] = []
    skipped: list[str] = []
    if not args.rebuild_indexes:
        for entry in selected:
            slug = Path(entry["file"]).stem
            raw_dir = ARTIFACT_ROOT / slug / "source"
            raw_path = Path(args.source).resolve() if args.source and args.boss_id == entry["id"] else raw_dir / "generated_attack_strip_chroma.png"
            if not raw_path.exists():
                skipped.append(entry["id"])
                continue
            raw_dir.mkdir(parents=True, exist_ok=True)
            stored_source = stored_source_path(raw_path, raw_dir)
            if raw_path != stored_source.resolve():
                shutil.copy2(raw_path, stored_source)
            imported.append(import_strip(entry, stored_source, args.layout))

    all_entries = rebuild_indexes(entries)
    contact_path = ARTIFACT_ROOT / "contact_sheets" / "boss_attack_keyframes_contact_sheet.png"
    render_contact_sheet(all_entries, contact_path)
    preview_path = ARTIFACT_ROOT / "preview.html"
    render_preview_html(all_entries, preview_path)
    print(
        "IMPORT_GENERATED_BOSS_ATTACK_STRIPS_PASS "
        f"imported={len(imported)} indexed={len(all_entries)} skipped={len(skipped)} "
        f"contact_sheet={contact_path.as_posix()}"
    )


def import_strip(entry: dict[str, Any], raw_path: Path, layout: str = "auto") -> dict[str, Any]:
    boss_id = str(entry["id"])
    slug = Path(entry["file"]).stem
    artifact_frames_dir = ARTIFACT_ROOT / slug / "actions" / "attack"
    artifact_sheets_dir = ARTIFACT_ROOT / slug / "sheets"
    godot_frames_dir = GODOT_BOSS_ROOT / slug / "frames" / "attack"
    artifact_frames_dir.mkdir(parents=True, exist_ok=True)
    artifact_sheets_dir.mkdir(parents=True, exist_ok=True)
    godot_frames_dir.mkdir(parents=True, exist_ok=True)

    strip = Image.open(raw_path).convert("RGBA")
    slots = split_source_frames(strip, FRAME_COUNT, layout)
    artifact_frames: list[Path] = []
    godot_frames: list[Path] = []
    normalized_frames: list[Image.Image] = []

    for index, slot in enumerate(slots):
        cutout = clean_alpha_source(slot) if has_transparent_background(slot) else remove_chroma(slot)
        artifact_frame = normalize_frame(cutout, ARTIFACT_FRAME_SIZE)
        artifact_path = artifact_frames_dir / f"attack_{index:02d}.png"
        artifact_frame.save(artifact_path)
        artifact_frames.append(artifact_path)
        normalized_frames.append(artifact_frame)

        godot_frame = normalize_frame(cutout, GODOT_FRAME_SIZE)
        godot_path = godot_frames_dir / f"attack_{index:02d}.png"
        godot_frame.save(godot_path)
        godot_frames.append(godot_path)

    strip_path = artifact_sheets_dir / f"{boss_id}_attack_strip.png"
    render_strip(normalized_frames, strip_path)
    manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
    godot_paths = [to_res_path(path) for path in godot_frames]
    manifest = {
        "id": boss_id,
        "name_zh": entry.get("name_zh", ""),
        "name_en": entry.get("name_en", ""),
        "source_concept": normalize_rel(ROOT / entry["file"]),
        "source_generated_strip": normalize_rel(raw_path),
        "frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
        "anchor": "bottom-center",
        "runtime_2d": {
            "view": "locked side or three-quarter side view",
            "anchor": "bottom-center",
            "timing": ["ready", "anticipation", "windup", "active_hit", "follow_through", "recovery"],
            "hit_frame_index": 3,
            "horizontal_motion_only": True,
            "keep_collision_box_stable": True
        },
        "style": "high quality dark fantasy non-pixel hand-painted generated attack keyframes",
        "animations": [
            {"name": "idle", "fps": 6.0, "loop": True, "frames": [godot_paths[0], godot_paths[5]]},
            {"name": "walk", "fps": 6.0, "loop": True, "frames": [godot_paths[0], godot_paths[1], godot_paths[5]]},
            {"name": "attack", "fps": 12.0, "loop": False, "frames": godot_paths},
            {"name": "hurt", "fps": 10.0, "loop": False, "frames": [godot_paths[4]]},
            {"name": "death", "fps": 8.0, "loop": False, "frames": [godot_paths[5]]},
        ],
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return build_entry(entry, raw_path, artifact_frames, strip_path, manifest_path, godot_frames)


def split_source_frames(image: Image.Image, count: int, layout: str) -> list[Image.Image]:
    if layout == "grid-3x2" or (layout == "auto" and looks_like_grid_3x2(image)):
        return split_grid_3x2(image)
    if layout == "strip-6":
        return split_strip(image, count)
    return split_strip(image, count)


def split_grid_3x2(image: Image.Image) -> list[Image.Image]:
    width, height = image.size
    slots: list[Image.Image] = []
    for row in range(2):
        top = round(row * height / 2)
        bottom = round((row + 1) * height / 2)
        for column in range(3):
            left = round(column * width / 3)
            right = round((column + 1) * width / 3)
            slots.append(image.crop((left, top, right, bottom)))
    return slots


def looks_like_grid_3x2(image: Image.Image) -> bool:
    ratio = image.width / max(1, image.height)
    if not 1.25 <= ratio <= 1.85:
        return False
    counts = content_column_counts(image)
    rows = content_row_counts(image)
    width, height = image.size
    vertical_cut = min(counts[int(width * 0.28): int(width * 0.72)] or [height])
    horizontal_cut = min(rows[int(height * 0.38): int(height * 0.62)] or [width])
    return vertical_cut < height * 0.04 and horizontal_cut < width * 0.04


def split_strip(image: Image.Image, count: int) -> list[Image.Image]:
    smart_bounds = detect_strip_boundaries(image, count)
    if smart_bounds is not None:
        return [image.crop((smart_bounds[index], 0, smart_bounds[index + 1], image.height)) for index in range(count)]

    width, height = image.size
    slots: list[Image.Image] = []
    for index in range(count):
        left = round(index * width / count)
        right = round((index + 1) * width / count)
        slots.append(image.crop((left, 0, right, height)))
    return slots


def detect_strip_boundaries(image: Image.Image, count: int) -> list[int] | None:
    counts = content_column_counts(image)
    width, height = image.size
    slot = width / count
    threshold = max(4, int(height * 0.012))
    smooth = smooth_counts(counts, radius=max(2, width // 900))
    low_ranges = find_low_ranges(smooth, threshold)
    if not low_ranges:
        return None

    separators: list[int] = []
    min_gap = max(6, width // 300)
    for index in range(1, count):
        expected = index * slot
        window_left = int(max(0, expected - slot * 0.42))
        window_right = int(min(width - 1, expected + slot * 0.42))
        candidates: list[tuple[float, int]] = []
        for left, right in low_ranges:
            overlap_left = max(left, window_left)
            overlap_right = min(right, window_right)
            overlap = overlap_right - overlap_left
            if overlap < min_gap:
                continue
            center = (overlap_left + overlap_right) // 2
            score = overlap * 4.0 - abs(center - expected) * 0.18
            candidates.append((score, center))
        if candidates:
            separator = max(candidates, key=lambda item: item[0])[1]
        else:
            search = range(window_left, max(window_left + 1, window_right))
            separator = min(search, key=lambda column: smooth[column])
        separators.append(separator)

    bounds = [0, *separators, width]
    min_width = max(36, int(slot * 0.42))
    if any(bounds[index + 1] - bounds[index] < min_width for index in range(count)):
        return None
    if any(bounds[index + 1] <= bounds[index] for index in range(count)):
        return None
    return bounds


def content_column_counts(image: Image.Image) -> list[int]:
    pixels = image.convert("RGBA")
    width, height = pixels.size
    alpha = pixels.getchannel("A")
    if any(
        alpha.getpixel(point) < 250
        for point in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    ):
        return [sum(1 for y in range(height) if alpha.getpixel((x, y)) > 16) for x in range(width)]

    key = estimate_key_color(pixels)
    counts: list[int] = []
    for x in range(width):
        active = 0
        for y in range(height):
            r, g, b, a = pixels.getpixel((x, y))
            if a > 16 and color_distance((r, g, b), key) > 72:
                active += 1
        counts.append(active)
    return counts


def content_row_counts(image: Image.Image) -> list[int]:
    pixels = image.convert("RGBA")
    width, height = pixels.size
    alpha = pixels.getchannel("A")
    if any(
        alpha.getpixel(point) < 250
        for point in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    ):
        return [sum(1 for x in range(width) if alpha.getpixel((x, y)) > 16) for y in range(height)]

    key = estimate_key_color(pixels)
    counts: list[int] = []
    for y in range(height):
        active = 0
        for x in range(width):
            r, g, b, a = pixels.getpixel((x, y))
            if a > 16 and color_distance((r, g, b), key) > 72:
                active += 1
        counts.append(active)
    return counts


def smooth_counts(counts: list[int], radius: int) -> list[float]:
    if radius <= 0:
        return [float(value) for value in counts]
    width = len(counts)
    prefix = [0]
    for value in counts:
        prefix.append(prefix[-1] + value)
    smoothed: list[float] = []
    for index in range(width):
        left = max(0, index - radius)
        right = min(width, index + radius + 1)
        smoothed.append((prefix[right] - prefix[left]) / max(1, right - left))
    return smoothed


def find_low_ranges(counts: list[float], threshold: float) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for index, value in enumerate(counts):
        if value <= threshold and start is None:
            start = index
        elif value > threshold and start is not None:
            ranges.append((start, index))
            start = None
    if start is not None:
        ranges.append((start, len(counts)))
    return ranges


def stored_source_path(source_path: Path, raw_dir: Path) -> Path:
    if source_path.suffix.lower() not in {".png", ".webp"}:
        return raw_dir / "generated_attack_strip_source.png"
    try:
        image = Image.open(source_path).convert("RGBA")
        alpha = image.getchannel("A")
        corners = [
            alpha.getpixel((0, 0)),
            alpha.getpixel((image.width - 1, 0)),
            alpha.getpixel((0, image.height - 1)),
            alpha.getpixel((image.width - 1, image.height - 1)),
        ]
        if any(value < 255 for value in corners):
            return raw_dir / "generated_attack_strip_alpha.png"
    except Exception:
        pass
    return raw_dir / "generated_attack_strip_chroma.png"


def has_transparent_background(image: Image.Image) -> bool:
    alpha = image.convert("RGBA").getchannel("A")
    corners = [
        alpha.getpixel((0, 0)),
        alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    ]
    return any(value < 16 for value in corners)


def remove_chroma(image: Image.Image) -> Image.Image:
    pixels = image.convert("RGBA")
    key = estimate_key_color(pixels)
    data = []
    for r, g, b, a in pixels.getdata():
        dist = color_distance((r, g, b), key)
        if dist < 130:
            matte = clamp((dist - 18) / 112, 0.0, 1.0)
            next_alpha = int(a * matte)
            r, g, b = despill((r, g, b), key, 1.0 - matte)
            data.append((r, g, b, next_alpha))
        else:
            data.append((r, g, b, a))
    pixels.putdata(data)
    alpha = pixels.getchannel("A").filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(0.35))
    pixels.putalpha(alpha)
    return trim_alpha(clean_alpha_source(pixels))


def clean_alpha_source(image: Image.Image) -> Image.Image:
    pixels = image.convert("RGBA")
    out = []
    for r, g, b, a in pixels.getdata():
        if a < 8:
            out.append((0, 0, 0, 0))
            continue
        green_delta = g - max(r, b)
        if green_delta > 16:
            cap = max(r, b) + 8
            g = min(g, cap)
            if a < 210:
                r = int(r * 0.92 + min(r, cap) * 0.08)
                b = int(b * 0.92 + min(b, cap) * 0.08)
        if a < 42 and green_delta > 8:
            a = max(0, int(a * 0.38))
        out.append((r, g, b, a))
    pixels.putdata(out)
    alpha = pixels.getchannel("A")
    pixels.putalpha(alpha.point(lambda value: 0 if value < 10 else value))
    return pixels


def estimate_key_color(image: Image.Image) -> tuple[int, int, int]:
    width, height = image.size
    samples: list[tuple[int, int, int]] = []
    step = max(1, min(width, height) // 80)
    for x in range(0, width, step):
        samples.append(image.getpixel((x, 0))[:3])
        samples.append(image.getpixel((x, height - 1))[:3])
    for y in range(0, height, step):
        samples.append(image.getpixel((0, y))[:3])
        samples.append(image.getpixel((width - 1, y))[:3])
    buckets: dict[tuple[int, int, int], int] = {}
    for r, g, b in samples:
        key = (round(r / 16) * 16, round(g / 16) * 16, round(b / 16) * 16)
        buckets[key] = buckets.get(key, 0) + 1
    winner = max(buckets.items(), key=lambda item: item[1])[0]
    return (min(255, winner[0]), min(255, winner[1]), min(255, winner[2]))


def color_distance(color: tuple[int, int, int], key: tuple[int, int, int]) -> float:
    return ((color[0] - key[0]) ** 2 + (color[1] - key[1]) ** 2 + (color[2] - key[2]) ** 2) ** 0.5


def despill(color: tuple[int, int, int], key: tuple[int, int, int], strength: float) -> tuple[int, int, int]:
    r, g, b = color
    channels = [r, g, b]
    key_channels = list(key)
    dominant = [index for index, value in enumerate(key_channels) if value >= 180]
    others = [index for index in range(3) if index not in dominant]
    if not dominant or not others:
        return color
    neutral_cap = int(sum(channels[index] for index in others) / len(others) + 28)
    for index in dominant:
        channels[index] = int(channels[index] * (1.0 - strength * 0.72) + min(channels[index], neutral_cap) * strength * 0.72)
    return tuple(max(0, min(255, value)) for value in channels)


def normalize_frame(image: Image.Image, frame_size: int) -> Image.Image:
    cutout = trim_alpha(image)
    bbox = cutout.getchannel("A").getbbox()
    canvas = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    if bbox is None:
        return canvas
    max_width = frame_size * 0.88
    max_height = frame_size * 0.88
    scale = min(max_width / max(1, cutout.width), max_height / max(1, cutout.height))
    resized = cutout.resize((max(1, int(cutout.width * scale)), max(1, int(cutout.height * scale))), Image.Resampling.LANCZOS)
    x = int(frame_size * 0.5 - resized.width * 0.5)
    y = int(frame_size * 0.91 - resized.height)
    canvas.alpha_composite(resized, (x, y))
    return canvas


def rebuild_indexes(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    artifact_entries: list[dict[str, Any]] = []
    godot_entries: list[dict[str, Any]] = []
    for entry in entries:
        slug = Path(entry["file"]).stem
        artifact_frames = [ARTIFACT_ROOT / slug / "actions" / "attack" / f"attack_{index:02d}.png" for index in range(FRAME_COUNT)]
        strip_path = ARTIFACT_ROOT / slug / "sheets" / f"{entry['id']}_attack_strip.png"
        manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
        godot_frames = [GODOT_BOSS_ROOT / slug / "frames" / "attack" / f"attack_{index:02d}.png" for index in range(FRAME_COUNT)]
        source_dir = ARTIFACT_ROOT / slug / "source"
        alpha_source = source_dir / "generated_attack_strip_alpha.png"
        chroma_source = source_dir / "generated_attack_strip_chroma.png"
        raw_path = first_existing(
            [
                alpha_source,
                chroma_source,
                source_dir / "generated_attack_strip_source.png",
            ]
        )
        if not all(path.exists() for path in artifact_frames + godot_frames) or not strip_path.exists() or not manifest_path.exists():
            continue
        artifact_entry = build_entry(entry, raw_path, artifact_frames, strip_path, manifest_path, godot_frames)
        artifact_entries.append(artifact_entry)
        godot_entries.append(
            {
                "id": entry["id"],
                "slug": slug,
                "name_zh": entry.get("name_zh", ""),
                "name_en": entry.get("name_en", ""),
                "manifest": to_res_path(manifest_path),
                "attack": [to_res_path(path) for path in godot_frames],
            }
        )

    (ARTIFACT_ROOT / "boss_attack_keyframes_index.json").write_text(
        json.dumps(
            {
                "count": len(artifact_entries),
                "frames_per_boss": FRAME_COUNT,
                "frame_size": [ARTIFACT_FRAME_SIZE, ARTIFACT_FRAME_SIZE],
                "godot_frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
                "note": "Generated non-pixel hand-painted attack keyframes imported from AI sprite strips.",
                "entries": artifact_entries,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    GODOT_BOSS_ROOT.mkdir(parents=True, exist_ok=True)
    (GODOT_BOSS_ROOT / "boss_attack_keyframes_index.json").write_text(
        json.dumps(
            {
                "count": len(godot_entries),
                "frames_per_boss": FRAME_COUNT,
                "frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
                "note": "Godot-ready generated non-pixel boss attack keyframe manifests.",
                "entries": godot_entries,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return artifact_entries


def build_entry(
    entry: dict[str, Any],
    raw_path: Path | None,
    artifact_frames: list[Path],
    strip_path: Path,
    manifest_path: Path,
    godot_frames: list[Path],
) -> dict[str, Any]:
    slug = Path(entry["file"]).stem
    return {
        "id": entry["id"],
        "slug": slug,
        "name_zh": entry.get("name_zh", ""),
        "name_en": entry.get("name_en", ""),
        "source": normalize_rel(ROOT / entry["file"]),
        "source_generated_strip": normalize_rel(raw_path) if raw_path and raw_path.exists() else "",
        "frames": [normalize_rel(path) for path in artifact_frames],
        "strip": normalize_rel(strip_path),
        "godot_manifest": to_res_path(manifest_path),
        "godot_frames": [to_res_path(path) for path in godot_frames],
    }


def first_existing(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.exists():
            return path
    return None


def render_strip(frames: list[Image.Image], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    strip = Image.new("RGBA", (ARTIFACT_FRAME_SIZE * len(frames), ARTIFACT_FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * ARTIFACT_FRAME_SIZE, 0))
    strip.save(out_path)


def render_contact_sheet(entries: list[dict[str, Any]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    thumb = 140
    label_w = 260
    row_h = 168
    margin = 18
    width = label_w + FRAME_COUNT * thumb + margin * 2
    height = max(margin * 2 + row_h * len(entries), 220)
    sheet = Image.new("RGB", (width, height), (10, 11, 16))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(22)
    small_font = load_font(15)
    for row_index, entry in enumerate(entries):
        y = margin + row_index * row_h
        draw.rectangle((margin // 2, y - 6, width - margin // 2, y + row_h - 8), outline=(43, 47, 58), width=1)
        draw.text((margin, y + 16), f"{entry['id']} {entry['name_zh']}", fill=(235, 225, 188), font=title_font)
        draw.text((margin, y + 48), str(entry["name_en"]), fill=(165, 178, 194), font=small_font)
        for frame_index, rel in enumerate(entry["frames"]):
            frame = Image.open(ROOT / rel).convert("RGBA").resize((thumb, thumb), Image.Resampling.LANCZOS)
            bg = Image.new("RGBA", (thumb, thumb), (18, 19, 25, 255))
            bg.alpha_composite(frame)
            x = label_w + frame_index * thumb
            sheet.paste(bg.convert("RGB"), (x, y + 10))
            draw.text((x + 8, y + thumb + 12), f"attack_{frame_index:02d}", fill=(132, 143, 158), font=small_font)
    sheet.save(out_path)


def render_preview_html(entries: list[dict[str, Any]], out_path: Path) -> None:
    lines = [
        "<!doctype html>",
        "<meta charset=\"utf-8\">",
        "<title>Boss Attack Keyframes</title>",
        "<style>",
        "body{margin:0;background:#0b0c10;color:#e8dfc5;font-family:Arial,'Microsoft YaHei',sans-serif}",
        "main{max-width:1180px;margin:0 auto;padding:24px}",
        "section{border-bottom:1px solid #303441;padding:18px 0}",
        "h1{font-size:26px;margin:0 0 12px}",
        "h2{font-size:18px;margin:0 0 10px;color:#e8dfc5}",
        "img{max-width:100%;height:auto;background:#11131a}",
        ".meta{color:#aeb9c8;font-size:13px;margin-bottom:8px}",
        "</style>",
        "<main>",
        "<h1>20 Boss Attack Keyframes</h1>",
    ]
    for entry in entries:
        strip_path = ROOT / entry["strip"]
        src = strip_path.relative_to(out_path.parent).as_posix() if strip_path.is_relative_to(out_path.parent) else entry["strip"]
        lines.extend(
            [
                "<section>",
                f"<h2>{entry['id']} {entry['name_zh']} / {entry['name_en']}</h2>",
                f"<div class=\"meta\">{entry['strip']}</div>",
                f"<img src=\"{src}?v={strip_path.stat().st_mtime_ns}\" alt=\"{entry['id']} attack strip\">",
                "</section>",
            ]
        )
    lines.extend(["</main>", ""])
    out_path.write_text("\n".join(lines), encoding="utf-8")


def trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    padding = 6
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def normalize_rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def to_res_path(path: Path) -> str:
    return "res://" + path.resolve().relative_to(GODOT_ROOT).as_posix()


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


if __name__ == "__main__":
    main()
