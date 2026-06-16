from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_SCRIPT = ROOT / "godot" / "scripts" / "main_level.gd"
PLAYER_SCRIPT = ROOT / "godot" / "scripts" / "player_controller.gd"
NOTICE = ROOT / "godot" / "assets" / "NOTICE.md"
DISTINCT_DIR = ROOT / "godot" / "assets" / "sprites" / "enemies" / "distinct"
DISTINCT_BUILDER = ROOT / "tools" / "build_distinct_enemy_assets.py"

POLICY_DOCS = [
    ROOT / "docs" / "spec" / "20260615222908350_绯线巡礼六章剧情关卡配置策划.md",
    ROOT / "docs" / "research" / "20260615223148988_免费开源可商用友好素材映射.md",
    ROOT / "godot" / "data" / "campaign_chapters.json",
    ROOT / "godot" / "data" / "audio_visual_manifest.json",
]


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section_between(source: str, start: str, end: str) -> str:
    assert_true(start in source, f"missing section start {start}")
    assert_true(end in source, f"missing section end {end}")
    return source.split(start, 1)[1].split(end, 1)[0]


def main() -> None:
    main_source = MAIN_SCRIPT.read_text(encoding="utf-8")
    player_source = PLAYER_SCRIPT.read_text(encoding="utf-8")
    notice = NOTICE.read_text(encoding="utf-8")

    enemy_sprites = section_between(main_source, "const SPRITES := {", "const NPC_SPRITES")
    npc_sprites = section_between(main_source, "const NPC_SPRITES := {", "const MOSSY_PLATFORM_TILES")

    assert_true("res://assets/sprites/gothicvania/demo/enemy_" in enemy_sprites, "fallback enemy sprites must use GothicVania open assets")
    assert_true("res://assets/sprites/gothicvania/demo/boss_" in enemy_sprites, "fallback boss sprites must use GothicVania open assets")
    assert_true("res://assets/sprites/enemies/itch/" not in enemy_sprites, "itch restricted art cannot be used by enemies")
    assert_true("res://assets/sprites/enemies/distinct/" not in main_source, "generated distinct enemy art must not be referenced")
    assert_true("res://assets/sprites/enemies/itch/" not in npc_sprites, "NPC sprites must not use restricted itch art in the open-source release")
    assert_true("res://assets/sprites/gothicvania/demo/" in npc_sprites, "NPC sprites should use redistributable GothicVania demo art")
    assert_true("res://assets/third_party/mossy_cavern/" not in main_source, "runtime must not reference Mossy Cavern restricted assets")

    assert_true("generated_hero_v2" in player_source, "player must use the project-owned generated hero v2 manifest")
    assert_true("res://assets/sprites/player/abyss_hero/manifest.json" not in player_source, "Abyss player manifest is no longer runtime-approved")
    assert_true("lumen_animations_manifest" not in player_source, "generated/open replacement lumen manifest is not runtime-approved")

    assert_true(not DISTINCT_DIR.exists(), "generated distinct enemy asset directory should not exist")
    assert_true(not DISTINCT_BUILDER.exists(), "generated distinct enemy builder should not exist")

    for required in [
        "GothicVania Cemetery",
        "Kenney",
        "Bread Adventure",
        "Dark Fantasy Platformer Bestiary",
        "not committed to public releases",
    ]:
        assert_true(required in notice, f"NOTICE.md missing asset policy entry: {required}")

    forbidden_doc_terms = ["自制", "Patreon Collection", "generated distinct", "enemies/distinct", "付费必需"]
    policy_paths = list(POLICY_DOCS) + sorted((ROOT / "godot" / "data" / "chapters").glob("ch*.json"))
    for path in policy_paths:
        source = path.read_text(encoding="utf-8")
        for term in forbidden_doc_terms:
            assert_true(term not in source, f"{path.name} still contains forbidden asset-policy term: {term}")

    print("OPEN_ASSET_POLICY_VALIDATION_PASS player=generated_hero_v2 runtime_restricted_assets=false")


if __name__ == "__main__":
    main()
