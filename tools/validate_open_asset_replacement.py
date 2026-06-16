from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEMO_DIR = ROOT / "godot" / "assets" / "sprites" / "demo"
PLAYER_DIR = ROOT / "godot" / "assets" / "sprites" / "lumen"
MANIFEST = ROOT / "godot" / "assets" / "sprites" / "open_asset_manifest.json"


DEMO_REQUIRED = [
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
    "hazard_spikes.png",
    "hazard_bell.png",
    "trap_fake_moss_floor.png",
    "trap_bell_gap.png",
    "trap_spore_chest.png",
    "trap_falling_clapper.png",
    "trap_shortcut_revenge.png",
    "trap_false_lamp.png",
    "pickup_bell_key.png",
    "shortcut_lever.png",
    "boss_gate.png",
]


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    assert_true(MANIFEST.exists(), "open asset manifest is missing")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert_true(data.get("primary_source") == "Kenney Platformer Art Deluxe", "unexpected primary asset source")
    assert_true(data.get("license") == "Creative Commons CC0", "unexpected asset license")
    targets = data.get("runtime_targets", {})
    for name in DEMO_REQUIRED:
        path = DEMO_DIR / name
        assert_true(path.exists(), f"missing runtime asset: {name}")
        with Image.open(path) as image:
            assert_true(image.mode == "RGBA", f"{name} should preserve transparency/RGBA")
            if name.startswith("bg_ch01_"):
                assert_true(image.size == (8192, 720), f"{name} should be 8192x720")
            else:
                assert_true(image.size[0] >= 64 and image.size[1] >= 64, f"{name} is too small")
        assert_true(name in targets, f"{name} missing from source manifest")

    player_manifest = json.loads((PLAYER_DIR / "lumen_animations_manifest.json").read_text(encoding="utf-8"))
    assert_true(player_manifest.get("character") == "kenney_p3_open_source_player", "player manifest still points to old character")
    animations = player_manifest.get("animations", [])
    assert_true(len(animations) >= 13, "player animation set is incomplete")
    for animation in animations:
        frames = animation.get("frames", [])
        assert_true(len(frames) == int(animation.get("frame_count", -1)), f"{animation.get('name')} frame count mismatch")
        for frame in frames:
            path = ROOT / "godot" / frame.replace("res://", "").replace("/", "\\")
            assert_true(path.exists(), f"missing player frame: {frame}")
            with Image.open(path) as image:
                assert_true(image.size == (128, 128), f"{frame} should be normalized to 128x128")
    print(f"OPEN_ASSET_VALIDATION_PASS source=Kenney_CC0 demo_assets={len(DEMO_REQUIRED)} player_anims={len(animations)}")


if __name__ == "__main__":
    main()
