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
SPECIAL_INDEX = ARTIFACT_ROOT / "boss_special_attack_keyframes_index.json"
GODOT_SPECIAL_INDEX = GODOT_BOSS_ROOT / "boss_special_attack_keyframes_index.json"
FRAME_COUNT = 6
ARTIFACT_FRAME_SIZE = 384
GODOT_FRAME_SIZE = 256


def main() -> None:
    concepts = read_json(CONCEPT_INDEX)["entries"]
    assert_equal(len(concepts), 20, "boss concept count")

    special_index = read_json(SPECIAL_INDEX)
    godot_special_index = read_json(GODOT_SPECIAL_INDEX)
    assert_equal(special_index["count"], len(special_index["entries"]), "artifact special boss count")
    assert_equal(godot_special_index["count"], len(godot_special_index["entries"]), "Godot special boss count")
    assert_equal(special_index["count"], godot_special_index["count"], "special index boss count parity")
    assert_equal(special_index["special_attack_count"], godot_special_index["special_attack_count"], "special attack count parity")

    concept_ids = {entry["id"] for entry in concepts}
    checked_frames = 0
    checked_attacks = 0
    completed_bosses = 0

    for entry in special_index["entries"]:
        boss_id = entry["id"]
        if boss_id not in concept_ids:
            raise AssertionError(f"unknown boss in special index: {boss_id}")
        attack_count = len(entry.get("attacks", []))
        if attack_count < 2 or attack_count > 3:
            raise AssertionError(f"{boss_id} must have 2-3 special attacks, got {attack_count}")
        completed_bosses += 1

        manifest = read_json(res_to_path(entry["godot_manifest"]))
        manifest_attacks = {attack["id"]: attack for attack in manifest.get("attacks", [])}
        if len(manifest_attacks) < attack_count:
            raise AssertionError(f"{boss_id} manifest missing attacks[] records")

        for attack in entry["attacks"]:
            attack_id = attack["id"]
            if attack_id == "attack":
                raise AssertionError(f"{boss_id} special index must not include default attack")
            if attack_id not in manifest_attacks:
                raise AssertionError(f"{boss_id} manifest missing special attack: {attack_id}")

            manifest_attack = manifest_attacks[attack_id]
            assert_equal(len(attack["frames"]), FRAME_COUNT, f"{boss_id}/{attack_id} artifact frame count")
            assert_equal(len(attack["godot_frames"]), FRAME_COUNT, f"{boss_id}/{attack_id} Godot frame count")
            if len(manifest_attack["frames"]) < FRAME_COUNT:
                raise AssertionError(
                    f"{boss_id}/{attack_id} manifest frame count: expected at least {FRAME_COUNT!r}, "
                    f"got {len(manifest_attack['frames'])!r}"
                )

            hit_frame = int(attack.get("hit_frame_index", manifest_attack.get("hit_frame_index", -1)))
            if hit_frame < 0 or hit_frame >= FRAME_COUNT:
                raise AssertionError(f"{boss_id}/{attack_id} invalid hit_frame_index: {hit_frame}")

            vfx = attack.get("vfx", [])
            if not vfx:
                raise AssertionError(f"{boss_id}/{attack_id} missing vfx")
            for item in vfx:
                if not item.get("key"):
                    raise AssertionError(f"{boss_id}/{attack_id} vfx missing key")
                trigger = int(item.get("trigger_frame", -1))
                if trigger < 0 or trigger >= FRAME_COUNT:
                    raise AssertionError(f"{boss_id}/{attack_id} vfx trigger out of range: {trigger}")

            check_image(ROOT / attack["strip"], ARTIFACT_FRAME_SIZE * FRAME_COUNT, ARTIFACT_FRAME_SIZE, f"{boss_id}/{attack_id} strip")
            for artifact_rel, godot_res in zip(attack["frames"], attack["godot_frames"], strict=True):
                check_image(ROOT / artifact_rel, ARTIFACT_FRAME_SIZE, ARTIFACT_FRAME_SIZE, f"{boss_id}/{attack_id} artifact frame")
                check_image(res_to_path(godot_res), GODOT_FRAME_SIZE, GODOT_FRAME_SIZE, f"{boss_id}/{attack_id} Godot frame")
                checked_frames += 2
            checked_attacks += 1

    assert_equal(completed_bosses, special_index["completed_boss_count"], "completed boss count")
    assert_equal(checked_attacks, special_index["special_attack_count"], "special attack count")

    contact_sheet = ARTIFACT_ROOT / "contact_sheets" / "boss_special_attack_keyframes_contact_sheet.png"
    if special_index["entries"]:
        check_image_exists(contact_sheet, "special attack contact sheet")
        preview_html = ARTIFACT_ROOT / "special_attacks_preview.html"
        if not preview_html.exists():
            raise AssertionError(f"missing preview html: {preview_html}")
        preview = preview_html.read_text(encoding="utf-8")
        if preview.count("<section>") != completed_bosses:
            raise AssertionError("special preview section count mismatch")

    print(
        "VALIDATE_BOSS_SPECIAL_ATTACKS_PASS "
        f"completed_bosses={completed_bosses} special_attacks={checked_attacks} frames={checked_frames} "
        f"artifact_index={normalize_rel(SPECIAL_INDEX)} godot_index={normalize_rel(GODOT_SPECIAL_INDEX)}"
    )


def check_image(path: Path, width: int, height: int, label: str) -> None:
    check_image_exists(path, label)
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


def check_image_exists(path: Path, label: str) -> None:
    if not path.exists():
        raise AssertionError(f"missing {label}: {path}")


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
