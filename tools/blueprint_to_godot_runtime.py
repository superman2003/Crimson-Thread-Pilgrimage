from __future__ import annotations

import json
import hashlib
import math
import re
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from collections import deque
from blueprint_runtime_parts import (LayoutRoom, ability_item_id, add_connection_support,
    add_room_platforms, annotate_shortcut_values, connection_progression, enemy_template,
    make_collectibles, make_connections, make_debug_map, make_enemy_spawns, make_hazards,
    make_interactives, make_locked_gates, make_map_rooms, make_npcs, make_platforms,
    make_save_points, platform, point_position, point_room, room_template, shortest_room_distance,
    slug, stable_id_part)


ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT_DIR = ROOT / "artifacts" / "map_blueprints" / "silksong_scale"
GODOT_DATA_DIR = ROOT / "godot" / "data"
OUT_DIR = GODOT_DATA_DIR / "generated"


CHAPTERS = {
    "ch01": {
        "source": GODOT_DATA_DIR / "demo_ch01_moss_bell_court.json",
        "blueprint": BLUEPRINT_DIR / "ch01_moss_bell_court_blueprint.json",
        "out": OUT_DIR / "demo_ch01_moss_bell_court.generated.json",
        "runtime_id": "demo_ch01_moss_bell_court_generated",
        "name": "苔铃外庭 自动生成灰盒",
        "art_theme": "moss_bell",
        "enemy_kinds": ["moss_larva", "bronze_moth", "spore_bellmaker", "gear_sentinel"],
        "materials": ("moss_stone", "bronze_bridge", "boss_stone"),
        "colors": ("1c2b1f", "315066", "5a2d2d"),
        "next_id": "demo_ch02_rain_foundry_canal_generated",
        "next_path": "res://data/generated/demo_ch02_rain_foundry_canal.generated.json",
    },
    "ch02": {
        "source": GODOT_DATA_DIR / "demo_ch02_rain_foundry_canal.json",
        "blueprint": BLUEPRINT_DIR / "ch02_rain_foundry_canal_blueprint.json",
        "out": OUT_DIR / "demo_ch02_rain_foundry_canal.generated.json",
        "runtime_id": "demo_ch02_rain_foundry_canal_generated",
        "name": "铸雨渠 自动生成灰盒",
        "art_theme": "rain_foundry",
        "enemy_kinds": ["drain_leech", "pipe_thrower", "rust_diver", "waterwheel_knight"],
        "materials": ("wet_metal", "rain_pipe", "foundry_boss"),
        "colors": ("344141", "3d5e66", "524338"),
        "next_id": "demo_ch03_saltwhite_archive_generated",
        "next_path": "res://data/generated/demo_ch03_saltwhite_archive.generated.json",
    },
    "ch03": {
        "source": GODOT_DATA_DIR / "demo_ch03_saltwhite_archive.json",
        "blueprint": BLUEPRINT_DIR / "ch03_saltwhite_archive_blueprint.json",
        "out": OUT_DIR / "demo_ch03_saltwhite_archive.generated.json",
        "runtime_id": "demo_ch03_saltwhite_archive_generated",
        "name": "盐白档案馆 自动生成灰盒",
        "art_theme": "salt_archive",
        "enemy_kinds": ["salt_bookmite", "page_duelist", "index_scribe", "wax_lancer", "erasure_bailiff", "summoned_page"],
        "materials": ("salt_marble", "vellum_bridge", "archive_boss"),
        "colors": ("4b493c", "73684a", "625644"),
        "next_id": "demo_ch04_broken_string_greenhouse_generated",
        "next_path": "res://data/generated/demo_ch04_broken_string_greenhouse.generated.json",
    },
    "ch04": {
        "source": GODOT_DATA_DIR / "demo_ch04_broken_string_greenhouse.json",
        "blueprint": BLUEPRINT_DIR / "ch04_broken_string_greenhouse_blueprint.json",
        "out": OUT_DIR / "demo_ch04_broken_string_greenhouse.generated.json",
        "runtime_id": "demo_ch04_broken_string_greenhouse_generated",
        "name": "断弦温室 自动生成灰盒",
        "art_theme": "string_greenhouse",
        "enemy_kinds": ["vine_crawler", "wax_bee", "root_cage_hunter", "pollen_lutist", "thorn_sentinel", "thorn_bloom_mote"],
        "materials": ("greenhouse_loam", "glassvine_bridge", "root_boss"),
        "colors": ("29422d", "426a4b", "3b4d31"),
        "next_id": "demo_ch05_obsidian_pilgrim_road_generated",
        "next_path": "res://data/generated/demo_ch05_obsidian_pilgrim_road.generated.json",
    },
    "ch05": {
        "source": GODOT_DATA_DIR / "demo_ch05_obsidian_pilgrim_road.json",
        "blueprint": BLUEPRINT_DIR / "ch05_obsidian_pilgrim_road_blueprint.json",
        "out": OUT_DIR / "demo_ch05_obsidian_pilgrim_road.generated.json",
        "runtime_id": "demo_ch05_obsidian_pilgrim_road_generated",
        "name": "黑曜朝圣路 自动生成灰盒",
        "art_theme": "obsidian_pilgrim",
        "enemy_kinds": ["obsidian_spearman", "phase_censor", "silent_bugbler", "kneeling_crossbowman", "pilgrim_chariot", "obsidian_bellwheel", "ash_banner_imp"],
        "materials": ("obsidian_basalt", "ember_bridge", "pilgrim_boss"),
        "colors": ("272734", "6e3d32", "3b3032"),
        "next_id": "demo_ch06_silent_crown_core_generated",
        "next_path": "res://data/generated/demo_ch06_silent_crown_core.generated.json",
    },
    "ch06": {
        "source": GODOT_DATA_DIR / "demo_ch06_silent_crown_core.json",
        "blueprint": BLUEPRINT_DIR / "ch06_silent_crown_core_blueprint.json",
        "out": OUT_DIR / "demo_ch06_silent_crown_core.generated.json",
        "runtime_id": "demo_ch06_silent_crown_core_generated",
        "name": "无声冠核 自动生成灰盒",
        "art_theme": "silent_crown",
        "enemy_kinds": ["echo_moss_larva", "echo_waterwheel_knight", "echo_contract_scribe", "echo_thorn_sentinel", "echo_pilgrim_commander_minor", "isotope_lumen", "delayed_shadow", "falling_clapper"],
        "materials": ("crown_bone", "void_bridge", "core_boss"),
        "colors": ("3c4358", "343a64", "3d4258"),
        "next_id": "",
        "next_path": "",
    },
}


ROOM_BASE_WIDTH = 500
ROOM_GAP = 64
BLUEPRINT_X_SCALE = 3.35
BLUEPRINT_Y_SCALE = 0.30
LOGIC_ROOM_WIDTH = 240
LOGIC_ROOM_GAP = 8
WORLD_HEIGHT = 1480
FALL_EXTRA = 180
LANE_Y = {
    "upper": 510,
    "main": 720,
    "lower": 930,
}
ROOM_KIND_FROM_ROLE = {
    "start": "gate",
    "hub": "field",
    "boss": "boss",
    "main_route": "field",
    "side_branch": "upper",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def ability_lookup(blueprint: dict[str, Any], chapter_id: str) -> dict[str, str]:
    return {str(name): f"{chapter_id}_ability_{index + 1}" for index, name in enumerate(blueprint.get("abilities", []))}


def build_room_layout(blueprint: dict[str, Any]) -> list[LayoutRoom]:
    rooms: list[LayoutRoom] = []
    logic_cursor = 0
    source_rooms = sorted(blueprint["rooms"], key=lambda item: int(item["index"]))
    source_x_values = [int(room.get("rect", {}).get("x", 0)) for room in source_rooms]
    min_source_x = min(source_x_values) if source_x_values else 0
    for i, room in enumerate(sorted(blueprint["rooms"], key=lambda item: int(item["index"]))):
        lane = str(room.get("lane", "main"))
        role = str(room.get("role", "side_branch"))
        source_rect = room.get("rect", {})
        width = ROOM_BASE_WIDTH + int(source_rect.get("w", 220)) // 4
        if role == "boss" or room.get("kind") == "boss":
            width = 980
        elif role == "main_route":
            width += 80
        source_x = int(source_rect.get("x", 0))
        source_y = int(source_rect.get("y", 1440))
        source_h = int(source_rect.get("h", 140))
        lane_nudge = {"upper": 30, "main": 0, "lower": 60}.get(lane, 0)
        role_nudge = {"hub": 28, "main_route": 0, "side_branch": 42, "boss": 86, "start": 0}.get(role, 0)
        x0 = 220 + int((source_x - min_source_x) * BLUEPRINT_X_SCALE) + lane_nudge + role_nudge
        x1 = x0 + width
        range_start = logic_cursor
        range_end = range_start + LOGIC_ROOM_WIDTH
        logic_cursor = range_end + LOGIC_ROOM_GAP
        floor_y = int(LANE_Y["main"] + (source_y + source_h - 1520) * BLUEPRINT_Y_SCALE)
        floor_y += {"upper": -20, "main": 0, "lower": 26}.get(lane, 0)
        floor_y = max(420, min(1040, floor_y))
        kind = ROOM_KIND_FROM_ROLE.get(role, "field")
        if room.get("kind") == "start":
            kind = "gate"
        if room.get("kind") == "boss":
            kind = "boss"
        depth = {"upper": -1, "main": 0, "lower": 1}.get(lane, 0)
        archetype = str(room.get("archetype") or ("boss_arena" if kind == "boss" else "main_spine"))
        rooms.append(
            LayoutRoom(
                id=str(room["id"]).lower().replace("-", "_"),
                name=str(room["name"]),
                index=int(room["index"]),
                cluster=str(room["cluster"]),
                lane=lane,
                role=role,
                kind=kind,
                archetype=archetype,
                design_goal=str(room.get("design_goal") or "Generated graybox room with a clear progression purpose."),
                traversal_focus=str(room.get("traversal_focus") or "walk_jump_dash pacing"),
                reward_contract=str(room.get("reward_contract") or "forward progress or optional reward"),
                pacing_role=str(room.get("pacing_role") or "expand_and_loop"),
                setpiece=str(room.get("setpiece") or ""),
                micro_objective=str(room.get("micro_objective") or ""),
                landmark=str(room.get("landmark") or ""),
                mechanic_prompt=str(room.get("mechanic_prompt") or ""),
                playtest_note=str(room.get("playtest_note") or ""),
                range_start=range_start,
                range_end=range_end,
                x0=x0,
                x1=x1,
                floor_y=floor_y,
                depth=depth,
                tags=[str(tag) for tag in room.get("tags", [])],
                placements=[str(pid) for pid in room.get("placements", [])],
            )
        )
    return rooms


def room_by_blueprint_id(layout_rooms: list[LayoutRoom], blueprint: dict[str, Any]) -> dict[str, LayoutRoom]:
    result: dict[str, LayoutRoom] = {}
    for source, room in zip(sorted(blueprint["rooms"], key=lambda item: int(item["index"])), layout_rooms):
        result[str(source["id"])] = room
    return result


def update_chapter_transition(config: dict[str, Any], chapter_cfg: dict[str, Any], layout_rooms: list[LayoutRoom]) -> None:
    transition = deepcopy(config.get("chapter_transition", {}))
    transition.update(
        {
            "from_runtime_config_id": chapter_cfg["runtime_id"],
            "to_runtime_config_id": chapter_cfg["next_id"],
            "next_config_path": chapter_cfg["next_path"],
            "exit_interactive_id": f"{layout_rooms[-1].id}_chapter_exit",
            "entry_spawn": [layout_rooms[0].x0 + 150, layout_rooms[0].floor_y - 40],
            "entry_hint": "自动生成章节出口：Boss 击败后进入下一章。",
        }
    )
    config["chapter_transition"] = transition


def build_generated_config(chapter_key: str) -> dict[str, Any]:
    chapter_cfg = CHAPTERS[chapter_key]
    source = load_json(chapter_cfg["source"])
    blueprint = load_json(chapter_cfg["blueprint"])
    layout_rooms = build_room_layout(blueprint)
    room_map = room_by_blueprint_id(layout_rooms, blueprint)
    room_map_by_id = {room.id: room for room in layout_rooms}
    ability_ids = ability_lookup(blueprint, chapter_key)
    config = deepcopy(source)
    config["id"] = chapter_cfg["runtime_id"]
    config["name"] = chapter_cfg["name"]
    config["map_title"] = chapter_cfg["name"]
    config["art_theme"] = chapter_cfg["art_theme"]
    config["progression_mode"] = "combat_clear"
    config["generation"] = {
        "source": "blueprint_to_godot_runtime.py",
        "blueprint": str(chapter_cfg["blueprint"].relative_to(ROOT)),
        "design_reference": "大体量银河恶魔城通用结构：主线、支线、能力门、捷径闭环、Boss 前短跑；不复刻商业地图。",
        "rooms": len(layout_rooms),
    }
    connections = make_connections(blueprint, room_map, chapter_key, ability_ids)
    annotate_shortcut_values(connections)
    locked_gates = make_locked_gates(connections, room_map_by_id, chapter_cfg)
    config["map_rooms"] = make_map_rooms(layout_rooms)
    config["connections"] = connections
    config["platforms"] = make_platforms(layout_rooms, chapter_cfg, connections)
    config["save_points"] = make_save_points(blueprint["points"], room_map)
    config["npcs"] = make_npcs(blueprint["points"], room_map)
    config["collectibles"] = make_collectibles(blueprint["points"], room_map, chapter_key, ability_ids)
    config["hazards"] = make_hazards(layout_rooms)
    config["enemy_spawns"] = make_enemy_spawns(source, layout_rooms, chapter_cfg)
    config["interactives"] = make_interactives(layout_rooms, blueprint, room_map, connections)
    config["locked_gates"] = locked_gates
    config["debug_map"] = make_debug_map(blueprint, layout_rooms, connections, locked_gates)
    config["parkour_segments"] = []
    config["labels"] = [
        {
            "text": "自动生成灰盒：红线主路、上下支线、捷径拉杆和能力回访门。",
            "position": [layout_rooms[0].x0 + 320, layout_rooms[0].floor_y - 260],
            "color": "9ef0dc",
        }
    ]
    world_width = max(max(room.x1 for room in layout_rooms), max(room.range_end for room in layout_rooms)) + 620
    config["world"] = {"width": world_width, "height": WORLD_HEIGHT, "fall_y": WORLD_HEIGHT + FALL_EXTRA}
    config["fall_y"] = WORLD_HEIGHT + FALL_EXTRA
    config["player_start"] = [layout_rooms[0].x0 + 120, layout_rooms[0].floor_y - 46]
    preboss = layout_rooms[-3]
    boss_room = layout_rooms[-1]
    config["boss_checkpoint"] = [preboss.x0 + 150, preboss.floor_y - 46]
    boss = deepcopy(config.get("boss", {}))
    boss.update(
        {
            "position": [boss_room.x0 + 520, boss_room.floor_y - 42],
            "platform_id": f"{boss_room.id}_floor",
            "arena_min_x": boss_room.x0 + 80,
            "arena_max_x": boss_room.x1 - 80,
        }
    )
    config["boss"] = boss
    update_chapter_transition(config, chapter_cfg, layout_rooms)
    entry = deepcopy(config.get("entry_from_previous", {}))
    entry["position"] = config["player_start"]
    entry["message"] = f"{chapter_cfg['name']}：自动生成灰盒入口。"
    config["entry_from_previous"] = entry
    config["goal"] = "穿过自动生成的大体量银河城灰盒：主线推进、支线奖励、捷径回环、Boss 前短跑。"
    return config


def main() -> None:
    written = {}
    for chapter_key in CHAPTERS:
        config = build_generated_config(chapter_key)
        out_path = CHAPTERS[chapter_key]["out"]
        write_json(out_path, config)
        written[chapter_key] = str(out_path)
    print(json.dumps({"ok": True, "written": written}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
