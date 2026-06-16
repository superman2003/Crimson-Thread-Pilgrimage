from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAIN_SCRIPT = ROOT / "godot" / "scripts" / "main_level.gd"
GOTHIC_DEMO = ROOT / "godot" / "assets" / "sprites" / "gothicvania" / "demo"

ENEMY_PATHS = {
    "moss_larva": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "bronze_moth": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "spore_bellmaker": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "gear_sentinel": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "rust_crown_guardian": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
}

NPC_PATHS = {
    "threadsmith": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "pilgrim": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "cartographer": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "sacristan": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "scout": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
}


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def resource_exists(res_path: str) -> bool:
    path = ROOT / "godot" / res_path.replace("res://", "")
    return path.exists()


def validate_png(path: Path) -> None:
    assert_true(path.exists(), f"missing png: {path}")
    with Image.open(path) as image:
        assert_true(image.mode == "RGBA", f"{path.name} must be RGBA")
        assert_true(image.getchannel("A").getbbox() is not None, f"{path.name} alpha must not be empty")


def main() -> None:
    source = MAIN_SCRIPT.read_text(encoding="utf-8")
    for kind, res_path in ENEMY_PATHS.items():
        assert_true(res_path in source, f"{kind} enemy must use open GothicVania art")
        validate_png(GOTHIC_DEMO / res_path.rsplit("/", 1)[-1])

    sprite_section = source.split("const NPC_SPRITES", 1)[0]
    assert_true("res://assets/sprites/enemies/itch/" not in source, "open-source runtime must not use restricted itch art")
    assert_true("res://assets/sprites/enemies/distinct/" not in source, "generated distinct enemy art must not be referenced")

    for role, res_path in NPC_PATHS.items():
        assert_true(res_path in source, f"{role} npc should use redistributable GothicVania art")
        assert_true(resource_exists(res_path), f"missing npc static sprite: {res_path}")

    print(f"ENEMY_VISUAL_SOURCE_VALIDATION_PASS enemies=gothicvania_open_assets npcs=gothicvania_open_assets restricted_itch=false count={len(NPC_PATHS)}")


if __name__ == "__main__":
    main()
