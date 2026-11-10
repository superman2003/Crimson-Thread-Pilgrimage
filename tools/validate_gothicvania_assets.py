"""Validate the retained GothicVania library, not the current original hero."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GOTHIC_DIR = ROOT / "godot" / "assets" / "sprites" / "gothicvania"
PLAYER_MANIFEST = ROOT / "godot" / "assets" / "sprites" / "gothicvania" / "player" / "manifest.json"


REQUIRED_DEMO = [
    "bg_ch01_sky.png",
    "bg_ch01_far_silhouettes.png",
    "bg_ch01_mid_arches.png",
    "bg_ch01_fog.png",
    "bg_ch01_near_vines.png",
    "platform_moss_stone.png",
    "platform_bronze_bridge.png",
    "platform_boss_stone.png",
    "enemy_moss_larva.png",
    "enemy_bronze_moth.png",
    "enemy_spore_bellmaker.png",
    "enemy_gear_sentinel.png",
    "boss_rust_crown_guardian.png",
    "pickup_bell_key.png",
    "shortcut_lever.png",
    "boss_gate.png",
]


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    manifest_path = GOTHIC_DIR / "asset_manifest.json"
    assert_true(manifest_path.exists(), "gothicvania asset manifest missing")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert_true(manifest["primary_source"] == "Ansimuz GothicVania Cemetery", "wrong primary asset source")

    for name in REQUIRED_DEMO:
        path = GOTHIC_DIR / "demo" / name
        assert_true(path.exists(), f"missing gothicvania runtime asset {name}")
        with Image.open(path) as image:
            assert_true(image.mode == "RGBA", f"{name} should be RGBA")
            if name.startswith("bg_ch01_"):
                assert_true(image.size == (8192, 720), f"{name} must be 8192x720")
            else:
                assert_true(image.size[0] >= 96 and image.size[1] >= 72, f"{name} runtime canvas too small")

    assert_true(PLAYER_MANIFEST.exists(), "gothicvania hero player manifest missing")
    player_manifest = json.loads(PLAYER_MANIFEST.read_text(encoding="utf-8"))
    assert_true(player_manifest.get("character") == "ansimuz_gothicvania_hero", "player manifest is not the open GothicVania hero")
    assert_true(len(player_manifest.get("animations", [])) >= 14, "not all player animations are available")
    for animation in player_manifest["animations"]:
        for frame in animation["frames"]:
            path = ROOT / "godot" / frame.replace("res://", "")
            assert_true(path.exists(), f"missing player frame {frame}")
            with Image.open(path) as image:
                assert_true(image.size == (128, 128), f"{frame} must be normalized to 128x128")

    print(f"GOTHICVANIA_ASSET_VALIDATION_PASS scope=legacy_library demo_assets={len(REQUIRED_DEMO)} player_anims={len(player_manifest['animations'])}")


if __name__ == "__main__":
    main()
