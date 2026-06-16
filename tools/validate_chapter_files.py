from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CHAPTER_DIR = ROOT / "godot" / "data" / "chapters"

EXPECTED_FILES = {
    "ch02_rain_foundry_canal.json": "ch02_rain_foundry_canal",
    "ch03_saltwhite_archive.json": "ch03_saltwhite_archive",
    "ch04_broken_string_greenhouse.json": "ch04_broken_string_greenhouse",
    "ch05_obsidian_pilgrim_road.json": "ch05_obsidian_pilgrim_road",
    "ch06_silent_crown_core.json": "ch06_silent_crown_core",
}

REQUIRED_FIELDS = {
    "id",
    "name",
    "main_goal",
    "story_beats",
    "rooms",
    "npcs",
    "enemy_points",
    "boss",
    "gates",
    "key_collectibles",
    "ending_clues",
    "open_assets",
    "vfx_audio",
}

REQUIRED_OPEN_ASSET_FIELDS = {"environment", "enemies", "boss", "npc", "ui_fx", "audio"}
ALLOWED_ASSET_MARKERS = {
    "GothicVania",
    "Ansimuz",
    "OpenGameArt",
    "Public Domain",
    "Kenney",
    "CC0",
    "Bread Adventure",
    "Apache-2.0",
    "本地已记录",
    "免费开放候选",
    "godot/assets",
}
FORBIDDEN_TERMS = {
    "自制",
    "生成素材",
    "AI生成",
    "付费必需",
    "付费素材",
    "收费素材",
    "Patreon",
    "premium required",
    "paid required",
    "Midjourney",
    "DALL-E",
    "Stable Diffusion",
    "enemies/distinct",
}


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def flatten_strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        result: list[str] = []
        for child in value.values():
            result.extend(flatten_strings(child))
        return result
    if isinstance(value, list):
        result = []
        for child in value:
            result.extend(flatten_strings(child))
        return result
    return []


def has_marker(text: str) -> bool:
    return any(marker in text for marker in ALLOWED_ASSET_MARKERS)


def validate_chapter(path: Path, expected_id: str) -> tuple[int, int, int]:
    data = json.loads(path.read_text(encoding="utf-8"))
    chapter_id = data.get("id", "")
    assert_true(chapter_id == expected_id, f"{path.name}: id mismatch, expected {expected_id}, got {chapter_id}")
    assert_true(REQUIRED_FIELDS.issubset(data), f"{chapter_id}: missing fields {sorted(REQUIRED_FIELDS - set(data))}")
    assert_true(isinstance(data.get("name"), str) and data["name"], f"{chapter_id}: missing name")
    assert_true(isinstance(data.get("main_goal"), str) and len(data["main_goal"]) >= 12, f"{chapter_id}: weak main_goal")

    story_beats = data["story_beats"]
    rooms = data["rooms"]
    npcs = data["npcs"]
    enemy_points = data["enemy_points"]
    boss = data["boss"]
    gates = data["gates"]
    key_collectibles = data["key_collectibles"]
    ending_clues = data["ending_clues"]
    open_assets = data["open_assets"]
    vfx_audio = data["vfx_audio"]

    assert_true(isinstance(story_beats, list) and len(story_beats) >= 4, f"{chapter_id}: needs at least 4 story beats")
    assert_true(isinstance(rooms, list) and len(rooms) >= 6, f"{chapter_id}: needs at least 6 rooms")
    assert_true(isinstance(npcs, list) and len(npcs) >= 3, f"{chapter_id}: needs at least 3 NPCs")
    assert_true(isinstance(enemy_points, list) and len(enemy_points) >= 5, f"{chapter_id}: needs at least 5 enemy points")
    assert_true(isinstance(gates, list) and len(gates) >= 3, f"{chapter_id}: needs at least 3 gates")
    assert_true(isinstance(key_collectibles, list) and len(key_collectibles) >= 4, f"{chapter_id}: needs at least 4 key collectibles")
    assert_true(isinstance(ending_clues, list) and len(ending_clues) >= 3, f"{chapter_id}: needs at least 3 ending clues")
    assert_true(isinstance(vfx_audio, list) and len(vfx_audio) >= 3, f"{chapter_id}: needs at least 3 vfx/audio beats")

    for beat in story_beats:
        assert_true(beat.get("id") and beat.get("summary") and beat.get("story_flag"), f"{chapter_id}: incomplete story beat")

    for room in rooms:
        for field in ["id", "name", "kind", "objective", "guide", "danger", "next"]:
            assert_true(room.get(field), f"{chapter_id}: room missing {field}")

    npc_ids = set()
    for npc in npcs:
        npc_id = npc.get("id", "")
        assert_true(npc_id and npc_id not in npc_ids, f"{chapter_id}: duplicate or missing npc id {npc_id}")
        npc_ids.add(npc_id)
        for field in ["name", "role", "position_hint"]:
            assert_true(npc.get(field), f"{chapter_id}/{npc_id}: npc missing {field}")
        dialogue = npc.get("dialogue", [])
        assert_true(isinstance(dialogue, list) and len(dialogue) >= 3, f"{chapter_id}/{npc_id}: dialogue must have 3+ lines")
        assert_true(all(isinstance(line, str) and len(line) >= 8 for line in dialogue), f"{chapter_id}/{npc_id}: weak dialogue line")

    for point in enemy_points:
        for field in ["id", "room", "spawn_mix", "combat_role", "story_use", "asset_hint"]:
            assert_true(point.get(field), f"{chapter_id}: enemy point missing {field}")
        assert_true(isinstance(point["spawn_mix"], list) and point["spawn_mix"], f"{chapter_id}/{point['id']}: spawn_mix must be non-empty")
        assert_true(has_marker(point["asset_hint"]), f"{chapter_id}/{point['id']}: asset_hint must cite free/open/local source")

    for field in ["id", "name", "kind", "arena", "phase_1", "phase_2", "drop", "story_after", "asset_hint"]:
        assert_true(boss.get(field), f"{chapter_id}: boss missing {field}")
    assert_true(isinstance(boss["drop"], list) and boss["drop"], f"{chapter_id}: boss drop must be non-empty")
    assert_true(has_marker(boss["asset_hint"]), f"{chapter_id}: boss asset_hint must cite free/open/local source")

    for gate in gates:
        for field in ["id", "type", "requires", "placement", "unlock_logic"]:
            assert_true(gate.get(field), f"{chapter_id}: gate missing {field}")

    for item in key_collectibles:
        for field in ["id", "name", "category", "use", "story_flag"]:
            assert_true(item.get(field), f"{chapter_id}: key collectible missing {field}")

    ending_routes = {clue.get("route") for clue in ending_clues}
    assert_true({"重鸣", "断冠", "真结局"}.issubset(ending_routes), f"{chapter_id}: ending clues must cover all three endings")
    for clue in ending_clues:
        for field in ["route", "clue", "evidence_item"]:
            assert_true(clue.get(field), f"{chapter_id}: ending clue missing {field}")

    assert_true(isinstance(open_assets, dict), f"{chapter_id}: open_assets must be object")
    assert_true(REQUIRED_OPEN_ASSET_FIELDS.issubset(open_assets), f"{chapter_id}: open_assets missing fields")
    for asset_key, asset_info in open_assets.items():
        strings = flatten_strings(asset_info)
        joined = " ".join(strings)
        assert_true(strings, f"{chapter_id}: open_assets.{asset_key} must contain source text")
        assert_true(has_marker(joined), f"{chapter_id}: open_assets.{asset_key} must cite free/open/local source")

    for beat in vfx_audio:
        for field in ["id", "visual", "audio", "asset_policy"]:
            assert_true(beat.get(field), f"{chapter_id}: vfx_audio missing {field}")
        assert_true(has_marker(beat["asset_policy"]), f"{chapter_id}/{beat['id']}: vfx/audio asset_policy must cite local/CC0 source")

    full_text = path.read_text(encoding="utf-8")
    for term in FORBIDDEN_TERMS:
        assert_true(term not in full_text, f"{chapter_id}: contains forbidden asset-policy term {term}")

    return len(npcs), len(enemy_points), len(rooms)


def main() -> None:
    assert_true(CHAPTER_DIR.exists(), "chapter directory is missing")
    found = {path.name for path in CHAPTER_DIR.glob("ch*.json")}
    assert_true(set(EXPECTED_FILES).issubset(found), f"missing chapter files: {sorted(set(EXPECTED_FILES) - found)}")

    total_npcs = 0
    total_enemy_points = 0
    total_rooms = 0
    for file_name, expected_id in EXPECTED_FILES.items():
        npcs, enemy_points, rooms = validate_chapter(CHAPTER_DIR / file_name, expected_id)
        total_npcs += npcs
        total_enemy_points += enemy_points
        total_rooms += rooms

    print(
        "CHAPTER_FILES_VALIDATION_PASS "
        f"files={len(EXPECTED_FILES)} rooms={total_rooms} npcs={total_npcs} enemy_points={total_enemy_points}"
    )


if __name__ == "__main__":
    main()
