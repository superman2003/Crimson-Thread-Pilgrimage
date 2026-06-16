from __future__ import annotations

import json
import math
import re
from copy import deepcopy
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "data" / "demo_ch01_moss_bell_court.json"
DRAFT_PATH = ROOT / "artifacts" / "maniamap" / "maniamap_chapter_draft.json"

WORLD_WIDTH = 19000
PRE_BOSS_END = 17300
BOSS_END = 18590
WORLD_HEIGHT = 3360
FALL_Y = 3520
LAYOUT_X_OFFSET = 40
LAYOUT_Y_OFFSET = 120
LAYOUT_Y_SCALE = 0.55
PLAYER_CLEARANCE = 40

LEGACY_META: dict[str, dict[str, Any]] = {
    "entry_bell": {
        "name": "绿苔起点钟门",
        "kind": "gate",
        "depth": 0,
        "objective": "从左侧绿色区第二个平台出生，沿 ManiaMap 的二维房间推进。",
        "guide": "左侧绿区保留宽平台教学，真正的大地图按生成图上下分叉。",
        "danger": "不要把上层标记当成地面，先看清连接台阶。",
        "next": "外庭下阶",
    },
    "outer_court": {
        "name": "外庭下阶",
        "kind": "lower",
        "depth": 1,
        "objective": "从起点房间向左上和右下两个绿色房间分流。",
        "guide": "这段承担第一章的基础跳跃和回爬。",
        "danger": "低处假苔会惩罚急跳。",
        "next": "齿轮升降井",
    },
    "gear_lift": {
        "name": "齿轮升降井",
        "kind": "vertical",
        "depth": 0,
        "objective": "通过绿色区顶部井道确认地图房间追踪。",
        "guide": "保留短回跳台，兼容旧测试坐标，也让回爬路径更清楚。",
        "danger": "井道净空有限，不要贪跳。",
        "next": "上层钟叶廊",
    },
    "upper_bells": {
        "name": "上层钟叶廊",
        "kind": "upper",
        "depth": -1,
        "objective": "进入第一条上层支路，再折回后门礼拜堂。",
        "guide": "上层短台阶会把玩家带回 ManiaMap 的绿区主链。",
        "danger": "空中敌人会压迫落点。",
        "next": "后门小礼拜堂",
    },
    "backdoor": {
        "name": "后门小礼拜堂",
        "kind": "safe",
        "depth": 0,
        "objective": "清完战斗路线后拉开后门捷径。",
        "guide": "这里是蓝紫分叉前的安全汇合点。",
        "danger": "捷径清场后才安全。",
        "next": "王冠回廊",
    },
    "runback": {
        "name": "王冠回廊",
        "kind": "danger",
        "depth": 0,
        "objective": "沿蓝区中线推进到 Boss 前段。",
        "guide": "中线蓝区现在按 ManiaMap 的横向长房间连接。",
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
        "guide": "竖井台阶连接紫区下层和蓝区中线。",
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
        "objective": "把下层紫区蓄水槽作为可选压力路线。",
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
        "guide": "这里向右转入红区前的最后整理区。",
        "danger": "钟匠会惩罚原地停留。",
        "next": "首领前钟廊",
    },
    "pre_boss_belfry": {
        "name": "首领前钟廊",
        "kind": "danger",
        "depth": 0,
        "objective": "使用后段存档点，进入 Boss 大厅。",
        "guide": "检查点位于红区前的稳定平台上。",
        "danger": "最后冲刺短，但敌人压力更高。",
        "next": "锈冠大厅",
    },
    "boss_chamber": {
        "name": "锈冠大厅",
        "kind": "boss",
        "depth": 0,
        "objective": "敲响 Boss 门，击败锈冠守卫。",
        "guide": "Boss 房间位于生成图右侧红区末端。",
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
HAND_DESIGNED_START_ROOMS = {"entry_bell", "outer_court", "gear_lift"}
START_VIEW_CLEANUP_ZONE = (3180, 520, 980, 460)
START_VIEW_ALLOWED = {
    "start_ground",
    "starter_step",
    "vista_bridge",
    "under_gate_lip",
    "outer_drop",
    "outer_low_bridge",
    "outer_return_lip",
    "gear_lift",
    "gear_lift_return_step",
    "moss_steps_a",
    "upper_route_preview",
}


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


def layout_rect(source: dict[str, Any]) -> list[int]:
    raw = source.get("rect", [0, 0, 0, 0])
    x = int(round(float(raw[0]) + LAYOUT_X_OFFSET))
    y = int(round(float(raw[1]) * LAYOUT_Y_SCALE + LAYOUT_Y_OFFSET))
    w = int(round(float(raw[2])))
    h = max(120, int(round(float(raw[3]) * LAYOUT_Y_SCALE)))
    return [x, y, w, h]


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
    return green_rooms[0] if green_rooms else real_rooms[0]


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
            "objective": str(meta.get("objective") or "沿 ManiaMap 拓扑前往下一个连接房间。"),
            "guide": str(meta.get("guide") or "该房间保留生成图的二维位置，并细化为可跳跃平台。"),
            "danger": str(meta.get("danger") or "注意敌人间距和短平台落点。"),
            "next": str(meta.get("next") or "下一个房间"),
            "source_id": source.get("source_id", source.get("id", "")),
            "source_major": source.get("source_major", source_major(str(source.get("source_id", "")))),
            "source_room_id": source.get("id", ""),
            "color_region": region,
            "grid_position": source.get("grid_position", [0, 0, 0]),
            "maniamap_rect": source.get("rect", [0, 0, 0, 0]),
            "layout_rect": layout_rect(source),
            "template": source.get("template", ""),
            "tags": source.get("tags", []),
        }
        rooms.append(room)

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
            "source_room_id": boss_source.get("id", ""),
            "color_region": boss_region,
            "grid_position": boss_source.get("grid_position", [0, 0, 0]),
            "maniamap_rect": boss_source.get("rect", [0, 0, 0, 0]),
            "layout_rect": layout_rect(boss_source),
            "template": boss_source.get("template", ""),
            "tags": boss_source.get("tags", []),
        }
    )

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
            "source_room_id": exit_source.get("id", "mm_exit"),
            "color_region": "exit",
            "grid_position": exit_source.get("grid_position", [0, 0, 0]),
            "maniamap_rect": exit_source.get("rect", [0, 0, 0, 0]),
            "layout_rect": layout_rect(exit_source),
            "template": exit_source.get("template", "synthetic"),
            "tags": exit_source.get("tags", []),
        }
    )

    for index, room in enumerate(rooms[:-1]):
        room["next"] = str(rooms[index + 1].get("name", rooms[index + 1]["id"]))
    rooms[-1]["next"] = "Chapter 2"
    for room in rooms:
        if room["id"] == "gear_lift":
            room["visit_rects"] = [[1900, 430, 1220, 190]]
        elif room["id"] == "entry_bell":
            room["visit_rects"] = [[680, 516, 1920, 396], [700, 760, 720, 150]]
    return rooms


def platform(platform_id: str, x: int, y: int, w: int, h: int, color: str, material: str) -> dict[str, Any]:
    return {"id": platform_id, "rect": [x, y, w, h], "color": color, "material": material}


def env_block(block_id: str, x: int, y: int, w: int, h: int, color: str, z_index: int = -91) -> dict[str, Any]:
    return {"id": block_id, "rect": [x, y, w, h], "color": color, "z_index": z_index}


def rect_intersects(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def add_platform_if_clear(result: list[dict[str, Any]], item: dict[str, Any]) -> None:
    x, y, w, h = [int(value) for value in item["rect"]]
    if item["id"] not in CORRIDOR_ALLOWED and rect_intersects((x, y, w, h), CRITICAL_CORRIDOR):
        return
    if item["id"] not in START_VIEW_ALLOWED and rect_intersects((x, y, w, h), START_VIEW_CLEANUP_ZONE):
        return
    result.append(item)


def room_floor_y(room: dict[str, Any]) -> int:
    x, y, w, h = [int(value) for value in room["layout_rect"]]
    return y + h - 42


def room_floor_platform_id(room_id: str) -> str:
    return f"{room_id}_mm_floor"


def center_of_rect(rect: list[int]) -> tuple[int, int]:
    x, y, w, h = [int(value) for value in rect]
    return x + w // 2, y + h // 2


def build_compat_platforms() -> list[dict[str, Any]]:
    moss = "1c2b1f"
    moss_dark = "22351f"
    moss_mid = "29402f"
    bronze = "6d6645"
    return [
        platform("start_ground", 640, 840, 860, 40, moss, "moss_stone"),
        platform("starter_step", 1138, 780, 176, 24, moss_mid, "moss_stone"),
        platform("vista_bridge", 1360, 706, 320, 26, bronze, "bronze_bridge"),
        platform("under_gate_lip", 1540, 560, 210, 28, moss_dark, "moss_stone"),
        platform("outer_drop", 1660, 640, 360, 34, "243a24", "moss_stone"),
        platform("outer_low_bridge", 2050, 580, 220, 28, "2b442d", "moss_stone"),
        platform("outer_return_lip", 2190, 570, 190, 26, "2b442d", "moss_stone"),
        platform("gear_lift", 2520, 520, 360, 28, bronze, "bronze_bridge"),
        platform("gear_lift_return_step", 2910, 482, 180, 26, "315032", "moss_stone"),
        platform("moss_steps_a", 3130, 444, 280, 28, "2f4c31", "moss_stone"),
        platform("upper_route_preview", 3460, 392, 340, 26, "315032", "moss_stone"),
    ]


def build_environment_blocks() -> list[dict[str, Any]]:
    return [
        env_block("ch01_start_back_wall", 560, 500, 1080, 420, "130d1b", -93),
        env_block("ch01_start_floor_mass", 580, 880, 980, 180, "07100f", -89),
        env_block("ch01_start_left_pier", 560, 510, 84, 420, "1a1020", -88),
        env_block("ch01_start_ceiling_band", 620, 500, 960, 38, "24152d", -87),
        env_block("ch01_entry_arch_shadow", 1480, 548, 260, 328, "180f1d", -92),
        env_block("ch01_mid_back_wall", 1540, 510, 900, 290, "120d18", -93),
        env_block("ch01_mid_floor_mass", 1580, 674, 920, 190, "081111", -89),
        env_block("ch01_lift_shaft_back", 2440, 356, 1040, 330, "10131c", -93),
        env_block("ch01_lift_shaft_floor_mass", 2460, 548, 1080, 170, "07100f", -89),
        env_block("ch01_lift_right_pier", 3380, 366, 90, 310, "1a1020", -88),
        env_block("ch01_upper_preview_back", 3400, 250, 520, 210, "151020", -93),
    ]


def build_room_platforms(rooms: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for room in rooms:
        region = str(room.get("color_region", "green"))
        color, material = REGION_COLORS.get(region, REGION_COLORS["green"])
        x, y, w, h = [int(value) for value in room["layout_rect"]]
        room_id = str(room["id"])
        if room_id in HAND_DESIGNED_START_ROOMS:
            continue
        floor_y = room_floor_y(room)
        floor_w = max(120, w - 96)
        add_platform_if_clear(result, platform(room_floor_platform_id(room_id), x + 48, floor_y, floor_w, 30, color, material))

        if h >= 260 and str(room.get("kind", "")) in {"upper", "danger", "boss"}:
            ledge_w = max(150, min(520, int(w * 0.46)))
            ledge_x = x + max(80, int(w * 0.12))
            ledge_y = y + max(76, int(h * 0.45))
            add_platform_if_clear(result, platform(f"{room_id}_upper_ledge", ledge_x, ledge_y, ledge_w, 24, color, material))
        if str(room.get("kind", "")) == "vertical" or h >= 260:
            steps = max(2, min(5, int(h / 92)))
            for step in range(steps):
                step_x = x + 120 + (step % 2) * max(180, int(w * 0.34))
                step_y = floor_y - 78 * (step + 1)
                if step_y <= y + 34:
                    continue
                step_w = max(120, min(300, int(w * 0.24)))
                add_platform_if_clear(result, platform(f"{room_id}_climb_{step}", step_x, step_y, step_w, 24, color, material))
    return result


def source_room_map(rooms: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for room in rooms:
        result[str(room.get("source_id", ""))] = room
        result[str(room.get("source_room_id", ""))] = room
    return result


def connection_points(room: dict[str, Any], direction: str) -> tuple[int, int]:
    x, y, w, h = [int(value) for value in room["layout_rect"]]
    floor_y = room_floor_y(room)
    if direction == "North":
        return x + w // 2, y + 52
    if direction == "South":
        return x + w // 2, floor_y
    if direction == "West":
        return x + 80, floor_y
    if direction == "East":
        return x + w - 80, floor_y
    return x + w // 2, floor_y


def build_connection_platforms(rooms: list[dict[str, Any]], draft: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for index in range(len(rooms) - 1):
        from_room = rooms[index]
        to_room = rooms[index + 1]
        if str(from_room.get("id", "")) in HAND_DESIGNED_START_ROOMS and str(to_room.get("id", "")) in HAND_DESIGNED_START_ROOMS:
            continue
        region = str(to_room.get("color_region", from_room.get("color_region", "green")))
        color, material = REGION_COLORS.get(region, REGION_COLORS["green"])
        ax, ay = connection_points(from_room, "East")
        bx, by = connection_points(to_room, "West")
        dx = bx - ax
        dy = by - ay
        if abs(dx) > 980 or abs(dy) > 560:
            continue
        steps = max(2, min(5, int(math.ceil(max(abs(dx) / 220.0, abs(dy) / 88.0)))))
        for step in range(1, steps):
            t = step / steps
            x = int(round(ax + dx * t))
            y = int(round(ay + dy * t))
            width = 170 if abs(dx) >= abs(dy) else 150
            add_platform_if_clear(result, platform(f"route_step_{index:02d}_{step:02d}", x - width // 2, y, width, 24, color, material))
    return result


def build_boss_exit_platforms(rooms: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    boss_room = next(room for room in rooms if room["id"] == "boss_chamber")
    exit_room = next(room for room in rooms if room["id"] == "chapter_exit")
    boss_color, boss_material = REGION_COLORS["red"]
    exit_color, exit_material = REGION_COLORS["exit"]
    bx, by, bw, bh = [int(value) for value in boss_room["layout_rect"]]
    ex, ey, ew, eh = [int(value) for value in exit_room["layout_rect"]]
    boss_floor_y = room_floor_y(boss_room)
    exit_floor_y = room_floor_y(exit_room)
    result.append(platform("boss_floor", bx + 70, boss_floor_y, bw - 140, 44, boss_color, boss_material))
    result.append(platform("boss_entry_lip", bx - 160, boss_floor_y + 40, 220, 34, boss_color, boss_material))
    result.append(platform("boss_back_wall", bx + bw - 42, boss_floor_y - 210, 38, 254, boss_color, boss_material))
    result.append(platform("ch01_post_boss_run_step", bx + bw - 120, boss_floor_y, 300, 34, boss_color, boss_material))
    result.append(platform("ch01_exit_runup", ex - 120, exit_floor_y, 180, 34, boss_color, boss_material))
    result.append(platform("ch01_exit_floor", ex + 20, exit_floor_y, max(320, ew), 34, exit_color, exit_material))
    return result


def build_platforms(rooms: list[dict[str, Any]], draft: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for group in (
        build_compat_platforms(),
        build_room_platforms(rooms),
        build_connection_platforms(rooms, draft),
        build_boss_exit_platforms(rooms),
    ):
        existing = {item["id"] for item in result}
        for item in group:
            if item["id"] not in existing:
                result.append(item)
                existing.add(item["id"])
    return result


def platform_by_id(platforms: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(item["id"]): item for item in platforms}


def position_on_platform(platforms: dict[str, dict[str, Any]], platform_id: str, x_ratio: float = 0.5) -> list[int]:
    rect = platforms[platform_id]["rect"]
    x = int(round(rect[0] + rect[2] * x_ratio))
    y = int(round(rect[1] - PLAYER_CLEARANCE))
    return [x, y]


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


def build_enemies(existing: list[dict[str, Any]], platforms: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_kind = {str(enemy.get("kind", "")): enemy for enemy in existing}
    platform_lookup = platform_by_id(platforms)
    larva = by_kind["moss_larva"]
    moth = by_kind["bronze_moth"]
    bellmaker = by_kind["spore_bellmaker"]
    sentinel = by_kind["gear_sentinel"]
    specs = [
        (larva, "E01", "outer_drop", 0.34, 90, 220),
        (moth, "E02", "gear_lift", 0.66, 80, 200),
        (bellmaker, "E03", "upper_bells_mm_floor", 0.55, 70, 180),
        (larva, "E04", "backdoor_mm_floor", 0.42, 80, 180),
        (sentinel, "E05", "runback_mm_floor", 0.72, 100, 230),
        (moth, "CH01_E_EXP01", "echo_moss_trench_mm_floor", 0.62, 90, 220),
        (bellmaker, "CH01_E_EXP02", "old_bell_rope_mm_floor", 0.45, 80, 190),
        (larva, "CH01_E_EXP03", "bell_leaf_tangle_mm_floor", 0.62, 90, 220),
        (sentinel, "CH01_E_EXP04", "lower_bell_cistern_mm_floor", 0.50, 90, 200),
        (larva, "CH01_E_EXP05", "cistern_pump_shaft_mm_floor", 0.40, 90, 220),
        (moth, "CH01_E_EXP06", "upper_crown_rafters_mm_floor", 0.56, 80, 190),
        (bellmaker, "CH01_E_EXP07", "bellmaker_crossway_mm_floor", 0.70, 80, 190),
        (sentinel, "CH01_E_EXP08", "pre_boss_belfry_mm_floor", 0.50, 80, 180),
    ]
    return [
        clone_enemy(template, enemy_id, position_on_platform(platform_lookup, platform_id, ratio), platform_id, patrol, leash)
        for template, enemy_id, platform_id, ratio, patrol, leash in specs
    ]


def build_npcs(existing: list[dict[str, Any]], platforms: list[dict[str, Any]]) -> list[dict[str, Any]]:
    lookup = platform_by_id(platforms)
    positions = {
        "npc_threadsmith_apprentice": position_on_platform(lookup, "start_ground", 0.16),
        "npc_gate_pilgrim": position_on_platform(lookup, "start_ground", 0.76),
        "npc_lift_cartographer": position_on_platform(lookup, "gear_lift", 0.52),
        "npc_backdoor_sacristan": position_on_platform(lookup, "backdoor_mm_floor", 0.24),
        "npc_runback_scout": position_on_platform(lookup, "runback_mm_floor", 0.35),
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
    room_ids = {str(room["id"]) for room in rooms}
    seen: set[tuple[str, str, str]] = set()

    def add(from_id: str, to_id: str, kind: str) -> None:
        if from_id not in room_ids or to_id not in room_ids or from_id == to_id:
            return
        key = (from_id, to_id, kind)
        if key in seen:
            return
        seen.add(key)
        connections.append({"from": from_id, "to": to_id, "type": kind})

    for index in range(len(rooms) - 1):
        add(str(rooms[index]["id"]), str(rooms[index + 1]["id"]), "main_maniamap_route")

    by_source = source_room_map(rooms)
    for connection in draft.get("connections", []):
        from_room = by_source.get(str(connection.get("from_source_id", ""))) or by_source.get(str(connection.get("from", "")))
        to_room = by_source.get(str(connection.get("to_source_id", ""))) or by_source.get(str(connection.get("to", "")))
        if from_room and to_room:
            add(str(from_room["id"]), str(to_room["id"]), str(connection.get("type", "maniamap_door")))

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
            "platforms": ["old_bell_rope_mm_floor", "old_bell_rope_climb_0", "old_bell_rope_climb_1", "bell_leaf_tangle_mm_floor"],
        },
        {
            "id": "ch01_lower_to_upper_loop",
            "room_id": "lower_bell_cistern",
            "technique": "lower detour, return shaft, upper bridge",
            "platforms": ["lower_bell_cistern_mm_floor", "cistern_pump_shaft_mm_floor", "upper_crown_rafters_mm_floor"],
        },
        {
            "id": "ch01_preboss_sprint",
            "room_id": "pre_boss_belfry",
            "technique": "short sprint, jump cancel, safe landing",
            "platforms": ["bellmaker_crossway_mm_floor", "pre_boss_belfry_mm_floor", "boss_floor"],
        },
    ]


def update_first_chapter() -> None:
    data = load_json(CONFIG_PATH)
    draft = load_json(DRAFT_PATH)
    rooms = build_rooms(draft)
    platforms = build_platforms(rooms, draft)
    platform_lookup = platform_by_id(platforms)
    boss_room = next(room for room in rooms if room["id"] == "boss_chamber")
    exit_room = next(room for room in rooms if room["id"] == "chapter_exit")
    bx, by, bw, bh = [int(value) for value in boss_room["layout_rect"]]
    ex, ey, ew, eh = [int(value) for value in exit_room["layout_rect"]]
    boss_spawn = position_on_platform(platform_lookup, "boss_floor", 0.56)
    boss_gate = position_on_platform(platform_lookup, "boss_floor", 0.14)
    chapter_exit = position_on_platform(platform_lookup, "ch01_exit_floor", 0.62)

    data["map_title"] = "苔钟庭：ManiaMap 二维房间版"
    data["goal"] = "从左侧绿色区第二个平台出发，按 ManiaMap 生成图的二维房间拓扑穿过苔钟庭，进入右侧红区 Boss 与出口。"
    data["world"] = {"width": WORLD_WIDTH, "height": WORLD_HEIGHT, "fall_y": FALL_Y}
    data["fall_y"] = FALL_Y
    data["player_start"] = position_on_platform(platform_lookup, "start_ground", 0.22)
    data["boss_checkpoint"] = position_on_platform(platform_lookup, "pre_boss_belfry_mm_floor", 0.18)
    data["map_rooms"] = rooms
    data["environment_blocks"] = build_environment_blocks()
    data["platforms"] = platforms
    data["hazards"] = [
        hazard("trap_fake_moss_01", "fake_moss_floor", 700, 814),
        hazard("ch01_hazard_outer_gap", "bell_gap", 1600, 846),
        hazard("ch01_hazard_upper_leaf", "spore_chest", 3590, 72),
        hazard("ch01_hazard_runback_lamp", "false_lamp", 7620, 1074),
        hazard("ch01_hazard_rope_clapper", "falling_clapper", 8950, 1450),
        hazard("ch01_hazard_lower_bite", "fake_moss_floor", 9720, 2710),
        hazard("ch01_hazard_crossway", "spore_chest", 12580, 1840),
        hazard("ch01_hazard_boss_ante", "falling_clapper", boss_gate[0] - 80, boss_gate[1] + 16),
    ]
    data["collectibles"] = []
    data["enemy_spawns"] = build_enemies(data.get("enemy_spawns", []), platforms)
    data["npcs"] = build_npcs(data.get("npcs", []), platforms)
    data["save_points"] = [
        {
            "id": "save_hidden_upper_respite",
            "label": "隐苔存档点",
            "position": position_on_platform(platform_lookup, "upper_crown_rafters_mm_floor", 0.20),
            "hidden": True,
            "note": "藏在上层王冠梁，奖励探索高路线。",
        },
        {
            "id": "save_late_runback",
            "label": "首领前苔灯",
            "position": position_on_platform(platform_lookup, "pre_boss_belfry_mm_floor", 0.70),
            "hidden": False,
            "note": "红区 Boss 前的稳定后段检查点。",
        },
    ]
    data["interactives"] = [
        {
            "id": "shortcut_lever",
            "kind": "lever",
            "position": position_on_platform(platform_lookup, "backdoor_mm_floor", 0.34),
            "requires_keys": 0,
            "label": "后门捷径拉杆",
        },
        {"id": "boss_gate", "kind": "boss_gate", "position": boss_gate},
        {
            "id": "ch01_chapter_exit",
            "kind": "chapter_exit",
            "label": "前往第二章：铸雨渠",
            "position": chapter_exit,
            "next_runtime_config_id": "demo_ch02_rain_foundry_canal",
            "next_config_path": "res://data/demo_ch02_rain_foundry_canal.json",
            "requires_demo_complete": True,
            "interaction_size": [240, 180],
        },
    ]
    boss = deepcopy(data["boss"])
    boss["position"] = boss_spawn
    boss["arena_min_x"] = bx + 110
    boss["arena_max_x"] = bx + bw - 180
    data["boss"] = boss
    data["parkour_segments"] = build_parkour_segments()
    data["connections"] = build_connections(rooms, draft)
    data["map_layout_tags"] = [
        "maniamap_generated",
        "maniamap_2d_layout",
        "green_second_platform_start",
        "actual_room_rects",
        "upper_shortcut",
        "lower_detour",
        "boss_antechamber",
    ]
    data["labels"] = [
        {"text": "起点：左侧绿色区第二个平台", "position": [860, 790], "color": "9ef0dc"},
        {"text": "绿区：教学与第一段回爬", "position": [1140, 450], "color": "baf4a6"},
        {"text": "蓝区：ManiaMap 中线长房间", "position": [7600, 990], "color": "c7e6ff"},
        {"text": "紫区：下层绕行和回升井", "position": [9100, 2210], "color": "dcb2ff"},
        {"text": "红区：Boss 门与战后出口", "position": [15580, 1760], "color": "f2b873"},
    ]
    data["design_note"] = {
        "source": "artifacts/maniamap/maniamap_chapter_draft.json",
        "intent": "Playable CH01 world uses the same two-dimensional room rectangles as the generated ManiaMap draft.",
        "coordinate_mapping": {
            "x": "maniamap_x + 40",
            "y": "maniamap_y * 0.55 + 120",
            "width": "maniamap_width",
            "height": "max(120, maniamap_height * 0.55)",
        },
    }

    write_json(CONFIG_PATH, data)
    print(
        "GENERATE_CH01_FROM_MANIAMAP_PASS "
        f"path={CONFIG_PATH} rooms={len(data['map_rooms'])} platforms={len(data['platforms'])} "
        f"enemies={len(data['enemy_spawns'])} start={data['player_start']} "
        f"world={data['world']}"
    )


if __name__ == "__main__":
    update_first_chapter()
