from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "godot" / "data"


ROOM_WIDTHS = {
    1: [900, 1000, 700, 850, 850, 1300, 1200, 1000, 1100, 1000, 900, 1000, 800, 600, 1250, 350],
    2: [850, 900, 750, 800, 750, 500, 550, 500, 500, 900, 300, 1100, 1150, 500, 600, 1000, 1100, 1200, 1050, 900, 1000, 650, 1700, 750],
    3: [850, 900, 850, 900, 1050, 1050, 1050, 1150, 1150, 1100, 1100, 1000, 900, 1050, 1200, 950, 1800, 750],
    4: [850, 900, 850, 900, 1050, 1050, 1050, 1150, 1150, 1100, 1100, 1000, 900, 1050, 1200, 950, 1800, 750],
    5: [850, 900, 850, 900, 1050, 1050, 1050, 1150, 1150, 1100, 1100, 1000, 900, 1050, 1200, 950, 1800, 750],
    6: [850, 900, 850, 900, 1050, 1050, 1050, 1150, 1150, 1100, 1100, 1000, 900, 1050, 1200, 950, 1800, 750],
}


ROOMS = {
    1: [
        ("entry_bell", "苔钟入口", 0, "gate"),
        ("outer_court", "苔钟外庭下层", 1, "lower"),
        ("gear_lift", "齿轮升降间", 0, "vertical"),
        ("upper_bells", "上层钟叶", -1, "upper"),
        ("backdoor", "后门祭室", 0, "safe"),
        ("runback", "苔钟长回廊", 1, "danger"),
        ("echo_moss_trench", "回响苔槽", 2, "lower"),
        ("old_bell_rope", "旧钟索井", -1, "vertical"),
        ("bell_leaf_tangle", "钟叶缠结处", 0, "field"),
        ("lower_bell_cistern", "沉钟下水庭", 2, "lower"),
        ("cistern_pump_shaft", "苔轮回升井", 0, "vertical"),
        ("upper_crown_rafters", "王冠上梁", -2, "upper"),
        ("bellmaker_crossway", "钟匠横桥", 0, "field"),
        ("pre_boss_belfry", "首领前钟廊", 0, "danger"),
        ("boss_chamber", "锈冠大厅", 0, "boss"),
        ("chapter_exit", "沉钟出口", 0, "exit"),
    ],
    2: [
        ("rain_inlet", "雨渠入口", 0, "gate"),
        ("low_bridge_canal", "外渠低桥", 1, "lower"),
        ("pump_lift", "泵轮升降机", 0, "vertical"),
        ("pipe_roof", "管道屋顶", -1, "upper"),
        ("pipewright_rest", "管工休息间", 0, "safe"),
        ("sluice_chapel", "泵井礼拜间", 0, "safe"),
        ("triple_pump_well", "三岔泵井", 1, "vertical"),
        ("wet_wall_intro", "湿墙入口", 0, "skill_gate"),
        ("wet_wall_shaft", "湿墙竖井", -1, "vertical"),
        ("overflow_basin", "溢水池", 2, "lower"),
        ("overflow_lower_grate", "溢水下格栅", 2, "danger"),
        ("pressure_stack", "压力栈", -1, "vertical"),
        ("echo_hook_bridge", "回声索桥", -2, "hook_bridge"),
        ("swing_crossing_secret", "秘密横渡", -1, "secret"),
        ("glass_pipe_gallery", "玻璃管廊", -1, "upper"),
        ("foundry_runback", "铸坊回廊", 0, "danger"),
        ("hammer_yard", "铸锤院", 1, "field"),
        ("anvil_lift", "铁砧升降机", -1, "vertical"),
        ("drainage_underloop", "排水下环", 2, "lower"),
        ("steam_return_shaft", "蒸汽回升井", 0, "vertical"),
        ("roof_pressure_bridge", "高压屋脊", -2, "upper"),
        ("anvil_preboss", "砧台前廊", 0, "danger"),
        ("pump_king_hall", "泵王殿", 0, "boss"),
        ("oath_outlet", "誓言排水口", 0, "exit"),
    ],
    3: [
        ("ch03_room_1", "盐封入口", -1, "entry"),
        ("ch03_room_2", "逆读书廊", 1, "lower"),
        ("ch03_room_3", "静默阅读井", 0, "vertical"),
        ("ch03_room_4", "契约索引台", -1, "upper"),
        ("ch03_room_5", "盐晶书脊", 0, "safe"),
        ("ch03_room_6", "抹名塔", 1, "danger"),
        ("ch03_room_7", "盐页跳台", -1, "parkour"),
        ("ch03_room_8", "倒置书梯", 0, "vertical"),
        ("ch03_room_9", "玻璃书架跑酷", -1, "upper"),
        ("ch03_room_10", "契约庭前廊", 0, "field"),
        ("ch03_room_11", "删名下层", 2, "lower"),
        ("ch03_room_12", "空白页回环", 2, "lower"),
        ("ch03_room_13", "盐印升降井", 0, "vertical"),
        ("ch03_room_14", "高阁索桥", -2, "upper"),
        ("ch03_room_15", "封页连战", 0, "danger"),
        ("ch03_room_16", "契约庭门廊", 0, "field"),
        ("ch03_room_17", "盐白契约庭", 0, "boss"),
        ("ch03_room_18", "盐页出口", 0, "exit"),
    ],
    4: [
        ("ch04_room_1", "温室门厅", -1, "entry"),
        ("ch04_room_2", "弦桥育苗室", 1, "lower"),
        ("ch04_room_3", "蜂蜡小屋", 0, "vertical"),
        ("ch04_room_4", "倒根井", -1, "upper"),
        ("ch04_room_5", "断弦热房", 0, "safe"),
        ("ch04_room_6", "荆棘礼拜堂", 1, "danger"),
        ("ch04_room_7", "藤索跳台", -1, "parkour"),
        ("ch04_room_8", "花粉风道", 0, "vertical"),
        ("ch04_room_9", "玻璃花房跑酷", -1, "upper"),
        ("ch04_room_10", "园主前庭", 0, "field"),
        ("ch04_room_11", "逆根下层", 2, "lower"),
        ("ch04_room_12", "蜂蜡回环", 2, "lower"),
        ("ch04_room_13", "藤蔓升降井", 0, "vertical"),
        ("ch04_room_14", "温室上梁", -2, "upper"),
        ("ch04_room_15", "根笼连战", 0, "danger"),
        ("ch04_room_16", "断弦门廊", 0, "field"),
        ("ch04_room_17", "断弦舞台", 0, "boss"),
        ("ch04_room_18", "温室外墙", 0, "exit"),
    ],
    5: [
        ("ch05_room_1", "黑曜前哨", -1, "entry"),
        ("ch05_room_2", "断旗长路", 1, "lower"),
        ("ch05_room_3", "盲钟营地", 0, "vertical"),
        ("ch05_room_4", "影门廊", -1, "upper"),
        ("ch05_room_5", "巡礼兵营", 0, "safe"),
        ("ch05_room_6", "王冠外桥", 1, "danger"),
        ("ch05_room_7", "黑曜跳台", -1, "parkour"),
        ("ch05_room_8", "灯影相位跑酷", 0, "vertical"),
        ("ch05_room_9", "雾桥冲刺", -1, "upper"),
        ("ch05_room_10", "统帅前阵", 0, "field"),
        ("ch05_room_11", "熄灯下层", 2, "lower"),
        ("ch05_room_12", "军墓回环", 2, "lower"),
        ("ch05_room_13", "旗影升降井", 0, "vertical"),
        ("ch05_room_14", "黑曜上桥", -2, "upper"),
        ("ch05_room_15", "军令连战", 0, "danger"),
        ("ch05_room_16", "阅兵门廊", 0, "field"),
        ("ch05_room_17", "静音阅兵场", 0, "boss"),
        ("ch05_room_18", "王冠门径", 0, "exit"),
    ],
    6: [
        ("ch06_room_1", "无声外壳", -1, "entry"),
        ("ch06_room_2", "王冠中枢", 1, "lower"),
        ("ch06_room_3", "苔钟回声室", 0, "vertical"),
        ("ch06_room_4", "铸雨回声室", -1, "upper"),
        ("ch06_room_5", "盐白回声室", 0, "safe"),
        ("ch06_room_6", "断弦回声室", 1, "danger"),
        ("ch06_room_7", "黑曜回声室", -1, "parkour"),
        ("ch06_room_8", "钟舌井", 0, "vertical"),
        ("ch06_room_9", "回声跳台", -1, "upper"),
        ("ch06_room_10", "无声风道跑酷", 0, "field"),
        ("ch06_room_11", "王冠下层回响", 2, "lower"),
        ("ch06_room_12", "五城回环", 2, "lower"),
        ("ch06_room_13", "第七升降井", 0, "vertical"),
        ("ch06_room_14", "无星上桥", -2, "upper"),
        ("ch06_room_15", "第七绯线廊", 0, "danger"),
        ("ch06_room_16", "核心前连战", 0, "field"),
        ("ch06_room_17", "无声王冠", 0, "boss"),
        ("ch06_room_18", "归线出口", 0, "exit"),
    ],
}


MATERIALS = {
    1: ("moss_stone", "bronze_bridge", "boss_stone", "1c2b1f", "6d6645", "47362f"),
    2: ("wet_metal", "rain_pipe", "foundry_boss", "344141", "3d5e66", "524338"),
    3: ("salt_marble", "vellum_bridge", "archive_boss", "4b493c", "73684a", "625644"),
    4: ("greenhouse_loam", "glassvine_bridge", "root_boss", "29422d", "426a4b", "3b4d31"),
    5: ("obsidian_basalt", "ember_bridge", "pilgrim_boss", "272734", "6e3d32", "3b3032"),
    6: ("crown_bone", "void_bridge", "core_boss", "3c4358", "343a64", "3d4258"),
}


PATHS = {
    1: DATA_DIR / "demo_ch01_moss_bell_court.json",
    2: DATA_DIR / "demo_ch02_rain_foundry_canal.json",
    3: DATA_DIR / "demo_ch03_saltwhite_archive.json",
    4: DATA_DIR / "demo_ch04_broken_string_greenhouse.json",
    5: DATA_DIR / "demo_ch05_obsidian_pilgrim_road.json",
    6: DATA_DIR / "demo_ch06_silent_crown_core.json",
}


def build_rooms(chapter: int) -> list[dict]:
    cursor = 0
    rooms: list[dict] = []
    room_specs = ROOMS[chapter]
    for index, (room_id, name, depth, kind) in enumerate(room_specs):
        width = ROOM_WIDTHS[chapter][index]
        end = cursor + width
        rooms.append(
            {
                "id": room_id,
                "name": name,
                "range": [cursor, end],
                "depth": depth,
                "kind": kind,
                "objective": f"{name}：沿横向主线推进，并观察上层/下层回路。",
                "guide": "主线保持横向可读；竖井连接上下层，捷径从背面回到熟悉区域。",
                "danger": "下层更宽但陷阱多，上层更安全但跳跃窗口更窄。",
                "next": room_specs[index + 1][1] if index + 1 < len(room_specs) else "章节出口",
            }
        )
        cursor = end
    return rooms


def room_range(rooms: list[dict], room_id: str) -> tuple[int, int]:
    for room in rooms:
        if room["id"] == room_id:
            return int(room["range"][0]), int(room["range"][1])
    raise KeyError(room_id)


def platform(platform_id: str, x: int, y: int, w: int, h: int, color: str, material: str) -> dict:
    return {"id": platform_id, "rect": [x, y, w, h], "color": color, "material": material}


def remove_old_late_platforms(chapter: int, platforms: list[dict]) -> list[dict]:
    if chapter == 1:
        cutoff = 9400
    elif chapter == 2:
        cutoff = 13900
    else:
        cutoff = 10700
    prefix = f"ch{chapter:02d}"
    generated_ids = {
        f"{prefix}_lower_loop_floor",
        f"{prefix}_lower_loop_mid",
        f"{prefix}_lower_loop_exit_lip",
        f"{prefix}_return_shaft_base",
        f"{prefix}_return_shaft_step_a",
        f"{prefix}_return_shaft_step_b",
        f"{prefix}_upper_bridge",
        f"{prefix}_upper_drop_step",
        f"{prefix}_crossway_floor",
        f"{prefix}_crossway_upper",
        f"{prefix}_preboss_floor",
        f"{prefix}_post_boss_run_step",
        f"{prefix}_exit_runup",
        f"{prefix}_exit_floor",
        f"{prefix}_anvil_bridge_mid",
    }
    removed_markers = ("boss_floor", "boss_back_wall", "post_boss", "pre_boss_floor")
    kept: list[dict] = []
    for item in platforms:
        pid = str(item.get("id", ""))
        x = int(item.get("rect", [0])[0])
        if pid in generated_ids or pid.startswith(f"{prefix}_late_route_link_"):
            continue
        if x >= cutoff or any(marker in pid for marker in removed_markers):
            continue
        kept.append(item)
    return kept


def late_route_start_x(platforms: list[dict]) -> float:
    for item in platforms:
        if item.get("id") == "backdoor_room":
            return float(item.get("rect", [3600])[0])
    return 3600.0


def add_late_route_connectors(
    chapter: int,
    platforms: list[dict],
    exit_x: int,
    color: str,
    material: str,
) -> None:
    prefix = f"ch{chapter:02d}"
    start_x = late_route_start_x(platforms)
    end_x = float(exit_x)
    if end_x <= start_x:
        return

    ranges: list[tuple[float, float]] = []
    for item in platforms:
        rect = item.get("rect", [])
        if len(rect) < 4:
            continue
        pid = str(item.get("id", "")).lower()
        x, y, width, height = [float(value) for value in rect[:4]]
        if any(marker in pid for marker in ("wall", "gate", "locked")):
            continue
        if width < 180.0 or height > 90.0 or y < 492.0 or y > 545.0:
            continue
        left = max(start_x, x)
        right = min(end_x, x + width)
        if right > left:
            ranges.append((left, right))
    ranges.sort()

    cursor = start_x
    link_index = 1
    for left, right in ranges:
        if left - cursor > 160.0:
            platforms.append(
                platform(
                    f"{prefix}_late_route_link_{link_index:02d}",
                    int(cursor),
                    540 if chapter != 1 else 500,
                    int(left - cursor),
                    30,
                    color,
                    material,
                )
            )
            link_index += 1
        cursor = max(cursor, right)
    if end_x - cursor > 160.0:
        platforms.append(
            platform(
                f"{prefix}_late_route_link_{link_index:02d}",
                int(cursor),
                540 if chapter != 1 else 500,
                int(end_x - cursor),
                30,
                color,
                material,
            )
        )


def add_common_late_platforms(chapter: int, data: dict, rooms: list[dict], platforms: list[dict]) -> None:
    ground_mat, accent_mat, boss_mat, ground_color, accent_color, boss_color = MATERIALS[chapter]
    prefix = f"ch{chapter:02d}"
    if chapter == 1:
        lower_id, shaft_id, upper_id, cross_id, preboss_id, boss_id, exit_id = (
            "lower_bell_cistern",
            "cistern_pump_shaft",
            "upper_crown_rafters",
            "bellmaker_crossway",
            "pre_boss_belfry",
            "boss_chamber",
            "chapter_exit",
        )
    elif chapter == 2:
        lower_id, shaft_id, upper_id, cross_id, preboss_id, boss_id, exit_id = (
            "drainage_underloop",
            "steam_return_shaft",
            "roof_pressure_bridge",
            "anvil_preboss",
            "anvil_preboss",
            "pump_king_hall",
            "oath_outlet",
        )
    else:
        lower_id = f"ch{chapter:02d}_room_11"
        shaft_id = f"ch{chapter:02d}_room_13"
        upper_id = f"ch{chapter:02d}_room_14"
        cross_id = f"ch{chapter:02d}_room_16"
        preboss_id = f"ch{chapter:02d}_room_16"
        boss_id = f"ch{chapter:02d}_room_17"
        exit_id = f"ch{chapter:02d}_room_18"

    lx0, lx1 = room_range(rooms, lower_id)
    sx0, sx1 = room_range(rooms, shaft_id)
    ux0, ux1 = room_range(rooms, upper_id)
    cx0, cx1 = room_range(rooms, cross_id)
    px0, px1 = room_range(rooms, preboss_id)
    bx0, bx1 = room_range(rooms, boss_id)
    ex0, ex1 = room_range(rooms, exit_id)

    # New lower loop, return shaft, upper bridge, and final horizontal approach.
    platforms.extend(
        [
            platform(f"{prefix}_lower_loop_floor", lx0 + 40, 610, lx1 - lx0 - 80, 34, ground_color, ground_mat),
            platform(f"{prefix}_lower_loop_mid", lx0 + 420, 520, 360, 28, accent_color, accent_mat),
            platform(f"{prefix}_lower_loop_exit_lip", lx1 - 210, 560, 220, 26, ground_color, ground_mat),
            platform(f"{prefix}_return_shaft_base", sx0 + 60, 540, 360, 30, ground_color, ground_mat),
            platform(f"{prefix}_return_shaft_step_a", sx0 + 360, 470, 260, 28, accent_color, accent_mat),
            platform(f"{prefix}_return_shaft_step_b", sx0 + 690, 400, 260, 28, accent_color, accent_mat),
            platform(f"{prefix}_upper_bridge", ux0 + 70, 350, ux1 - ux0 - 140, 28, accent_color, accent_mat),
            platform(f"{prefix}_upper_drop_step", ux1 - 280, 430, 260, 28, accent_color, accent_mat),
            platform(f"{prefix}_crossway_floor", cx0 + 20, 540, cx1 - cx0 - 40, 34, ground_color, ground_mat),
            platform(f"{prefix}_crossway_upper", cx0 + 420, 452, 380, 28, accent_color, accent_mat),
            platform(f"{prefix}_preboss_floor", px0 + 30, 540, px1 - px0 - 60, 34, boss_color, boss_mat),
            platform("boss_floor", bx0, 540 if chapter != 1 else 500, bx1 - bx0 - 140, 44, boss_color, boss_mat),
            platform("boss_back_wall", bx1 - 140, 315 if chapter != 1 else 300, 38, 270 if chapter != 1 else 244, boss_color, boss_mat),
            platform(f"{prefix}_post_boss_run_step", bx1 - 150, 540 if chapter != 1 else 500, 300, 34, boss_color, boss_mat),
            platform(f"{prefix}_exit_runup", ex0 - 10, 540 if chapter != 1 else 500, ex1 - ex0 - 170, 34, boss_color, boss_mat),
            platform(f"{prefix}_exit_floor", ex1 - 320, 540 if chapter != 1 else 520, 320, 34, boss_color, boss_mat),
        ]
    )

    if chapter == 2:
        # CH02 has a longer late route, so add one extra foundry bridge to keep gaps small.
        platforms.append(platform("ch02_anvil_bridge_mid", px0 + 520, 455, 360, 28, accent_color, accent_mat))
        if not any(item.get("id") == "wet_wall_shaft_exit" for item in platforms):
            platforms.append(platform("wet_wall_shaft_exit", 5820, 350, 260, 28, "746943", "sluice_bridge"))
        if not any(item.get("id") == "echo_hook_exit" for item in platforms):
            platforms.append(platform("echo_hook_exit", 9320, 382, 300, 28, "746943", "sluice_bridge"))

    boss_floor_y = 500 if chapter == 1 else 540
    boss_y = boss_floor_y - 40
    gate_x = bx0 + 210
    boss_x = bx0 + 720
    exit_x = ex1 - 180
    add_late_route_connectors(chapter, platforms, exit_x, boss_color, boss_mat)

    data["boss_checkpoint"] = [px0 + 180, 500]
    data["boss"]["position"] = [boss_x, boss_y]
    data["boss"]["arena_min_x"] = bx0 + 120
    data["boss"]["arena_max_x"] = bx1 - 260
    if "patrol" in data["boss"]:
        data["boss"]["patrol"] = 260
    for interactive in data.get("interactives", []):
        kind = interactive.get("kind", "")
        if kind == "boss_gate":
            interactive["position"] = [gate_x, boss_y]
        elif kind in ("chapter_exit", "ending_exit"):
            interactive["position"] = [exit_x, 480 if chapter == 1 else 500]


def build_connections(rooms: list[dict]) -> list[dict]:
    connections = [
        {"from": rooms[index]["id"], "to": rooms[index + 1]["id"], "type": "passage"}
        for index in range(len(rooms) - 1)
    ]
    lower_rooms = [room for room in rooms if room["kind"] == "lower"]
    upper_rooms = [room for room in rooms if room["kind"] == "upper"]
    vertical_rooms = [room for room in rooms if room["kind"] == "vertical"]
    if lower_rooms and vertical_rooms:
        connections.append({"from": lower_rooms[-1]["id"], "to": vertical_rooms[-1]["id"], "type": "lower_return"})
    if upper_rooms:
        boss_or_danger = next((room for room in rooms if room["kind"] == "danger" and room["range"][0] > upper_rooms[-1]["range"][0]), None)
        if boss_or_danger is not None:
            connections.append({"from": upper_rooms[-1]["id"], "to": boss_or_danger["id"], "type": "upper_shortcut"})
    safe_rooms = [room for room in rooms if room["kind"] == "safe"]
    boss_rooms = [room for room in rooms if room["kind"] == "boss"]
    if safe_rooms and boss_rooms:
        connections.append({"from": safe_rooms[-1]["id"], "to": boss_rooms[0]["id"], "type": "opened_shortcut"})
    return connections


def platform_top_by_id(platforms: list[dict], platform_id: str) -> int:
    for item in platforms:
        if item["id"] == platform_id:
            return int(item["rect"][1])
    raise KeyError(platform_id)


def platform_center_x(platforms: list[dict], platform_id: str, offset: int = 0) -> int:
    for item in platforms:
        if item["id"] == platform_id:
            rect = item["rect"]
            return int(rect[0] + rect[2] // 2 + offset)
    raise KeyError(platform_id)


def update_enemy_spawns(chapter: int, data: dict, platforms: list[dict]) -> None:
    templates_by_kind = {}
    for enemy in data.get("enemy_spawns", []):
        templates_by_kind.setdefault(enemy["kind"], enemy)
    kinds = list(templates_by_kind)
    if not kinds:
        return

    prefix = f"CH{chapter:02d}"
    if chapter == 1:
        placements = [
            ("E01", "moss_larva", "outer_drop", -80),
            ("E02", "bronze_moth", "gear_lift", 80),
            ("E03", "spore_bellmaker", "moss_steps_b", 0),
            ("E04", "moss_larva", "backdoor_room", 0),
            ("E05", "gear_sentinel", "boss_runback", 360),
            ("CH01_E_EXP01", "bronze_moth", "ch01_echo_trench_floor", 220),
            ("CH01_E_EXP02", "spore_bellmaker", "ch01_old_rope_upper_bridge", 80),
            ("CH01_E_EXP03", "moss_larva", "ch01_bell_tangle_floor", 120),
            ("CH01_E_EXP04", "gear_sentinel", "ch01_runback_after_tangle", 80),
            ("CH01_E_EXP05", "moss_larva", "ch01_lower_loop_floor", 180),
            ("CH01_E_EXP06", "bronze_moth", "ch01_upper_bridge", 120),
            ("CH01_E_EXP07", "spore_bellmaker", "ch01_crossway_floor", -120),
        ]
    elif chapter == 2:
        placements = [
            ("C2_E01", "drain_leech", "outer_low_floor", -180),
            ("C2_E02", "pipe_thrower", "pump_lift_base", 0),
            ("C2_E03", "rust_diver", "pipe_roof_bridge", 100),
            ("C2_E04", "bell_mote", "foundry_runback_floor", 0),
            ("C2_E05", "waterwheel_knight", "hammer_yard_floor", -120),
            ("C2_E06", "drain_leech", "anvil_lift_floor", 0),
            ("C2_E07", "pipe_thrower", "anvil_lift_upper", 0),
            ("C2_E08", "bell_mote", "echo_hook_mid_island", 0),
            ("C2_E09", "waterwheel_knight", "hammer_yard_floor", 180),
            ("C2_E10", "rust_diver", "anvil_lift_floor", 120),
            ("C2_E11", "pipe_thrower", "ch02_lower_loop_floor", -140),
            ("C2_E12", "rust_diver", "ch02_return_shaft_base", 80),
            ("C2_E13", "drain_leech", "ch02_upper_bridge", 180),
            ("C2_E14", "waterwheel_knight", "ch02_preboss_floor", 120),
        ]
    else:
        existing = data.get("enemy_spawns", [])
        template_platforms = [
            "outer_low_floor",
            "lift_base",
            "upper_bridge_a",
            f"ch{chapter:02d}_runback_floor",
            f"ch{chapter:02d}_parkour_floor_a",
            f"ch{chapter:02d}_parkour_upper_a",
            f"ch{chapter:02d}_parkour_upper_b",
            f"ch{chapter:02d}_sprint_floor",
            f"ch{chapter:02d}_gauntlet_floor",
            f"ch{chapter:02d}_approach_floor",
            f"ch{chapter:02d}_lower_loop_floor",
            f"ch{chapter:02d}_return_shaft_base",
            f"ch{chapter:02d}_upper_bridge",
            f"ch{chapter:02d}_preboss_floor",
        ]
        placements = []
        for index, platform_id in enumerate(template_platforms):
            kind = existing[index % len(existing)]["kind"]
            placements.append((f"{prefix}_E{index + 1:02d}", kind, platform_id, (-120 if index % 2 == 0 else 120)))

    new_spawns = []
    for spawn_id, kind, platform_id, offset in placements:
        template = deepcopy(templates_by_kind[kind])
        template["id"] = spawn_id
        template["platform_id"] = platform_id
        x = platform_center_x(platforms, platform_id, offset)
        y = platform_top_by_id(platforms, platform_id) - 40
        template["position"] = [x, y]
        template["patrol"] = max(80, int(template.get("patrol", 80)))
        template["leash_radius"] = min(260, int(template.get("leash_radius", 220)))
        new_spawns.append(template)
    data["enemy_spawns"] = new_spawns


def update_hazards(chapter: int, data: dict, platforms: list[dict]) -> None:
    existing = data.get("hazards", [])
    kind_cycle = [item.get("kind", "bell_gap") for item in existing] or ["bell_gap"]
    platform_ids = [
        item["id"]
        for item in platforms
        if item["rect"][2] >= 240 and not any(marker in item["id"] for marker in ("boss_back_wall", "wall", "gate"))
    ]
    selected = platform_ids[1::4][:12]
    hazards = []
    for index, platform_id in enumerate(selected):
        top = platform_top_by_id(platforms, platform_id)
        x = platform_center_x(platforms, platform_id, 0) - 55
        hazard_id = f"ch{chapter:02d}_hazard_{index + 1:02d}"
        if chapter == 1 and index == 0:
            hazard_id = "trap_fake_moss_01"
        hazards.append(
            {
                "id": hazard_id,
                "kind": kind_cycle[index % len(kind_cycle)],
                "rect": [x, top - 24, 110, 24],
                "damage": 1,
                "message": "多层扩建路线上出现预警陷阱。",
            }
        )
    data["hazards"] = hazards


def update_save_points(chapter: int, data: dict, platforms: list[dict]) -> None:
    prefix = f"ch{chapter:02d}"
    hidden_platform = f"{prefix}_upper_bridge" if chapter != 1 else "ch01_upper_bridge"
    preboss_platform = f"{prefix}_preboss_floor" if chapter != 1 else "ch01_preboss_floor"
    hidden = deepcopy(data.get("save_points", [{}])[0]) if data.get("save_points") else {}
    hidden.update(
        {
            "id": "save_hidden_upper_respite",
            "position": [platform_center_x(platforms, hidden_platform, -120), platform_top_by_id(platforms, hidden_platform) - 40],
            "hidden": True,
        }
    )
    late = deepcopy(data.get("save_points", [{}])[-1]) if data.get("save_points") else {}
    late.update(
        {
            "id": "save_late_runback",
            "position": [platform_center_x(platforms, preboss_platform, -140), platform_top_by_id(platforms, preboss_platform) - 40],
            "hidden": False,
        }
    )
    if chapter == 1:
        data["save_points"] = [hidden, late]
        return
    mid_platform = f"{prefix}_lower_loop_floor"
    mid = deepcopy(late)
    mid.update(
        {
            "id": f"save_{prefix}_lower_loop",
            "label": f"第{chapter}章下层回环存档点",
            "position": [platform_center_x(platforms, mid_platform, 160), platform_top_by_id(platforms, mid_platform) - 40],
            "hidden": False,
            "note": "扩建后下层回环的中段存档点。",
        }
    )
    data["save_points"] = [hidden, mid, late]


def update_parkour(chapter: int, data: dict) -> None:
    prefix = f"ch{chapter:02d}"
    if chapter == 1:
        data["parkour_segments"] = [
            {
                "id": "ch01_outer_court_return",
                "room_id": "outer_court",
                "technique": "drop recovery + short hop return route",
                "platforms": ["outer_drop", "outer_return_lip", "gear_lift", "gear_lift_return_step", "moss_steps_a"],
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
    else:
        generated_ids = {f"{prefix}_lower_upper_return", f"{prefix}_preboss_crossway"}
        existing = [
            segment for segment in data.get("parkour_segments", [])
            if not (isinstance(segment, dict) and segment.get("id") in generated_ids)
        ]
        existing.append(
            {
                "id": f"{prefix}_lower_upper_return",
                "room_id": ROOMS[chapter][-6][0],
                "technique": "lower loop, return shaft, upper bridge",
                "platforms": [
                    f"{prefix}_lower_loop_floor",
                    f"{prefix}_return_shaft_base",
                    f"{prefix}_return_shaft_step_a",
                    f"{prefix}_return_shaft_step_b",
                    f"{prefix}_upper_bridge",
                ],
            }
        )
        existing.append(
            {
                "id": f"{prefix}_preboss_crossway",
                "room_id": ROOMS[chapter][-3][0],
                "technique": "upper drop into final horizontal approach",
                "platforms": [f"{prefix}_upper_drop_step", f"{prefix}_crossway_floor", f"{prefix}_preboss_floor", "boss_floor"],
            }
        )
        data["parkour_segments"] = existing


def update_layout(chapter: int) -> None:
    path = PATHS[chapter]
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    rooms = build_rooms(chapter)
    data["map_rooms"] = rooms
    data["world"]["width"] = rooms[-1]["range"][1]
    data["map_layout_tags"] = ["horizontal_mainline", "upper_route", "lower_route", "vertical_shaft", "opened_shortcut"]
    data["connections"] = build_connections(rooms)

    platforms = remove_old_late_platforms(chapter, data.get("platforms", []))
    add_common_late_platforms(chapter, data, rooms, platforms)
    data["platforms"] = platforms

    update_enemy_spawns(chapter, data, platforms)
    update_hazards(chapter, data, platforms)
    update_save_points(chapter, data, platforms)
    update_parkour(chapter, data)

    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"expanded {path.name}: width={data['world']['width']} rooms={len(data['map_rooms'])} "
        f"platforms={len(data['platforms'])} enemies={len(data['enemy_spawns'])}"
    )


def main() -> None:
    for chapter in range(1, 7):
        update_layout(chapter)


if __name__ == "__main__":
    main()
