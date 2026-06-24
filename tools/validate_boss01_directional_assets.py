from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS01_MANIFEST = GODOT_ROOT / "assets" / "sprites" / "bosses" / "boss_01_moss_bell_matriarch" / "manifest.json"
REQUIRED_BASE_ANIMATIONS = [
    "walk",
    "attack",
    "boss_01_atk_01",
    "boss_01_atk_02",
    "boss_01_atk_03",
]
MIN_FRAME_COUNT = 8
MIN_FRAME_COUNTS = {
    "walk": 16,
}
GODOT_FRAME_SIZE = (256, 256)
ALPHA_BOTTOM_MIN = 242
ALPHA_BOTTOM_MAX = 248
BOSS01_MAX_MAGENTA_RATIO = 0.001
BOSS01_MAX_MAGENTA_PIXELS_PER_FRAME = 96
BOSS01_MAX_WALK_EXTRA_COMPONENT_PIXELS = 180


def main() -> None:
    errors: list[str] = []
    manifest = read_json(BOSS01_MANIFEST, errors)
    if not isinstance(manifest, dict):
        raise AssertionError("\n".join(errors) if errors else f"invalid manifest: {BOSS01_MANIFEST}")

    animations = index_animations(manifest, errors)
    checked_frames = 0
    checked_animations = 0
    alpha_bottoms: dict[str, list[int]] = {}
    magenta_totals: dict[str, tuple[int, int]] = {}

    for base_name in REQUIRED_BASE_ANIMATIONS:
        min_frame_count = MIN_FRAME_COUNTS.get(base_name, MIN_FRAME_COUNT)
        left_name = f"{base_name}_left"
        right_name = f"{base_name}_right"
        left_frames = animation_frames(animations, left_name, errors)
        right_frames = animation_frames(animations, right_name, errors)

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
            magenta_total = 0
            for index, frame_path in enumerate(frame_paths):
                bottom, visible_pixels, magenta_pixels = check_frame(frame_path, f"{animation_name}[{index}]", errors)
                if bottom is not None:
                    bottoms.append(bottom)
                    checked_frames += 1
                visible_total += visible_pixels
                magenta_total += magenta_pixels
            alpha_bottoms[animation_name] = bottoms
            magenta_totals[animation_name] = (visible_total, magenta_total)

    if errors:
        raise AssertionError("BOSS01_DIRECTIONAL_ASSET_VALIDATION_FAIL\n" + "\n".join(f"- {error}" for error in errors))

    bottom_summary = ", ".join(
        f"{name}={min(bottoms)}..{max(bottoms)}"
        for name, bottoms in sorted(alpha_bottoms.items())
        if bottoms
    )
    magenta_summary = ", ".join(
        f"{name}={magenta}/{visible}"
        for name, (visible, magenta) in sorted(magenta_totals.items())
        if visible
    )
    print(
        "BOSS01_DIRECTIONAL_ASSET_VALIDATION_PASS "
        f"animations={checked_animations} frames={checked_frames} "
        f"manifest={normalize_rel(BOSS01_MANIFEST)} alpha_bottoms={bottom_summary} "
        f"magenta_like={magenta_summary}"
    )


def read_json(path: Path, errors: list[str]) -> Any:
    if not path.exists():
        errors.append(f"missing manifest: {path}")
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


def check_frame(frame_res_path: str, label: str, errors: list[str]) -> tuple[int | None, int, int]:
    try:
        frame_path = res_to_path(frame_res_path)
    except ValueError as exc:
        errors.append(f"{label}: {exc}")
        return None, 0, 0

    if not frame_path.exists():
        errors.append(f"{label} missing png: {frame_path}")
        return None, 0, 0

    try:
        with Image.open(frame_path) as image:
            if image.format != "PNG":
                errors.append(f"{label} must be PNG, got {image.format!r}: {frame_path}")
            if image.size != GODOT_FRAME_SIZE:
                errors.append(f"{label} must be 256x256, got {image.size}: {frame_path}")
            if image.mode != "RGBA":
                errors.append(f"{label} must be RGBA, got {image.mode!r}: {frame_path}")
                rgba = image.convert("RGBA")
            else:
                rgba = image
            bbox = rgba.getchannel("A").getbbox()
            if bbox is None:
                errors.append(f"{label} alpha bbox is empty: {frame_path}")
                return None, 0, 0
            alpha_bottom = int(bbox[3])
            if alpha_bottom < ALPHA_BOTTOM_MIN or alpha_bottom > ALPHA_BOTTOM_MAX:
                errors.append(
                    f"{label} alpha bbox bottom must be {ALPHA_BOTTOM_MIN}-{ALPHA_BOTTOM_MAX}, "
                    f"got bottom={alpha_bottom}: {frame_path}"
                )
            visible_pixels, magenta_pixels = count_magenta_like_pixels(rgba)
            magenta_ratio = magenta_pixels / visible_pixels if visible_pixels else 0.0
            if magenta_pixels > BOSS01_MAX_MAGENTA_PIXELS_PER_FRAME and magenta_ratio > BOSS01_MAX_MAGENTA_RATIO:
                errors.append(
                    f"{label} has magenta spill pixels={magenta_pixels} visible={visible_pixels} "
                    f"ratio={magenta_ratio:.6f}: {frame_path}"
                )
            if label.startswith("walk_"):
                extra_components = large_extra_alpha_components(rgba)
                if extra_components:
                    errors.append(f"{label} has detached alpha components {extra_components}: {frame_path}")
            return alpha_bottom, visible_pixels, magenta_pixels
    except OSError as exc:
        errors.append(f"{label} cannot open image {frame_path}: {exc}")
        return None, 0, 0


def count_magenta_like_pixels(image: Image.Image) -> tuple[int, int]:
    visible = 0
    magenta = 0
    for r, g, b, a in image.getdata():
        if a <= 24:
            continue
        visible += 1
        magenta_bias = (r + b) * 0.5 - g
        if r > 76 and b > 76 and g < 118 and abs(r - b) < 132 and magenta_bias > 28:
            magenta += 1
    return visible, magenta


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
                for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    if pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    stack.append((nx, ny))
            if count > 40:
                components.append((count, (min_x, min_y, max_x, max_y)))
    components.sort(reverse=True)
    return [component for component in components[1:] if component[0] > BOSS01_MAX_WALK_EXTRA_COMPONENT_PIXELS]


def res_to_path(path: str) -> Path:
    if not path.startswith("res://"):
        raise ValueError(f"not a Godot res path: {path}")
    return GODOT_ROOT / path.removeprefix("res://")


def normalize_rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


if __name__ == "__main__":
    main()
