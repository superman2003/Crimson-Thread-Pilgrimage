from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
GODOT_BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes"
CONCEPT_INDEX = ROOT / "artifacts" / "boss_concepts" / "boss_concepts_index.json"
SPECIAL_INDEX = ARTIFACT_ROOT / "boss_special_attack_keyframes_index.json"

FRAME_SIZE = 256
TARGET_BOTTOM = 246
WALK_FRAME_COUNT = 16
ATTACK_FRAME_COUNT = 8
PREVIEW_GAP = 34


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
    Motion(0, -1.5, 1.00, 1.00, -9.0, 0.0, 0.03, 0.00, 0.0),
    Motion(0, -0.8, 1.02, 0.99, -7.0, -1.0, 0.04, 0.00, 2.0),
    Motion(1, 0.4, 1.04, 0.97, -4.0, -2.0, 0.05, 0.00, 4.0),
    Motion(1, 1.0, 1.02, 0.99, -1.0, -2.0, 0.04, 0.00, 5.0),
    Motion(2, 1.2, 1.00, 1.00, 3.0, -1.0, 0.04, 0.00, 3.0),
    Motion(2, 0.5, 0.99, 1.01, 6.0, 0.0, 0.03, 0.00, 0.0),
    Motion(3, -0.5, 1.02, 0.99, 8.0, -1.0, 0.04, 0.00, 2.0),
    Motion(3, -1.2, 1.04, 0.97, 6.0, -2.0, 0.05, 0.00, 4.0),
    Motion(4, -1.0, 1.01, 0.99, 2.0, -2.0, 0.04, 0.00, 5.0),
    Motion(4, 0.1, 0.99, 1.01, -1.0, -1.0, 0.03, 0.00, 3.0),
    Motion(5, 0.9, 1.02, 0.99, -5.0, 0.0, 0.04, 0.00, 0.0),
    Motion(5, 1.5, 1.04, 0.97, -8.0, -1.0, 0.05, 0.00, 2.0),
    Motion(4, 0.7, 1.01, 1.00, -5.0, -2.0, 0.04, 0.00, 4.0),
    Motion(3, -0.3, 0.99, 1.01, -1.0, -2.0, 0.03, 0.00, 5.0),
    Motion(1, -1.1, 1.02, 0.99, 4.0, -1.0, 0.04, 0.00, 3.0),
    Motion(0, -0.5, 1.00, 1.00, 8.0, 0.0, 0.03, 0.00, 0.0),
]

ATTACK_MOTIONS = [
    Motion(0, -2.5, 1.00, 1.00, -2.0, 0.0, 0.06, 0.00),
    Motion(0, -7.0, 1.04, 0.96, 4.0, -3.0, 0.11, 0.12),
    Motion(1, -9.5, 1.08, 0.93, 9.0, -5.0, 0.16, 0.30),
    Motion(2, -4.0, 1.13, 0.89, 17.0, -2.0, 0.25, 0.62),
    Motion(3, 5.0, 1.16, 0.86, 24.0, 1.0, 0.36, 1.00),
    Motion(4, 7.5, 1.10, 0.92, 17.0, 2.0, 0.24, 0.56),
    Motion(5, 2.5, 1.04, 0.97, 7.0, 1.0, 0.12, 0.20),
    Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.05, 0.00),
]

SPECIAL_MOTIONS = {
    1: [
        Motion(0, -2.0, 1.00, 1.00, 0.0, 0.0, 0.09, 0.00),
        Motion(1, -5.5, 1.04, 0.96, 2.0, -5.0, 0.15, 0.18),
        Motion(2, -8.0, 1.08, 0.93, 6.0, -8.0, 0.24, 0.38),
        Motion(3, 0.0, 1.15, 0.88, 0.0, 0.0, 0.36, 1.00),
        Motion(4, 5.5, 1.12, 0.91, -2.0, 2.0, 0.28, 0.72),
        Motion(4, 8.0, 1.07, 0.95, 2.0, 1.0, 0.20, 0.40),
        Motion(5, 2.0, 1.03, 0.98, 1.0, 0.0, 0.11, 0.14),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.05, 0.00),
    ],
    2: [
        Motion(0, -4.0, 1.00, 1.00, -8.0, -1.0, 0.09, 0.00),
        Motion(1, -10.0, 1.05, 0.95, -15.0, -10.0, 0.17, 0.18),
        Motion(2, -12.0, 1.10, 0.91, -10.0, -20.0, 0.26, 0.40),
        Motion(2, -5.0, 1.12, 0.89, 7.0, -9.0, 0.32, 0.65),
        Motion(4, 8.0, 1.17, 0.85, 25.0, 3.0, 0.38, 1.00),
        Motion(4, 5.0, 1.11, 0.91, 18.0, 2.0, 0.26, 0.58),
        Motion(5, 1.0, 1.04, 0.97, 8.0, 1.0, 0.13, 0.20),
        Motion(5, -1.0, 1.00, 1.00, 0.0, 0.0, 0.05, 0.00),
    ],
    3: [
        Motion(0, -1.0, 1.00, 1.00, 0.0, 0.0, 0.09, 0.00),
        Motion(1, -4.0, 1.03, 0.97, 4.0, -8.0, 0.17, 0.22),
        Motion(2, -6.5, 1.08, 0.93, 8.0, -12.0, 0.26, 0.44),
        Motion(3, 0.0, 1.13, 0.89, 0.0, -3.0, 0.40, 0.95),
        Motion(3, 4.0, 1.15, 0.87, 11.0, 2.0, 0.32, 1.00),
        Motion(4, 7.0, 1.10, 0.92, 8.0, 3.0, 0.24, 0.60),
        Motion(5, 2.0, 1.04, 0.97, 4.0, 1.0, 0.13, 0.20),
        Motion(5, 0.0, 1.00, 1.00, 0.0, 0.0, 0.05, 0.00),
    ],
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Build directional walk and attack runtime frames for bosses.")
    parser.add_argument("--start", type=int, default=5, help="First boss number to process.")
    parser.add_argument("--end", type=int, default=20, help="Last boss number to process.")
    parser.add_argument("--force", action="store_true", help="Rebuild even if directional frames already exist.")
    args = parser.parse_args()

    concepts = read_json(CONCEPT_INDEX)["entries"]
    special_entries = {entry["id"]: entry for entry in read_json(SPECIAL_INDEX)["entries"]}
    selected = [
        entry
        for entry in concepts
        if args.start <= boss_number(str(entry["id"])) <= args.end
    ]
    built: list[str] = []
    skipped: list[str] = []
    total_frames = 0
    for concept in selected:
        boss_id = str(concept["id"])
        special = special_entries.get(boss_id)
        if special is None:
            raise RuntimeError(f"{boss_id} missing from {SPECIAL_INDEX}")
        if not args.force and directional_complete(str(special["slug"])):
            skipped.append(boss_id)
            continue
        frame_count = build_boss(concept, special)
        total_frames += frame_count
        built.append(boss_id)

    print(
        "BUILD_BOSS_DIRECTIONAL_ASSETS_PASS "
        f"built={len(built)} skipped={len(skipped)} frames={total_frames} "
        f"range=boss_{args.start:02d}..boss_{args.end:02d} "
        f"preview_gap={PREVIEW_GAP} built_ids={','.join(built)}"
    )


def build_boss(concept: dict[str, Any], special: dict[str, Any]) -> int:
    boss_id = str(concept["id"])
    slug = str(special["slug"])
    boss_root = GODOT_BOSS_ROOT / slug
    frames_root = boss_root / "frames"
    artifact_root = ARTIFACT_ROOT / slug
    manifest_path = boss_root / "manifest.json"
    manifest = read_json(manifest_path)
    attacks = [attack for attack in special.get("attacks", []) if isinstance(attack, dict)]
    action_names = ["walk", "attack", *[str(attack["id"]) for attack in attacks]]
    action_metadata = {str(attack["id"]): attack for attack in attacks}
    sources = load_sources(frames_root, action_names)
    accent = pick_boss_accent(manifest, action_metadata)
    rows: list[tuple[str, list[Image.Image]]] = []

    for action_name in action_names:
        if action_name == "walk":
            motions = WALK_MOTIONS
        elif action_name == "attack":
            motions = ATTACK_MOTIONS
        else:
            motions = SPECIAL_MOTIONS.get(special_index(action_name), ATTACK_MOTIONS)
        right_frames = build_action(action_name, sources[action_name], motions, "right", accent, boss_id)
        left_frames = build_action(action_name, sources[action_name], motions, "left", accent, boss_id)
        write_action_frames(frames_root, action_name, "right", right_frames)
        write_action_frames(frames_root, action_name, "left", left_frames)
        rows.append((f"{action_name}_left", left_frames))
        rows.append((f"{action_name}_right", right_frames))

    preview_path = artifact_root / f"{boss_id}_directional_contact.png"
    update_manifest(manifest, concept, special, action_names, attacks, preview_path, accent)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    render_contact_sheet(rows, preview_path, boss_id, str(special["name_zh"]), str(special["name_en"]))
    return WALK_FRAME_COUNT * 2 + ATTACK_FRAME_COUNT * (1 + len(attacks)) * 2


def load_sources(frames_root: Path, action_names: list[str]) -> dict[str, list[Image.Image]]:
    result: dict[str, list[Image.Image]] = {}
    for action_name in action_names:
        source_name = "attack" if action_name == "walk" else action_name
        source_dir = frames_root / source_name
        frames = [Image.open(path).convert("RGBA") for path in sorted(source_dir.glob("attack_*.png"))]
        if len(frames) < 6:
            raise FileNotFoundError(f"{source_dir} needs at least 6 source frames")
        result[action_name] = [prepare_source_frame(frame, strict=action_name == "walk") for frame in frames[:6]]
    return result


def prepare_source_frame(image: Image.Image, strict: bool) -> Image.Image:
    cleaned = remove_green_spill(image)
    cleaned = remove_tiny_alpha_components(cleaned, min_pixels=240 if strict else 145)
    cleaned = ImageEnhance.Contrast(cleaned).enhance(1.08)
    cleaned = ImageEnhance.Sharpness(cleaned).enhance(1.12)
    return cleaned


def build_action(
    action_name: str,
    sources: list[Image.Image],
    motions: list[Motion],
    direction_name: str,
    accent: tuple[int, int, int, int],
    boss_id: str,
) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index, motion in enumerate(motions):
        source = sources[min(motion.source_index, len(sources) - 1)]
        if direction_name == "left":
            source = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        seed = stable_seed(f"{boss_id}:{action_name}", index)
        frames.append(compose_frame(source, motion, action_name, direction_name, accent, seed))
    return frames


def compose_frame(
    source: Image.Image,
    motion: Motion,
    action_name: str,
    direction_name: str,
    accent: tuple[int, int, int, int],
    seed: int,
) -> Image.Image:
    rng = random.Random(seed)
    direction = 1 if direction_name == "right" else -1
    subject = normalize_subject(source, motion, direction)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))

    if motion.glow > 0.0:
        canvas.alpha_composite(make_body_afterimage(subject, accent, motion.glow, -direction), (0, 0))
    if action_name == "walk":
        canvas.alpha_composite(make_step_vfx(motion, direction, accent), (0, 0))
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
    canvas = remove_tiny_alpha_components(canvas, min_pixels=34)
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


def make_action_vfx(
    action_name: str,
    amount: float,
    direction: int,
    accent: tuple[int, int, int, int],
    rng: random.Random,
) -> Image.Image:
    variant = special_index(action_name)
    if variant == 1:
        return make_wave_vfx(amount, direction, accent, rng)
    if variant == 2:
        return make_charge_vfx(amount, direction, accent, rng)
    if variant == 3:
        return make_burst_vfx(amount, direction, accent, rng)
    return make_slash_vfx(amount, direction, accent, rng)


def make_slash_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(150 * amount)
    width = max(3, int(10 * amount))
    if direction > 0:
        boxes = [(78, 54, 258, 218), (96, 74, 242, 202)]
        start, end = -64, 70
        spark_x = (122, 226)
    else:
        boxes = [(-2, 54, 178, 218), (14, 74, 160, 202)]
        start, end = 110, 244
        spark_x = (30, 134)
    draw.arc(boxes[0], start=start, end=end, fill=(accent[0], accent[1], accent[2], max(22, alpha // 2)), width=width)
    draw.arc(boxes[1], start=start + 8, end=end - 8, fill=(245, 238, 216, alpha), width=max(2, width // 3))
    add_sparks(draw, rng, spark_x, (72, 214), direction, alpha, amount, accent)
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def make_wave_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(142 * amount)
    origin_x = 128 - direction * 14
    for index in range(max(4, int(9 * amount))):
        y = 88 + index * 12 + rng.randint(-5, 5)
        x0 = origin_x - direction * rng.randint(8, 22)
        x1 = origin_x + direction * rng.randint(54, 112)
        draw.line((x0, y, x1, y + rng.randint(-15, 15)), fill=(accent[0], accent[1], accent[2], max(24, alpha - index * 6)), width=2)
    draw.arc((44, 74, 218, 232), start=200 if direction > 0 else -20, end=338 if direction > 0 else 118, fill=(230, 246, 246, max(20, alpha // 2)), width=5)
    return layer.filter(ImageFilter.GaussianBlur(0.28))


def make_charge_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(150 * amount)
    for index in range(max(5, int(12 * amount))):
        x0 = 42 + index * 9 if direction > 0 else 214 - index * 9
        y0 = 82 + rng.randint(-14, 88)
        x1 = x0 + direction * rng.randint(34, 92)
        draw.line((x0, y0, x1, y0 + rng.randint(-10, 10)), fill=(accent[0], accent[1], accent[2], max(22, alpha - index * 4)), width=1 + (index % 2))
    edge_x = 226 if direction > 0 else 30
    draw.ellipse((edge_x - 9, 124, edge_x + 9, 142), outline=(242, 238, 216, alpha), width=2)
    return layer.filter(ImageFilter.GaussianBlur(0.22))


def make_burst_vfx(amount: float, direction: int, accent: tuple[int, int, int, int], rng: random.Random) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = int(138 * amount)
    cx = 128 + direction * 10
    cy = 132
    for radius, width in ((56, 5), (78, 4), (100, 2)):
        draw.arc((cx - radius, cy - radius, cx + radius, cy + radius), 18, 332, fill=(accent[0], accent[1], accent[2], max(22, alpha)), width=width)
    for _ in range(max(5, int(13 * amount))):
        angle = rng.uniform(-0.25 * math.pi, 1.25 * math.pi)
        distance = rng.uniform(34, 102) * amount
        x = int(cx + math.cos(angle) * distance)
        y = int(cy + math.sin(angle) * distance)
        draw.line((cx, cy, x, y), fill=(accent[0], accent[1], accent[2], max(20, alpha // 3)), width=1)
    return layer.filter(ImageFilter.GaussianBlur(0.30))


def add_sparks(
    draw: ImageDraw.ImageDraw,
    rng: random.Random,
    x_range: tuple[int, int],
    y_range: tuple[int, int],
    direction: int,
    alpha: int,
    amount: float,
    accent: tuple[int, int, int, int],
) -> None:
    for _ in range(max(3, int(9 * amount))):
        x = rng.randint(*x_range)
        y = rng.randint(*y_range)
        draw.line((x, y, x + direction * rng.randint(8, 22), y + rng.randint(-8, 8)), fill=(accent[0], accent[1], accent[2], max(24, alpha)), width=1)


def make_step_vfx(motion: Motion, direction: int, accent: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    if motion.step_lift <= 0:
        return layer
    draw = ImageDraw.Draw(layer)
    cx = int(128 + direction * motion.dx * 0.55)
    y = TARGET_BOTTOM - 5
    for index in range(4):
        x = cx + direction * (index * 7 - 9)
        draw.line((x, y, x + direction * 9, y - 5 - index), fill=(accent[0], accent[1], accent[2], 48), width=1)
    return layer.filter(ImageFilter.GaussianBlur(0.22))


def add_ground_shadow(canvas: Image.Image, direction: int, motion: Motion) -> Image.Image:
    shadow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    cx = 128 + int(direction * motion.dx * 0.32)
    draw.ellipse((cx - 62, TARGET_BOTTOM - 8, cx + 64, TARGET_BOTTOM + 6), fill=(16, 12, 16, 34))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4.0))
    shadow.alpha_composite(canvas, (0, 0))
    return shadow


def update_manifest(
    manifest: dict[str, Any],
    concept: dict[str, Any],
    special: dict[str, Any],
    action_names: list[str],
    attacks: list[dict[str, Any]],
    preview_path: Path,
    accent: tuple[int, int, int, int],
) -> None:
    boss_id = str(concept["id"])
    slug = str(special["slug"])
    old_by_name = {
        animation.get("name"): animation
        for animation in manifest.get("animations", [])
        if isinstance(animation, dict) and isinstance(animation.get("name"), str)
    }
    animation_specs = build_animation_specs(slug, action_names)
    spec_names = {spec[0] for spec in animation_specs}
    directional_names = directional_animation_names(action_names)
    animations = [{"name": name, "fps": fps, "loop": loop, "frames": frames} for name, fps, loop, frames in animation_specs]
    for name, animation in old_by_name.items():
        if name in spec_names or name in directional_names:
            continue
        animations.append(animation)

    manifest["id"] = boss_id
    manifest["name_zh"] = str(special.get("name_zh") or concept.get("name_zh") or manifest.get("name_zh", ""))
    manifest["name_en"] = str(special.get("name_en") or concept.get("name_en") or manifest.get("name_en", ""))
    manifest["source_concept"] = str(special.get("source") or concept.get("file", ""))
    manifest["frame_size"] = [FRAME_SIZE, FRAME_SIZE]
    manifest["anchor"] = "bottom-center"
    manifest["style"] = "high quality dark fantasy non-pixel hand-painted generated directional keyframes"
    manifest["directional_asset_pack"] = {
        "source": f"generated runtime frames derived from six-frame boss keyframes, {slug}",
        "source_facing": "right",
        "walk_frames_per_direction": WALK_FRAME_COUNT,
        "attack_frames_per_direction": ATTACK_FRAME_COUNT,
        "directional_animations": sorted(directional_names),
        "alpha_bottom_target": TARGET_BOTTOM,
        "cutout_cleanup": "green spill removal plus small detached alpha component filtering",
        "frame_file_prefix": "attack",
        "preview_gap_px": PREVIEW_GAP,
        "contact_sheet": preview_path.relative_to(ROOT).as_posix(),
        "accent_rgba": list(accent),
    }
    manifest["animations"] = animations
    update_attack_metadata(manifest, slug, attacks)


def build_animation_specs(slug: str, action_names: list[str]) -> list[tuple[str, float, bool, list[str]]]:
    specs: list[tuple[str, float, bool, list[str]]] = [
        ("idle", 6.0, True, frame_paths(slug, "walk_right", [0, 4, 8, 12])),
        ("walk", 9.0, True, frame_paths(slug, "walk_right", range(WALK_FRAME_COUNT))),
        ("attack", 12.0, False, frame_paths(slug, "attack_right", range(ATTACK_FRAME_COUNT))),
        ("hurt", 10.0, False, frame_paths(slug, "attack_right", [5])),
        ("death", 8.0, False, frame_paths(slug, "attack_right", [7])),
    ]
    for action_name in action_names:
        if action_name in ("walk", "attack"):
            continue
        specs.append((action_name, 12.0, False, frame_paths(slug, f"{action_name}_right", range(ATTACK_FRAME_COUNT))))
    for action_name in action_names:
        count = WALK_FRAME_COUNT if action_name == "walk" else ATTACK_FRAME_COUNT
        fps = 9.0 if action_name == "walk" else 12.0
        loop = action_name == "walk"
        for direction_name in ("left", "right"):
            name = f"{action_name}_{direction_name}"
            specs.append((name, fps, loop, frame_paths(slug, name, range(count))))
    return specs


def update_attack_metadata(manifest: dict[str, Any], slug: str, special_attacks: list[dict[str, Any]]) -> None:
    metadata = {str(attack["id"]): attack for attack in special_attacks}
    old_attacks = [
        attack
        for attack in manifest.get("attacks", [])
        if isinstance(attack, dict) and str(attack.get("id", "")) not in metadata
    ]
    attacks: list[dict[str, Any]] = list(old_attacks)
    for attack_id, source in metadata.items():
        frame_list = frame_paths(slug, f"{attack_id}_right", range(ATTACK_FRAME_COUNT))
        record = {
            "id": attack_id,
            "name": attack_id,
            "name_zh": source.get("name_zh", attack_id),
            "name_en": source.get("name_en", attack_id),
            "fps": source.get("fps", 12.0),
            "loop": source.get("loop", False),
            "frames": frame_list,
            "hit_frame_index": min(int(source.get("hit_frame_index", 3)), ATTACK_FRAME_COUNT - 1),
            "hitbox": source.get("hitbox", {"shape": "rect", "size": [156, 96], "offset": [76, -44]}),
            "vfx": source.get("vfx", []),
            "source_generated_strip": source.get("source_generated_strip", ""),
            "directional_frames": {
                "left": frame_paths(slug, f"{attack_id}_left", range(ATTACK_FRAME_COUNT)),
                "right": frame_list,
            },
        }
        attacks.append(record)
    manifest["attacks"] = attacks


def write_action_frames(frames_root: Path, action_name: str, direction_name: str, frames: list[Image.Image]) -> None:
    out_dir = frames_root / f"{action_name}_{direction_name}"
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("attack_*.png"):
        stale.unlink()
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"attack_{index:02d}.png")


def render_contact_sheet(
    rows: list[tuple[str, list[Image.Image]]],
    out_path: Path,
    boss_id: str,
    name_zh: str,
    name_en: str,
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cell = 128
    label_w = 280
    row_h = 178
    margin = 28
    max_frames = max(len(frames) for _, frames in rows)
    width = label_w + max_frames * cell + max(0, max_frames - 1) * PREVIEW_GAP + margin * 2
    height = margin * 2 + 42 + len(rows) * row_h
    sheet = Image.new("RGB", (width, height), (13, 12, 15))
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, margin), f"{boss_id} {name_zh} / {name_en}", fill=(238, 226, 204))
    draw.text((margin, margin + 20), f"preview_gap={PREVIEW_GAP}px, walk=16f, attacks=8f per direction", fill=(160, 150, 144))
    y_offset = margin + 42
    for row_index, (name, frames) in enumerate(rows):
        y = y_offset + row_index * row_h
        draw.text((margin, y + 14), name, fill=(232, 228, 205))
        draw.text((margin, y + 40), f"{len(frames)} frames", fill=(151, 145, 128))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (cell, cell), (22, 21, 24, 255))
            thumb.alpha_composite(frame.resize((cell, cell), Image.Resampling.LANCZOS), (0, 0))
            x = label_w + frame_index * (cell + PREVIEW_GAP)
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), outline=(68, 64, 70))
            draw.text((x + 5, y + cell + 7), f"{frame_index:02d}", fill=(148, 144, 150))
    sheet.save(out_path)


def pick_boss_accent(manifest: dict[str, Any], action_metadata: dict[str, dict[str, Any]]) -> tuple[int, int, int, int]:
    for attack in action_metadata.values():
        for item in attack.get("vfx", []):
            if isinstance(item, dict):
                color = parse_hex_color(str(item.get("color", "")))
                if color:
                    return color
    pack = manifest.get("directional_asset_pack", {})
    if isinstance(pack, dict) and isinstance(pack.get("accent_rgba"), list) and len(pack["accent_rgba"]) >= 3:
        r, g, b = [int(value) for value in pack["accent_rgba"][:3]]
        return (r, g, b, 255)
    return (190, 174, 112, 255)


def parse_hex_color(value: str) -> tuple[int, int, int, int] | None:
    value = value.strip()
    if not value.startswith("#") or len(value) != 7:
        return None
    try:
        return (int(value[1:3], 16), int(value[3:5], 16), int(value[5:7], 16), 255)
    except ValueError:
        return None


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


def frame_paths(slug: str, animation_name: str, indexes: Any) -> list[str]:
    return [
        f"res://assets/sprites/bosses/{slug}/frames/{animation_name}/attack_{int(index):02d}.png"
        for index in indexes
    ]


def directional_animation_names(action_names: list[str]) -> set[str]:
    names: set[str] = set()
    for action_name in action_names:
        names.add(f"{action_name}_left")
        names.add(f"{action_name}_right")
    return names


def directional_complete(slug: str) -> bool:
    manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
    if not manifest_path.exists():
        return False
    try:
        manifest = read_json(manifest_path)
    except Exception:
        return False
    pack = manifest.get("directional_asset_pack", {})
    return (
        isinstance(pack, dict)
        and int(pack.get("walk_frames_per_direction", 0)) >= WALK_FRAME_COUNT
        and int(pack.get("attack_frames_per_direction", 0)) >= ATTACK_FRAME_COUNT
    )


def special_index(action_name: str) -> int:
    suffix = action_name.rsplit("_", 1)[-1]
    return int(suffix) if suffix.isdigit() else 0


def boss_number(boss_id: str) -> int:
    return int(boss_id.split("_", 1)[1])


def stable_seed(action_name: str, index: int) -> int:
    value = 2166136261
    for byte in f"{action_name}:{index}".encode("utf-8"):
        value ^= byte
        value = (value * 16777619) & 0xFFFFFFFF
    return value


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
