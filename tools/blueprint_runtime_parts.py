"""Turning blueprint rooms into runtime parts: platforms, connection supports, save points, NPCs, collectibles, hazards, enemies, interactives and gates.

Moved out of blueprint_to_godot_runtime.py unchanged; blueprint_to_godot_runtime.py imports these names back."""
from __future__ import annotations
import hashlib
import math
import re
from copy import deepcopy
from dataclasses import dataclass
from typing import Any
from collections import deque


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


def slug(value: str) -> str:
    raw = re.sub(r"[^A-Za-z0-9_]+", "_", value)
    raw = re.sub(r"_+", "_", raw).strip("_")
    return raw.lower() or "room"


def stable_id_part(value: str) -> str:
    raw = slug(value)
    if raw != "room":
        return raw
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:8]


def ability_item_id(chapter_id: str, ability_name: str, lookup: dict[str, str]) -> str:
    ability_name = str(ability_name)
    return lookup.get(ability_name, f"{chapter_id}_ability_{stable_id_part(ability_name)}")


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
                "danger": "支线房有更多敌人，Boss 前 2-3 房保留短跑与存档。",
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
    # Level traps were retired; keep the schema readable by old consumers.
    return []


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
