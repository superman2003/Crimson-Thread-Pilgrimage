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


@dataclass(frozen=True)
class LayoutRoom:
    id: str
    name: str
    index: int
    cluster: str
    lane: str
    role: str
    kind: str
    archetype: str
    design_goal: str
    traversal_focus: str
    reward_contract: str
    pacing_role: str
    setpiece: str
    micro_objective: str
    landmark: str
    mechanic_prompt: str
    playtest_note: str
    range_start: int
    range_end: int
    x0: int
    x1: int
    floor_y: int
    depth: int
    tags: list[str]
    placements: list[str]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def slug(value: str) -> str:
    raw = re.sub(r"[^A-Za-z0-9_]+", "_", value)
    raw = re.sub(r"_+", "_", raw).strip("_")
    return raw.lower() or "room"


def stable_id_part(value: str) -> str:
    raw = slug(value)
    if raw != "room":
        return raw
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:8]


def ability_lookup(blueprint: dict[str, Any], chapter_id: str) -> dict[str, str]:
    return {str(name): f"{chapter_id}_ability_{index + 1}" for index, name in enumerate(blueprint.get("abilities", []))}


def ability_item_id(chapter_id: str, ability_name: str, lookup: dict[str, str]) -> str:
    ability_name = str(ability_name)
    return lookup.get(ability_name, f"{chapter_id}_ability_{stable_id_part(ability_name)}")


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


def make_map_rooms(layout_rooms: list[LayoutRoom]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for room, next_room in zip(layout_rooms, layout_rooms[1:] + [None]):
        result.append(
            {
                "id": room.id,
                "name": room.name,
                "range": [room.range_start, room.range_end],
                "depth": room.depth,
                "kind": room.kind,
                "objective": f"{room.name}：按自动生成灰盒推进，识别主线、支线、捷径和回访门。",
                "guide": "红线主线转成连续地面；上下层支线以平台桥和竖井回接；奖励死胡同必须有道具或 NPC。",
                "danger": "支线房有更多陷阱和敌人，Boss 前 2-3 房保留短跑与存档。",
                "next": next_room.name if next_room else "章节出口",
                "cluster": room.cluster,
                "lane": room.lane,
                "role": room.role,
                "archetype": room.archetype,
                "design_goal": room.design_goal,
                "traversal_focus": room.traversal_focus,
                "reward_contract": room.reward_contract,
                "pacing_role": room.pacing_role,
                "setpiece": room.setpiece,
                "micro_objective": room.micro_objective,
                "landmark": room.landmark,
                "mechanic_prompt": room.mechanic_prompt,
                "playtest_note": room.playtest_note,
                "tags": room.tags,
                "layout_rect": [room.x0, room.floor_y - 235, room.x1 - room.x0, 325],
                "visit_rects": [[room.x0 - 18, room.floor_y - 255, room.x1 - room.x0 + 36, 365]],
            }
        )
    return result


def platform(platform_id: str, x: int, y: int, w: int, h: int, color: str, material: str) -> dict[str, Any]:
    return {"id": platform_id, "rect": [x, y, w, h], "color": color, "material": material}


def room_template(room: LayoutRoom) -> str:
    archetype_templates = {
        "entry_gate": "entry",
        "region_hub": "hub_loop",
        "main_spine": "through_hall",
        "vertical_shaft": "hook_ladder",
        "loop_gallery": "hub_loop",
        "reward_pocket": "reward_pocket",
        "ability_tutorial": "stair_hall",
        "shortcut_lock": "return_cave",
        "hidden_reward": "reward_pocket",
        "overlook_branch": "balcony",
        "return_passage": "return_cave",
        "preboss_run": "broken_bridge",
        "boss_arena": "arena",
    }
    if room.archetype in archetype_templates:
        return archetype_templates[room.archetype]
    if room.kind == "boss":
        return "arena"
    if room.kind == "gate":
        return "entry"
    if room.role == "hub":
        return "hub_loop"
    if room.lane == "upper":
        return ["balcony", "reward_pocket", "hook_ladder"][room.index % 3]
    if room.lane == "lower":
        return ["sunken_passage", "hazard_crawl", "return_cave"][room.index % 3]
    return ["through_hall", "broken_bridge", "stair_hall", "quiet_plateau"][room.index % 4]


def connection_progression(link_type: str) -> tuple[str, str, str]:
    if link_type in {"main", "main_route", "passage"}:
        return ("critical_path", "walk_jump_dash", "two_way")
    if link_type in {"local_branch", "side_room"}:
        return ("optional_branch", "walk_jump_dash", "two_way")
    if link_type == "shortcut":
        return ("opened_shortcut", "lever_or_backside_open", "one_way_until_open")
    if link_type == "ability_gate":
        return ("ability_locked", "requires_ability", "locked_until_ability")
    return ("supporting_link", "walk_jump_dash", "two_way")


def add_room_platforms(
    platforms: list[dict[str, Any]],
    room: LayoutRoom,
    main_color: str,
    bridge_color: str,
    boss_color: str,
    main_material: str,
    bridge_material: str,
    boss_material: str,
) -> None:
    width = room.x1 - room.x0
    mat = boss_material if room.kind == "boss" else main_material
    color = boss_color if room.kind == "boss" else main_color
    platforms.append(platform(f"{room.id}_floor", room.x0, room.floor_y, width, 44, color, mat))

    template = room_template(room)
    ledges: list[tuple[str, float, int, float]] = []
    if room.setpiece == "moss_bell_entry_silhouette":
        ledges = [("safe_read_lip", 0.18, -78, 0.22), ("first_landmark_lip", 0.62, -154, 0.20)]
    elif room.setpiece == "first_overlook_save_balcony":
        ledges = [("save_balcony", 0.10, -128, 0.34), ("locked_route_preview", 0.64, -232, 0.18)]
    elif room.setpiece == "cartographer_lower_pocket":
        ledges = [("npc_porch", 0.16, -82, 0.26), ("return_step", 0.58, -162, 0.20)]
    elif room.setpiece == "first_backside_shortcut_lock":
        ledges = [("sealed_gate_read", 0.18, -108, 0.26), ("return_shelf", 0.58, -184, 0.24)]
    elif room.setpiece == "moss_bell_court_hub":
        ledges = [("hub_left_exit", 0.08, -86, 0.22), ("hub_high_route", 0.40, -186, 0.22), ("hub_right_exit", 0.72, -94, 0.20)]
    elif room.setpiece == "visible_upper_shaft_goal":
        ledges = [("shaft_foothold_1", 0.15, -84, 0.16), ("shaft_foothold_2", 0.42, -174, 0.16), ("shaft_preview_lip", 0.70, -276, 0.18)]
    elif room.setpiece == "bell_shaft_midpoint_reward":
        ledges = [("reward_midrib", 0.26, -126, 0.24), ("lower_return_hint", 0.62, -224, 0.18)]
    elif room.setpiece == "shaft_return_shortcut_lock":
        ledges = [("root_gate_floor", 0.12, -74, 0.24), ("backflow_step", 0.48, -154, 0.22), ("upper_memory", 0.72, -246, 0.16)]
    elif room.setpiece == "rain_canopy_loop_hub":
        ledges = [("upper_canopy_read", 0.12, -132, 0.24), ("main_canopy_bridge", 0.42, -82, 0.30), ("lower_return_read", 0.74, -170, 0.16)]
    elif room.setpiece == "first_ability_tutorial_span":
        ledges = [("ability_pickup_dais", 0.18, -92, 0.22), ("safe_span_mid", 0.48, -162, 0.16), ("tutorial_exit", 0.73, -96, 0.20)]
    elif room.setpiece == "loop_gallery_npc_crossroads":
        ledges = [("npc_crossroad", 0.16, -90, 0.24), ("upper_loop_sign", 0.45, -190, 0.20), ("lower_loop_exit", 0.72, -116, 0.18)]
    elif room.setpiece == "upper_reward_rain_bell":
        ledges = [("reward_perch", 0.18, -178, 0.24), ("drop_return", 0.58, -84, 0.24)]
    elif room.setpiece == "canopy_shortcut_lever_room":
        ledges = [("lever_stage", 0.20, -90, 0.26), ("grate_view", 0.58, -184, 0.24)]
    elif room.setpiece == "root_well_miniboss_foyer":
        ledges = [("elite_left", 0.12, -106, 0.18), ("well_mid", 0.42, -174, 0.22), ("elite_right", 0.72, -106, 0.18)]
    elif room.setpiece == "root_well_recovery_save":
        ledges = [("save_alcove", 0.16, -86, 0.26), ("reward_choice_lip", 0.60, -168, 0.22)]
    elif room.setpiece == "second_ability_gate_lesson":
        ledges = [("lesson_start", 0.12, -78, 0.22), ("split_floor", 0.42, -156, 0.18), ("return_lip", 0.70, -228, 0.18)]
    elif room.setpiece == "final_key_memory_room":
        ledges = [("key_niche", 0.20, -116, 0.24), ("boss_route_arrow", 0.58, -208, 0.20)]
    elif room.setpiece == "boss_run_short_save":
        ledges = [("quiet_bench_lip", 0.18, -74, 0.24), ("boss_silhouette_read", 0.60, -168, 0.22)]
    elif template == "entry":
        ledges = [("porch", 0.18, -92, 0.28), ("bell_lip", 0.58, -164, 0.22)]
    elif template == "arena":
        ledges = [("left_perch", 0.12, -118, 0.18), ("right_perch", 0.70, -118, 0.18), ("high_lip", 0.43, -232, 0.16)]
    elif template == "hub_loop":
        ledges = [("hub_low", 0.10, -86, 0.26), ("hub_mid", 0.38, -166, 0.30), ("hub_return", 0.70, -248, 0.20)]
    elif template == "balcony":
        ledges = [("balcony_run", 0.18, -126, 0.42)]
    elif template == "reward_pocket":
        ledges = [("pocket_step", 0.12, -94, 0.20), ("pocket_nest", 0.56, -218, 0.26)]
    elif template == "hook_ladder":
        ledges = [("hook_1", 0.18, -82, 0.18), ("hook_2", 0.46, -170, 0.18), ("hook_3", 0.72, -258, 0.16)]
    elif template == "sunken_passage":
        ledges = [("sunken_shelf", 0.46, -92, 0.30)]
    elif template == "hazard_crawl":
        ledges = [("crawl_safety", 0.15, -122, 0.24), ("crawl_exit", 0.65, -76, 0.22)]
    elif template == "return_cave":
        ledges = [("return_ledge", 0.22, -152, 0.22), ("return_cap", 0.62, -238, 0.18)]
    elif template == "broken_bridge":
        ledges = [("broken_left", 0.12, -116, 0.18), ("broken_right", 0.66, -128, 0.22)]
    elif template == "stair_hall":
        ledges = [("stair_low", 0.18, -82, 0.18), ("stair_mid", 0.42, -158, 0.18), ("stair_top", 0.66, -234, 0.18)]
    elif template == "quiet_plateau":
        ledges = [("plateau", 0.35, -144, 0.30)]
    else:
        ledges = [("hall_lip", 0.48, -138, 0.30)]

    for suffix, rel_x, rel_y, rel_w in ledges:
        platforms.append(
            platform(
                f"{room.id}_{suffix}",
                room.x0 + int(width * rel_x),
                room.floor_y + rel_y,
                max(110, int(width * rel_w)),
                28,
                bridge_color,
                bridge_material,
            )
        )


def add_connection_support(
    platforms: list[dict[str, Any]],
    a: LayoutRoom,
    b: LayoutRoom,
    link_type: str,
    bridge_color: str,
    bridge_material: str,
) -> None:
    should_bridge = link_type in {"main", "main_route", "passage", "local_branch", "side_room"}
    if not should_bridge:
        return
    left = min(a.x1, b.x1)
    right = max(a.x0, b.x0)
    v_delta = abs(a.floor_y - b.floor_y)
    if v_delta > 118:
        a_center = (a.x0 + a.x1) / 2
        b_center = (b.x0 + b.x1) / 2
        if b.x0 > a.x1:
            start_x = a.x1
            end_x = b.x0
        elif a.x0 > b.x1:
            start_x = a.x0
            end_x = b.x1
        else:
            start_x = a_center
            end_x = b_center
        h_span = abs(end_x - start_x)
        count = max(2, math.ceil(v_delta / 96), math.ceil(h_span / 220))
        for index in range(count):
            t = (index + 1) / (count + 1)
            px = int(start_x + (end_x - start_x) * t - 68)
            py = int(a.floor_y + (b.floor_y - a.floor_y) * t)
            platforms.append(platform(f"step_{a.id}_to_{b.id}_{index+1}", px, py, 136, 24, bridge_color, bridge_material))
        return
    if b.x0 > a.x1:
        gap = b.x0 - a.x1
        if gap <= 210 and v_delta <= 84:
            return
        x = a.x1 - 18
        y = max(a.floor_y, b.floor_y) + 8
        if gap > 320:
            count = max(2, math.ceil(gap / 235))
            for index in range(count):
                t = (index + 1) / (count + 1)
                px = int(a.x1 + gap * t - 68)
                py = int(a.floor_y + (b.floor_y - a.floor_y) * t + 8)
                platforms.append(platform(f"bridge_{a.id}_to_{b.id}_{index+1}", px, py, 136, 24, bridge_color, bridge_material))
            step_x = int(a.x1 + gap / max(2, count))
        else:
            w = max(72, min(gap + 36, 260))
            platforms.append(platform(f"bridge_{a.id}_to_{b.id}", x, y, w, 24, bridge_color, bridge_material))
            step_x = x + max(80, w // 3)
    elif a.x0 > b.x1:
        gap = a.x0 - b.x1
        if gap <= 210 and v_delta <= 84:
            return
        x = b.x1 - 18
        y = max(a.floor_y, b.floor_y) + 8
        if gap > 320:
            count = max(2, math.ceil(gap / 235))
            for index in range(count):
                t = (index + 1) / (count + 1)
                px = int(b.x1 + gap * t - 68)
                py = int(b.floor_y + (a.floor_y - b.floor_y) * t + 8)
                platforms.append(platform(f"bridge_{a.id}_to_{b.id}_{index+1}", px, py, 136, 24, bridge_color, bridge_material))
            step_x = int(b.x1 + gap / max(2, count))
        else:
            w = max(72, min(gap + 36, 260))
            platforms.append(platform(f"bridge_{a.id}_to_{b.id}", x, y, w, 24, bridge_color, bridge_material))
            step_x = x + max(80, w // 3)
    else:
        if v_delta <= 118 and link_type != "local_branch":
            return
        overlap_width = max(0, left - right)
        overlap_x = right + max(120, overlap_width // 2)
        y = max(a.floor_y, b.floor_y) + 8
        platforms.append(platform(f"shaft_bridge_{a.id}_to_{b.id}", overlap_x - 82, y, 164, 24, bridge_color, bridge_material))
        step_x = overlap_x - 84
    if v_delta > 118:
        high_y = min(a.floor_y, b.floor_y)
        low_y = max(a.floor_y, b.floor_y)
        step = 112
        count = max(1, math.ceil((low_y - high_y) / step) - 1)
        for index in range(count):
            yy = high_y + step * (index + 1)
            platforms.append(platform(f"step_{a.id}_to_{b.id}_{index+1}", step_x + (index % 2) * 112, yy, 136, 24, bridge_color, bridge_material))


def make_platforms(layout_rooms: list[LayoutRoom], chapter_cfg: dict[str, Any], connections: list[dict[str, Any]]) -> list[dict[str, Any]]:
    main_material, bridge_material, boss_material = chapter_cfg["materials"]
    main_color, bridge_color, boss_color = chapter_cfg["colors"]
    platforms: list[dict[str, Any]] = []
    by_id = {room.id: room for room in layout_rooms}
    for room in layout_rooms:
        add_room_platforms(platforms, room, main_color, bridge_color, boss_color, main_material, bridge_material, boss_material)

    supported = set()
    for link in connections:
        a = by_id.get(str(link.get("from")))
        b = by_id.get(str(link.get("to")))
        if a is None or b is None:
            continue
        key = tuple(sorted([a.id, b.id]))
        if key in supported:
            continue
        supported.add(key)
        add_connection_support(platforms, a, b, str(link.get("type", "")), bridge_color, bridge_material)
    return platforms


def point_room(point: dict[str, Any], room_map: dict[str, LayoutRoom]) -> LayoutRoom:
    room_id = str(point["room"])
    if room_id not in room_map:
        raise KeyError(room_id)
    return room_map[room_id]


def point_position(room: LayoutRoom, offset_index: int = 0) -> list[int]:
    width = room.x1 - room.x0
    x = room.x0 + int(width * (0.28 + 0.16 * (offset_index % 3)))
    y = room.floor_y - 42 - 18 * (offset_index // 3)
    return [x, y]


def make_save_points(points: dict[str, Any], room_map: dict[str, LayoutRoom]) -> list[dict[str, Any]]:
    result = []
    for i, point in enumerate(points.get("saves", [])):
        room = point_room(point, room_map)
        result.append(
            {
                "id": f"save_{room.id}_{i+1}",
                "label": str(point.get("note") or point.get("label") or f"S{i+1}"),
                "position": point_position(room, i),
                "hidden": "hidden" in str(point.get("note", "")).lower(),
                "note": str(point.get("note", "自动生成存档点")),
            }
        )
    return result


def make_npcs(points: dict[str, Any], room_map: dict[str, LayoutRoom]) -> list[dict[str, Any]]:
    roles = ["cartographer", "pilgrim", "threadsmith", "route_hint", "vendor_sidequest", "main_witness"]
    result = []
    for i, point in enumerate(points.get("npcs", [])):
        room = point_room(point, room_map)
        result.append(
            {
                "id": f"npc_{room.id}_{i+1}",
                "name": f"地图证人{i+1}",
                "position": point_position(room, i),
                "role": roles[i % len(roles)],
                "dialogue": [
                    "这片区域不是直线，记住回来的门。",
                    "走到死路时先找奖励，再看有没有从背面开的捷径。",
                    "Boss 前的短路已经留好，别把长回跑当成难度。",
                ],
                "identity": "自动生成灰盒 NPC，用于提示路线与能力回访。",
                "motive": "帮助玩家理解大地图回环。",
                "help": "提示主线、支线、捷径和奖励死胡同。",
            }
        )
    return result


def make_collectibles(
    points: dict[str, Any],
    room_map: dict[str, LayoutRoom],
    chapter_id: str,
    ability_ids: dict[str, str],
) -> list[dict[str, Any]]:
    result = []
    for i, point in enumerate(points.get("rewards", [])):
        room = point_room(point, room_map)
        result.append(
            {
                "id": f"reward_{chapter_id}_{i+1:02d}",
                "kind": "currency",
                "room_id": room.id,
                "position": point_position(room, i),
                "amount": 8 + (i % 4) * 4,
                "label": str(point.get("label", f"R{i+1}")),
                "note": str(point.get("note", "自动生成支线奖励")),
            }
        )
    for i, point in enumerate(points.get("abilities", [])):
        room = point_room(point, room_map)
        ability_name = str(point.get("note", point.get("label", "ability")))
        result.append(
            {
                "id": f"ability_{chapter_id}_{i+1:02d}",
                "kind": "item",
                "room_id": room.id,
                "item_id": ability_item_id(chapter_id, ability_name, ability_ids),
                "position": point_position(room, i + 4),
                "ability_name": ability_name,
                "label": str(point.get("note", point.get("label", "能力"))),
                "note": "自动生成能力门钥记。",
            }
        )
    return result


def make_hazards(layout_rooms: list[LayoutRoom]) -> list[dict[str, Any]]:
    result = []
    for room in layout_rooms:
        if room.kind in {"gate", "safe"}:
            continue
        width = room.x1 - room.x0
        if room.index % 3 == 0 or room.kind == "boss":
            result.append(
                {
                    "id": f"hazard_{room.id}_spikes",
                    "kind": "spikes",
                    "rect": [room.x0 + int(width * 0.34), room.floor_y - 18, int(width * 0.18), 24],
                    "position": [room.x0 + int(width * 0.43), room.floor_y - 8],
                    "damage": 1,
                    "message": "自动生成灰盒危险区：跳过或从上层绕行。",
                }
            )
    return result


def enemy_template(source: dict[str, Any]) -> dict[str, dict[str, Any]]:
    templates = {}
    for enemy in source.get("enemy_spawns", []):
        kind = str(enemy.get("kind", ""))
        if kind and kind not in templates:
            templates[kind] = deepcopy(enemy)
    return templates


def make_enemy_spawns(source: dict[str, Any], layout_rooms: list[LayoutRoom], chapter_cfg: dict[str, Any]) -> list[dict[str, Any]]:
    templates = enemy_template(source)
    result = []
    enemy_kinds = chapter_cfg["enemy_kinds"]
    counter = 1
    for room in layout_rooms:
        if room.kind in {"gate", "safe", "boss", "exit"}:
            continue
        count = 0
        if room.role == "main_route" and room.index % 3 != 1:
            count = 1
        elif room.role == "hub" and room.index % 2 == 0:
            count = 1
        elif room.role == "side_branch" and room.index % 4 in {0, 3}:
            count = 1
        if room.index % 13 == 0 and room.role != "side_branch":
            count += 1
        for local in range(count):
            kind = enemy_kinds[(room.index + local) % len(enemy_kinds)]
            template = deepcopy(templates.get(kind) or next(iter(templates.values()), {}))
            if not template:
                template = {
                    "kind": kind,
                    "sprite_region": [0, 0, 128, 128],
                    "visual_scale": 0.82,
                    "visual_offset": [0, -8],
                    "patrol": 90,
                    "leash_radius": 220,
                    "spawn_half_width": 36,
                    "spawn_visual_height": 58,
                }
            template["id"] = f"{chapter_cfg['runtime_id']}_E{counter:03d}"
            template["kind"] = kind
            width = room.x1 - room.x0
            template["position"] = [room.x0 + int(width * (0.34 + local * 0.24)), room.floor_y - 24]
            template["platform_id"] = f"{room.id}_floor"
            template["patrol"] = 80 + 18 * ((room.index + local) % 3)
            result.append(template)
            counter += 1
    return result


def make_interactives(
    layout_rooms: list[LayoutRoom],
    blueprint: dict[str, Any],
    room_map: dict[str, LayoutRoom],
    connections: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    result = []
    shortcut_connections = {(link["from"], link["to"]): link for link in connections if link.get("type") == "shortcut"}
    for i, shortcut in enumerate(blueprint.get("connections", {}).get("shortcuts", [])[:8]):
        target_id = str(shortcut.get("from"))
        if target_id not in room_map:
            continue
        room = room_map[target_id]
        to_id = str(shortcut.get("to", "")).lower().replace("-", "_")
        shortcut_connection = shortcut_connections.get((room.id, to_id), {})
        result.append(
            {
                "id": f"shortcut_lever_{i+1:02d}",
                "kind": "lever",
                "position": point_position(room, i),
                "requires_keys": 0,
                "label": f"捷径拉杆 {i+1}",
                "opens_connection": {
                    "from": room.id,
                    "to": to_id,
                    "id": shortcut_connection.get("id", ""),
                    "initial_directionality": shortcut_connection.get("initial_directionality", ""),
                    "opened_directionality": shortcut_connection.get("opened_directionality", ""),
                },
                "shortcut_id": shortcut_connection.get("shortcut_id", ""),
            }
        )
    exit_room = layout_rooms[-1]
    result.append(
        {
            "id": f"{exit_room.id}_chapter_exit",
            "kind": "chapter_exit",
            "position": [exit_room.x1 - 220, exit_room.floor_y - 36],
            "requires_boss_defeated": True,
            "label": "章节出口",
        }
    )
    return result


def make_connections(
    blueprint: dict[str, Any],
    room_map: dict[str, LayoutRoom],
    chapter_id: str,
    ability_ids: dict[str, str],
) -> list[dict[str, Any]]:
    result = []
    seen = set()
    for group_name, links in blueprint.get("connections", {}).items():
        if group_name == "hidden":
            continue
        for link in links:
            a = str(link.get("from"))
            b = str(link.get("to"))
            if a not in room_map or b not in room_map:
                continue
            link_type = str(link.get("type", group_name))
            key = (room_map[a].id, room_map[b].id, link_type)
            if key in seen:
                continue
            seen.add(key)
            progression_tier, traversal, directionality = connection_progression(link_type)
            connection = {
                "id": f"conn_{key[0]}_{key[1]}_{link_type}",
                "from": key[0],
                "to": key[1],
                "type": link_type,
                "group": group_name,
                "note": str(link.get("note", "")),
                "progression_tier": progression_tier,
                "traversal": traversal,
                "directionality": directionality,
                "requires_unlock": link_type in {"shortcut", "ability_gate"},
                "ability": str(link.get("ability", "")),
            }
            if link_type == "ability_gate":
                ability_name = str(link.get("ability", ""))
                gate_id = f"gate_{key[0]}_to_{key[1]}_{stable_id_part(ability_name)}"
                connection.update(
                    {
                        "gate_id": gate_id,
                        "locked": True,
                        "required_ability": ability_item_id(chapter_id, ability_name, ability_ids),
                        "required_ability_name": ability_name,
                    }
                )
            if link_type == "shortcut":
                connection.update(
                    {
                        "shortcut_id": f"shortcut_{key[0]}_to_{key[1]}",
                        "opens_from_room": key[0],
                        "return_to_room": key[1],
                        "initial_directionality": "from_to_only",
                        "opened_directionality": "two_way",
                    }
                )
            result.append(connection)
    return result


def shortest_room_distance(connections: list[dict[str, Any]], start: str, target: str, opened_shortcut_id: str | None = None) -> int | None:
    graph: dict[str, set[str]] = {}
    for connection in connections:
        a = str(connection.get("from", ""))
        b = str(connection.get("to", ""))
        if not a or not b:
            continue
        graph.setdefault(a, set())
        graph.setdefault(b, set())
        link_type = str(connection.get("type", ""))
        graph[a].add(b)
        if link_type != "shortcut" or connection.get("shortcut_id") == opened_shortcut_id:
            graph[b].add(a)
    queue: deque[tuple[str, int]] = deque([(start, 0)])
    seen = {start}
    while queue:
        node, dist = queue.popleft()
        if node == target:
            return dist
        for nxt in graph.get(node, set()):
            if nxt not in seen:
                seen.add(nxt)
                queue.append((nxt, dist + 1))
    return None


def annotate_shortcut_values(connections: list[dict[str, Any]]) -> None:
    for connection in connections:
        if connection.get("type") != "shortcut":
            continue
        shortcut_id = str(connection.get("shortcut_id", ""))
        from_room = str(connection.get("from", ""))
        to_room = str(connection.get("to", ""))
        before = shortest_room_distance(connections, to_room, from_room, None)
        after = shortest_room_distance(connections, to_room, from_room, shortcut_id)
        distance_saved = 0 if before is None or after is None else max(0, before - after)
        connection["shortcut_value"] = {
            "metric": "room_steps_saved",
            "from_room": from_room,
            "return_to_room": to_room,
            "before_open": before,
            "after_open": after,
            "distance_saved": distance_saved,
        }


def make_locked_gates(connections: list[dict[str, Any]], room_map_by_id: dict[str, LayoutRoom], chapter_cfg: dict[str, Any]) -> list[dict[str, Any]]:
    gates: list[dict[str, Any]] = []
    _main_material, bridge_material, _boss_material = chapter_cfg["materials"]
    _main_color, _bridge_color, boss_color = chapter_cfg["colors"]
    for connection in connections:
        if connection.get("type") != "ability_gate":
            continue
        target = room_map_by_id.get(str(connection.get("to")))
        if target is None:
            continue
        gate_x = target.x0 + 26
        gates.append(
            {
                "id": connection["gate_id"],
                "connection_id": connection["id"],
                "from": connection["from"],
                "to": connection["to"],
                "required_ability": connection["required_ability"],
                "required_ability_name": connection["required_ability_name"],
                "rect": [gate_x, target.floor_y - 150, 34, 150],
                "color": boss_color,
                "material": bridge_material,
                "map_marker": "ability_gate",
            }
        )
    return gates


def make_debug_map(
    blueprint: dict[str, Any],
    layout_rooms: list[LayoutRoom],
    connections: list[dict[str, Any]],
    locked_gates: list[dict[str, Any]],
) -> dict[str, Any]:
    counters: dict[str, int] = {}
    for connection in connections:
        tier = str(connection.get("progression_tier", "unknown"))
        counters[tier] = counters.get(tier, 0) + 1
    return {
        "source_blueprint": blueprint.get("id", ""),
        "legend": {
            "critical_path": "main route available before upgrades",
            "optional_branch": "side branch reachable by base movement",
            "opened_shortcut": "shortcut opened from the far side or lever",
            "ability_locked": "backtrack gate requiring a chapter ability",
        },
        "connection_counts": counters,
        "main_route": [link["id"] for link in connections if link.get("progression_tier") == "critical_path"],
        "side_branches": [link["id"] for link in connections if link.get("progression_tier") == "optional_branch"],
        "shortcuts": [link["id"] for link in connections if link.get("progression_tier") == "opened_shortcut"],
        "ability_gates": [
            {
                "connection_id": gate["connection_id"],
                "gate_id": gate["id"],
                "from": gate["from"],
                "to": gate["to"],
                "required_ability": gate["required_ability"],
                "required_ability_name": gate["required_ability_name"],
            }
            for gate in locked_gates
        ],
        "room_centers": {
            room.id: [int((room.x0 + room.x1) / 2), int(room.floor_y - 120)]
            for room in layout_rooms
        },
    }


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
