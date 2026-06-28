from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
DATA_DIR = GODOT / "data"
CONFIG_FILES = [
    DATA_DIR / "demo_ch01_moss_bell_court.json",
    DATA_DIR / "demo_ch02_rain_foundry_canal.json",
    DATA_DIR / "demo_ch03_saltwhite_archive.json",
    DATA_DIR / "demo_ch04_broken_string_greenhouse.json",
    DATA_DIR / "demo_ch05_obsidian_pilgrim_road.json",
    DATA_DIR / "demo_ch06_silent_crown_core.json",
]

REQUIRED_ANIMATIONS = {
    "idle": 1,
    "walk": 8,
    "walk_left": 8,
    "walk_right": 8,
    "attack": 8,
    "attack_left": 8,
    "attack_right": 8,
    "hurt": 1,
    "death": 1,
}

EXPECTED_WALK_STAGES = [
    "contact_a",
    "down_a",
    "passing_a",
    "up_a",
    "contact_b",
    "down_b",
    "passing_b",
    "up_b",
]

EXPECTED_ATTACK_STAGES = [
    "ready",
    "anticipation",
    "coil",
    "release",
    "impact",
    "follow_through",
    "recover",
    "settle",
]

MIN_STRIP_SPACING_PX = 24
MIN_WALK_CENTER_TRAVEL_PX = 5
MIN_WALK_AREA_DELTA = 80
MIN_ATTACK_X_EXTENT_PX = 20
MIN_ATTACK_CENTER_TRAVEL_PX = 20
MIN_ATTACK_AREA_DELTA = 180
EXPECTED_QUALITY_PROFILES = {"shape_aware_walk_attack_v19_no_line_attack_fx"}
LINE_SCAN_SLOPES = [(-3, 4), (-2, 3), (-1, 2), (-1, 1), (1, 1), (1, 2), (2, 3), (3, 4)]
MAX_CHROMA_KEY_PIXELS = 12
MIN_FORBIDDEN_LINE_PIXELS = 90
MIN_FORBIDDEN_LINE_SPAN = 42
MIN_FORBIDDEN_LINE_ASPECT = 2.8
MIN_FORBIDDEN_LINE_DENSITY = 0.13
NO_ADDED_WALK_LIMB_PLANS = {
    "snail_slide",
    "worm_slither",
    "winged_hover",
    "tendril_float",
    "flame_wisp",
    "hunched_shambler",
    "amphibian_hop",
    "armored_biped",
    "beast_biped",
    "biped_imp",
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-unique-enemies", type=int, default=40)
    args = parser.parse_args()

    enemy_kinds: dict[str, dict[str, Any]] = {}
    chapter_counts: dict[str, int] = {}
    spawn_count = 0
    for config_path in CONFIG_FILES:
        data = load_json(config_path)
        chapter_id = str(data.get("id", config_path.stem))
        chapter_unique: set[str] = set()
        profiles = data.get("ai_profiles", {})
        for spawn in data.get("enemy_spawns", []):
            if not isinstance(spawn, dict):
                continue
            spawn_count += 1
            kind = str(spawn.get("kind", ""))
            assert_true(kind, f"{chapter_id}: enemy kind missing")
            chapter_unique.add(kind)
            assert_true(kind in profiles, f"{chapter_id}: ai profile missing for {kind}")
            attacks = profiles[kind].get("attacks", []) if isinstance(profiles[kind], dict) else []
            assert_true(len(attacks) == 1, f"{chapter_id}/{kind}: small enemy must have exactly one attack")
            enemy_kinds.setdefault(kind, {"chapter": chapter_id, "spawn": spawn})
        chapter_counts[chapter_id] = len(chapter_unique)

    assert_true(
        len(enemy_kinds) >= args.min_unique_enemies,
        f"unique small enemy kinds {len(enemy_kinds)} < required {args.min_unique_enemies}",
    )

    checked_frames = 0
    checked_manifests: set[str] = set()
    for kind, record in sorted(enemy_kinds.items()):
        spawn = record["spawn"]
        sprite = str(spawn.get("sprite", ""))
        assert_true("runtime_keyframes" in sprite and sprite.endswith("manifest.json"), f"{kind}: sprite must point to runtime keyframe manifest")
        manifest_path = from_res_path(sprite)
        assert_true(manifest_path.exists(), f"{kind}: missing manifest {sprite}")
        checked_manifests.add(sprite)
        manifest = load_json(manifest_path)
        assert_true(manifest.get("quality_profile") in EXPECTED_QUALITY_PROFILES, f"{kind}: unexpected quality_profile {manifest.get('quality_profile')}")
        assert_true(manifest.get("attack_count") == 1, f"{kind}: manifest attack_count must be 1")
        assert_true(manifest.get("cell_size") == [128, 128], f"{kind}: manifest cell_size must be 128x128")
        assert_true(
            int(manifest.get("frame_spacing_px", 0)) >= MIN_STRIP_SPACING_PX,
            f"{kind}: frame spacing too small for reliable slicing",
        )
        assert_true(
            manifest.get("attack_stages") == EXPECTED_ATTACK_STAGES,
            f"{kind}: attack stages must describe anticipation/release/impact/recovery",
        )
        assert_true(
            manifest.get("walk_stages") == EXPECTED_WALK_STAGES,
            f"{kind}: walk stages must describe an 8-frame gait cycle",
        )
        quality_gates = manifest.get("quality_gates", {})
        locomotion_plan = str(manifest.get("locomotion_plan", ""))
        shape_constraints = manifest.get("shape_constraints", {})
        assert_true(locomotion_plan, f"{kind}: missing locomotion_plan")
        assert_true(
            isinstance(shape_constraints, dict) and shape_constraints.get("no_added_walk_limbs") is True,
            f"{kind}: all small enemy walk cycles must forbid added walk limbs",
        )
        assert_true(
            isinstance(shape_constraints, dict) and shape_constraints.get("no_detached_attack_effects") is True,
            f"{kind}: all small enemy attacks must forbid detached attack effects",
        )
        assert_true(
            isinstance(shape_constraints, dict) and shape_constraints.get("source_silhouette_driven") is True,
            f"{kind}: attacks must be source silhouette driven",
        )
        assert_true(
            isinstance(quality_gates, dict) and quality_gates.get("attack_body_pose_changes") is True,
            f"{kind}: missing high-fidelity attack quality gate metadata",
        )
        assert_true(
            quality_gates.get("walk_body_pose_changes") is True,
            f"{kind}: missing high-fidelity walk quality gate metadata",
        )
        animations = {
            str(animation.get("name", "")): animation
            for animation in manifest.get("animations", [])
            if isinstance(animation, dict)
        }
        for animation_name, min_frames in REQUIRED_ANIMATIONS.items():
            assert_true(animation_name in animations, f"{kind}: missing animation {animation_name}")
            frames = animations[animation_name].get("frames", [])
            assert_true(len(frames) >= min_frames, f"{kind}/{animation_name}: frames {len(frames)} < {min_frames}")
            for frame_path_value in frames:
                frame_path = from_res_path(str(frame_path_value))
                validate_png(frame_path, kind, animation_name)
                checked_frames += 1
        validate_walk_motion(kind, animations, "walk_right", locomotion_plan)
        validate_walk_motion(kind, animations, "walk_left", locomotion_plan)
        validate_attack_motion(kind, animations, "attack_right")
        validate_attack_motion(kind, animations, "attack_left")

    print(
        "ENEMY_RUNTIME_MANIFEST_COVERAGE_PASS "
        f"unique_enemies={len(enemy_kinds)} spawns={spawn_count} manifests={len(checked_manifests)} "
        f"frames={checked_frames} chapter_unique_counts={chapter_counts}"
    )


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def from_res_path(path: str) -> Path:
    if path.startswith("res://"):
        return GODOT / path.removeprefix("res://")
    return ROOT / path


def validate_png(path: Path, kind: str, animation_name: str) -> None:
    assert_true(path.exists(), f"{kind}/{animation_name}: missing frame {path}")
    with Image.open(path) as image:
        assert_true(image.mode == "RGBA", f"{kind}/{animation_name}: frame must be RGBA {path}")
        assert_true(image.size == (128, 128), f"{kind}/{animation_name}: frame must be 128x128 {path}")
        assert_true(image.getchannel("A").getbbox() is not None, f"{kind}/{animation_name}: alpha is empty {path}")
        bbox = image.getchannel("A").getbbox()
        if bbox is not None:
            assert_true(bbox[0] >= 1 and bbox[1] >= 1 and bbox[2] <= 127 and bbox[3] <= 127, f"{kind}/{animation_name}: frame content too close to edge/cropped {path} bbox={bbox}")
        validate_no_source_artifacts(image.convert("RGBA"), kind, animation_name, path)


def validate_walk_motion(kind: str, animations: dict[str, Any], animation_name: str, locomotion_plan: str) -> None:
    stats = motion_stats(kind, animations, animation_name)
    assert_true(
        stats["center_travel"] >= MIN_WALK_CENTER_TRAVEL_PX,
        f"{kind}/{animation_name}: walk body center travel too small {stats['center_travel']:.1f}",
    )
    assert_true(
        stats["area_delta"] >= MIN_WALK_AREA_DELTA,
        f"{kind}/{animation_name}: walk silhouette/limb area delta too small {stats['area_delta']}",
    )
    validate_no_added_walk_limbs(kind, animations, animation_name)


def validate_attack_motion(kind: str, animations: dict[str, Any], animation_name: str) -> None:
    stats = motion_stats(kind, animations, animation_name)
    x_extent = stats["x_extent"]
    center_travel = stats["center_travel"]
    area_delta = stats["area_delta"]
    assert_true(
        x_extent >= MIN_ATTACK_X_EXTENT_PX or center_travel >= MIN_ATTACK_X_EXTENT_PX * 0.65,
        f"{kind}/{animation_name}: attack pose does not travel enough x_extent={x_extent} center_travel={center_travel:.1f}",
    )
    assert_true(
        center_travel >= MIN_ATTACK_CENTER_TRAVEL_PX,
        f"{kind}/{animation_name}: attack body center travel too small {center_travel:.1f}",
    )
    assert_true(
        area_delta >= MIN_ATTACK_AREA_DELTA,
        f"{kind}/{animation_name}: attack silhouette/effect area delta too small {area_delta}",
    )
    validate_no_detached_attack_effects(kind, animations, animation_name)


def motion_stats(kind: str, animations: dict[str, Any], animation_name: str) -> dict[str, float]:
    frames = animations[animation_name].get("frames", [])
    bboxes: list[tuple[int, int, int, int]] = []
    areas: list[int] = []
    centers: list[float] = []
    for frame_path_value in frames:
        frame_path = from_res_path(str(frame_path_value))
        with Image.open(frame_path).convert("RGBA") as image:
            bbox = image.getchannel("A").getbbox()
            assert_true(bbox is not None, f"{kind}/{animation_name}: alpha is empty {frame_path}")
            bboxes.append(bbox)
            areas.append(alpha_area(image))
            centers.append((bbox[0] + bbox[2]) / 2.0)
    x_extent = max(bbox[2] for bbox in bboxes) - min(bbox[0] for bbox in bboxes)
    center_travel = max(centers) - min(centers)
    area_delta = max(areas) - min(areas)
    return {"x_extent": float(x_extent), "center_travel": center_travel, "area_delta": float(area_delta)}


def validate_no_added_walk_limbs(kind: str, animations: dict[str, Any], animation_name: str) -> None:
    for frame_path_value in animations[animation_name].get("frames", []):
        frame_path = from_res_path(str(frame_path_value))
        with Image.open(frame_path).convert("RGBA") as image:
            bbox = image.getchannel("A").getbbox()
            assert_true(bbox is not None, f"{kind}/{animation_name}: alpha is empty {frame_path}")
            bottom_y = max(0, bbox[3] - 14)
            alpha = image.getchannel("A")
            pixels = alpha.load()
            columns = []
            for x in range(bbox[0], bbox[2]):
                count = 0
                for y in range(bottom_y, bbox[3]):
                    if pixels[x, y] > 0:
                        count += 1
                if count:
                    columns.append((x, count))
            if not columns:
                continue
            thin_columns = [x for x, count in columns if count <= 3]
            thin_ratio = len(thin_columns) / max(1, len(columns))
            assert_true(
                thin_ratio <= 0.48,
                f"{kind}/{animation_name}: no-leg body plan has thin dangling pixels that look like added legs {frame_path}",
            )


def validate_no_source_artifacts(image: Image.Image, kind: str, animation_name: str, path: Path) -> None:
    pixels = image.load()
    chroma_pixels = 0
    label_like_pixels = 0
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a <= 24:
                continue
            if b >= 170 and r <= 90 and g <= 110:
                chroma_pixels += 1
            if a >= 160 and r >= 220 and g >= 220 and b >= 210 and (y <= 18 or y >= 110):
                label_like_pixels += 1
    assert_true(
        chroma_pixels <= MAX_CHROMA_KEY_PIXELS,
        f"{kind}/{animation_name}: source blue/purple background residue {chroma_pixels}px {path}",
    )
    assert_true(
        label_like_pixels <= 42,
        f"{kind}/{animation_name}: source label-like text residue near frame edge {label_like_pixels}px {path}",
    )


def validate_no_detached_attack_effects(kind: str, animations: dict[str, Any], animation_name: str) -> None:
    for frame_path_value in animations[animation_name].get("frames", []):
        frame_path = from_res_path(str(frame_path_value))
        with Image.open(frame_path).convert("RGBA") as image:
            line = forbidden_attack_line(image)
            assert_true(
                line is None,
                f"{kind}/{animation_name}: detached line-like attack effect {line} {frame_path}",
            )


def forbidden_attack_line(image: Image.Image) -> dict[str, Any] | None:
    pixels = image.load()
    points: list[tuple[int, int]] = []
    for y in range(image.height):
        if y >= 113:
            continue
        for x in range(image.width):
            _, _, _, alpha = pixels[x, y]
            if alpha >= 160:
                points.append((x, y))
    for slope_num, slope_den in LINE_SCAN_SLOPES:
        bands: dict[int, list[tuple[int, int]]] = {}
        for x, y in points:
            intercept = y * slope_den - slope_num * x
            band = round(intercept / 5)
            bands.setdefault(band, []).append((x, y))
        for band, band_points in bands.items():
            if len(band_points) < MIN_FORBIDDEN_LINE_PIXELS:
                continue
            xs = [point[0] for point in band_points]
            ys = [point[1] for point in band_points]
            width = max(xs) - min(xs) + 1
            height = max(ys) - min(ys) + 1
            span = max(width, height)
            aspect = span / max(1, min(width, height))
            density = len(band_points) / max(1, width * height)
            if span >= MIN_FORBIDDEN_LINE_SPAN and aspect >= MIN_FORBIDDEN_LINE_ASPECT and density >= MIN_FORBIDDEN_LINE_DENSITY:
                return {
                    "pixels": len(band_points),
                    "span": span,
                    "aspect": round(aspect, 2),
                    "density": round(density, 2),
                    "slope": [slope_num, slope_den],
                    "band": band,
                    "bbox": [min(xs), min(ys), max(xs) + 1, max(ys) + 1],
                }
    return None


def alpha_area(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    if hasattr(alpha, "get_flattened_data"):
        return sum(1 for value in alpha.get_flattened_data() if value > 0)
    return sum(1 for value in alpha.getdata() if value > 0)


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


if __name__ == "__main__":
    main()
