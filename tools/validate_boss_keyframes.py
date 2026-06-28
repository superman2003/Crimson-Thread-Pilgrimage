from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CONCEPT_INDEX = ROOT / "artifacts" / "boss_concepts" / "boss_concepts_index.json"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes"
GODOT_ROOT = ROOT / "godot"
GODOT_BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"
FRAME_COUNT = 6
ARTIFACT_FRAME_SIZE = 384
GODOT_FRAME_SIZE = 256


def main() -> None:
    concepts = read_json(CONCEPT_INDEX)["entries"]
    assert_equal(len(concepts), 20, "boss concept count")

    artifact_index = read_json(ARTIFACT_ROOT / "boss_attack_keyframes_index.json")
    godot_index = read_json(GODOT_BOSS_ROOT / "boss_attack_keyframes_index.json")
    assert_equal(artifact_index["count"], 20, "artifact keyframe index count")
    assert_equal(godot_index["count"], 20, "Godot keyframe index count")
    assert_equal(len(artifact_index["entries"]), 20, "artifact keyframe index entries")
    assert_equal(len(godot_index["entries"]), 20, "Godot keyframe index entries")

    artifact_by_id = {entry["id"]: entry for entry in artifact_index["entries"]}
    godot_by_id = {entry["id"]: entry for entry in godot_index["entries"]}

    checked_frames = 0
    for concept in concepts:
        boss_id = concept["id"]
        slug = Path(concept["file"]).stem
        if boss_id not in artifact_by_id:
            raise AssertionError(f"{boss_id} missing from artifact index")
        if boss_id not in godot_by_id:
            raise AssertionError(f"{boss_id} missing from Godot index")

        artifact_entry = artifact_by_id[boss_id]
        godot_entry = godot_by_id[boss_id]
        assert_equal(artifact_entry["slug"], slug, f"{boss_id} artifact slug")
        assert_equal(godot_entry["slug"], slug, f"{boss_id} Godot slug")
        assert_equal(len(artifact_entry["frames"]), FRAME_COUNT, f"{boss_id} artifact frame count")
        assert_equal(len(artifact_entry["godot_frames"]), FRAME_COUNT, f"{boss_id} artifact Godot frame count")
        assert_equal(len(godot_entry["attack"]), FRAME_COUNT, f"{boss_id} Godot attack count")

        strip_path = ROOT / artifact_entry["strip"]
        check_image(strip_path, ARTIFACT_FRAME_SIZE * FRAME_COUNT, ARTIFACT_FRAME_SIZE, f"{boss_id} strip")

        manifest_path = res_to_path(artifact_entry["godot_manifest"])
        manifest = read_json(manifest_path)
        attack = next((anim for anim in manifest["animations"] if anim["name"] == "attack"), None)
        if attack is None:
            raise AssertionError(f"{boss_id} manifest missing attack animation")
        if len(attack["frames"]) < FRAME_COUNT:
            raise AssertionError(
                f"{boss_id} manifest attack count: expected at least {FRAME_COUNT!r}, got {len(attack['frames'])!r}"
            )

        for frame_rel, godot_res in zip(artifact_entry["frames"], godot_entry["attack"], strict=True):
            check_image(ROOT / frame_rel, ARTIFACT_FRAME_SIZE, ARTIFACT_FRAME_SIZE, f"{boss_id} artifact frame")
            check_image(res_to_path(godot_res), GODOT_FRAME_SIZE, GODOT_FRAME_SIZE, f"{boss_id} Godot frame")
            checked_frames += 2

    contact_sheet = ARTIFACT_ROOT / "contact_sheets" / "boss_attack_keyframes_contact_sheet.png"
    check_image(contact_sheet, 1136, 3396, "boss keyframes contact sheet")
    preview_html = ARTIFACT_ROOT / "preview.html"
    if not preview_html.exists():
        raise AssertionError(f"missing preview html: {preview_html}")
    preview = preview_html.read_text(encoding="utf-8")
    if preview.count("<section>") != 20:
        raise AssertionError("preview html must contain 20 boss sections")

    print(
        "VALIDATE_BOSS_KEYFRAMES_PASS "
        f"bosses=20 frames={checked_frames} "
        f"artifact_index={normalize_rel(ARTIFACT_ROOT / 'boss_attack_keyframes_index.json')} "
        f"godot_index={normalize_rel(GODOT_BOSS_ROOT / 'boss_attack_keyframes_index.json')}"
    )


def check_image(path: Path, width: int, height: int, label: str) -> None:
    if not path.exists():
        raise AssertionError(f"missing {label}: {path}")
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        assert_equal(rgba.size, (width, height), label)
        alpha = rgba.getchannel("A")
        if alpha.getbbox() is None:
            raise AssertionError(f"{label} is empty: {path}")
        corners = [
            alpha.getpixel((0, 0)),
            alpha.getpixel((rgba.width - 1, 0)),
            alpha.getpixel((0, rgba.height - 1)),
            alpha.getpixel((rgba.width - 1, rgba.height - 1)),
        ]
        if label.endswith("frame") and any(value > 0 for value in corners):
            raise AssertionError(f"{label} corners are not transparent: {path}")


def read_json(path: Path) -> Any:
    if not path.exists():
        raise AssertionError(f"missing json: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def res_to_path(path: str) -> Path:
    if not path.startswith("res://"):
        raise AssertionError(f"not a Godot res path: {path}")
    return GODOT_ROOT / path.removeprefix("res://")


def normalize_rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def assert_equal(actual: Any, expected: Any, label: str) -> None:
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected!r}, got {actual!r}")


if __name__ == "__main__":
    main()
