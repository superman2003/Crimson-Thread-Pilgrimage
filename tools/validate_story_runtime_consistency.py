from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT / "godot" / "data" / "campaign_chapters.json"
AV_MANIFEST = ROOT / "godot" / "data" / "audio_visual_manifest.json"
CHAPTER_DIR = ROOT / "godot" / "data" / "chapters"

EXPECTED_IDS = [
    "ch01_moss_bell_court",
    "ch02_rain_foundry_canal",
    "ch03_saltwhite_archive",
    "ch04_broken_string_greenhouse",
    "ch05_obsidian_pilgrim_road",
    "ch06_silent_crown_core",
]


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_json(path: Path) -> dict[str, Any]:
    assert_true(path.exists(), f"missing file: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    assert_true(isinstance(data, dict), f"json root must be object: {path.name}")
    return data


def short_name(name: str) -> str:
    return name.split("：", 1)[1] if "：" in name else name


def main() -> None:
    campaign = load_json(CAMPAIGN)
    av_manifest = load_json(AV_MANIFEST)
    campaign_chapters = campaign.get("chapters", [])
    av_chapters = av_manifest.get("chapter_audio_visual", [])

    assert_true([chapter.get("id") for chapter in campaign_chapters] == EXPECTED_IDS, "campaign chapter ids drifted from final story route")
    assert_true([chapter.get("chapter_id") for chapter in av_chapters] == EXPECTED_IDS, "AV manifest chapter ids drifted from final story route")

    by_av = {chapter["chapter_id"]: chapter for chapter in av_chapters}
    detailed_total_npcs = 0
    detailed_total_enemy_points = 0
    for chapter in campaign_chapters:
        chapter_id = chapter["id"]
        av_chapter = by_av[chapter_id]
        assert_true(chapter["index"] == av_chapter["chapter_index"], f"{chapter_id}: AV index mismatch")
        assert_true(chapter["name"] == av_chapter["chapter_name"], f"{chapter_id}: AV name mismatch")
        assert_true(chapter.get("vfx_audio") == [beat.get("campaign_beat") for beat in av_chapter.get("beats", [])], f"{chapter_id}: AV beats must mirror campaign beats")

        if chapter_id == "ch01_moss_bell_court":
            assert_true(chapter.get("runtime_config_id") == "demo_ch01_moss_bell_court", "CH01 must bind to current playable config")
            continue

        detail_path = CHAPTER_DIR / f"{chapter_id}.json"
        detail = load_json(detail_path)
        assert_true(short_name(detail.get("name", "")) == chapter.get("name"), f"{chapter_id}: detail name mismatch")
        assert_true(detail.get("main_goal") == chapter.get("objective"), f"{chapter_id}: detail main_goal mismatch")
        assert_true(len(detail.get("npcs", [])) == len(chapter.get("npcs", [])), f"{chapter_id}: NPC count mismatch")
        assert_true(len(detail.get("enemy_points", [])) >= 5, f"{chapter_id}: detailed enemy points incomplete")
        assert_true(detail.get("boss", {}).get("name") == chapter.get("boss", {}).get("name"), f"{chapter_id}: boss name mismatch")
        assert_true(chapter.get("chapter_file") == f"res://data/chapters/{chapter_id}.json", f"{chapter_id}: chapter_file path mismatch")
        detailed_total_npcs += len(detail.get("npcs", []))
        detailed_total_enemy_points += len(detail.get("enemy_points", []))

    print(
        "STORY_RUNTIME_CONSISTENCY_PASS "
        f"chapters={len(EXPECTED_IDS)} detailed_npcs={detailed_total_npcs} detailed_enemy_points={detailed_total_enemy_points}"
    )


if __name__ == "__main__":
    main()
