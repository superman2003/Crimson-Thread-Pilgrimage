from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
REGISTRY_PATH = GODOT_ROOT / "assets" / "sprites" / "bosses" / "boss_asset_registry.json"

GODOT_FRAME_SIZE = (256, 256)
WALK_FRAME_COUNT = 16
ATTACK_FRAME_COUNT = 8
RUNTIME_ANIMATIONS = ["idle", "walk", "attack", "hurt", "death"]


def main() -> None:
    registry = read_json(REGISTRY_PATH)
    errors: list[str] = []
    entries = registry.get("entries", [])
    if registry.get("count") != 20:
        errors.append(f"registry count must be 20, got {registry.get('count')!r}")
    if not isinstance(entries, list) or len(entries) != 20:
        errors.append(f"registry entries must contain 20 bosses, got {len(entries) if isinstance(entries, list) else 'invalid'}")

    checked_core_frames = 0
    demo_refs = 0
    seen_ids: set[str] = set()
    seen_manifests: set[str] = set()
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            errors.append("registry entry must be an object")
            continue
        checked_core_frames += validate_entry(entry, seen_ids, seen_manifests, errors)
        demo_refs += len(entry.get("godot_demo_refs", [])) if isinstance(entry.get("godot_demo_refs", []), list) else 0

    if errors:
        raise AssertionError("VALIDATE_BOSS_ASSET_REGISTRY_FAIL\n" + "\n".join(f"- {error}" for error in errors))

    print(
        "VALIDATE_BOSS_ASSET_REGISTRY_PASS "
        f"bosses={len(entries)} core_frames={checked_core_frames} demo_refs={demo_refs} "
        f"registry={rel(REGISTRY_PATH)}"
    )


def validate_entry(
    entry: dict[str, Any],
    seen_ids: set[str],
    seen_manifests: set[str],
    errors: list[str],
) -> int:
    boss_id = str(entry.get("id", ""))
    manifest_res = str(entry.get("manifest", ""))
    if not boss_id:
        errors.append("registry entry missing id")
        return 0
    if boss_id in seen_ids:
        errors.append(f"{boss_id} duplicate registry id")
    seen_ids.add(boss_id)
    if manifest_res in seen_manifests:
        errors.append(f"{boss_id} duplicate manifest path: {manifest_res}")
    seen_manifests.add(manifest_res)

    manifest_path = res_to_path(manifest_res, errors, f"{boss_id} manifest")
    if manifest_path is None or not manifest_path.exists():
        errors.append(f"{boss_id} missing manifest: {manifest_res}")
        return 0
    manifest = read_json_safe(manifest_path, errors, f"{boss_id} manifest")
    if not isinstance(manifest, dict):
        return 0
    if manifest.get("id") != boss_id:
        errors.append(f"{boss_id} manifest id mismatch: {manifest.get('id')!r}")
    if manifest.get("frame_size") != [256, 256]:
        errors.append(f"{boss_id} frame_size must be [256, 256]")
    if len(manifest.get("attacks", [])) != 3:
        errors.append(f"{boss_id} attacks[] must contain 3 special attacks")

    contact_sheet = str(entry.get("contact_sheet", ""))
    if contact_sheet and not (ROOT / contact_sheet).exists():
        errors.append(f"{boss_id} missing contact sheet: {contact_sheet}")

    animations = index_animations(manifest, boss_id, errors)
    for animation_name in RUNTIME_ANIMATIONS:
        frames = animation_frames(animations, animation_name, boss_id, errors)
        if frames is not None and not frames:
            errors.append(f"{boss_id}/{animation_name} runtime animation is empty")

    checked_core_frames = 0
    required = entry.get("required_directional_animations", [])
    if not isinstance(required, list):
        errors.append(f"{boss_id} required_directional_animations must be a list")
        required = []
    for animation_name_value in required:
        animation_name = str(animation_name_value)
        minimum = WALK_FRAME_COUNT if animation_name.startswith("walk_") else ATTACK_FRAME_COUNT
        frames = animation_frames(animations, animation_name, boss_id, errors)
        if frames is None:
            continue
        if len(frames) < minimum:
            errors.append(f"{boss_id}/{animation_name} must have >= {minimum} frames, got {len(frames)}")
        for frame_res in frames[:minimum]:
            check_image(frame_res, f"{boss_id}/{animation_name}", errors)
            checked_core_frames += 1

    expected_attack_ids = [f"{boss_id}_atk_{index:02d}" for index in range(1, 4)]
    manifest_attack_ids = [str(attack.get("id", "")) for attack in manifest.get("attacks", []) if isinstance(attack, dict)]
    for attack_id in expected_attack_ids:
        if attack_id not in manifest_attack_ids:
            errors.append(f"{boss_id} missing attack record {attack_id}")

    return checked_core_frames


def index_animations(manifest: dict[str, Any], boss_id: str, errors: list[str]) -> dict[str, dict[str, Any]]:
    animations: dict[str, dict[str, Any]] = {}
    animations_value = manifest.get("animations", [])
    if not isinstance(animations_value, list):
        errors.append(f"{boss_id} animations must be a list")
        return animations
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
    return [str(frame).strip() for frame in frames if str(frame).strip()]


def check_image(frame_res: str, label: str, errors: list[str]) -> None:
    path = res_to_path(frame_res.strip(), errors, label)
    if path is None:
        return
    if not path.exists():
        errors.append(f"{label} missing frame: {frame_res}")
        return
    try:
        with Image.open(path) as image:
            if image.format != "PNG":
                errors.append(f"{label} frame must be PNG: {frame_res}")
            if image.size != GODOT_FRAME_SIZE:
                errors.append(f"{label} frame must be 256x256, got {image.size}: {frame_res}")
            if image.convert("RGBA").getchannel("A").getbbox() is None:
                errors.append(f"{label} frame alpha is empty: {frame_res}")
    except OSError as exc:
        errors.append(f"{label} cannot open frame {frame_res}: {exc}")


def res_to_path(path: str, errors: list[str], label: str) -> Path | None:
    if not path.startswith("res://"):
        errors.append(f"{label} is not a Godot res path: {path!r}")
        return None
    return GODOT_ROOT / path.removeprefix("res://")


def read_json_safe(path: Path, errors: list[str], label: str) -> Any:
    try:
        return read_json(path)
    except json.JSONDecodeError as exc:
        errors.append(f"{label} invalid json: {exc}")
    except OSError as exc:
        errors.append(f"{label} cannot read json: {exc}")
    return None


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


if __name__ == "__main__":
    main()
