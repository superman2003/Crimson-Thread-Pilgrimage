from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS_ID = "boss_04"
BOSS_NAME = "boss_04_copperroot_bishop"
BOSS_EN = "Copperroot Bishop"
BOSS_MANIFEST = GODOT_ROOT / "assets" / "sprites" / "bosses" / BOSS_NAME / "manifest.json"
REQUIRED_BASE_ANIMATIONS = [
    "walk",
    "attack",
    "boss_04_atk_01",
    "boss_04_atk_02",
    "boss_04_atk_03",
]
MIN_FRAME_COUNTS = {
    "walk": 16,
    "attack": 8,
    "boss_04_atk_01": 8,
    "boss_04_atk_02": 8,
    "boss_04_atk_03": 8,
}
GODOT_FRAME_SIZE = (256, 256)
ALPHA_BOTTOM_MIN = 242
ALPHA_BOTTOM_MAX = 248
MAX_LARGE_EXTRA_COMPONENTS = 4
MAX_EXTRA_COMPONENT_PIXELS = 1800
MIN_VISIBLE_PIXELS = 2200


def main() -> None:
    errors: list[str] = []
    manifest = read_json(BOSS_MANIFEST, errors)
    if not isinstance(manifest, dict):
        raise AssertionError("\n".join(errors) if errors else "invalid manifest")

    validate_manifest_identity(manifest, errors)
    animations = index_animations(manifest, errors)
    checked_frames = 0
    checked_animations = 0
    alpha_bottoms: dict[str, list[int]] = {}
    visible_totals: dict[str, int] = {}

    for base_name in REQUIRED_BASE_ANIMATIONS:
        left_name = f"{base_name}_left"
        right_name = f"{base_name}_right"
        left_frames = animation_frames(animations, left_name, errors)
        right_frames = animation_frames(animations, right_name, errors)
        min_frame_count = MIN_FRAME_COUNTS[base_name]

        if left_frames is not None and len(left_frames) < min_frame_count:
            errors.append(f"{left_name} must have >= {min_frame_count} frames, got {len(left_frames)}")
        if right_frames is not None and len(right_frames) < min_frame_count:
            errors.append(f"{right_name} must have >= {min_frame_count} frames, got {len(right_frames)}")
        if left_frames is not None and right_frames is not None and len(left_frames) != len(right_frames):
            errors.append(f"{base_name} left/right frame count mismatch: left={len(left_frames)} right={len(right_frames)}")

        for animation_name, frame_paths in ((left_name, left_frames), (right_name, right_frames)):
            if frame_paths is None:
                continue
            checked_animations += 1
            bottoms: list[int] = []
            visible_total = 0
            for index, frame_path in enumerate(frame_paths):
                bottom, visible_pixels = check_frame(frame_path, f"{animation_name}[{index}]", errors)
                if bottom is not None:
                    bottoms.append(bottom)
                    checked_frames += 1
                visible_total += visible_pixels
            alpha_bottoms[animation_name] = bottoms
            visible_totals[animation_name] = visible_total

    validate_base_runtime_animations(animations, errors)

    if errors:
        raise AssertionError("BOSS04_DIRECTIONAL_ASSET_VALIDATION_FAIL\n" + "\n".join(f"- {error}" for error in errors))

    bottom_summary = ", ".join(
        f"{name}={min(bottoms)}..{max(bottoms)}"
        for name, bottoms in sorted(alpha_bottoms.items())
        if bottoms
    )
    visible_summary = ", ".join(
        f"{name}={visible}"
        for name, visible in sorted(visible_totals.items())
        if visible
    )
    print(
        "BOSS04_DIRECTIONAL_ASSET_VALIDATION_PASS "
        f"animations={checked_animations} frames={checked_frames} "
        f"manifest={normalize_rel(BOSS_MANIFEST)} "
        f"alpha_bottoms={bottom_summary} visible_pixels={visible_summary}"
    )


def validate_manifest_identity(manifest: dict[str, Any], errors: list[str]) -> None:
    if manifest.get("id") != BOSS_ID:
        errors.append(f"manifest id must be {BOSS_ID}, got {manifest.get('id')!r}")
    if BOSS_EN not in str(manifest.get("name_en", "")):
        errors.append(f"manifest name_en must be {BOSS_EN}")
    if BOSS_NAME not in str(manifest.get("source_concept", "")):
        errors.append("manifest source_concept must point at the high-fidelity boss_04 concept")
    if manifest.get("frame_size") != [256, 256]:
        errors.append(f"manifest frame_size must be [256, 256], got {manifest.get('frame_size')!r}")
    pack = manifest.get("directional_asset_pack", {})
    if not isinstance(pack, dict):
        errors.append("manifest missing directional_asset_pack")
        return
    if int(pack.get("walk_frames_per_direction", 0)) < 16:
        errors.append("directional_asset_pack walk_frames_per_direction must be >= 16")
    if int(pack.get("attack_frames_per_direction", 0)) < 8:
        errors.append("directional_asset_pack attack_frames_per_direction must be >= 8")


def validate_base_runtime_animations(animations: dict[str, dict[str, Any]], errors: list[str]) -> None:
    for animation_name in ["idle", "walk", "attack", "hurt", "death"]:
        frames = animation_frames(animations, animation_name, errors)
        if frames is not None and len(frames) <= 0:
            errors.append(f"{animation_name} must have at least one frame")


def read_json(path: Path, errors: list[str]) -> Any:
    if not path.exists():
        errors.append(f"missing json: {path}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid json {path}: {exc}")
        return None


def index_animations(manifest: dict[str, Any], errors: list[str]) -> dict[str, dict[str, Any]]:
    animations_value = manifest.get("animations", [])
    if not isinstance(animations_value, list):
        errors.append("manifest animations must be a list")
        return {}
    animations: dict[str, dict[str, Any]] = {}
    for index, animation in enumerate(animations_value):
        if not isinstance(animation, dict):
            errors.append(f"animations[{index}] must be an object")
            continue
        name = animation.get("name")
        if not isinstance(name, str) or not name:
            errors.append(f"animations[{index}] missing name")
            continue
        if name in animations:
            errors.append(f"duplicate animation name: {name}")
        animations[name] = animation
    return animations


def animation_frames(
    animations: dict[str, dict[str, Any]],
    animation_name: str,
    errors: list[str],
) -> list[str] | None:
    animation = animations.get(animation_name)
    if animation is None:
        errors.append(f"manifest missing required animation: {animation_name}")
        return None
    frames = animation.get("frames", [])
    if not isinstance(frames, list):
        errors.append(f"{animation_name} frames must be a list")
        return None
    frame_paths: list[str] = []
    for index, frame in enumerate(frames):
        if not isinstance(frame, str) or not frame:
            errors.append(f"{animation_name}[{index}] must be a non-empty res:// path")
            continue
        frame_paths.append(frame)
    return frame_paths


def check_frame(frame_res_path: str, label: str, errors: list[str]) -> tuple[int | None, int]:
    try:
        frame_path = res_to_path(frame_res_path)
    except ValueError as exc:
        errors.append(f"{label}: {exc}")
        return None, 0
    if not frame_path.exists():
        errors.append(f"{label} missing png: {frame_path}")
        return None, 0
    try:
        with Image.open(frame_path) as image:
            if image.format != "PNG":
                errors.append(f"{label} must be PNG, got {image.format!r}: {frame_path}")
            if image.size != GODOT_FRAME_SIZE:
                errors.append(f"{label} must be 256x256, got {image.size}: {frame_path}")
            rgba = image.convert("RGBA")
            if image.mode != "RGBA":
                errors.append(f"{label} must be RGBA, got {image.mode!r}: {frame_path}")
            bbox = rgba.getchannel("A").point(lambda value: 255 if value > 5 else 0).getbbox()
            if bbox is None:
                errors.append(f"{label} alpha bbox is empty: {frame_path}")
                return None, 0
            alpha_bottom = int(bbox[3])
            if alpha_bottom < ALPHA_BOTTOM_MIN or alpha_bottom > ALPHA_BOTTOM_MAX:
                errors.append(
                    f"{label} alpha bbox bottom must be {ALPHA_BOTTOM_MIN}-{ALPHA_BOTTOM_MAX}, "
                    f"got bottom={alpha_bottom}: {frame_path}"
                )
            visible_pixels = count_visible_pixels(rgba)
            if visible_pixels < MIN_VISIBLE_PIXELS:
                errors.append(f"{label} visible pixels too low ({visible_pixels}): {frame_path}")
            extras = large_extra_alpha_components(rgba)
            if len(extras) > MAX_LARGE_EXTRA_COMPONENTS:
                errors.append(f"{label} has too many detached alpha components {extras[:6]}: {frame_path}")
            too_large = [component for component in extras if component[0] > MAX_EXTRA_COMPONENT_PIXELS]
            if too_large:
                errors.append(f"{label} has large detached alpha components {too_large[:4]}: {frame_path}")
            return alpha_bottom, visible_pixels
    except OSError as exc:
        errors.append(f"{label} cannot open image {frame_path}: {exc}")
        return None, 0


def count_visible_pixels(image: Image.Image) -> int:
    return sum(1 for _, _, _, a in image.getdata() if a > 24)


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


def res_to_path(path: str) -> Path:
    if not path.startswith("res://"):
        raise ValueError(f"not a Godot res path: {path}")
    return GODOT_ROOT / path.removeprefix("res://")


def normalize_rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


if __name__ == "__main__":
    main()
