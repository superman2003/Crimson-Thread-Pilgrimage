from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT / "godot" / "data" / "campaign_chapters.json"

REQUIRED_ASSET_FIELDS = {"map", "enemy", "npc", "audio"}
FORBIDDEN_REQUIRED_WORDS = {"付费必需", "paid required", "premium required"}


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    data = json.loads(CAMPAIGN.read_text(encoding="utf-8"))
    chapters = data.get("chapters", [])
    assert_true(data.get("asset_policy", {}).get("required"), "campaign asset policy is required")
    assert_true(len(chapters) == 6, "campaign must define 6 chapters")
    assert_true([chapter.get("index") for chapter in chapters] == [1, 2, 3, 4, 5, 6], "chapter indices must be 1..6")

    ids = set()
    npc_total = 0
    enemy_total = 0
    for chapter in chapters:
        chapter_id = chapter.get("id", "")
        assert_true(chapter_id and chapter_id not in ids, f"chapter id must be unique: {chapter_id}")
        ids.add(chapter_id)
        assert_true(chapter.get("name"), f"{chapter_id} missing name")
        assert_true(chapter.get("biome"), f"{chapter_id} missing biome")
        assert_true(chapter.get("objective"), f"{chapter_id} missing objective")
        assert_true(chapter.get("reward"), f"{chapter_id} missing reward")
        if int(chapter.get("index", 0)) == 1:
            assert_true(
                chapter.get("runtime_config_id") == "demo_ch01_moss_bell_court",
                "chapter 1 must map to the playable demo config",
            )

        npcs = chapter.get("npcs", [])
        enemies = chapter.get("enemies", [])
        vfx_audio = chapter.get("vfx_audio", [])
        boss = chapter.get("boss", {})
        open_assets = chapter.get("open_assets", {})

        assert_true(len(npcs) >= 3, f"{chapter_id} must have at least 3 NPCs")
        assert_true(len(enemies) >= 5, f"{chapter_id} must have at least 5 enemy concepts")
        assert_true(boss.get("name") and boss.get("pattern") and boss.get("story_drop"), f"{chapter_id} boss is incomplete")
        assert_true(len(vfx_audio) >= 3, f"{chapter_id} must define at least 3 vfx/audio beats")
        assert_true(REQUIRED_ASSET_FIELDS.issubset(open_assets), f"{chapter_id} missing asset mapping fields")

        for npc in npcs:
            assert_true(npc.get("role") and npc.get("name") and npc.get("place"), f"{chapter_id} npc has missing identity")
            assert_true(len(npc.get("dialogue", [])) >= 3, f"{chapter_id}/{npc.get('name')} needs at least 3 dialogue lines")
        npc_total += len(npcs)
        enemy_total += len(enemies)

    text = CAMPAIGN.read_text(encoding="utf-8").lower()
    for word in FORBIDDEN_REQUIRED_WORDS:
        assert_true(word not in text, f"campaign contains forbidden paid-required wording: {word}")
    print(f"CAMPAIGN_CHAPTER_VALIDATION_PASS chapters={len(chapters)} npcs={npc_total} enemy_concepts={enemy_total}")


if __name__ == "__main__":
    main()
