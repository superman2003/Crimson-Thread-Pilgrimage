from __future__ import annotations

import json
import math
import random
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from statistics import median
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CONCEPT_INDEX = ROOT / "artifacts" / "boss_concepts" / "boss_concepts_index.json"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes"
GODOT_ROOT = ROOT / "godot"
GODOT_BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"

FRAME_COUNT = 6
ARTIFACT_FRAME_SIZE = 384
GODOT_FRAME_SIZE = 256


@dataclass(frozen=True)
class Pose:
    name: str
    rotation: float
    scale_x: float
    scale_y: float
    dx_ratio: float
    dy_ratio: float
    trail: float
    slash: float
    sparks: int


POSES = [
    Pose("anticipation", -5.0, 1.03, 0.96, -0.035, 0.014, 0.00, 0.00, 0),
    Pose("windup", -9.0, 1.08, 0.92, -0.060, -0.006, 0.18, 0.10, 5),
    Pose("release", 3.0, 1.12, 0.90, 0.040, -0.020, 0.38, 0.50, 11),
    Pose("impact", 8.0, 1.16, 0.88, 0.090, -0.010, 0.55, 1.00, 18),
    Pose("follow_through", 4.0, 1.08, 0.94, 0.050, 0.012, 0.28, 0.45, 8),
    Pose("recover", -2.0, 1.00, 1.00, 0.000, 0.000, 0.06, 0.00, 2),
]


def main() -> None:
    if not CONCEPT_INDEX.exists():
        raise FileNotFoundError(CONCEPT_INDEX)

    entries = json.loads(CONCEPT_INDEX.read_text(encoding="utf-8")).get("entries", [])
    if len(entries) != 20:
        raise RuntimeError(f"Expected 20 boss concepts, got {len(entries)}")

    ARTIFACT_ROOT.mkdir(parents=True, exist_ok=True)
    GODOT_BOSS_ROOT.mkdir(parents=True, exist_ok=True)

    artifact_entries: list[dict[str, Any]] = []
    godot_entries: list[dict[str, Any]] = []
    contact_rows: list[dict[str, Any]] = []

    for ordinal, entry in enumerate(entries, start=1):
        built = build_boss_keyframes(ordinal, entry)
        artifact_entries.append(built["artifact_entry"])
        godot_entries.append(built["godot_entry"])
        contact_rows.append(built["contact_row"])

    artifact_index = {
        "count": len(artifact_entries),
        "frames_per_boss": FRAME_COUNT,
        "frame_size": [ARTIFACT_FRAME_SIZE, ARTIFACT_FRAME_SIZE],
        "godot_frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
        "note": "Generated attack keyframes derived from the approved original boss concept images.",
        "entries": artifact_entries,
    }
    artifact_index_path = ARTIFACT_ROOT / "boss_attack_keyframes_index.json"
    artifact_index_path.write_text(json.dumps(artifact_index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    godot_index = {
        "count": len(godot_entries),
        "frames_per_boss": FRAME_COUNT,
        "frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
        "note": "Godot-ready generated boss attack keyframe manifests.",
        "entries": godot_entries,
    }
    godot_index_path = GODOT_BOSS_ROOT / "boss_attack_keyframes_index.json"
    godot_index_path.write_text(json.dumps(godot_index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    contact_path = ARTIFACT_ROOT / "contact_sheets" / "boss_attack_keyframes_contact_sheet.png"
    render_contact_sheet(contact_rows, contact_path)
    preview_path = ARTIFACT_ROOT / "preview.html"
    render_preview_html(artifact_entries, preview_path)

    total_frames = len(entries) * FRAME_COUNT
    print(
        "BOSS_ATTACK_KEYFRAMES_PASS "
        f"bosses={len(entries)} frames={total_frames} "
        f"artifact_index={artifact_index_path.as_posix()} "
        f"godot_index={godot_index_path.as_posix()} "
        f"contact_sheet={contact_path.as_posix()}"
    )


def build_boss_keyframes(ordinal: int, entry: dict[str, Any]) -> dict[str, Any]:
    boss_id = str(entry["id"])
    concept_path = ROOT / str(entry["file"])
    if not concept_path.exists():
        raise FileNotFoundError(concept_path)

    slug = concept_path.stem
    artifact_frames_dir = ARTIFACT_ROOT / slug / "actions" / "attack"
    artifact_sheets_dir = ARTIFACT_ROOT / slug / "sheets"
    godot_frames_dir = GODOT_BOSS_ROOT / slug / "frames" / "attack"
    artifact_frames_dir.mkdir(parents=True, exist_ok=True)
    artifact_sheets_dir.mkdir(parents=True, exist_ok=True)
    godot_frames_dir.mkdir(parents=True, exist_ok=True)

    source = load_concept(concept_path)
    cutout = extract_subject_cutout(source)
    accent = choose_accent_color(cutout, fallback=accent_fallback(ordinal))

    artifact_frames: list[Path] = []
    godot_frames: list[Path] = []
    contact_frames: list[Image.Image] = []
    metrics: list[dict[str, Any]] = []

    for frame_index, pose in enumerate(POSES):
        artifact_frame = render_attack_frame(cutout, accent, pose, ARTIFACT_FRAME_SIZE, seed=ordinal * 100 + frame_index)
        artifact_path = artifact_frames_dir / f"attack_{frame_index:02d}.png"
        artifact_frame.save(artifact_path)
        artifact_frames.append(artifact_path)
        contact_frames.append(artifact_frame.copy())

        godot_frame = render_attack_frame(cutout, accent, pose, GODOT_FRAME_SIZE, seed=ordinal * 100 + frame_index)
        godot_path = godot_frames_dir / f"attack_{frame_index:02d}.png"
        godot_frame.save(godot_path)
        godot_frames.append(godot_path)
        metrics.append(frame_metrics(godot_frame))

    strip_path = artifact_sheets_dir / f"{boss_id}_attack_strip.png"
    render_strip(contact_frames, strip_path)

    manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
    godot_frame_paths = [to_res_path(path) for path in godot_frames]
    manifest = {
        "id": boss_id,
        "name_zh": entry.get("name_zh", ""),
        "name_en": entry.get("name_en", ""),
        "source_concept": normalize_rel(concept_path),
        "frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
        "anchor": "bottom-center",
        "style": "high quality dark fantasy non-pixel generated keyframes",
        "animations": [
            {"name": "idle", "fps": 6.0, "loop": True, "frames": [godot_frame_paths[0], godot_frame_paths[1]]},
            {"name": "walk", "fps": 6.0, "loop": True, "frames": [godot_frame_paths[0], godot_frame_paths[1], godot_frame_paths[5]]},
            {"name": "attack", "fps": 12.0, "loop": False, "frames": godot_frame_paths},
            {"name": "hurt", "fps": 10.0, "loop": False, "frames": [godot_frame_paths[4]]},
            {"name": "death", "fps": 8.0, "loop": False, "frames": [godot_frame_paths[5]]},
        ],
        "quality_checks": {
            "frame_count": FRAME_COUNT,
            "transparent_corners": all(metric["transparent_corners"] for metric in metrics),
            "non_empty_frames": all(metric["alpha_bbox"] is not None for metric in metrics),
        },
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    artifact_entry = {
        "id": boss_id,
        "slug": slug,
        "name_zh": entry.get("name_zh", ""),
        "name_en": entry.get("name_en", ""),
        "source": normalize_rel(concept_path),
        "frames": [normalize_rel(path) for path in artifact_frames],
        "strip": normalize_rel(strip_path),
        "godot_manifest": to_res_path(manifest_path),
        "godot_frames": [to_res_path(path) for path in godot_frames],
        "accent_rgba": accent,
    }
    godot_entry = {
        "id": boss_id,
        "slug": slug,
        "name_zh": entry.get("name_zh", ""),
        "name_en": entry.get("name_en", ""),
        "manifest": to_res_path(manifest_path),
        "attack": godot_frame_paths,
    }
    return {
        "artifact_entry": artifact_entry,
        "godot_entry": godot_entry,
        "contact_row": {
            "id": boss_id,
            "name_zh": entry.get("name_zh", ""),
            "name_en": entry.get("name_en", ""),
            "frames": contact_frames,
        },
    }


def load_concept(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    longest = max(image.size)
    if longest > 920:
        scale = 920 / longest
        image = image.resize((int(image.width * scale), int(image.height * scale)), Image.Resampling.LANCZOS)
    return image


def extract_subject_cutout(image: Image.Image) -> Image.Image:
    alpha = grabcut_alpha(image)
    if alpha is None:
        background = estimate_background(image)
        alpha = build_subject_alpha(image, background)
    alpha = alpha.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(0.65))
    hard = alpha.point(lambda value: 255 if value > 26 else 0)
    bbox = hard.getbbox()
    if bbox is None:
        return fallback_center_cutout(image)

    padded = pad_box(bbox, image.size, 20)
    cutout = image.crop(padded)
    cutout_alpha = alpha.crop(padded)
    cutout.putalpha(cutout_alpha)
    cutout = trim_alpha(cutout)
    cutout = ImageEnhance.Contrast(cutout).enhance(1.08)
    cutout = ImageEnhance.Sharpness(cutout).enhance(1.18)
    return cutout


def grabcut_alpha(image: Image.Image) -> Image.Image | None:
    try:
        import cv2
        import numpy as np
    except Exception:
        return None

    rgb = image.convert("RGB")
    source = np.array(rgb)
    bgr = cv2.cvtColor(source, cv2.COLOR_RGB2BGR)
    height, width = bgr.shape[:2]
    if width < 64 or height < 64:
        return None
    mask = np.zeros((height, width), np.uint8)
    rect = (
        int(width * 0.035),
        int(height * 0.025),
        int(width * 0.93),
        int(height * 0.94),
    )
    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)
    try:
        cv2.grabCut(bgr, mask, rect, bgd_model, fgd_model, 5, cv2.GC_INIT_WITH_RECT)
    except Exception:
        return None
    foreground = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 1, 0).astype("uint8")
    coverage = float(foreground.sum()) / float(width * height)
    if coverage < 0.015 or coverage > 0.86:
        return None

    num, labels, stats, _centroids = cv2.connectedComponentsWithStats(foreground, 8)
    clean = np.zeros_like(foreground)
    min_area = max(45, int(width * height * 0.00022))
    for component in range(1, num):
        area = int(stats[component, cv2.CC_STAT_AREA])
        if area >= min_area:
            clean[labels == component] = 1
    if clean.sum() == 0:
        return None
    kernel = np.ones((3, 3), np.uint8)
    clean = cv2.morphologyEx(clean, cv2.MORPH_CLOSE, kernel, iterations=1)
    detail = recover_connected_detail(source, clean, cv2, np)
    protected = np.maximum(clean, detail)
    protected = cv2.dilate(protected, np.ones((2, 2), np.uint8), iterations=1)
    protected = cv2.morphologyEx(protected, cv2.MORPH_CLOSE, kernel, iterations=1)
    alpha = soft_alpha_from_detail_score(source, protected, clean, cv2, np)
    alpha = cv2.GaussianBlur(alpha, (3, 3), 0)
    return Image.fromarray(alpha, mode="L")


def recover_connected_detail(source: Any, base_mask: Any, cv2: Any, np: Any) -> Any:
    height, width = base_mask.shape[:2]
    background = np.array(estimate_background(Image.fromarray(source, mode="RGB")), dtype=np.float32)
    rgb = source.astype(np.float32)
    dist = np.sqrt(np.sum((rgb - background) ** 2, axis=2))
    max_channel = rgb.max(axis=2)
    min_channel = rgb.min(axis=2)
    saturation = max_channel - min_channel
    luma_map = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    bg_luma = float(background[0] * 0.2126 + background[1] * 0.7152 + background[2] * 0.0722)
    score = dist * 1.02 + saturation * 0.30 + np.maximum(0, np.abs(luma_map - bg_luma) - 3.0) * 0.34
    candidates = (score > 24.0).astype("uint8")
    border_guard = max(3, int(min(width, height) * 0.015))
    candidates[:border_guard, :] = 0
    candidates[-border_guard:, :] = 0
    candidates[:, :border_guard] = 0
    candidates[:, -border_guard:] = 0

    reach = cv2.dilate(base_mask, np.ones((19, 19), np.uint8), iterations=1)
    num, labels, stats, _centroids = cv2.connectedComponentsWithStats(candidates, 8)
    detail = np.zeros_like(base_mask)
    min_area = max(8, int(width * height * 0.00002))
    max_area = int(width * height * 0.22)
    for component in range(1, num):
        area = int(stats[component, cv2.CC_STAT_AREA])
        if area < min_area or area > max_area:
            continue
        component_mask = labels == component
        if np.any(reach[component_mask]):
            detail[component_mask] = 1
    return detail.astype("uint8")


def soft_alpha_from_detail_score(source: Any, mask: Any, base_mask: Any, cv2: Any, np: Any) -> Any:
    background = np.array(estimate_background(Image.fromarray(source, mode="RGB")), dtype=np.float32)
    rgb = source.astype(np.float32)
    dist = np.sqrt(np.sum((rgb - background) ** 2, axis=2))
    max_channel = rgb.max(axis=2)
    min_channel = rgb.min(axis=2)
    saturation = max_channel - min_channel
    luma_map = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    bg_luma = float(background[0] * 0.2126 + background[1] * 0.7152 + background[2] * 0.0722)
    score = dist * 1.08 + saturation * 0.38 + np.maximum(0, np.abs(luma_map - bg_luma) - 3.0) * 0.46

    gray = cv2.cvtColor(source, cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 32, 96)
    edges = cv2.dilate(edges, np.ones((2, 2), np.uint8), iterations=1)

    soft = np.clip((score - 20.0) / 58.0 * 255.0, 0, 255).astype("uint8")
    soft = np.maximum(soft, (edges * 0.72).astype("uint8"))
    alpha = np.where(mask > 0, soft, 0).astype("uint8")
    strong = (base_mask > 0) & (score > 43.0)
    alpha[strong] = np.maximum(alpha[strong], 214)
    very_strong = (mask > 0) & (score > 70.0)
    alpha[very_strong] = 255
    alpha[(mask > 0) & (alpha < 24)] = 0
    return alpha


def estimate_background(image: Image.Image) -> tuple[int, int, int]:
    pixels = image.convert("RGB").load()
    width, height = image.size
    samples: list[tuple[int, int, int]] = []
    step = max(1, min(width, height) // 80)
    for x in range(0, width, step):
        samples.append(pixels[x, 0])
        samples.append(pixels[x, height - 1])
    for y in range(0, height, step):
        samples.append(pixels[0, y])
        samples.append(pixels[width - 1, y])
    return tuple(int(median(channel)) for channel in zip(*samples))


def build_subject_alpha(image: Image.Image, background: tuple[int, int, int]) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    bg_luma = luma(background)
    src = rgb.load()
    raw = bytearray(width * height)
    background_walk = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            r, g, b = src[x, y]
            dist = math.sqrt((r - background[0]) ** 2 + (g - background[1]) ** 2 + (b - background[2]) ** 2)
            sat = max(r, g, b) - min(r, g, b)
            lum_diff = abs(luma((r, g, b)) - bg_luma)
            score = dist * 1.05 + sat * 0.34 + max(0.0, lum_diff - 4.0) * 0.40
            value = int(clamp((score - 30.0) / 76.0, 0.0, 1.0) * 255)
            index = y * width + x
            raw[index] = value
            if score < 92.0 or value < 126:
                background_walk[index] = 1

    connected_background = flood_connected_background(background_walk, width, height)
    result = bytearray(width * height)
    for index, value in enumerate(raw):
        if connected_background[index] or value < 22:
            result[index] = 0
        else:
            result[index] = value
    return Image.frombytes("L", (width, height), bytes(result))


def flood_connected_background(walkable: bytearray, width: int, height: int) -> bytearray:
    seen = bytearray(width * height)
    queue: deque[int] = deque()

    def push(index: int) -> None:
        if walkable[index] and not seen[index]:
            seen[index] = 1
            queue.append(index)

    for x in range(width):
        push(x)
        push((height - 1) * width + x)
    for y in range(height):
        push(y * width)
        push(y * width + width - 1)

    while queue:
        index = queue.popleft()
        x = index % width
        y = index // width
        if x > 0:
            push(index - 1)
        if x < width - 1:
            push(index + 1)
        if y > 0:
            push(index - width)
        if y < height - 1:
            push(index + width)
    return seen


def fallback_center_cutout(image: Image.Image) -> Image.Image:
    width, height = image.size
    box = (int(width * 0.12), int(height * 0.05), int(width * 0.88), int(height * 0.96))
    cutout = image.crop(box)
    alpha = Image.new("L", cutout.size, 255)
    cutout.putalpha(alpha)
    return cutout


def render_attack_frame(cutout: Image.Image, accent: tuple[int, int, int, int], pose: Pose, frame_size: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    canvas = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    body = prepare_body(cutout, frame_size, pose)
    x = int(frame_size * 0.5 - body.width * 0.5 + pose.dx_ratio * frame_size)
    y = int(frame_size * 0.90 - body.height + pose.dy_ratio * frame_size)

    if pose.trail > 0:
        for step in range(2, 0, -1):
            trail_alpha = pose.trail * (0.12 + 0.10 * step)
            trail = tint_image(body, accent, trail_alpha)
            canvas.alpha_composite(trail, (x - int(step * frame_size * 0.050), y + int(step * frame_size * 0.006)))

    shadow = make_ground_shadow(frame_size, accent, pose)
    canvas.alpha_composite(shadow, (0, 0))
    canvas.alpha_composite(body, (x, y))

    if pose.slash > 0:
        slash = make_slash_layer(frame_size, accent, pose.slash, rng)
        canvas.alpha_composite(slash, (0, 0))

    if pose.sparks > 0:
        sparks = make_sparks(frame_size, accent, pose.sparks, rng)
        canvas.alpha_composite(sparks, (0, 0))

    return canvas


def prepare_body(cutout: Image.Image, frame_size: int, pose: Pose) -> Image.Image:
    crop = trim_alpha(cutout)
    width, height = crop.size
    max_width = frame_size * 0.74
    max_height = frame_size * 0.84
    scale = min(max_width / max(1, width), max_height / max(1, height))
    next_size = (max(1, int(width * scale * pose.scale_x)), max(1, int(height * scale * pose.scale_y)))
    body = crop.resize(next_size, Image.Resampling.LANCZOS)
    if abs(pose.rotation) > 0.01:
        body = body.rotate(pose.rotation, resample=Image.Resampling.BICUBIC, expand=True)
    return trim_alpha(body)


def make_ground_shadow(frame_size: int, accent: tuple[int, int, int, int], pose: Pose) -> Image.Image:
    layer = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx = frame_size * (0.50 + pose.dx_ratio * 0.60)
    cy = frame_size * 0.91
    color = (accent[0], accent[1], accent[2], 18)
    draw.ellipse(
        (
            int(cx - frame_size * 0.22),
            int(cy - frame_size * 0.030),
            int(cx + frame_size * 0.24),
            int(cy + frame_size * 0.035),
        ),
        fill=color,
    )
    return layer.filter(ImageFilter.GaussianBlur(frame_size * 0.018))


def make_slash_layer(frame_size: int, accent: tuple[int, int, int, int], intensity: float, rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    base_alpha = int(190 * intensity)
    wide_alpha = int(80 * intensity)
    boxes = [
        (
            int(frame_size * 0.36),
            int(frame_size * 0.15),
            int(frame_size * 1.05),
            int(frame_size * 0.86),
        ),
        (
            int(frame_size * 0.42),
            int(frame_size * 0.25),
            int(frame_size * 1.00),
            int(frame_size * 0.76),
        ),
    ]
    draw.arc(boxes[0], start=-64, end=64, fill=(accent[0], accent[1], accent[2], wide_alpha), width=max(4, int(frame_size * 0.050)))
    draw.arc(boxes[1], start=-54, end=54, fill=(238, 232, 196, base_alpha), width=max(2, int(frame_size * 0.014)))
    for _ in range(5):
        x0 = int(frame_size * rng.uniform(0.62, 0.94))
        y0 = int(frame_size * rng.uniform(0.30, 0.66))
        x1 = x0 + int(frame_size * rng.uniform(0.06, 0.16))
        y1 = y0 + int(frame_size * rng.uniform(-0.06, 0.06))
        draw.line((x0, y0, x1, y1), fill=(accent[0], accent[1], accent[2], int(95 * intensity)), width=max(1, int(frame_size * 0.006)))
    glow = layer.filter(ImageFilter.GaussianBlur(frame_size * 0.008))
    glow.alpha_composite(layer)
    return glow


def make_sparks(frame_size: int, accent: tuple[int, int, int, int], count: int, rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(count):
        x = int(frame_size * rng.uniform(0.58, 0.94))
        y = int(frame_size * rng.uniform(0.20, 0.82))
        radius = max(1, int(frame_size * rng.uniform(0.004, 0.011)))
        alpha = rng.randint(90, 180)
        color = (accent[0], accent[1], accent[2], alpha)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
        if rng.random() > 0.45:
            draw.line((x - radius * 2, y, x + radius * 3, y - radius), fill=(240, 226, 180, alpha), width=max(1, radius // 2))
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def tint_image(image: Image.Image, color: tuple[int, int, int, int], alpha_multiplier: float) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: int(value * alpha_multiplier))
    tinted = Image.new("RGBA", image.size, (color[0], color[1], color[2], 0))
    tinted.putalpha(alpha)
    return tinted


def render_strip(frames: list[Image.Image], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    width = sum(frame.width for frame in frames)
    height = max(frame.height for frame in frames)
    strip = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    for frame in frames:
        strip.alpha_composite(frame, (x, 0))
        x += frame.width
    strip.save(out_path)


def render_contact_sheet(rows: list[dict[str, Any]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    thumb = 140
    label_w = 260
    row_h = 168
    margin = 18
    width = label_w + FRAME_COUNT * thumb + margin * 2
    height = margin * 2 + row_h * len(rows)
    sheet = Image.new("RGB", (width, height), (10, 11, 16))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(22)
    small_font = load_font(15)
    for row_index, row in enumerate(rows):
        y = margin + row_index * row_h
        draw.rectangle((margin // 2, y - 6, width - margin // 2, y + row_h - 8), outline=(43, 47, 58), width=1)
        draw.text((margin, y + 16), f"{row['id']} {row['name_zh']}", fill=(235, 225, 188), font=title_font)
        draw.text((margin, y + 48), str(row["name_en"]), fill=(165, 178, 194), font=small_font)
        for frame_index, frame in enumerate(row["frames"]):
            thumb_img = frame.resize((thumb, thumb), Image.Resampling.LANCZOS)
            bg = Image.new("RGBA", (thumb, thumb), (18, 19, 25, 255))
            bg.alpha_composite(thumb_img, (0, 0))
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
        strip = Path(entry["strip"]).as_posix()
        lines.extend(
            [
                "<section>",
                f"<h2>{entry['id']} {entry['name_zh']} / {entry['name_en']}</h2>",
                f"<div class=\"meta\">{entry['strip']}</div>",
                f"<img src=\"{relative_from(out_path.parent, ROOT / strip)}\" alt=\"{entry['id']} attack strip\">",
                "</section>",
            ]
        )
    lines.extend(["</main>", ""])
    out_path.write_text("\n".join(lines), encoding="utf-8")


def choose_accent_color(image: Image.Image, fallback: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    sample = image.resize((96, 96), Image.Resampling.BILINEAR).convert("RGBA")
    pixels: list[tuple[int, int, int, int, float]] = []
    for r, g, b, a in sample.getdata():
        if a < 48:
            continue
        sat = max(r, g, b) - min(r, g, b)
        lum = luma((r, g, b))
        if sat < 18 or lum < 24:
            continue
        score = sat * 1.5 + lum * 0.35
        pixels.append((r, g, b, a, score))
    if not pixels:
        return fallback
    pixels.sort(key=lambda item: item[4], reverse=True)
    top = pixels[: max(12, min(260, len(pixels) // 12))]
    r = int(sum(item[0] for item in top) / len(top))
    g = int(sum(item[1] for item in top) / len(top))
    b = int(sum(item[2] for item in top) / len(top))
    return boost_color((r, g, b, 255))


def accent_fallback(index: int) -> tuple[int, int, int, int]:
    palette = [
        (180, 206, 104, 255),
        (208, 54, 59, 255),
        (205, 174, 118, 255),
        (171, 132, 80, 255),
        (134, 206, 222, 255),
        (210, 177, 89, 255),
        (219, 154, 69, 255),
        (174, 180, 188, 255),
        (206, 54, 86, 255),
        (159, 118, 91, 255),
        (206, 184, 114, 255),
        (213, 144, 119, 255),
        (71, 176, 194, 255),
        (165, 201, 218, 255),
        (206, 72, 72, 255),
        (189, 146, 88, 255),
        (196, 231, 230, 255),
        (198, 163, 94, 255),
        (62, 189, 222, 255),
        (218, 49, 72, 255),
    ]
    return palette[(index - 1) % len(palette)]


def boost_color(color: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    r, g, b, a = color
    return (
        int(clamp(r * 1.18 + 18, 0, 255)),
        int(clamp(g * 1.18 + 18, 0, 255)),
        int(clamp(b * 1.18 + 18, 0, 255)),
        a,
    )


def frame_metrics(image: Image.Image) -> dict[str, Any]:
    alpha = image.getchannel("A")
    corners = [
        alpha.getpixel((0, 0)),
        alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    ]
    return {
        "size": [image.width, image.height],
        "alpha_bbox": alpha.point(lambda value: 255 if value > 5 else 0).getbbox(),
        "transparent_corners": all(value == 0 for value in corners),
    }


def trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").point(lambda value: 255 if value > 4 else 0).getbbox()
    if bbox is None:
        return image
    return image.crop(pad_box(bbox, image.size, 3))


def pad_box(box: tuple[int, int, int, int], size: tuple[int, int], padding: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = box
    width, height = size
    return (
        max(0, left - padding),
        max(0, top - padding),
        min(width, right + padding),
        min(height, bottom + padding),
    )


def luma(color: tuple[int, int, int]) -> float:
    return color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def normalize_rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def to_res_path(path: Path) -> str:
    return "res://" + path.relative_to(GODOT_ROOT).as_posix()


def relative_from(base: Path, target: Path) -> str:
    return target.relative_to(base).as_posix() if target.is_relative_to(base) else target.relative_to(ROOT).as_posix()


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


if __name__ == "__main__":
    main()
