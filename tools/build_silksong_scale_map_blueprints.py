from __future__ import annotations

import json
import math
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "silksong_scale"
DOC_SPEC_DIR = ROOT / "docs" / "spec"
DOC_PLAN_DIR = ROOT / "docs" / "plan"


CANVAS_W = 6000
CANVAS_H = 3600
OUTPUT_SCALE = 2
OVERVIEW_W = 7680
OVERVIEW_H = 4320


PALETTE = {
    "bg": "#f5f1e6",
    "ink": "#20242b",
    "muted": "#606775",
    "grid": "#ded5c6",
    "room": "#fff8e8",
    "room_shadow": "#c8bba8",
    "main": "#d23b3b",
    "branch": "#5c6f99",
    "shortcut": "#2f9d73",
    "lock": "#8e54b7",
    "hidden": "#7f6a3d",
    "danger": "#d47a2a",
    "save": "#2b8ac6",
    "boss": "#9f2b2b",
    "npc": "#477a48",
    "reward": "#b78b16",
    "exit": "#1a6566",
    "white": "#ffffff",
}


CLUSTER_COLORS = [
    "#ead8a9",
    "#cfe3b2",
    "#b9d4df",
    "#e7bdaf",
    "#d2c3e7",
    "#c9dec8",
    "#efd0a6",
    "#bfc7e6",
    "#e1c6da",
    "#bfe1d5",
    "#e6dfb4",
    "#cfdae5",
]


CHAPTERS = [
    {
        "id": "ch01",
        "slug": "moss_bell_court",
        "title": "第一章 苔铃外庭",
        "theme": "苔藓庭院、钟廊、湿木台阶、地下根道",
        "room_count": 64,
        "clusters": [
            "旧驿门厅",
            "苔钟前庭",
            "雨棚廊桥",
            "根须蓄水井",
            "破铃训练院",
            "月光温室",
            "虫蜡栈道",
            "外庭钟塔",
            "封印根门",
            "主母巢厅",
        ],
        "abilities": ["丝线钩刺", "下劈反弹", "苔铃钥记"],
        "boss": "苔铃主母",
        "loop_note": "用钟塔纵井把前庭、温室、巢厅三层打通，Boss 前存档到战场不超过 2 房间。",
    },
    {
        "id": "ch02",
        "slug": "rain_foundry_canal",
        "title": "第二章 铸雨渠",
        "theme": "雨水工厂、齿轮泵、铁渠、蒸汽阀门",
        "room_count": 68,
        "clusters": [
            "排水闸口",
            "铸雨主渠",
            "齿轮泵房",
            "赤锈熔桥",
            "旧矿升降井",
            "蒸汽祷告室",
            "回流暗渠",
            "阀门守卫线",
            "暴雨蓄压池",
            "剪刀使徒坛",
        ],
        "abilities": ["阀门冲刺", "水轮二段跳", "赤锈耐热"],
        "boss": "绯线剪刀使徒",
        "loop_note": "核心是横向长渠加两根竖井，阀门捷径让后半段回到主渠中点。",
    },
    {
        "id": "ch03",
        "slug": "saltwhite_archive",
        "title": "第三章 盐白档案馆",
        "theme": "盐晶书库、折叠档案、审判柜、纸页虫群",
        "room_count": 66,
        "clusters": [
            "盐门阅览阶",
            "折页中庭",
            "索引长廊",
            "无声书井",
            "纸虫孵化柜",
            "审判抄写室",
            "镜面禁库",
            "空白祈祷台",
            "倒置档案塔",
            "灰冠战台",
        ],
        "abilities": ["索引传送", "镜面穿梭", "盐晶护符"],
        "boss": "灰冠螳螂军阀",
        "loop_note": "用折页门做回访门，首次路线绕远，拿镜面穿梭后缩短为 1/3。",
    },
    {
        "id": "ch04",
        "slug": "broken_string_greenhouse",
        "title": "第四章 断弦温室",
        "theme": "荆棘温室、铜根礼拜堂、花粉机关、断弦升降台",
        "room_count": 72,
        "clusters": [
            "断弦门廊",
            "铜根礼拜堂",
            "花粉玻璃房",
            "荆刺回廊",
            "菌灯深棚",
            "坠藤井",
            "虫蜡育苗区",
            "回声音乐台",
            "王冠种子库",
            "铜根主教席",
            "沉睡根核",
        ],
        "abilities": ["荆刺攀附", "花粉滑翔", "根脉共鸣"],
        "boss": "铜根主教",
        "loop_note": "强调高低差与滑翔回环，温室外壳是大环，内部三条支线互相打通。",
    },
    {
        "id": "ch05",
        "slug": "obsidian_pilgrim_road",
        "title": "第五章 黑曜朝圣路",
        "theme": "黑曜山路、蜡像队列、钟火驿站、裂谷桥",
        "room_count": 70,
        "clusters": [
            "朝圣起坡",
            "黑曜碑林",
            "蜡像商队营",
            "裂谷悬桥",
            "钟火墓坡",
            "风切尖塔",
            "灰烬货梯",
            "忏悔环道",
            "王路封门",
            "镜池婚坛",
        ],
        "abilities": ["风切冲刺", "黑曜踏壁", "钟火开门"],
        "boss": "镜池新娘",
        "loop_note": "用裂谷桥做章节视觉锚点，前后两端各有回城捷径，后期可从尖塔直落 Boss 区。",
    },
    {
        "id": "ch06",
        "slug": "silent_crown_core",
        "title": "第六章 无声冠核",
        "theme": "王冠内核、无声钟室、银线管道、最终礼仪宫",
        "room_count": 74,
        "clusters": [
            "冠核外环",
            "银线检修廊",
            "无声钟室",
            "王座下水脉",
            "记忆回收井",
            "折光审判桥",
            "终礼祭衣间",
            "赤线心房",
            "白冠观象台",
            "最终封坛",
            "回忆侧厅",
            "余烬电梯",
        ],
        "abilities": ["赤线相位", "王冠静默", "终礼钥记"],
        "boss": "赤庭终礼司祭",
        "loop_note": "终章采用三层环形核结构，全部前章能力都能开回访门，最终 Boss 前形成短闭环。",
    },
]


@dataclass(frozen=True)
class Room:
    id: str
    index: int
    cluster: str
    name: str
    x: int
    y: int
    w: int
    h: int
    kind: str
    lane: str
    tags: list[str]
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
    event_type: str
    event_trigger: str
    event_feedback: str
    event_validation: str


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyhbd.ttc") if bold else Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for font_path in candidates:
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size=size)
    return ImageFont.load_default()


FONT_TITLE = load_font(54, True)
FONT_H2 = load_font(34, True)
FONT_BODY = load_font(24)
FONT_SMALL = load_font(18)
FONT_TINY = load_font(14)


def timestamp() -> str:
    return datetime.now().strftime("%Y%m%d%H%M%S%f")[:-3]


def ensure_dirs() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    DOC_SPEC_DIR.mkdir(parents=True, exist_ok=True)
    DOC_PLAN_DIR.mkdir(parents=True, exist_ok=True)


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, fill: str, font: ImageFont.ImageFont, anchor: str | None = None) -> None:
    draw.text(xy, value, fill=fill, font=font, anchor=anchor)


def center(room: Room) -> tuple[int, int]:
    return (room.x + room.w // 2, room.y + room.h // 2)


def room_rect(room: Room) -> tuple[int, int, int, int]:
    return (room.x, room.y, room.x + room.w, room.y + room.h)


def draw_arrow(
    draw: ImageDraw.ImageDraw,
    p1: tuple[int, int],
    p2: tuple[int, int],
    fill: str,
    width: int = 5,
    dash: bool = False,
) -> None:
    x1, y1 = p1
    x2, y2 = p2
    if dash:
        segments = 18
        for i in range(segments):
            if i % 2 == 0:
                a = i / segments
                b = (i + 0.65) / segments
                sx = x1 + (x2 - x1) * a
                sy = y1 + (y2 - y1) * a
                ex = x1 + (x2 - x1) * b
                ey = y1 + (y2 - y1) * b
                draw.line((sx, sy, ex, ey), fill=fill, width=width)
    else:
        draw.line((x1, y1, x2, y2), fill=fill, width=width)
    angle = math.atan2(y2 - y1, x2 - x1)
    head_len = 22
    head_angle = 0.55
    a1 = angle + math.pi - head_angle
    a2 = angle + math.pi + head_angle
    p3 = (x2 + head_len * math.cos(a1), y2 + head_len * math.sin(a1))
    p4 = (x2 + head_len * math.cos(a2), y2 + head_len * math.sin(a2))
    draw.polygon([p2, p3, p4], fill=fill)


CLUSTER_SHAPES = [
    "entry_spine",
    "tall_shaft",
    "loop_gallery",
    "reward_cave",
    "wide_canal",
    "boss_run",
]

ROOM_ARCHETYPE_RULES = {
    "entry_gate": {
        "goal": "Teach the first landmark, safe footing, and the chapter visual language.",
        "traversal": "low-risk walk_jump",
        "reward": "orientation, map silhouette, first safe return point",
    },
    "region_hub": {
        "goal": "Create a memorable local hub that reconnects branches after exploration.",
        "traversal": "multi-exit loop reading",
        "reward": "route choice, NPC hint, shortcut awareness",
    },
    "main_spine": {
        "goal": "Carry the upward pilgrimage through a readable critical path.",
        "traversal": "walk_jump_dash pacing",
        "reward": "forward progress and landmark reveal",
    },
    "vertical_shaft": {
        "goal": "Make height change visible so later abilities recontextualize the room.",
        "traversal": "tiered platforms and fall-safe returns",
        "reward": "future gate sightline or upper route preview",
    },
    "loop_gallery": {
        "goal": "Wrap the player back near a known room after a longer detour.",
        "traversal": "two-level loop with bridge supports",
        "reward": "spatial memory and return-path compression",
    },
    "reward_pocket": {
        "goal": "Offer optional risk with a clean exit back to the main route.",
        "traversal": "short side challenge",
        "reward": "currency, lore, health shard, or tool material",
    },
    "ability_tutorial": {
        "goal": "Immediately prove the value of a new ability before using it as a gate.",
        "traversal": "single-mechanic teaching room",
        "reward": "new ability and one obvious use case",
    },
    "shortcut_lock": {
        "goal": "Show a closed return path first, then let the far side open it.",
        "traversal": "one_way_until_open",
        "reward": "shorter runback and stronger world memory",
    },
    "hidden_reward": {
        "goal": "Reward close reading without blocking critical progression.",
        "traversal": "optional search pocket",
        "reward": "rare item or lore room",
    },
    "overlook_branch": {
        "goal": "Let the player see a goal or route before they can reach it.",
        "traversal": "upper balcony and safe drop",
        "reward": "foreshadowed destination",
    },
    "return_passage": {
        "goal": "Use lower routes as backflow after a branch, shortcut, or ability pickup.",
        "traversal": "downward path with recovery ledges",
        "reward": "backtracking relief and familiar exit",
    },
    "preboss_run": {
        "goal": "Keep the final approach tense but short after a save point.",
        "traversal": "compact gauntlet",
        "reward": "boss anticipation without long death runback",
    },
    "boss_arena": {
        "goal": "Provide a clear combat stage with readable edges and recovery space.",
        "traversal": "arena movement",
        "reward": "chapter boss clear and exit unlock",
    },
}

CLUSTER_MACRO_RULES = {
    "entry_spine": "early readable spine with a few visible branches",
    "tall_shaft": "vertical memory anchor that later abilities compress",
    "loop_gallery": "wide loop that returns to a known room",
    "reward_cave": "optional pocket cluster with risk/reward exits",
    "wide_canal": "horizontal travel band broken by vertical callbacks",
    "boss_run": "late gauntlet with short save-to-boss runback",
}

CH01_VERTICAL_SLICE_ROOMS = {
    1: {
        "setpiece": "moss_bell_entry_silhouette",
        "micro_objective": "Enter safely, read the bell tower silhouette, and learn the main route color language.",
        "landmark": "broken station gate under a hanging moss bell",
        "mechanic_prompt": "Safe floor, one optional ledge, no punishment.",
        "playtest_note": "Player should understand the first destination within ten seconds.",
    },
    3: {
        "setpiece": "first_overlook_save_balcony",
        "micro_objective": "Rest at the first save and see a locked return path above the main route.",
        "landmark": "small balcony save point looking over the entry spine",
        "mechanic_prompt": "Show an upper route before it is useful.",
        "playtest_note": "Player should remember this balcony when a later shortcut opens.",
    },
    5: {
        "setpiece": "cartographer_lower_pocket",
        "micro_objective": "Drop into a safe lower pocket, meet the route hint NPC, and return to the spine.",
        "landmark": "low moss alcove with map witness",
        "mechanic_prompt": "Teach optional detour with no permanent commitment.",
        "playtest_note": "Optional pocket should not feel like the critical path.",
    },
    7: {
        "setpiece": "first_backside_shortcut_lock",
        "micro_objective": "See a sealed shortcut door from the wrong side before reaching its lever later.",
        "landmark": "green-etched locked grate facing the entry route",
        "mechanic_prompt": "One-way shortcut promise.",
        "playtest_note": "Player should see why opening this will shorten travel.",
    },
    8: {
        "setpiece": "moss_bell_court_hub",
        "micro_objective": "Choose between the main path, upper shaft, and reward branch while keeping the bell tower visible.",
        "landmark": "wide bell court with three visible exits",
        "mechanic_prompt": "Local hub reading.",
        "playtest_note": "This room is the first place the map should feel non-linear but readable.",
    },
    9: {
        "setpiece": "visible_upper_shaft_goal",
        "micro_objective": "Climb a partial shaft and preview a ledge that will become easier after the first ability.",
        "landmark": "mossy vertical shaft with a high brass lip",
        "mechanic_prompt": "Vertical aspiration, fall-safe return.",
        "playtest_note": "Falling should return the player to a known floor, not punish heavily.",
    },
    11: {
        "setpiece": "bell_shaft_midpoint_reward",
        "micro_objective": "Cross the shaft midpoint, collect a side reward, and identify the lower return passage.",
        "landmark": "mid-shaft bell rib platform",
        "mechanic_prompt": "Reward placed on the way, not in a blind dead end.",
        "playtest_note": "Reward should be visible before the player commits to the climb.",
    },
    14: {
        "setpiece": "shaft_return_shortcut_lock",
        "micro_objective": "Find the second shortcut lock and understand that the shaft will later fold back on itself.",
        "landmark": "sealed root gate beside lower shaft water",
        "mechanic_prompt": "Shortcut compression foreshadow.",
        "playtest_note": "This should make the shaft feel like a future loop, not a ladder.",
    },
    15: {
        "setpiece": "rain_canopy_loop_hub",
        "micro_objective": "Enter the rain canopy loop and read both the high branch and lower return route.",
        "landmark": "rain-streaked canopy bridge",
        "mechanic_prompt": "Two-level loop entry.",
        "playtest_note": "Player should see at least two exits without opening the map.",
    },
    16: {
        "setpiece": "first_ability_tutorial_span",
        "micro_objective": "Pick up the first chapter ability and immediately use it to cross a short, safe span.",
        "landmark": "thread hook shrine above the canopy",
        "mechanic_prompt": "New ability, then one obvious application.",
        "playtest_note": "Failing the tutorial jump should reset locally without long travel.",
    },
    17: {
        "setpiece": "loop_gallery_npc_crossroads",
        "micro_objective": "Talk to the route hint NPC, then choose main bridge or lower loop.",
        "landmark": "crossroads under three rain bells",
        "mechanic_prompt": "NPC reinforces loop logic.",
        "playtest_note": "NPC line should confirm that the area loops back.",
    },
    20: {
        "setpiece": "upper_reward_rain_bell",
        "micro_objective": "Take the upper loop reward and drop back near the main route.",
        "landmark": "upper rain-bell reward perch",
        "mechanic_prompt": "Optional branch with fast return.",
        "playtest_note": "Reward detour target time should stay under 45 seconds.",
    },
    21: {
        "setpiece": "canopy_shortcut_lever_room",
        "micro_objective": "Open the canopy shortcut from the far side and feel the route collapse back to the hub.",
        "landmark": "lever room with visible locked grate below",
        "mechanic_prompt": "Far-side shortcut payoff.",
        "playtest_note": "After opening, runback to the hub should be obviously shorter.",
    },
    22: {
        "setpiece": "root_well_miniboss_foyer",
        "micro_objective": "Enter the root well, survive a small elite fight, and earn access to the lower water loop.",
        "landmark": "root-wrapped well mouth",
        "mechanic_prompt": "First pressure spike after route learning.",
        "playtest_note": "This is a checkpoint for combat pressure, not navigation confusion.",
    },
    24: {
        "setpiece": "root_well_recovery_save",
        "micro_objective": "Recover after the well fight and choose whether to press into the lower reward pocket.",
        "landmark": "save alcove beside dripping roots",
        "mechanic_prompt": "Breather after pressure spike.",
        "playtest_note": "Save placement should make the next experiment feel fair.",
    },
    33: {
        "setpiece": "second_ability_gate_lesson",
        "micro_objective": "Introduce the second ability with a compact lock-and-return lesson.",
        "landmark": "training yard with split floor and return lip",
        "mechanic_prompt": "Ability into immediate backtrack gate.",
        "playtest_note": "Player should know exactly which earlier route this ability reopens.",
    },
    52: {
        "setpiece": "final_key_memory_room",
        "micro_objective": "Grant the final chapter key and point the player toward the boss approach loop.",
        "landmark": "moonlit greenhouse key niche",
        "mechanic_prompt": "Final key, then route compression.",
        "playtest_note": "This should start the emotional shift toward the boss run.",
    },
    62: {
        "setpiece": "boss_run_short_save",
        "micro_objective": "Save, read the boss silhouette, and prepare for a short final approach.",
        "landmark": "quiet bench under the outer court bell tower",
        "mechanic_prompt": "Short runback promise.",
        "playtest_note": "Death runback target is under three rooms.",
    },
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


def draw_cluster_background(draw: ImageDraw.ImageDraw, cluster: dict[str, Any], color: str) -> None:
    b = cluster["bounds"]
    rect = (b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"])
    draw.rounded_rectangle(rect, radius=34, fill=color, outline="#947d65", width=3)
    draw.rounded_rectangle((rect[0] + 8, rect[1] + 8, rect[2] - 8, rect[3] - 8), radius=26, outline="#ffffff", width=2)
    text(draw, (rect[0] + 24, rect[1] + 18), f"{cluster['id']} {cluster['name']}", PALETTE["ink"], FONT_SMALL)
    text(draw, (rect[0] + 24, rect[1] + 48), f"{cluster['room_count']}房 / {cluster['design_role']}", PALETTE["muted"], FONT_TINY)


def draw_room(draw: ImageDraw.ImageDraw, room: dict[str, Any]) -> None:
    r = room["rect"]
    rect = (r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
    kind = room["kind"]
    fill = PALETTE["room"]
    outline = "#2f3138"
    if kind == "start":
        fill = "#d6f0e8"
        outline = PALETTE["exit"]
    elif kind == "boss":
        fill = "#f2c0b5"
        outline = PALETTE["boss"]
    elif kind == "hub":
        fill = "#fff1be"
    if "隐藏" in room["tags"]:
        fill = "#eee0bd"
    draw.rounded_rectangle((rect[0] + 9, rect[1] + 10, rect[2] + 9, rect[3] + 10), radius=10, fill=PALETTE["room_shadow"])
    draw.rounded_rectangle(rect, radius=10, fill=fill, outline=outline, width=4)
    text(draw, (rect[0] + 12, rect[1] + 10), room["id"], PALETTE["ink"], FONT_SMALL)
    label = room["name"]
    if len(label) > 10:
        label = label[:10]
    text(draw, (rect[0] + 12, rect[1] + 42), label, PALETTE["muted"], FONT_TINY)
    tag_text = " ".join([t for t in room["tags"] if t in {"主线", "上层支线", "下层回访", "隐藏"}][:2])
    text(draw, (rect[0] + 12, rect[3] - 26), tag_text, PALETTE["muted"], FONT_TINY)


def draw_badge(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, fill: str, text_fill: str = "#ffffff") -> None:
    radius = 24
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill, outline=PALETTE["ink"], width=3)
    text(draw, (x, y - 12), label, text_fill, FONT_TINY, anchor="ma")


def draw_connections(draw: ImageDraw.ImageDraw, blueprint: dict[str, Any], room_lookup: dict[str, dict[str, Any]]) -> None:
    def c(room_id: str) -> tuple[int, int]:
        r = room_lookup[room_id]["rect"]
        return (r["x"] + r["w"] // 2, r["y"] + r["h"] // 2)

    for link in blueprint["connections"]["branches"]:
        if link["from"] in room_lookup and link["to"] in room_lookup:
            draw.line((*c(link["from"]), *c(link["to"])), fill=PALETTE["branch"], width=3)
    for link in blueprint["connections"]["shortcuts"]:
        if link["from"] in room_lookup and link["to"] in room_lookup:
            draw_arrow(draw, c(link["from"]), c(link["to"]), PALETTE["shortcut"], width=6, dash=True)
    for link in blueprint["connections"]["ability_gates"]:
        if link["from"] in room_lookup and link["to"] in room_lookup:
            draw_arrow(draw, c(link["from"]), c(link["to"]), PALETTE["lock"], width=5, dash=True)
            mx = (c(link["from"])[0] + c(link["to"])[0]) // 2
            my = (c(link["from"])[1] + c(link["to"])[1]) // 2
            draw.rounded_rectangle((mx - 78, my - 24, mx + 78, my + 24), radius=10, fill="#efe2f8", outline=PALETTE["lock"], width=2)
            text(draw, (mx, my - 13), link["ability"], PALETTE["lock"], FONT_TINY, anchor="ma")
    for link in blueprint["connections"]["main_route"]:
        if link["from"] in room_lookup and link["to"] in room_lookup:
            draw_arrow(draw, c(link["from"]), c(link["to"]), PALETTE["main"], width=7)


def draw_points(draw: ImageDraw.ImageDraw, blueprint: dict[str, Any]) -> None:
    point_styles = {
        "saves": (PALETTE["save"], "#ffffff"),
        "npcs": (PALETTE["npc"], "#ffffff"),
        "rewards": (PALETTE["reward"], "#ffffff"),
        "minibosses": (PALETTE["danger"], "#ffffff"),
        "abilities": (PALETTE["lock"], "#ffffff"),
        "bosses": (PALETTE["boss"], "#ffffff"),
        "exits": (PALETTE["exit"], "#ffffff"),
    }
    for group, points in blueprint["points"].items():
        fill, text_fill = point_styles[group]
        for p in points:
            draw_badge(draw, p["x"], p["y"], p["label"], fill, text_fill)


def draw_legend(draw: ImageDraw.ImageDraw, x: int, y: int) -> None:
    draw.rounded_rectangle((x, y, x + 1050, y + 390), radius=18, fill="#ffffff", outline="#5b5348", width=3)
    text(draw, (x + 28, y + 24), "图例 / 复绘用", PALETTE["ink"], FONT_H2)
    rows = [
        ("红箭头", "一周目主线推进", PALETTE["main"]),
        ("蓝线", "支线/奖励房/区域内连接", PALETTE["branch"]),
        ("绿虚箭", "捷径，通常从背面开启", PALETTE["shortcut"]),
        ("紫虚箭", "能力门/回访门，标注需求能力", PALETTE["lock"]),
        ("S/N/R/M/A", "存档/NPC/奖励/精英战/能力", PALETTE["save"]),
        ("BOSS/IN/OUT", "Boss 战/章节入口/出口", PALETTE["boss"]),
    ]
    for i, (k, desc, col) in enumerate(rows):
        yy = y + 92 + i * 46
        draw.line((x + 30, yy + 13, x + 120, yy + 13), fill=col, width=8)
        text(draw, (x + 145, yy), k, PALETTE["ink"], FONT_SMALL)
        text(draw, (x + 285, yy), desc, PALETTE["muted"], FONT_SMALL)


def render_blueprint(blueprint: dict[str, Any], image_path: Path) -> None:
    img = Image.new("RGB", (CANVAS_W, CANVAS_H), PALETTE["bg"])
    draw = ImageDraw.Draw(img)
    for gx in range(160, CANVAS_W, 160):
        draw.line((gx, 350, gx, CANVAS_H - 180), fill=PALETTE["grid"], width=1)
    for gy in range(430, CANVAS_H - 180, 160):
        draw.line((160, gy, CANVAS_W - 160, gy), fill=PALETTE["grid"], width=1)

    text(draw, (180, 80), blueprint["title"], PALETTE["ink"], FONT_TITLE)
    text(draw, (180, 154), blueprint["theme"], PALETTE["muted"], FONT_BODY)
    scale = blueprint["target_scale"]
    text(
        draw,
        (180, 210),
        f"体量：{scale['rooms']}房 / {scale['clusters']}区域簇 / 主线{scale['main_route_rooms']}房 / 捷径{scale['shortcuts']} / 能力门{scale['ability_gates']} / 存档{scale['save_points']}",
        PALETTE["ink"],
        FONT_BODY,
    )
    text(draw, (180, 258), blueprint["loop_note"], PALETTE["muted"], FONT_SMALL)

    for i, cluster in enumerate(blueprint["clusters"]):
        draw_cluster_background(draw, cluster, CLUSTER_COLORS[i % len(CLUSTER_COLORS)])

    room_lookup = {room["id"]: room for room in blueprint["rooms"]}
    draw_connections(draw, blueprint, room_lookup)
    for room in blueprint["rooms"]:
        draw_room(draw, room)
    draw_points(draw, blueprint)
    draw_legend(draw, CANVAS_W - 1260, 70)

    footer = "注：这是高保真拓扑蓝图，不是最终美术；房间间距已加大，便于你在软件中拆分、放大、重排。"
    text(draw, (180, CANVAS_H - 90), footer, PALETTE["muted"], FONT_SMALL)
    if OUTPUT_SCALE != 1:
        img = img.resize((CANVAS_W * OUTPUT_SCALE, CANVAS_H * OUTPUT_SCALE), Image.Resampling.LANCZOS)
    img.save(image_path)


def render_overview(blueprints: list[dict[str, Any]], image_path: Path) -> None:
    img = Image.new("RGB", (OVERVIEW_W, OVERVIEW_H), "#f2efe7")
    draw = ImageDraw.Draw(img)
    text(draw, (180, 90), "六章丝之歌级地图总览拓扑", PALETTE["ink"], FONT_TITLE)
    text(draw, (180, 166), "每章独立 55+ 房间，章节之间保留能力回访线与出口承接点", PALETTE["muted"], FONT_BODY)
    x0 = 320
    y0 = 420
    card_w = 2200
    card_h = 1200
    gap_x = 220
    gap_y = 260
    chapter_centers: list[tuple[int, int]] = []

    for idx, bp in enumerate(blueprints):
        col = idx % 3
        row = idx // 3
        x = x0 + col * (card_w + gap_x)
        y = y0 + row * (card_h + gap_y)
        draw.rounded_rectangle((x + 12, y + 14, x + card_w + 12, y + card_h + 14), radius=22, fill="#c9bda9")
        draw.rounded_rectangle((x, y, x + card_w, y + card_h), radius=22, fill="#fff8ea", outline="#4b4d54", width=4)
        title = bp["title"]
        text(draw, (x + 42, y + 32), title, PALETTE["ink"], FONT_H2)
        scale = bp["target_scale"]
        text(draw, (x + 42, y + 84), f"{scale['rooms']}房 / {scale['clusters']}区域 / {scale['shortcuts']}捷径 / {scale['ability_gates']}能力门", PALETTE["muted"], FONT_SMALL)

        # Mini topology: cluster dots and route line.
        dot_points: list[tuple[int, int]] = []
        for ci, cluster in enumerate(bp["clusters"]):
            px = x + 160 + (ci % 6) * 320
            py = y + 280 + (ci // 6) * 330 + (ci % 2) * 34
            dot_points.append((px, py))
            draw.ellipse((px - 44, py - 44, px + 44, py + 44), fill=CLUSTER_COLORS[ci % len(CLUSTER_COLORS)], outline="#3d4148", width=3)
            text(draw, (px, py - 16), cluster["id"], PALETTE["ink"], FONT_TINY, anchor="ma")
            short = cluster["name"][:5]
            text(draw, (px, py + 7), short, PALETTE["ink"], FONT_TINY, anchor="ma")
        for a, b in zip(dot_points, dot_points[1:]):
            draw_arrow(draw, a, b, PALETTE["main"], width=5)
        for si in range(1, len(dot_points), 3):
            a = dot_points[si]
            b = dot_points[min(len(dot_points) - 1, si + 3)]
            draw_arrow(draw, b, a, PALETTE["shortcut"], width=4, dash=True)

        text(draw, (x + 42, y + card_h - 260), "核心回环", PALETTE["ink"], FONT_SMALL)
        text(draw, (x + 42, y + card_h - 224), bp["loop_note"], PALETTE["muted"], FONT_SMALL)
        text(draw, (x + 42, y + card_h - 132), "能力", PALETTE["ink"], FONT_SMALL)
        text(draw, (x + 42, y + card_h - 96), " / ".join(bp["abilities"]), PALETTE["lock"], FONT_SMALL)
        chapter_centers.append((x + card_w // 2, y + card_h // 2))

    for i in range(len(chapter_centers) - 1):
        draw_arrow(draw, chapter_centers[i], chapter_centers[i + 1], "#594f43", width=6, dash=True)
    text(draw, (180, OVERVIEW_H - 120), "总览只看章节间承接；具体房间编号和点位以单章高清 PNG/JSON 为准。", PALETTE["muted"], FONT_BODY)
    img.save(image_path)


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def write_docs(ts: str, blueprints: list[dict[str, Any]], index: dict[str, Any]) -> dict[str, str]:
    spec_path = DOC_SPEC_DIR / f"{ts}_六章丝之歌级大体量地图蓝图规格.md"
    plan_path = DOC_PLAN_DIR / f"{ts}_六章大地图落地计划.md"
    lines = [
        "# 六章丝之歌级大体量地图蓝图规格",
        "",
        "## 目标",
        "",
        "- 每章按 55-75 个房间设计，强调长主线、密支线、能力回访、捷径闭环和 Boss 前短跑。",
        "- 本规格不复刻任何商业地图，只抽象大体量银河恶魔城的结构密度与节奏。",
        "- 高清 PNG 用于外部软件复绘；JSON 用于后续 Godot/Tiled/Tres 关卡数据落地。",
        "",
        "## 公共图例",
        "",
        "- 红箭头：一周目主线推进。",
        "- 蓝线：支线、奖励房、区域内连接。",
        "- 绿虚箭：从背面开启的捷径。",
        "- 紫虚箭：能力门或回访门，图中标注所需能力。",
        "- S/N/R/M/A/BOSS/IN/OUT：存档、NPC、奖励、精英战、能力、Boss、章节入口、章节出口。",
        "",
        "## 章节规格",
        "",
    ]
    for bp in blueprints:
        s = bp["target_scale"]
        lines.extend(
            [
                f"### {bp['title']}",
                "",
                f"- 主题：{bp['theme']}",
                f"- 体量：{s['rooms']} 房，{s['clusters']} 个区域簇，主线 {s['main_route_rooms']} 房。",
                f"- 点位：捷径 {s['shortcuts']}，能力门 {s['ability_gates']}，存档 {s['save_points']}，NPC {s['npcs']}，奖励 {s['rewards']}，精英战 {s['minibosses']}。",
                f"- 能力：{' / '.join(bp['abilities'])}",
                f"- Boss：{bp['points']['bosses'][0]['note']}",
                f"- 回环：{bp['loop_note']}",
                f"- 蓝图：`{Path(index['chapters'][bp['id']]['json']).name}`",
                f"- 图片：`{Path(index['chapters'][bp['id']]['png']).name}`",
                "",
            ]
        )
    lines.extend(
        [
            "## 验收阈值",
            "",
            "- 每章房间数 >= 55。",
            "- 每章区域簇 >= 8。",
            "- 每章捷径 >= 8。",
            "- 每章能力门 >= 6。",
            "- 每章存档点 >= 5，且 Boss 前 3 房间内有存档点。",
            "- 每章至少 5 个 NPC、8 个奖励点、2 个精英战。",
            "- 每张 PNG 宽 >= 4096、高 >= 2500，且包含图例、编号、主线、支线、捷径、能力门、Boss/NPC/存档/奖励标记。",
        ]
    )
    spec_path.write_text("\n".join(lines), encoding="utf-8")

    plan_lines = [
        "# 六章大地图落地计划",
        "",
        "## A0 集成节奏",
        "",
        "1. 先按 PNG 在设计软件中确定房间轮廓和章节大环。",
        "2. 再把 JSON 的房间编号映射到 Godot `demo_chXX` 数据，保留入口、出口、Boss 前存档和能力门字段。",
        "3. 每章先做灰盒可通关，再补敌人、奖励、NPC、场景美术和小地图显示。",
        "",
        "## 推荐实施顺序",
        "",
    ]
    for bp in blueprints:
        plan_lines.extend(
            [
                f"### {bp['title']}",
                "",
                "- 阶段 1：搭主线红箭头房间，入口到 Boss 必须可跑通。",
                "- 阶段 2：接蓝色支线和奖励房，不影响主线通关。",
                "- 阶段 3：接绿色捷径，确保回程时间缩短。",
                "- 阶段 4：接紫色能力门，只允许已获得能力后开启。",
                "- 阶段 5：放 NPC/奖励/精英战，最后做 Boss 前短跑体验。",
                "",
            ]
        )
    plan_lines.extend(
        [
            "## 风险",
            "",
            "- 一次性把 60+ 房全部做成精装修会拖慢进度，建议先灰盒跑通。",
            "- 捷径如果没有单向门或机关反馈，会让玩家迷路。",
            "- Boss 前没有短存档会显著破坏节奏。",
        ]
    )
    plan_path.write_text("\n".join(plan_lines), encoding="utf-8")
    return {"spec": str(spec_path), "plan": str(plan_path)}


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
