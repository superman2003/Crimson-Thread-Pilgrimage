from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "data" / "demo_ch01_moss_bell_court.json"


ROOM_SPECS = [
    ("entry_bell", "苔钟入口", 0, 900, 0, "gate", "教学入口：NPC、基础跳跃和第一处可见上层路线。"),
    ("outer_court", "外庭下阶", 900, 1900, 1, "lower", "向下展开的第一处战斗庭院，教玩家用低路线绕过正门。"),
    ("gear_lift", "齿轮升降井", 1900, 2650, 0, "vertical", "短竖井，把下层外庭送回中线并展示地图图例。"),
    ("upper_bells", "上层钟叶廊", 2650, 3520, -1, "upper", "第一条上层支线，节奏为短跳、空中敌人和隐藏高台。"),
    ("backdoor", "后门小礼拜堂", 3520, 4320, 0, "safe", "安全房和捷径拉杆，连接 Boss 回廊的中线起点。"),
    ("runback", "王冠回廊", 4320, 5480, 0, "danger", "中线战斗回廊，让玩家从安全房进入连续战斗。"),
    ("echo_moss_trench", "回响苔沟", 5480, 6620, 2, "lower", "下层苔沟，放置宽平台和低风险敌群。"),
    ("old_bell_rope", "旧钟绳井", 6620, 7620, -1, "vertical", "第二个竖向枢纽，同时连接下层回环和上层捷径。"),
    ("bell_leaf_tangle", "钟叶缠结处", 7620, 8780, -1, "upper", "上层平台编织区，制造连续跳跃和视野奖励。"),
    ("lower_bell_cistern", "沉钟蓄水槽", 8780, 9800, 2, "lower", "可选下层绕行，有陷阱、敌人和回升出口。"),
    ("cistern_pump_shaft", "苔轮回升井", 9800, 10720, 0, "vertical", "从蓄水槽回到主线，形成完整下层回环。"),
    ("upper_crown_rafters", "王冠上梁", 10720, 11740, -2, "upper", "隐藏存档和上层捷径，奖励探索。"),
    ("bellmaker_crossway", "钟匠横桥", 11740, 12580, 0, "field", "中线汇合点，衔接 Boss 前冲刺。"),
    ("pre_boss_belfry", "首领前钟廊", 12580, 13240, 0, "danger", "Boss 前缓冲、存档和最终提示。"),
    ("boss_chamber", "锈冠大厅", 13240, 14460, 0, "boss", "Boss 房，入口门、锁场墙和战后出口阻挡。"),
    ("chapter_exit", "沉钟出口", 14460, 14800, 0, "exit", "战后出口，通往第二章铸雨渠。"),
]


def platform(platform_id: str, x: int, y: int, w: int, h: int, color: str, material: str) -> dict:
    return {"id": platform_id, "rect": [x, y, w, h], "color": color, "material": material}


def hazard(hazard_id: str, kind: str, x: int, y: int, w: int = 110, h: int = 24) -> dict:
    return {
        "id": hazard_id,
        "kind": kind,
        "rect": [x, y, w, h],
        "damage": 1,
        "message": "旧苔钟机关被触发，巡礼者被迫后撤。",
    }


def build_rooms() -> list[dict]:
    rooms: list[dict] = []
    for index, (room_id, name, start, end, depth, kind, objective) in enumerate(ROOM_SPECS):
        next_name = ROOM_SPECS[index + 1][1] if index + 1 < len(ROOM_SPECS) else "第二章入口"
        rooms.append(
            {
                "id": room_id,
                "name": name,
                "range": [start, end],
                "depth": depth,
                "kind": kind,
                "objective": objective,
                "guide": "主线保持中层可读；下层用于绕行和资源压力；上层用于捷径、存档和视野奖励。",
                "danger": "下层空间宽但陷阱多；上层跳跃更窄；Boss 前回廊要求连续处理近战敌人。",
                "next": next_name,
            }
        )
    return rooms


def build_platforms() -> list[dict]:
    moss = "1c2b1f"
    moss_dark = "22351f"
    moss_mid = "29402f"
    bronze = "6d6645"
    boss = "47362f"
    platforms = [
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
        platform("ch01_return_shaft_base", 9940, 540, 380, 30, moss, "moss_stone"),
        platform("ch01_return_shaft_step_a", 10240, 470, 270, 28, bronze, "bronze_bridge"),
        platform("ch01_return_shaft_step_b", 10580, 400, 270, 28, bronze, "bronze_bridge"),
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
        platform("ch01_exit_floor", 14480, 520, 320, 34, boss, "boss_stone"),
        platform("ch01_late_route_link_01", 9340, 500, 360, 30, boss, "boss_stone"),
        platform("ch01_late_route_link_02", 9700, 500, 1500, 30, boss, "boss_stone"),
        platform("ch01_late_route_link_03", 11200, 500, 1540, 30, boss, "boss_stone"),
        platform("ch01_late_route_link_04", 12740, 500, 1880, 30, boss, "boss_stone"),
    ]
    return platforms


def clone_enemy(template: dict, enemy_id: str, position: list[int], platform_id: str, patrol: int = 90, leash: int = 220) -> dict:
    enemy = deepcopy(template)
    enemy["id"] = enemy_id
    enemy["position"] = position
    enemy["platform_id"] = platform_id
    enemy["patrol"] = patrol
    enemy["leash_radius"] = leash
    return enemy


def build_enemies(existing: list[dict]) -> list[dict]:
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
        (larva, "CH01_E_EXP05", [9580, 570], "ch01_lower_loop_floor", 90, 220),
        (moth, "CH01_E_EXP06", [11420, 310], "ch01_upper_bridge", 80, 190),
        (bellmaker, "CH01_E_EXP07", [12120, 500], "ch01_crossway_floor", 80, 190),
        (sentinel, "CH01_E_EXP08", [12860, 500], "ch01_preboss_floor", 80, 180),
    ]
    return [clone_enemy(*spec) for spec in specs]


def build_npcs(existing: list[dict]) -> list[dict]:
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


def build_connections() -> list[dict]:
    rooms = [room[0] for room in ROOM_SPECS]
    connections = [{"from": rooms[index], "to": rooms[index + 1], "type": "passage"} for index in range(len(rooms) - 1)]
    connections.extend(
        [
            {"from": "entry_bell", "to": "upper_bells", "type": "visible_shortcut"},
            {"from": "outer_court", "to": "gear_lift", "type": "lower_return"},
            {"from": "runback", "to": "echo_moss_trench", "type": "drop_route"},
            {"from": "lower_bell_cistern", "to": "cistern_pump_shaft", "type": "lower_return"},
            {"from": "old_bell_rope", "to": "upper_crown_rafters", "type": "upper_shortcut"},
            {"from": "upper_crown_rafters", "to": "pre_boss_belfry", "type": "upper_shortcut"},
            {"from": "backdoor", "to": "boss_chamber", "type": "opened_shortcut"},
        ]
    )
    return connections


def update_first_chapter() -> None:
    data = json.loads(CONFIG_PATH.read_text(encoding="utf-8-sig"))
    data["name"] = "苔钟庭试玩章"
    data["map_title"] = "苔钟庭：外庭下阶 / 旧钟绳井 / 王冠回廊"
    data["goal"] = "穿过苔钟庭的外庭、下层蓄水槽与上层钟梁，清理巡礼路上的敌群，打开锈冠大厅并击败锈冠守卫。"
    data["world"] = {"width": 14800, "height": 720, "fall_y": 820}
    data["fall_y"] = 820
    data["player_start"] = [120, 500]
    data["boss_checkpoint"] = [12760, 500]
    data["map_rooms"] = build_rooms()
    data["platforms"] = build_platforms()
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
    data["enemy_spawns"] = build_enemies(data.get("enemy_spawns", []))
    data["save_points"] = [
        {
            "id": "save_hidden_upper_respite",
            "label": "隐苔存档点",
            "position": [11180, 310],
            "hidden": True,
            "note": "藏在王冠上梁的稀疏存档点，奖励探索上层路线。",
        },
        {
            "id": "save_late_runback",
            "label": "首领前回响苔灯",
            "position": [12760, 500],
            "hidden": False,
            "note": "Boss 前中段存档点，避免第一章后半段重复跑图过长。",
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
    data["npcs"] = build_npcs(data.get("npcs", []))
    boss = deepcopy(data["boss"])
    boss["position"] = [13920, 460]
    boss["arena_min_x"] = 13320
    boss["arena_max_x"] = 14180
    data["boss"] = boss
    data["parkour_segments"] = [
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
    data["connections"] = build_connections()
    data["map_layout_tags"] = [
        "from_scratch_ch01",
        "horizontal_mainline",
        "upper_shortcut",
        "lower_detour",
        "vertical_shaft",
        "opened_shortcut",
        "boss_antechamber",
    ]
    data["labels"] = [
        {"text": "入口：先学跳跃、交互和第一条上层视线。", "position": [180, 458], "color": "9ef0dc"},
        {"text": "外庭：下层绕行，敌群间距更宽。", "position": [1320, 570], "color": "e6d28c"},
        {"text": "钟绳井：从下层回到上层，形成第一章核心回环。", "position": [6720, 340], "color": "c7e6ff"},
        {"text": "王冠上梁：隐藏存档，奖励探索。", "position": [10880, 300], "color": "9ef0dc"},
        {"text": "首领前：存档、提示、短冲刺后进入锈冠大厅。", "position": [12480, 466], "color": "f2b873"},
    ]

    CONFIG_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"GENERATE_CH01_MAP_PASS path={CONFIG_PATH} rooms={len(data['map_rooms'])} platforms={len(data['platforms'])} enemies={len(data['enemy_spawns'])}")


if __name__ == "__main__":
    update_first_chapter()
