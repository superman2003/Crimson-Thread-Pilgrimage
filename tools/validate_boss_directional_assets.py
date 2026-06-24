from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
GODOT_BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"
CONCEPT_INDEX = ROOT / "artifacts" / "boss_concepts" / "boss_concepts_index.json"
SPECIAL_INDEX = ROOT / "artifacts" / "boss_keyframes" / "boss_special_attack_keyframes_index.json"

GODOT_FRAME_SIZE = (256, 256)
WALK_FRAME_COUNT = 16
ATTACK_FRAME_COUNT = 8
ALPHA_BOTTOM_MIN = 242
ALPHA_BOTTOM_MAX = 248
MIN_PREVIEW_GAP = 30
MIN_VISIBLE_PIXELS = 1800
MAX_LARGE_EXTRA_COMPONENTS = 12
MAX_EXTRA_COMPONENT_PIXELS = 9000


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate directional boss runtime assets.")
    parser.add_argument("--start", type=int, default=2, help="First boss number to validate.")
    parser.add_argument("--end", type=int, default=20, help="Last boss number to validate.")
    args = parser.parse_args()

    concepts = read_json(CONCEPT_INDEX)["entries"]
    special_entries = {entry["id"]: entry for entry in read_json(SPECIAL_INDEX)["entries"]}
    errors: list[str] = []
    checked_frames = 0
    checked_animations = 0
    checked_bosses = 0
    preview_paths: list[str] = []

    for concept in concepts:
        boss_id = str(concept["id"])
        number = int(boss_id.split("_", 1)[1])
        if number < args.start or number > args.end:
            continue
        special = special_entries.get(boss_id)
        if special is None:
            errors.append(f"{boss_id} missing from special attack index")
            continue
        result = validate_boss(concept, special, errors)
        checked_frames += result["frames"]
        checked_animations += result["animations"]
        checked_bosses += 1
        if result["preview"]:
            preview_paths.append(result["preview"])

    if errors:
        raise AssertionError("BOSS_DIRECTIONAL_ASSET_VALIDATION_FAIL\n" + "\n".join(f"- {error}" for error in errors))

    print(
        "BOSS_DIRECTIONAL_ASSET_VALIDATION_PASS "
        f"bosses={checked_bosses} animations={checked_animations} frames={checked_frames} "
        f"range=boss_{args.start:02d}..boss_{args.end:02d} "
        f"preview_gap_min={MIN_PREVIEW_GAP} previews={len(preview_paths)}"
    )


def validate_boss(concept: dict[str, Any], special: dict[str, Any], errors: list[str]) -> dict[str, Any]:
    boss_id = str(concept["id"])
    slug = str(special["slug"])
    manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
    manifest = read_json_safe(manifest_path, errors)
    if not isinstance(manifest, dict):
        return {"frames": 0, "animations": 0, "preview": ""}

    if manifest.get("id") != boss_id:
        errors.append(f"{boss_id} manifest id mismatch: {manifest.get('id')!r}")
    if str(manifest.get("name_en", "")) != str(special.get("name_en", "")):
        errors.append(f"{boss_id} manifest name_en mismatch")
    if slug not in str(manifest.get("source_concept", "")):
        errors.append(f"{boss_id} source_concept must include slug {slug}")
    if manifest.get("frame_size") != [256, 256]:
        errors.append(f"{boss_id} frame_size must be [256, 256]")

    pack = manifest.get("directional_asset_pack", {})
    if not isinstance(pack, dict):
        errors.append(f"{boss_id} missing directional_asset_pack")
        pack = {}
    if int(pack.get("walk_frames_per_direction", 0)) < WALK_FRAME_COUNT:
        errors.append(f"{boss_id} walk_frames_per_direction must be >= {WALK_FRAME_COUNT}")
    if int(pack.get("attack_frames_per_direction", 0)) < ATTACK_FRAME_COUNT:
        errors.append(f"{boss_id} attack_frames_per_direction must be >= {ATTACK_FRAME_COUNT}")
    if int(pack.get("preview_gap_px", 0)) < MIN_PREVIEW_GAP:
        errors.append(f"{boss_id} preview_gap_px must be >= {MIN_PREVIEW_GAP}")
    preview = str(pack.get("contact_sheet", ""))
    if preview:
        preview_path = ROOT / preview
        if not preview_path.exists():
            errors.append(f"{boss_id} missing contact sheet: {preview}")
    else:
        errors.append(f"{boss_id} missing contact sheet path")

    animations = index_animations(manifest, boss_id, errors)
    action_names = ["walk", "attack", *[attack["id"] for attack in special.get("attacks", [])]]
    checked_frames = 0
    checked_animations = 0
    for action_name in action_names:
        min_count = WALK_FRAME_COUNT if action_name == "walk" else ATTACK_FRAME_COUNT
        for direction in ("left", "right"):
            animation_name = f"{action_name}_{direction}"
            frames = animation_frames(animations, animation_name, boss_id, errors)
            if frames is None:
                continue
            if len(frames) < min_count:
                errors.append(f"{boss_id}/{animation_name} must have >= {min_count} frames, got {len(frames)}")
            checked_animations += 1
            for index, frame_path in enumerate(frames[:min_count]):
                check_frame(frame_path, f"{boss_id}/{animation_name}[{index}]", errors)
                checked_frames += 1

    for runtime_name in ["idle", "walk", "attack", "hurt", "death"]:
        frames = animation_frames(animations, runtime_name, boss_id, errors)
        if frames is not None and not frames:
            errors.append(f"{boss_id}/{runtime_name} must not be empty")
    for attack in special.get("attacks", []):
        attack_id = str(attack["id"])
        frames = animation_frames(animations, attack_id, boss_id, errors)
        if frames is not None and len(frames) < ATTACK_FRAME_COUNT:
            errors.append(f"{boss_id}/{attack_id} runtime animation must have >= {ATTACK_FRAME_COUNT} frames")
        attack_record = next((item for item in manifest.get("attacks", []) if item.get("id") == attack_id), None)
        if not isinstance(attack_record, dict):
            errors.append(f"{boss_id} attacks[] missing {attack_id}")
            continue
        directional = attack_record.get("directional_frames", {})
        if not isinstance(directional, dict):
            errors.append(f"{boss_id}/{attack_id} missing directional_frames")
            continue
        for direction in ("left", "right"):
            frames_value = directional.get(direction, [])
            if not isinstance(frames_value, list) or len(frames_value) < ATTACK_FRAME_COUNT:
                errors.append(f"{boss_id}/{attack_id} directional_frames.{direction} must have >= {ATTACK_FRAME_COUNT} frames")

    return {"frames": checked_frames, "animations": checked_animations, "preview": preview}


def index_animations(manifest: dict[str, Any], boss_id: str, errors: list[str]) -> dict[str, dict[str, Any]]:
    animations_value = manifest.get("animations", [])
    if not isinstance(animations_value, list):
        errors.append(f"{boss_id} animations must be a list")
        return {}
    animations: dict[str, dict[str, Any]] = {}
    for index, animation in enumerate(animations_value):
        if not isinstance(animation, dict):
            errors.append(f"{boss_id} animations[{index}] must be an object")
            continue
        name = animation.get("name")
        if not isinstance(name, str) or not name:
            errors.append(f"{boss_id} animations[{index}] missing name")
            continue
        if name in animations:
            errors.append(f"{boss_id} duplicate animation: {name}")
        animations[name] = animation
    return animations


def animation_frames(
    animations: dict[str, dict[str, Any]],
    animation_name: str,
    boss_id: str,
    errors: list[str],
) -> list[str] | None:
    animation = animations.get(animation_name)
    if animation is None:
        errors.append(f"{boss_id} missing animation: {animation_name}")
        return None
    frames = animation.get("frames", [])
    if not isinstance(frames, list):
        errors.append(f"{boss_id}/{animation_name} frames must be a list")
        return None
    frame_paths: list[str] = []
    for index, frame in enumerate(frames):
        if not isinstance(frame, str) or not frame:
            errors.append(f"{boss_id}/{animation_name}[{index}] must be a non-empty res:// path")
            continue
        frame_paths.append(frame)
    return frame_paths


def check_frame(frame_res_path: str, label: str, errors: list[str]) -> None:
    try:
        frame_path = res_to_path(frame_res_path)
    except ValueError as exc:
        errors.append(f"{label}: {exc}")
        return
    if not frame_path.exists():
        errors.append(f"{label} missing png: {frame_path}")
        return
    try:
        with Image.open(frame_path) as image:
            if image.format != "PNG":
                errors.append(f"{label} must be PNG, got {image.format!r}")
            if image.size != GODOT_FRAME_SIZE:
                errors.append(f"{label} must be 256x256, got {image.size}")
            if image.mode != "RGBA":
                errors.append(f"{label} must be RGBA, got {image.mode!r}")
            rgba = image.convert("RGBA")
            alpha = rgba.getchannel("A")
            bbox = alpha.point(lambda value: 255 if value > 5 else 0).getbbox()
            if bbox is None:
                errors.append(f"{label} alpha bbox is empty")
                return
            bottom = int(bbox[3])
            if bottom < ALPHA_BOTTOM_MIN or bottom > ALPHA_BOTTOM_MAX:
                errors.append(f"{label} alpha bottom must be {ALPHA_BOTTOM_MIN}-{ALPHA_BOTTOM_MAX}, got {bottom}")
            visible = sum(1 for _, _, _, a in rgba.getdata() if a > 24)
            if visible < MIN_VISIBLE_PIXELS:
                errors.append(f"{label} visible pixels too low: {visible}")
            extras = large_extra_alpha_components(rgba)
            if len(extras) > MAX_LARGE_EXTRA_COMPONENTS:
                errors.append(f"{label} has too many detached alpha components: {extras[:6]}")
            too_large = [component for component in extras if component[0] > MAX_EXTRA_COMPONENT_PIXELS]
            if too_large:
                errors.append(f"{label} has large detached alpha components: {too_large[:4]}")
    except OSError as exc:
        errors.append(f"{label} cannot open image {frame_path}: {exc}")


def large_extra_alpha_components(image: Image.Image) -> list[tuple[int, tuple[int, int, int, int]]]:
    binary = image.getchannel("A").point(lambda value: 255 if value > 24 else 0)
    pixels = binary.load()
    width, height = binary.size
    visited: set[tuple[int, int]] = set()
    components: list[tuple[int, tuple[int, int, int, int]]] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in visited:
                continue
            stack = [(x, y)]
            visited.add((x, y))
            count = 0
            min_x = max_x = x
            min_y = max_y = y
            while stack:
                px, py = stack.pop()
                count += 1
                min_x = min(min_x, px)
                max_x = max(max_x, px + 1)
                min_y = min(min_y, py)
                max_y = max(max_y, py + 1)
                for nx in (px - 1, px, px + 1):
                    for ny in (py - 1, py, py + 1):
                        if nx == px and ny == py:
                            continue
                        if nx < 0 or ny < 0 or nx >= width or ny >= height:
                            continue
                        if pixels[nx, ny] == 0 or (nx, ny) in visited:
                            continue
                        visited.add((nx, ny))
                        stack.append((nx, ny))
            if count > 80:
                components.append((count, (min_x, min_y, max_x, max_y)))
    components.sort(reverse=True)
    return components[1:]


def read_json_safe(path: Path, errors: list[str]) -> Any:
    if not path.exists():
        errors.append(f"missing json: {path}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid json {path}: {exc}")
        return None


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def res_to_path(path: str) -> Path:
    if not path.startswith("res://"):
        raise ValueError(f"not a Godot res path: {path}")
    return GODOT_ROOT / path.removeprefix("res://")


if __name__ == "__main__":
    main()
