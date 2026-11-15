from __future__ import annotations

import json
import math
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont
from blueprint_rendering import (CANVAS_H, CANVAS_W, CLUSTER_COLORS, DOC_PLAN_DIR, DOC_SPEC_DIR,
    FONT_BODY, FONT_H2, FONT_SMALL, FONT_TINY, FONT_TITLE, OUTPUT_SCALE, OVERVIEW_H, OVERVIEW_W,
    PALETTE, ROOT, Room, center, draw_arrow, draw_badge, draw_cluster_background, draw_connections,
    draw_legend, draw_points, draw_room, load_font, render_blueprint, render_overview, room_rect,
    text, write_docs)
from blueprint_data import (CH01_VERTICAL_SLICE_ROOMS, CHAPTERS, ROOM_ARCHETYPE_RULES)


OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "silksong_scale"


def timestamp() -> str:
    return datetime.now().strftime("%Y%m%d%H%M%S%f")[:-3]


def ensure_dirs() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    DOC_SPEC_DIR.mkdir(parents=True, exist_ok=True)
    DOC_PLAN_DIR.mkdir(parents=True, exist_ok=True)


CLUSTER_SHAPES = [
    "entry_spine",
    "tall_shaft",
    "loop_gallery",
    "reward_cave",
    "wide_canal",
    "boss_run",
]


CLUSTER_MACRO_RULES = {
    "entry_spine": "early readable spine with a few visible branches",
    "tall_shaft": "vertical memory anchor that later abilities compress",
    "loop_gallery": "wide loop that returns to a known room",
    "reward_cave": "optional pocket cluster with risk/reward exits",
    "wide_canal": "horizontal travel band broken by vertical callbacks",
    "boss_run": "late gauntlet with short save-to-boss runback",
}


def ch01_event_contract(room_index: int, setpiece: dict[str, str]) -> dict[str, str]:
    setpiece_id = str(setpiece.get("setpiece", ""))
    if not setpiece_id:
        return {
            "event_type": "",
            "event_trigger": "",
            "event_feedback": "",
            "event_validation": "",
        }
    if "ability" in setpiece_id or "key_memory" in setpiece_id:
        event_type = "ability_lesson"
        trigger = "Collect the room item, then cross or reopen the paired route."
        feedback = "Map panel shows the ability setpiece and the nearby gate becomes understandable."
        validation = "Ability pickup is present and the room has a micro objective."
    elif "shortcut" in setpiece_id or "lever" in setpiece_id:
        event_type = "shortcut_payoff"
        trigger = "Reach the far side or lever side of a previously seen shortcut."
        feedback = "Shortcut counter increases and the route probe confirms travel compression."
        validation = "Room participates in a shortcut connection or lever route."
    elif "npc" in setpiece_id or "cartographer" in setpiece_id:
        event_type = "npc_route_hint"
        trigger = "Talk to the local route witness before committing to the branch."
        feedback = "NPC text reinforces loop, reward, or return-path logic."
        validation = "NPC placement exists in or near the setpiece room."
    elif "reward" in setpiece_id:
        event_type = "visible_reward"
        trigger = "See the reward before committing to the side challenge."
        feedback = "Reward is reachable without turning the branch into a blind dead end."
        validation = "Reward placement exists in or near the setpiece room."
    elif "save" in setpiece_id or "overlook" in setpiece_id:
        event_type = "save_and_read"
        trigger = "Reach a safe point and read the next route silhouette."
        feedback = "Save point and map text lower risk before a route decision."
        validation = "Save placement exists in or near the setpiece room."
    elif "miniboss" in setpiece_id:
        event_type = "combat_pressure"
        trigger = "Enter the arena-like foyer after learning the route language."
        feedback = "Enemy pressure rises without confusing the navigation goal."
        validation = "Miniboss or enemy pressure is associated with the setpiece."
    elif "hub" in setpiece_id:
        event_type = "route_choice"
        trigger = "Enter a room with at least two readable exits."
        feedback = "Map text names branch, return, and main-route responsibilities."
        validation = "Room has multiple connections and a landmark."
    else:
        event_type = "landmark_read"
        trigger = "Enter the room and read its landmark before moving on."
        feedback = "Map panel exposes setpiece, landmark, and micro objective."
        validation = "Setpiece room has a complete design contract."
    return {
        "event_type": event_type,
        "event_trigger": trigger,
        "event_feedback": feedback,
        "event_validation": validation if isinstance(validation, str) else str(validation),
    }


def room_lane_for_shape(shape: str, local: int, cluster_count: int) -> str:
    patterns = {
        "entry_spine": ["main", "main", "upper", "main", "lower", "main", "upper"],
        "tall_shaft": ["main", "upper", "upper", "main", "lower", "lower", "main"],
        "loop_gallery": ["main", "upper", "main", "lower", "main", "upper", "lower"],
        "reward_cave": ["main", "lower", "lower", "main", "upper", "main", "lower"],
        "wide_canal": ["main", "main", "lower", "main", "upper", "main", "main"],
        "boss_run": ["main", "upper", "main", "main", "lower", "main", "upper"],
    }
    lane = patterns[shape][local % len(patterns[shape])]
    if local == 0 or local == cluster_count - 1:
        return "main"
    return lane


def room_design_contract(
    kind: str,
    shape: str,
    lane: str,
    local: int,
    cluster_count: int,
    room_index: int,
    room_count: int,
) -> dict[str, str]:
    if kind == "start":
        archetype = "entry_gate"
    elif kind == "boss":
        archetype = "boss_arena"
    elif room_index >= room_count - 2:
        archetype = "preboss_run"
    elif room_index in {16, 33, 52}:
        archetype = "ability_tutorial"
    elif room_index % 7 == 0:
        archetype = "shortcut_lock"
    elif local == 0:
        archetype = "region_hub"
    elif local == cluster_count - 1 and room_index % 2 == 1:
        archetype = "hidden_reward"
    elif shape == "tall_shaft":
        archetype = "vertical_shaft"
    elif shape == "loop_gallery":
        archetype = "loop_gallery"
    elif shape == "reward_cave":
        archetype = "reward_pocket"
    elif lane != "main" and room_index % 5 == 0:
        archetype = "reward_pocket"
    elif lane == "upper":
        archetype = "overlook_branch"
    elif lane == "lower":
        archetype = "return_passage"
    else:
        archetype = "main_spine"

    rule = ROOM_ARCHETYPE_RULES[archetype]
    if room_index <= max(8, room_count // 8):
        pacing = "teach_and_orient"
    elif room_index >= room_count - 6:
        pacing = "boss_pressure"
    elif archetype in {"reward_pocket", "hidden_reward", "overlook_branch"}:
        pacing = "optional_breath"
    elif archetype in {"ability_tutorial", "shortcut_lock"}:
        pacing = "unlock_and_return"
    else:
        pacing = "expand_and_loop"
    return {
        "archetype": archetype,
        "design_goal": rule["goal"],
        "traversal_focus": rule["traversal"],
        "reward_contract": rule["reward"],
        "pacing_role": pacing,
    }


def natural_room_position(shape: str, base_x: int, base_y: int, local: int, lane: str, ci: int) -> tuple[int, int]:
    lane_offset = {"upper": -420, "main": 0, "lower": 420}[lane]
    jitter_x = ((local * 37 + ci * 23) % 74) - 37
    jitter_y = ((local * 29 + ci * 17) % 66) - 33
    if shape == "entry_spine":
        x = base_x + local * 170 + jitter_x
        y = base_y + lane_offset + int(math.sin((local + ci) * 0.9) * 76) + jitter_y
    elif shape == "tall_shaft":
        column = local % 3
        tier = local // 3
        x = base_x + column * 155 + tier * 78 + jitter_x
        y = base_y - 510 + local * 190 + jitter_y
    elif shape == "loop_gallery":
        loop = [
            (0, 0),
            (150, -360),
            (420, -410),
            (610, -80),
            (520, 300),
            (210, 365),
            (-40, 120),
        ][local % 7]
        wrap = (local // 7) * 185
        x = base_x + loop[0] + wrap + jitter_x
        y = base_y + loop[1] + jitter_y
    elif shape == "reward_cave":
        pocket = [
            (0, 0),
            (190, 350),
            (430, 470),
            (650, 80),
            (480, -300),
            (750, -170),
            (910, 170),
        ][local % 7]
        x = base_x + pocket[0] + jitter_x
        y = base_y + pocket[1] + jitter_y
    elif shape == "wide_canal":
        x = base_x + local * 210 + jitter_x
        y = base_y + lane_offset * 0.58 + int(math.sin(local * 1.35 + ci) * 96) + jitter_y
    else:
        x = base_x + local * 185 + jitter_x
        y = base_y + lane_offset * 0.45 + max(-90, 170 - local * 62) + jitter_y
    return int(x), int(y)


def generate_rooms(chapter: dict[str, Any]) -> list[Room]:
    rooms: list[Room] = []
    clusters = chapter["clusters"]
    count = int(chapter["room_count"])
    cols = min(12, len(clusters))
    margin_x = 260
    cell_w = (CANVAS_W - margin_x * 2) // cols
    index = 1

    for ci, cluster in enumerate(clusters):
        base = count // len(clusters)
        extra = 1 if ci < count % len(clusters) else 0
        cluster_count = base + extra
        col = ci % cols
        shape = CLUSTER_SHAPES[ci % len(CLUSTER_SHAPES)]
        base_x = margin_x + col * cell_w + [0, -40, 35, -25, 52, -12][ci % 6]
        base_y = 1460 + [0, -120, 95, 160, -60, 45][ci % 6]

        for local in range(cluster_count):
            lane = room_lane_for_shape(shape, local, cluster_count)
            x, y = natural_room_position(shape, base_x, base_y, local, lane, ci)
            w = 230 + ((local + ci) % 4) * 28
            h = 112 + ((local * 2 + ci) % 3) * 28
            if lane == "main" and local % 4 == 0:
                h += 45
            if shape in {"tall_shaft", "loop_gallery"} and lane != "main":
                h += 22
            if index == 1:
                kind = "start"
                tags = ["入口", "主线"]
            elif index == count:
                kind = "boss"
                tags = ["Boss", "章节出口"]
            elif local == 0:
                kind = "hub"
                tags = ["区域入口", "主线"]
            else:
                kind = "room"
                tags = []
            if lane == "upper":
                tags.append("上层支线")
            elif lane == "main":
                tags.append("主线")
            else:
                tags.append("下层回访")
            if local == cluster_count - 1 and ci % 2 == 0:
                tags.append("隐藏")
            room_id = f"{chapter['id'].upper()}-{index:02d}"
            contract = room_design_contract(kind, shape, lane, local, cluster_count, index, count)
            setpiece = CH01_VERTICAL_SLICE_ROOMS.get(index, {}) if chapter["id"] == "ch01" else {}
            event_contract = ch01_event_contract(index, setpiece) if chapter["id"] == "ch01" else ch01_event_contract(index, {})
            rooms.append(
                Room(
                    id=room_id,
                    index=index,
                    cluster=cluster,
                    name=f"{cluster}{local + 1}",
                    x=x,
                    y=y,
                    w=w,
                    h=h,
                    kind=kind,
                    lane=lane,
                    tags=tags,
                    archetype=contract["archetype"],
                    design_goal=contract["design_goal"],
                    traversal_focus=contract["traversal_focus"],
                    reward_contract=contract["reward_contract"],
                    pacing_role=contract["pacing_role"],
                    setpiece=str(setpiece.get("setpiece", "")),
                    micro_objective=str(setpiece.get("micro_objective", "")),
                    landmark=str(setpiece.get("landmark", "")),
                    mechanic_prompt=str(setpiece.get("mechanic_prompt", "")),
                    playtest_note=str(setpiece.get("playtest_note", "")),
                    event_type=event_contract["event_type"],
                    event_trigger=event_contract["event_trigger"],
                    event_feedback=event_contract["event_feedback"],
                    event_validation=event_contract["event_validation"],
                )
            )
            index += 1
    return rooms


def by_id(rooms: list[Room]) -> dict[str, Room]:
    return {room.id: room for room in rooms}


def generate_connections(rooms: list[Room], chapter: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    main = [room for room in rooms if room.lane == "main" or room.kind in {"start", "boss"}]
    main = sorted(main, key=lambda r: r.index)
    all_rooms = sorted(rooms, key=lambda r: r.index)
    normal: list[dict[str, Any]] = []
    main_route: list[dict[str, Any]] = []
    branch: list[dict[str, Any]] = []
    shortcuts: list[dict[str, Any]] = []
    gates: list[dict[str, Any]] = []
    hidden: list[dict[str, Any]] = []

    for a, b in zip(main, main[1:]):
        link = {"from": a.id, "to": b.id, "type": "main", "note": "主线推进"}
        normal.append(link)
        main_route.append(link)

    cluster_groups: dict[str, list[Room]] = {}
    for room in all_rooms:
        cluster_groups.setdefault(room.cluster, []).append(room)

    for group in cluster_groups.values():
        group = sorted(group, key=lambda r: r.index)
        for a, b in zip(group, group[1:]):
            if abs(a.index - b.index) <= 3:
                branch.append({"from": a.id, "to": b.id, "type": "local_branch", "note": "区域内部支路"})
        hub = next((r for r in group if r.lane == "main"), group[0])
        for r in group:
            if r.id != hub.id and (r.lane != "main" or r.index % 4 == 0):
                branch.append({"from": hub.id, "to": r.id, "type": "side_room", "note": "支线房/奖励房"})

    for i in range(6, len(all_rooms) - 8, 7):
        a = all_rooms[i]
        b = all_rooms[min(len(all_rooms) - 1, i + 6)]
        shortcuts.append({"from": b.id, "to": a.id, "type": "shortcut", "note": "单向开启捷径"})

    for i in range(9, len(all_rooms) - 7, 11):
        a = all_rooms[i]
        b = all_rooms[min(len(all_rooms) - 1, i + 5)]
        ability = chapter["abilities"][(i // 11) % len(chapter["abilities"])]
        gates.append({"from": a.id, "to": b.id, "type": "ability_gate", "ability": ability, "note": "能力门/回访门"})

    for room in all_rooms:
        if "隐藏" in room.tags:
            hidden.append({"from": room.id, "to": room.id, "type": "hidden_hint", "note": "隐藏墙/假地板提示"})

    return {
        "main_route": main_route,
        "normal": normal,
        "branches": branch,
        "shortcuts": shortcuts[:11],
        "ability_gates": gates[:10],
        "hidden": hidden,
    }


def place_points(rooms: list[Room], chapter: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    all_rooms = sorted(rooms, key=lambda r: r.index)
    room_map = by_id(rooms)

    def point(room: Room, kind: str, label: str, note: str) -> dict[str, Any]:
        return {"room": room.id, "kind": kind, "label": label, "note": note, "x": center(room)[0], "y": center(room)[1]}

    save_indices = [3, 13, 24, 36, 49, len(all_rooms) - 4]
    npc_indices = [5, 17, 29, 41, 53, max(55, len(all_rooms) - 10)]
    reward_indices = [8, 11, 20, 27, 34, 44, 50, 57, len(all_rooms) - 6]
    miniboss_indices = [22, 47]
    ability_indices = [16, 33, 52]
    exit_rooms = [all_rooms[0], all_rooms[-1]]

    saves = [point(all_rooms[i - 1], "save", f"S{n + 1}", "存档椅/传送登记") for n, i in enumerate(save_indices) if i <= len(all_rooms)]
    npcs = [point(all_rooms[i - 1], "npc", f"N{n + 1}", "剧情 NPC / 商人 / 地图师") for n, i in enumerate(npc_indices) if i <= len(all_rooms)]
    rewards = [point(all_rooms[i - 1], "reward", f"R{n + 1}", "护符/货币/生命碎片/剧情道具") for n, i in enumerate(reward_indices) if i <= len(all_rooms)]
    minibosses = [point(all_rooms[i - 1], "miniboss", f"M{n + 1}", "精英战/封门战") for n, i in enumerate(miniboss_indices) if i <= len(all_rooms)]
    abilities = [
        point(all_rooms[i - 1], "ability", f"A{n + 1}", chapter["abilities"][n % len(chapter["abilities"])])
        for n, i in enumerate(ability_indices)
        if i <= len(all_rooms)
    ]
    boss = [point(all_rooms[-1], "boss", "BOSS", chapter["boss"])]
    exits = [point(exit_rooms[0], "exit", "IN", "章节入口"), point(exit_rooms[-1], "exit", "OUT", "章节出口")]

    # Put a checkpoint directly before the boss even if it duplicates save rhythm.
    pre_boss = all_rooms[-3]
    if pre_boss.id not in {p["room"] for p in saves}:
        saves.append(point(pre_boss, "save", f"S{len(saves) + 1}", "Boss 前短跑存档点"))

    # Enrich room tags from points.
    tag_by_room: dict[str, list[str]] = {}
    for collection in [saves, npcs, rewards, minibosses, abilities, boss, exits]:
        for p in collection:
            tag_by_room.setdefault(p["room"], []).append(p["kind"])
    for room in rooms:
        room.tags.extend(tag_by_room.get(room.id, []))  # type: ignore[attr-defined]
        if room.id in room_map:
            pass

    return {
        "saves": saves,
        "npcs": npcs,
        "rewards": rewards,
        "minibosses": minibosses,
        "abilities": abilities,
        "bosses": boss,
        "exits": exits,
    }


def build_blueprint(chapter: dict[str, Any]) -> dict[str, Any]:
    rooms = generate_rooms(chapter)
    connections = generate_connections(rooms, chapter)
    points = place_points(rooms, chapter)
    flat_placements: list[dict[str, Any]] = []
    placements_by_room: dict[str, list[str]] = {}
    for point_group, items in points.items():
        for p in items:
            placement_id = f"{p['room']}-{p['label']}"
            placement = {
                "id": placement_id,
                "type": point_group,
                "kind": p["kind"],
                "room": p["room"],
                "x": p["x"],
                "y": p["y"],
                "label": p["label"],
                "note": p["note"],
                "visible_on_map": True,
            }
            flat_placements.append(placement)
            placements_by_room.setdefault(p["room"], []).append(placement_id)
    exits_by_room: dict[str, list[str]] = {}
    for connection_group in connections.values():
        for link in connection_group:
            exits_by_room.setdefault(link["from"], []).append(link["to"])
            if link["type"] not in {"shortcut", "ability_gate", "hidden_hint"}:
                exits_by_room.setdefault(link["to"], []).append(link["from"])
    cluster_summaries = []
    for ci, cluster in enumerate(chapter["clusters"]):
        group = [r for r in rooms if r.cluster == cluster]
        xs = [r.x for r in group] + [r.x + r.w for r in group]
        ys = [r.y for r in group] + [r.y + r.h for r in group]
        cluster_summaries.append(
            {
                "id": f"C{ci + 1:02d}",
                "name": cluster,
                "room_count": len(group),
                "bounds": {"x": min(xs) - 35, "y": min(ys) - 42, "w": max(xs) - min(xs) + 70, "h": max(ys) - min(ys) + 84},
                "design_role": ["入口教学", "主线推进", "回访门", "资源支线", "纵向井", "Boss 前压强"][ci % 6],
            }
        )

    return {
        "id": chapter["id"],
        "slug": chapter["slug"],
        "title": chapter["title"],
        "theme": chapter["theme"],
        "target_scale": {
            "rooms": len(rooms),
            "clusters": len(chapter["clusters"]),
            "main_route_rooms": len({link["from"] for link in connections["main_route"]} | {connections["main_route"][-1]["to"]}),
            "shortcuts": len(connections["shortcuts"]),
            "ability_gates": len(connections["ability_gates"]),
            "save_points": len(points["saves"]),
            "npcs": len(points["npcs"]),
            "rewards": len(points["rewards"]),
            "minibosses": len(points["minibosses"]),
        },
        "scale_intent": "不复刻商业地图，只采用大体量银河恶魔城的通用节奏：长主线、多支路、能力回访、捷径闭环、Boss 前短跑。",
        "loop_note": chapter["loop_note"],
        "abilities": chapter["abilities"],
        "metroidvania_design_rules": {
            "inspiration_boundary": "Use original map layouts only; borrow genre principles such as vertical hubs, gated return paths, and shortcut compression.",
            "chapter_arc": [
                "teach one safe landmark",
                "show locked routes before the key ability",
                "open optional branches with visible rewards",
                "compress travel with far-side shortcuts",
                "keep boss runback short after the final save",
            ],
            "required_room_archetypes": sorted(ROOM_ARCHETYPE_RULES.keys()),
            "cluster_macro_rules": CLUSTER_MACRO_RULES,
        },
        "palette": PALETTE,
        "legend": {
            "main_route": "红箭头：一周目主线推进",
            "branch": "蓝线：支线、奖励房、区域内连接",
            "shortcut": "绿虚箭：从背面开启的捷径",
            "ability_gate": "紫虚箭：能力门或回访门，线中标注需求能力",
            "save": "S：存档点或传送登记",
            "npc": "N：剧情 NPC、商人、地图师或提示者",
            "reward": "R：护符、货币、生命碎片或剧情道具",
            "miniboss": "M：精英战或封门战",
            "ability": "A：本章关键能力或钥记",
            "boss": "BOSS：章节 Boss 战场",
        },
        "clusters": cluster_summaries,
        "rooms": [
            {
                "id": r.id,
                "index": r.index,
                "chapter": chapter["id"],
                "cluster": r.cluster,
                "name": r.name,
                "rect": {"x": r.x, "y": r.y, "w": r.w, "h": r.h},
                "kind": r.kind,
                "role": r.kind if r.kind != "room" else ("main_route" if r.lane == "main" else "side_branch"),
                "intensity": 4 if r.kind == "boss" else 3 if "miniboss" in r.tags else 2 if r.lane == "main" else 1,
                "lane": r.lane,
                "archetype": r.archetype,
                "design_goal": r.design_goal,
                "traversal_focus": r.traversal_focus,
                "reward_contract": r.reward_contract,
                "pacing_role": r.pacing_role,
                "setpiece": r.setpiece,
                "micro_objective": r.micro_objective,
                "landmark": r.landmark,
                "mechanic_prompt": r.mechanic_prompt,
                "playtest_note": r.playtest_note,
                "event_type": r.event_type,
                "event_trigger": r.event_trigger,
                "event_feedback": r.event_feedback,
                "event_validation": r.event_validation,
                "tags": list(dict.fromkeys(r.tags)),
                "exits": sorted(set(exits_by_room.get(r.id, []))),
                "placements": placements_by_room.get(r.id, []),
            }
            for r in rooms
        ],
        "connections": connections,
        "points": points,
        "placements": flat_placements,
        "implementation_notes": [
            "单张 PNG 是关卡设计用俯视拓扑图，不是最终游戏内小地图贴图。",
            "房间矩形留有较大间距，便于在 Aseprite/Tiled/Godot 中拆成独立区域。",
            "红线为一周目主线，蓝线为支线，绿线为已解锁捷径，紫线为能力门/回访门。",
            "每章 Boss 前必须保留短路径存档点，避免玩家死亡后重复跑长线。",
        ],
    }


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    ensure_dirs()
    ts = timestamp()
    blueprints: list[dict[str, Any]] = []
    index: dict[str, Any] = {
        "generated_at": ts,
        "output_dir": str(OUT_DIR),
        "overview_png": str(OUT_DIR / "six_chapter_silksong_scale_overview.png"),
        "chapters": {},
        "scale_policy": {
            "rooms_per_chapter": "55-75",
            "clusters_per_chapter": "8-12",
            "shortcuts_per_chapter": "8+",
            "ability_gates_per_chapter": "6+",
            "save_points_per_chapter": "5+",
        },
    }
    for chapter in CHAPTERS:
        bp = build_blueprint(chapter)
        json_path = OUT_DIR / f"{chapter['id']}_{chapter['slug']}_blueprint.json"
        png_path = OUT_DIR / f"{chapter['id']}_{chapter['slug']}_blueprint.png"
        write_json(json_path, bp)
        render_blueprint(bp, png_path)
        index["chapters"][chapter["id"]] = {
            "title": chapter["title"],
            "json": str(json_path),
            "png": str(png_path),
            "rooms": bp["target_scale"]["rooms"],
            "clusters": bp["target_scale"]["clusters"],
        }
        blueprints.append(bp)

    overview_path = OUT_DIR / "six_chapter_silksong_scale_overview.png"
    render_overview(blueprints, overview_path)
    docs = write_docs(ts, blueprints, index)
    index["docs"] = docs
    index_path = OUT_DIR / "map_blueprint_index.json"
    write_json(index_path, index)
    print(json.dumps({"ok": True, "index": str(index_path), "overview": str(overview_path), "docs": docs}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
