from __future__ import annotations

import json
import re
from copy import deepcopy
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "data" / "demo_ch01_moss_bell_court.json"
DRAFT_PATH = ROOT / "artifacts" / "maniamap" / "maniamap_chapter_draft.json"

WORLD_WIDTH = 18800
PRE_BOSS_END = 13240
BOSS_END = 14460
WORLD_HEIGHT = 720
FALL_Y = 820


LEGACY_META: dict[str, dict[str, Any]] = {
    "entry_bell": {
        "name": "绿苔起点钟门",
        "kind": "gate",
        "depth": 0,
        "objective": "从左侧绿色区第二个平台出生，学习第一段安全跳跃。",
        "guide": "上方绿台作为视觉锚点，真正的主路线从下方绿苔平台展开。",
        "danger": "先读清下层外庭间距，再尝试上层路线。",
        "next": "外庭下阶",
    },
    "outer_court": {
        "name": "外庭下阶",
        "kind": "lower",
        "depth": 1,
        "objective": "从庭院正面下绕，通过低路线回到第一处升降井。",
        "guide": "这段把绿色起点群和齿轮升降井接起来。",
        "danger": "伪装苔面会惩罚急跳。",
        "next": "齿轮升降井",
    },
    "gear_lift": {
        "name": "齿轮升降井",
        "kind": "vertical",
        "depth": 0,
        "objective": "从下层回到中线，并确认地图房间追踪。",
        "guide": "短回跳台让回爬路径更清楚。",
        "danger": "井道需要净空，不要在这里贪跳。",
        "next": "上层钟叶廊",
    },
    "upper_bells": {
        "name": "上层钟叶廊",
        "kind": "upper",
        "depth": -1,
        "objective": "进入第一条上层支路，再折回后门礼拜堂。",
        "guide": "上层短台更考验节奏。",
        "danger": "空中敌人会压迫落点。",
        "next": "后门小礼拜堂",
    },
    "backdoor": {
        "name": "后门小礼拜堂",
        "kind": "safe",
        "depth": 0,
        "objective": "清完战斗路线后拉开后门捷径。",
        "guide": "这里也是后半段连续地面的起点。",
        "danger": "捷径清场后才安全。",
        "next": "王冠回廊",
    },
    "runback": {
        "name": "王冠回廊",
        "kind": "danger",
        "depth": 0,
        "objective": "沿中线推进到 Boss 门前。",
        "guide": "从这里到出口保持连续中层地面。",
        "danger": "更重的敌人巡逻这条线。",
        "next": "回响苔沟",
    },
    "echo_moss_trench": {
        "name": "回响苔沟",
        "kind": "lower",
        "depth": 2,
        "objective": "穿过下层紫区绕行线。",
        "guide": "宽平台给地面战斗留出空间。",
        "danger": "别被下层敌人逼进陷阱。",
        "next": "旧钟绳井",
    },
    "old_bell_rope": {
        "name": "旧钟绳井",
        "kind": "vertical",
        "depth": -1,
        "objective": "通过竖井进入上层回环。",
        "guide": "上层桥把低路线重新接回王冠路线。",
        "danger": "坠落钟锤提示节奏变化。",
        "next": "钟叶缠结处",
    },
    "bell_leaf_tangle": {
        "name": "钟叶缠结处",
        "kind": "upper",
        "depth": -1,
        "objective": "穿过上层苔叶短平台。",
        "guide": "短平台奖励稳跳。",
        "danger": "地面敌人在下方卡落点。",
        "next": "沉钟蓄水槽",
    },
    "lower_bell_cistern": {
        "name": "沉钟蓄水槽",
        "kind": "lower",
        "depth": 2,
        "objective": "把下层蓄水槽作为可选压力路线。",
        "guide": "这条低路线会在 Boss 前回到中线。",
        "danger": "这里间距更宽，别急着追敌。",
        "next": "苔轮回升井",
    },
    "cistern_pump_shaft": {
        "name": "苔轮回升井",
        "kind": "vertical",
        "depth": 0,
        "objective": "从蓄水槽爬回上层王冠桥。",
        "guide": "回升井的台阶错落但安全。",
        "danger": "失误会掉回低路线。",
        "next": "王冠上梁",
    },
    "upper_crown_rafters": {
        "name": "王冠上梁",
        "kind": "upper",
        "depth": -2,
        "objective": "在上层王冠梁找到隐藏存档点。",
        "guide": "隐藏存档位于最终汇合前的高路线。",
        "danger": "飞行敌人守住奖励线。",
        "next": "钟匠横桥",
    },
    "bellmaker_crossway": {
        "name": "钟匠横桥",
        "kind": "field",
        "depth": 0,
        "objective": "汇合上下分支，准备进入 Boss 前段。",
        "guide": "从这里到 Boss 门是连续中线。",
        "danger": "钟匠会惩罚原地停留。",
        "next": "首领前钟廊",
    },
    "pre_boss_belfry": {
        "name": "首领前钟廊",
        "kind": "danger",
        "depth": 0,
        "objective": "使用后段存档点，进入 Boss 大厅。",
        "guide": "检查点位于稳定中层地面。",
        "danger": "最后冲刺短，但敌人压力更高。",
        "next": "锈冠大厅",
    },
    "boss_chamber": {
        "name": "锈冠大厅",
        "kind": "boss",
        "depth": 0,
        "objective": "敲响 Boss 门，击败锈冠守卫。",
        "guide": "Boss 地面和战后墙体与出口地面分开处理。",
        "danger": "守卫倒下前大厅会锁场。",
        "next": "沉钟出口",
    },
    "chapter_exit": {
        "name": "沉钟出口",
        "kind": "exit",
        "depth": 0,
        "objective": "离开苔钟庭，进入第二章铸雨渠。",
        "guide": "出口会在获得 Boss 奖励后激活。",
        "danger": "战后墙体打开后无危险。",
        "next": "铸雨渠",
    },
}

LEGACY_TARGETS = {
    "upper_bells": 2650,
    "backdoor": 3680,
    "runback": 4320,
    "echo_moss_trench": 5480,
    "old_bell_rope": 6620,
    "bell_leaf_tangle": 7620,
    "lower_bell_cistern": 8780,
    "cistern_pump_shaft": 9940,
    "upper_crown_rafters": 10720,
    "bellmaker_crossway": 11740,
    "pre_boss_belfry": 12580,
}

REGION_COLORS = {
    "green": ("1f3d24", "moss_stone"),
    "blue": ("315066", "bronze_bridge"),
    "purple": ("47345e", "boss_stone"),
    "red": ("5a2d2d", "boss_stone"),
    "exit": ("4b5960", "boss_stone"),
    "synthetic": ("4b5960", "boss_stone"),
}

REGION_NAMES = {
    "green": "绿区",
    "blue": "蓝区",
    "purple": "紫区",
    "red": "红区",
    "exit": "出口区",
    "synthetic": "合成区",
}

CRITICAL_CORRIDOR = (1760, 380, 1000, 170)
CORRIDOR_ALLOWED = {"outer_return_lip", "gear_lift", "gear_lift_return_step", "moss_steps_a"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def source_major(source_id: str) -> int | None:
    match = re.search(r"Uid\((\d+)", source_id)
    return int(match.group(1)) if match else None


def region_for_source(source_id: str) -> str:
    major = source_major(source_id)
    if major is None:
        return "synthetic"
    if major <= 10:
        return "blue"
    if major <= 18:
        return "green"
    if major <= 26:
        return "purple"
    return "red"


def room_region(room: dict[str, Any]) -> str:
    return str(room.get("color_region") or region_for_source(str(room.get("source_id", ""))))


def pre_boss_ranges() -> list[tuple[int, int]]:
    ranges = [(0, 900), (900, 1560), (1560, 1900), (1900, 2260)]
    remaining = 51 - len(ranges)
    start = 2260
    span = PRE_BOSS_END - start
    cursor = start
    for index in range(remaining):
        end = PRE_BOSS_END if index == remaining - 1 else int(round(start + span * (index + 1) / remaining))
        ranges.append((cursor, end))
        cursor = end
    return ranges


def range_index_for_x(ranges: list[tuple[int, int]], x: int) -> int:
    for index, (start, end) in enumerate(ranges):
        if start <= x < end:
            return index
    return len(ranges) - 1


def legacy_id_slots(ranges: list[tuple[int, int]]) -> dict[int, str]:
    slots = {0: "entry_bell", 1: "outer_court", 3: "gear_lift"}
    for room_id, target_x in LEGACY_TARGETS.items():
        index = range_index_for_x(ranges, target_x)
        while index in slots and index + 1 < len(ranges):
            index += 1
        while index in slots and index > 0:
            index -= 1
        slots[index] = room_id
    return slots


def start_source_room(real_rooms: list[dict[str, Any]]) -> dict[str, Any]:
    green_rooms = [room for room in real_rooms if room_region(room) == "green"]
    green_rooms.sort(key=lambda room: (room.get("rect", [0, 0])[0], room.get("rect", [0, 0])[1]))
    if len(green_rooms) >= 2:
        return green_rooms[1]
    if green_rooms:
        return green_rooms[0]
    return real_rooms[0]


def ordered_source_rooms(draft: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any], dict[str, Any]]:
    rooms = list(draft.get("rooms", []))
    real_rooms = [room for room in rooms if str(room.get("source_id", "")) != "synthetic_exit"]
    real_rooms.sort(key=lambda room: (room.get("rect", [0, 0])[0], room.get("rect", [0, 0])[1], room.get("id", "")))
    start_room = start_source_room(real_rooms)
    boss_room = real_rooms[-1]
    pre_sources = [start_room]
    for room in real_rooms:
        if room.get("id") in {start_room.get("id"), boss_room.get("id")}:
            continue
        pre_sources.append(room)
    exit_room = next((room for room in rooms if str(room.get("source_id", "")) == "synthetic_exit"), {})
    return pre_sources[:51], boss_room, exit_room


def build_rooms(draft: dict[str, Any]) -> list[dict[str, Any]]:
    ranges = pre_boss_ranges()
    slots = legacy_id_slots(ranges)
    pre_sources, boss_source, exit_source = ordered_source_rooms(draft)
    rooms: list[dict[str, Any]] = []
    source_to_room: dict[str, str] = {}

    for index, (start, end) in enumerate(ranges):
        source = pre_sources[index]
        room_id = slots.get(index, f"mm_route_{index:02d}")
        region = room_region(source)
        meta = LEGACY_META.get(room_id, {})
        kind = str(meta.get("kind") or source.get("kind", "field"))
        depth = int(meta.get("depth", source.get("depth", 0)))
        name = str(meta.get("name") or f"{REGION_NAMES.get(region, region)}路线 {index:02d}")
        room = {
            "id": room_id,
            "name": name,
            "range": [start, end],
            "depth": depth,
            "kind": kind,
            "objective": str(meta.get("objective") or "沿 ManiaMap 拓扑路线前往下一个连接房间。"),
            "guide": str(meta.get("guide") or "这个房间保留原始 ManiaMap 拓扑，并转换为可玩的横版平台段。"),
            "danger": str(meta.get("danger") or "注意敌人间距和短平台落点。"),
            "next": str(meta.get("next") or "下一个房间"),
            "source_id": source.get("source_id", source.get("id", "")),
            "source_major": source.get("source_major", source_major(str(source.get("source_id", "")))),
            "color_region": region,
            "grid_position": source.get("grid_position", [0, 0, 0]),
            "maniamap_rect": source.get("rect", [0, 0, 0, 0]),
            "template": source.get("template", ""),
            "tags": source.get("tags", []),
        }
        rooms.append(room)
        source_to_room[str(room["source_id"])] = room_id

    boss_meta = LEGACY_META["boss_chamber"]
    boss_region = room_region(boss_source)
    rooms.append(
        {
            "id": "boss_chamber",
            "name": boss_meta["name"],
            "range": [PRE_BOSS_END, BOSS_END],
            "depth": boss_meta["depth"],
            "kind": boss_meta["kind"],
            "objective": boss_meta["objective"],
            "guide": boss_meta["guide"],
            "danger": boss_meta["danger"],
            "next": boss_meta["next"],
            "source_id": boss_source.get("source_id", boss_source.get("id", "")),
            "source_major": boss_source.get("source_major", source_major(str(boss_source.get("source_id", "")))),
            "color_region": boss_region,
            "grid_position": boss_source.get("grid_position", [0, 0, 0]),
            "maniamap_rect": boss_source.get("rect", [0, 0, 0, 0]),
            "template": boss_source.get("template", ""),
            "tags": boss_source.get("tags", []),
        }
    )
    source_to_room[str(rooms[-1]["source_id"])] = "boss_chamber"

    exit_meta = LEGACY_META["chapter_exit"]
    rooms.append(
        {
            "id": "chapter_exit",
            "name": exit_meta["name"],
            "range": [BOSS_END, WORLD_WIDTH],
            "depth": exit_meta["depth"],
            "kind": exit_meta["kind"],
            "objective": exit_meta["objective"],
            "guide": exit_meta["guide"],
            "danger": exit_meta["danger"],
            "next": exit_meta["next"],
            "source_id": exit_source.get("source_id", "synthetic_exit"),
            "source_major": None,
            "color_region": "exit",
            "grid_position": exit_source.get("grid_position", [0, 0, 0]),
            "maniamap_rect": exit_source.get("rect", [0, 0, 0, 0]),
            "template": exit_source.get("template", "synthetic"),
            "tags": exit_source.get("tags", []),
        }
    )
    source_to_room["synthetic_exit"] = "chapter_exit"

    for index, room in enumerate(rooms[:-1]):
        room["next"] = str(rooms[index + 1].get("name", rooms[index + 1]["id"]))
    rooms[-1]["next"] = "Chapter 2"
    return rooms


def platform(platform_id: str, x: int, y: int, w: int, h: int, color: str, material: str) -> dict[str, Any]:
    return {"id": platform_id, "rect": [x, y, w, h], "color": color, "material": material}


def rect_intersects(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def auto_floor_y(room: dict[str, Any]) -> int:
    kind = str(room.get("kind", "field"))
    depth = int(room.get("depth", 0))
    if kind == "upper" or depth < 0:
        return 420
    if kind == "lower" or depth > 0:
        return 610
    if kind == "boss":
        return 500
    if kind == "exit":
        return 520
    if kind == "vertical":
        return 540
    return 540


def add_platform_if_clear(result: list[dict[str, Any]], item: dict[str, Any]) -> None:
    x, y, w, h = [int(value) for value in item["rect"]]
    if item["id"] not in CORRIDOR_ALLOWED and rect_intersects((x, y, w, h), CRITICAL_CORRIDOR):
        return
    result.append(item)


def build_core_platforms() -> list[dict[str, Any]]:
    moss = "1c2b1f"
    moss_dark = "22351f"
    moss_mid = "29402f"
    bronze = "6d6645"
    boss = "47362f"
    return [
        platform("green_start_upper_marker", 470, 430, 300, 26, "315032", "moss_stone"),
        platform("start_ground", 0, 540, 760, 40, moss, "moss_stone"),
        platform("starter_step", 430, 492, 180, 24, moss_mid, "moss_stone"),
        platform("vista_bridge", 600, 430, 360, 26, bronze, "bronze_bridge"),
        platform("under_gate_lip", 860, 585, 300, 28, moss_dark, "moss_stone"),
        platform("outer_drop", 1180, 610, 650, 34, "243a24", "moss_stone"),
        platform("outer_low_bridge", 1500, 548, 240, 28, "2b442d", "moss_stone"),
        platform("outer_return_lip", 1760, 560, 220, 26, "2b442d", "moss_stone"),
        platform("gear_lift", 1900, 520, 380, 28, bronze, "bronze_bridge"),
        platform("gear_lift_return_step", 2240, 485, 210, 26, "315032", "moss_stone"),
        platform("moss_steps_a", 2380, 450, 330, 28, "2f4c31", "moss_stone"),
        platform("moss_steps_b", 2820, 370, 340, 28, "365438", "moss_stone"),
        platform("upper_respite", 3260, 410, 400, 28, "2e4a34", "moss_stone"),
        platform("backdoor_room", 3680, 500, 540, 32, bronze, "bronze_bridge"),
        platform("shortcut_upper", 1180, 390, 520, 26, "6f673d", "bronze_bridge"),
        platform("boss_runback", 4200, 500, 1280, 34, boss, "boss_stone"),
        platform("runback_overlook", 4680, 420, 360, 28, bronze, "bronze_bridge"),
        platform("ch01_echo_trench_floor", 5480, 540, 940, 34, "274526", "moss_stone"),
        platform("ch01_echo_trench_step", 6200, 468, 360, 28, bronze, "bronze_bridge"),
        platform("ch01_echo_trench_exit", 6400, 540, 260, 34, "274526", "moss_stone"),
        platform("ch01_old_rope_floor", 6620, 540, 980, 34, "294829", "moss_stone"),
        platform("ch01_old_rope_mid_a", 6840, 470, 260, 28, bronze, "bronze_bridge"),
        platform("ch01_old_rope_mid_b", 7120, 420, 260, 28, bronze, "bronze_bridge"),
        platform("ch01_old_rope_upper_bridge", 6800, 388, 760, 28, bronze, "bronze_bridge"),
        platform("ch01_bell_tangle_floor", 7560, 500, 1000, 34, "263f29", "moss_stone"),
        platform("ch01_bell_tangle_upper", 7900, 420, 560, 28, bronze, "bronze_bridge"),
        platform("ch01_tangle_drop", 8480, 500, 300, 34, "263f29", "moss_stone"),
        platform("ch01_runback_after_tangle", 8720, 500, 620, 34, boss, "boss_stone"),
        platform("ch01_pre_boss_step", 9140, 452, 360, 28, bronze, "bronze_bridge"),
        platform("ch01_lower_loop_floor", 8780, 610, 980, 34, moss, "moss_stone"),
        platform("ch01_lower_loop_mid", 9280, 520, 390, 28, bronze, "bronze_bridge"),
        platform("ch01_lower_loop_exit_lip", 9700, 560, 220, 26, moss, "moss_stone"),
        platform("ch01_late_route_link_01", 9670, 500, 270, 30, boss, "boss_stone"),
        platform("ch01_return_shaft_base", 9940, 540, 380, 30, moss, "moss_stone"),
        platform("ch01_return_shaft_step_a", 10240, 470, 270, 28, bronze, "bronze_bridge"),
        platform("ch01_return_shaft_step_b", 10580, 400, 270, 28, bronze, "bronze_bridge"),
        platform("ch01_late_route_link_02", 10320, 500, 1420, 30, boss, "boss_stone"),
        platform("ch01_upper_bridge", 10840, 350, 880, 28, bronze, "bronze_bridge"),
        platform("ch01_upper_hidden_save", 11100, 350, 240, 28, "7a7046", "bronze_bridge"),
        platform("ch01_upper_drop_step", 11540, 430, 260, 28, bronze, "bronze_bridge"),
        platform("ch01_crossway_floor", 11740, 540, 900, 34, moss, "moss_stone"),
        platform("ch01_crossway_upper", 12180, 452, 380, 28, bronze, "bronze_bridge"),
        platform("ch01_preboss_floor", 12580, 540, 660, 34, boss, "boss_stone"),
        platform("boss_floor", 13240, 500, 1080, 44, boss, "boss_stone"),
        platform("boss_entry_lip", 13100, 540, 170, 34, boss, "boss_stone"),
        platform("boss_back_wall", 14320, 300, 38, 244, boss, "boss_stone"),
        platform("ch01_post_boss_run_step", 14300, 500, 300, 34, boss, "boss_stone"),
        platform("ch01_exit_runup", 14440, 500, 190, 34, boss, "boss_stone"),
        platform("ch01_exit_floor", 14480, 520, 360, 34, boss, "boss_stone"),
    ]


def build_platforms(rooms: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result = build_core_platforms()
    existing_ids = {item["id"] for item in result}
    for index, room in enumerate(rooms):
        region = str(room.get("color_region", "green"))
        color, material = REGION_COLORS.get(region, REGION_COLORS["green"])
        left, right = [int(value) for value in room["range"]]
        width = max(110, right - left - 28)
        base_x = left + 14
        base_y = auto_floor_y(room)
        room_id = str(room["id"])
        main_id = f"{room_id}_mm_floor"
        if main_id not in existing_ids:
            add_platform_if_clear(result, platform(main_id, base_x, base_y, width, 28, color, material))
            existing_ids.add(main_id)
        lower_id = f"{room_id}_mm_lower_slab"
        lower_y = min(680, base_y + 78)
        slab_width = max(96, min(width - 12, int(width * 0.62)))
        slab_x = min(right - slab_width - 10, base_x + max(24, int(width * 0.28)))
        if lower_id not in existing_ids:
            add_platform_if_clear(result, platform(lower_id, slab_x, lower_y, slab_width, 24, color, material))
            existing_ids.add(lower_id)
    return result


def hazard(hazard_id: str, kind: str, x: int, y: int, w: int = 110, h: int = 24) -> dict[str, Any]:
    return {
        "id": hazard_id,
        "kind": kind,
        "rect": [x, y, w, h],
        "position": [x + w // 2, y + h // 2],
        "damage": 1,
        "message": "Old moss machinery snaps shut.",
    }


def clone_enemy(template: dict[str, Any], enemy_id: str, position: list[int], platform_id: str, patrol: int, leash: int) -> dict[str, Any]:
    enemy = deepcopy(template)
    enemy["id"] = enemy_id
    enemy["position"] = position
    enemy["platform_id"] = platform_id
    enemy["patrol"] = patrol
    enemy["leash_radius"] = leash
    return enemy


def build_enemies(existing: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_kind = {str(enemy.get("kind", "")): enemy for enemy in existing}
    larva = by_kind["moss_larva"]
    moth = by_kind["bronze_moth"]
    bellmaker = by_kind["spore_bellmaker"]
    sentinel = by_kind["gear_sentinel"]
    specs = [
        (larva, "E01", [1410, 570], "outer_drop", 90, 220),
        (moth, "E02", [2160, 480], "gear_lift", 80, 200),
        (bellmaker, "E03", [2990, 330], "moss_steps_b", 70, 180),
        (larva, "E04", [3930, 460], "backdoor_room", 80, 180),
        (sentinel, "E05", [5160, 460], "boss_runback", 100, 230),
        (moth, "CH01_E_EXP01", [6300, 500], "ch01_echo_trench_floor", 90, 220),
        (bellmaker, "CH01_E_EXP02", [7180, 348], "ch01_old_rope_upper_bridge", 80, 190),
        (larva, "CH01_E_EXP03", [8200, 460], "ch01_bell_tangle_floor", 90, 220),
        (sentinel, "CH01_E_EXP04", [9130, 460], "ch01_runback_after_tangle", 90, 200),
        (larva, "CH01_E_EXP05", [8880, 570], "ch01_lower_loop_floor", 90, 220),
        (moth, "CH01_E_EXP06", [11420, 310], "ch01_upper_bridge", 80, 190),
        (bellmaker, "CH01_E_EXP07", [12120, 500], "ch01_crossway_floor", 80, 190),
        (sentinel, "CH01_E_EXP08", [12860, 500], "ch01_preboss_floor", 80, 180),
    ]
    return [clone_enemy(*spec) for spec in specs]


def build_npcs(existing: list[dict[str, Any]]) -> list[dict[str, Any]]:
    positions = {
        "npc_threadsmith_apprentice": [320, 500],
        "npc_gate_pilgrim": [735, 500],
        "npc_lift_cartographer": [2100, 480],
        "npc_backdoor_sacristan": [3740, 460],
        "npc_runback_scout": [4380, 460],
    }
    result = []
    for npc in existing:
        item = deepcopy(npc)
        if item.get("id") in positions:
            item["position"] = positions[item["id"]]
        result.append(item)
    return result


def build_connections(rooms: list[dict[str, Any]], draft: dict[str, Any]) -> list[dict[str, Any]]:
    connections: list[dict[str, Any]] = []
    room_ids = [str(room["id"]) for room in rooms]
    seen: set[tuple[str, str, str]] = set()

    def add(from_id: str, to_id: str, kind: str) -> None:
        if from_id not in room_ids or to_id not in room_ids or from_id == to_id:
            return
        key = (from_id, to_id, kind)
        if key in seen:
            return
        seen.add(key)
        connections.append({"from": from_id, "to": to_id, "type": kind})

    for index in range(len(room_ids) - 1):
        add(room_ids[index], room_ids[index + 1], "main_maniamap_route")

    by_source = {str(room.get("source_id", "")): str(room.get("id", "")) for room in rooms}
    for connection in draft.get("connections", []):
        from_id = by_source.get(str(connection.get("from_source_id", "")))
        to_id = by_source.get(str(connection.get("to_source_id", "")))
        if from_id is None:
            from_id = by_source.get(str(connection.get("from", "")))
        if to_id is None:
            to_id = by_source.get(str(connection.get("to", "")))
        if from_id and to_id:
            add(from_id, to_id, str(connection.get("type", "maniamap_door")))

    add("entry_bell", "upper_bells", "visible_upper_shortcut")
    add("outer_court", "gear_lift", "lower_return")
    add("backdoor", "boss_chamber", "opened_shortcut")
    add("upper_crown_rafters", "pre_boss_belfry", "upper_reward_shortcut")
    return connections


def build_parkour_segments() -> list[dict[str, Any]]:
    return [
        {
            "id": "ch01_outer_court_return",
            "room_id": "outer_court",
            "technique": "drop recovery + short hop return route",
            "platforms": ["outer_drop", "outer_low_bridge", "outer_return_lip", "gear_lift", "gear_lift_return_step", "moss_steps_a"],
        },
        {
            "id": "ch01_rope_to_upper_loop",
            "room_id": "old_bell_rope",
            "technique": "vertical rope shaft into upper shortcut",
            "platforms": ["ch01_old_rope_floor", "ch01_old_rope_mid_a", "ch01_old_rope_mid_b", "ch01_old_rope_upper_bridge", "ch01_bell_tangle_upper"],
        },
        {
            "id": "ch01_lower_to_upper_loop",
            "room_id": "lower_bell_cistern",
            "technique": "lower detour, return shaft, upper bridge",
            "platforms": ["ch01_lower_loop_floor", "ch01_return_shaft_base", "ch01_return_shaft_step_a", "ch01_return_shaft_step_b", "ch01_upper_bridge"],
        },
        {
            "id": "ch01_preboss_sprint",
            "room_id": "pre_boss_belfry",
            "technique": "short sprint, jump cancel, safe landing",
            "platforms": ["ch01_crossway_floor", "ch01_crossway_upper", "ch01_preboss_floor", "boss_floor"],
        },
    ]


def update_first_chapter() -> None:
    data = load_json(CONFIG_PATH)
    draft = load_json(DRAFT_PATH)
    rooms = build_rooms(draft)

    data["map_title"] = "苔钟庭：ManiaMap 绿色起点路线"
    data["goal"] = "从左侧绿色区第二个平台出发，穿过 ManiaMap 拓扑生成的苔钟庭，打开锈冠大厅并击败锈冠守卫。"
    data["world"] = {"width": WORLD_WIDTH, "height": WORLD_HEIGHT, "fall_y": FALL_Y}
    data["fall_y"] = FALL_Y
    data["player_start"] = [180, 500]
    data["boss_checkpoint"] = [12760, 500]
    data["map_rooms"] = rooms
    data["platforms"] = build_platforms(rooms)
    data["hazards"] = [
        hazard("trap_fake_moss_01", "fake_moss_floor", 700, 406),
        hazard("ch01_hazard_outer_gap", "bell_gap", 1600, 586),
        hazard("ch01_hazard_upper_leaf", "spore_chest", 3010, 346),
        hazard("ch01_hazard_runback_lamp", "false_lamp", 4860, 476),
        hazard("ch01_hazard_rope_clapper", "falling_clapper", 7040, 516),
        hazard("ch01_hazard_lower_bite", "fake_moss_floor", 9260, 586),
        hazard("ch01_hazard_crossway", "spore_chest", 12160, 516),
        hazard("ch01_hazard_boss_ante", "falling_clapper", 12920, 516),
    ]
    data["collectibles"] = []
    data["enemy_spawns"] = build_enemies(data.get("enemy_spawns", []))
    data["npcs"] = build_npcs(data.get("npcs", []))
    data["save_points"] = [
        {
            "id": "save_hidden_upper_respite",
            "label": "隐苔存档点",
            "position": [11180, 310],
            "hidden": True,
            "note": "藏在上层王冠梁，奖励探索高路线。",
        },
        {
            "id": "save_late_runback",
            "label": "首领前苔灯",
            "position": [12760, 500],
            "hidden": False,
            "note": "锈冠大厅前的稀疏后段检查点。",
        },
    ]
    data["interactives"] = [
        {"id": "shortcut_lever", "kind": "lever", "position": [3780, 460], "requires_keys": 0, "label": "后门捷径拉杆"},
        {"id": "boss_gate", "kind": "boss_gate", "position": [13420, 460]},
        {
            "id": "ch01_chapter_exit",
            "kind": "chapter_exit",
            "label": "前往第二章：铸雨渠",
            "position": [14620, 480],
            "next_runtime_config_id": "demo_ch02_rain_foundry_canal",
            "next_config_path": "res://data/demo_ch02_rain_foundry_canal.json",
            "requires_demo_complete": True,
            "interaction_size": [240, 180],
        },
    ]
    boss = deepcopy(data["boss"])
    boss["position"] = [13920, 460]
    boss["arena_min_x"] = 13320
    boss["arena_max_x"] = 14180
    data["boss"] = boss
    data["parkour_segments"] = build_parkour_segments()
    data["connections"] = build_connections(rooms, draft)
    data["map_layout_tags"] = [
        "maniamap_generated",
        "green_second_platform_start",
        "horizontalized_topology",
        "upper_shortcut",
        "lower_detour",
        "continuous_late_route",
        "boss_antechamber",
    ]
    data["labels"] = [
        {"text": "起点：左侧绿色区第二个平台", "position": [180, 458], "color": "9ef0dc"},
        {"text": "绿色群：教学与第一段下层回路", "position": [1100, 570], "color": "baf4a6"},
        {"text": "蓝/紫区：ManiaMap 房间链", "position": [6040, 340], "color": "c7e6ff"},
        {"text": "隐藏存档：王冠上梁", "position": [10880, 300], "color": "9ef0dc"},
        {"text": "红区：Boss 门与战后出口", "position": [13080, 466], "color": "f2b873"},
    ]

    write_json(CONFIG_PATH, data)
    print(
        "GENERATE_CH01_FROM_MANIAMAP_PASS "
        f"path={CONFIG_PATH} rooms={len(data['map_rooms'])} platforms={len(data['platforms'])} "
        f"enemies={len(data['enemy_spawns'])} start={data['player_start']}"
    )


if __name__ == "__main__":
    update_first_chapter()
