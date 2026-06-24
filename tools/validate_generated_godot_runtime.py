from __future__ import annotations

import json
import math
import re
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GENERATED_DIR = ROOT / "godot" / "data" / "generated"
CONFIGS = sorted(GENERATED_DIR.glob("*.generated.json"))
PLAYER_CONTROLLER = ROOT / "godot" / "scripts" / "player_controller.gd"
MAIN_LEVEL = ROOT / "godot" / "scripts" / "main_level.gd"
PACKAGE_JSON = ROOT / "package.json"

REQUIRED_FIELDS = [
    "id",
    "world",
    "player_start",
    "map_rooms",
    "platforms",
    "enemy_spawns",
    "hazards",
    "npcs",
    "save_points",
    "boss",
    "connections",
    "interactives",
]

BASE_TRAVERSAL_TYPES = {"main", "main_route", "passage", "local_branch", "side_room"}
PROGRESSION_TIERS = {"critical_path", "optional_branch", "opened_shortcut", "ability_locked", "supporting_link"}
REQUIRED_ARCHETYPES = {
    "entry_gate",
    "region_hub",
    "main_spine",
    "vertical_shaft",
    "loop_gallery",
    "reward_pocket",
    "ability_tutorial",
    "shortcut_lock",
    "overlook_branch",
    "return_passage",
    "preboss_run",
    "boss_arena",
}
OPTIONAL_MEMORY_ARCHETYPES = {"hidden_reward"}
SAFE_JUMP_HEIGHT = 125.0
SAFE_HORIZONTAL_GAP = 380.0
MAX_PLATFORMS_PER_ROOM = 8.5
MAX_ENEMIES_PER_ROOM = 0.7
MIN_LAYOUT_X_BUCKET_RATIO = 0.55
PLAYER_WIDTH = 34.0
REACH_SAFETY = 0.82


@dataclass(frozen=True)
class PlayerPhysics:
    speed: float
    jump_velocity: float
    gravity: float
    dash_speed: float
    dash_time: float

    @property
    def jump_height(self) -> float:
        return (abs(self.jump_velocity) ** 2) / (2.0 * self.gravity)

    @property
    def air_time(self) -> float:
        return (2.0 * abs(self.jump_velocity)) / self.gravity

    @property
    def horizontal_jump_reach(self) -> float:
        return self.speed * self.air_time * REACH_SAFETY

    @property
    def dash_reach(self) -> float:
        return self.dash_speed * self.dash_time * REACH_SAFETY

    @property
    def combined_reach(self) -> float:
        return self.horizontal_jump_reach + self.dash_reach


def fail(message: str) -> None:
    raise SystemExit(f"验证失败：{message}")


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        fail(f"缺少生成配置：{path}")
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_player_physics() -> PlayerPhysics:
    source = PLAYER_CONTROLLER.read_text(encoding="utf-8")

    def export_float(name: str) -> float:
        match = re.search(rf"@export\s+var\s+{re.escape(name)}:\s*float\s*=\s*(-?\d+(?:\.\d+)?)", source)
        if not match:
            fail(f"missing player physics export: {name}")
        return float(match.group(1))

    return PlayerPhysics(
        speed=export_float("speed"),
        jump_velocity=export_float("jump_velocity"),
        gravity=export_float("gravity"),
        dash_speed=export_float("dash_speed"),
        dash_time=export_float("dash_time"),
    )


def assert_unique(items: list[dict[str, Any]], key: str, label: str, config_id: str) -> None:
    seen = set()
    for item in items:
        value = item.get(key)
        if value in seen:
            fail(f"{config_id} {label} 重复 {key}: {value}")
        seen.add(value)


def room_for_position(config: dict[str, Any], position: list[int | float]) -> dict[str, Any] | None:
    x, y = float(position[0]), float(position[1])
    rooms = config["map_rooms"]
    for room in rooms:
        rects = list(room.get("visit_rects", []))
        if "layout_rect" in room:
            rects.append(room["layout_rect"])
        for rect in rects:
            rx, ry, rw, rh = [float(v) for v in rect]
            if rx <= x <= rx + rw and ry <= y <= ry + rh:
                return room
    for room in rooms:
        start, end = [float(v) for v in room["range"]]
        if start <= x <= end:
            return room
    return None


def validate_ranges(config: dict[str, Any]) -> None:
    rooms = config["map_rooms"]
    if not rooms:
        fail(f"{config['id']} 缺少 map_rooms")
    prev_end = None
    for room in rooms:
        start, end = room.get("range", [None, None])
        if start is None or end is None or start >= end:
            fail(f"{config['id']} 房间 range 非法：{room.get('id')}")
        if prev_end is not None and start < prev_end:
            fail(f"{config['id']} 房间 range 重叠：{room.get('id')}")
        prev_end = end
    if prev_end is None or prev_end > int(config["world"]["width"]):
        fail(f"{config['id']} 房间 range 超出 world.width")


def validate_connections(config: dict[str, Any]) -> dict[str, set[str]]:
    room_ids = {room["id"] for room in config["map_rooms"]}
    graph = {room_id: set() for room_id in room_ids}
    for link in config["connections"]:
        a = link.get("from")
        b = link.get("to")
        link_type = str(link.get("type", ""))
        if a == b:
            fail(f"{config['id']} connections 自环：{a}")
        if a not in room_ids or b not in room_ids:
            fail(f"{config['id']} connections 引用不存在房间：{a}->{b}")
        if not link.get("id"):
            fail(f"{config['id']} connection missing id: {a}->{b}")
        if str(link.get("progression_tier", "")) not in PROGRESSION_TIERS:
            fail(f"{config['id']} connection missing progression_tier: {a}->{b} type={link_type}")
        if not link.get("traversal") or not link.get("directionality"):
            fail(f"{config['id']} connection missing traversal contract: {a}->{b}")
        if link_type == "ability_gate":
            for field in ["gate_id", "required_ability", "required_ability_name"]:
                if not link.get(field):
                    fail(f"{config['id']} ability gate missing {field}: {a}->{b}")
            if not bool(link.get("locked", False)):
                fail(f"{config['id']} ability gate not marked locked: {a}->{b}")
        if link_type == "shortcut" and not link.get("shortcut_id"):
            fail(f"{config['id']} shortcut missing shortcut_id: {a}->{b}")
        if link_type == "shortcut":
            for field in ["opens_from_room", "return_to_room", "initial_directionality", "opened_directionality"]:
                if not link.get(field):
                    fail(f"{config['id']} shortcut missing {field}: {a}->{b}")
            value = link.get("shortcut_value", {})
            if not isinstance(value, dict):
                fail(f"{config['id']} shortcut missing value metric: {a}->{b}")
            if int(value.get("distance_saved", 0)) < 1:
                fail(f"{config['id']} shortcut does not shorten return path: {a}->{b} value={value}")
        graph[a].add(b)
        graph[b].add(a)
    return graph


def distance(graph: dict[str, set[str]], start: str, target: str) -> int | None:
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


def reachable_nodes(graph: dict[str, set[str]], start: str) -> set[str]:
    queue: deque[str] = deque([start])
    seen = {start}
    while queue:
        node = queue.popleft()
        for nxt in graph.get(node, set()):
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    return seen


def rect_tuple(platform: dict[str, Any]) -> tuple[float, float, float, float]:
    x, y, w, h = platform["rect"]
    return float(x), float(y), float(w), float(h)


def rect_horizontal_gap(a: dict[str, Any], b: dict[str, Any]) -> float:
    ax, _ay, aw, _ah = rect_tuple(a)
    bx, _by, bw, _bh = rect_tuple(b)
    if ax + aw < bx:
        return bx - (ax + aw)
    if bx + bw < ax:
        return ax - (bx + bw)
    return 0.0


def rect_vertical_delta(a: dict[str, Any], b: dict[str, Any]) -> float:
    _ax, ay, _aw, _ah = rect_tuple(a)
    _bx, by, _bw, _bh = rect_tuple(b)
    return abs(ay - by)


def rect_top_delta(a: dict[str, Any], b: dict[str, Any]) -> float:
    _ax, ay, _aw, _ah = rect_tuple(a)
    _bx, by, _bw, _bh = rect_tuple(b)
    return by - ay


def platform_reachable(a: dict[str, Any], b: dict[str, Any], physics: PlayerPhysics) -> bool:
    gap = rect_horizontal_gap(a, b)
    delta = rect_top_delta(a, b)
    if delta < -physics.jump_height * 1.35:
        return False
    if delta > physics.jump_height:
        return False
    allowed_gap = physics.horizontal_jump_reach
    if abs(delta) > physics.jump_height * 0.55:
        allowed_gap *= 0.76
    if gap > allowed_gap + physics.dash_reach:
        return False
    return True


def platforms_reachable_with_supports(
    config: dict[str, Any],
    a: dict[str, Any],
    b: dict[str, Any],
    support_prefixes: list[str],
    physics: PlayerPhysics,
) -> bool:
    ax, _ay, aw, _ah = rect_tuple(a)
    bx, _by, bw, _bh = rect_tuple(b)
    a_center = ax + aw * 0.5
    b_center = bx + bw * 0.5
    supports = [
        platform
        for platform in config["platforms"]
        if any(str(platform.get("id", "")).startswith(prefix) for prefix in support_prefixes)
    ]
    candidates = [a, *supports, b]
    candidates = sorted(
        candidates,
        key=lambda item: (rect_tuple(item)[0] + rect_tuple(item)[2] * 0.5, rect_tuple(item)[1]),
        reverse=a_center > b_center,
    )
    for current, nxt in zip(candidates, candidates[1:]):
        if not platform_reachable(current, nxt, physics) and not platform_reachable(nxt, current, physics):
            return False
    return True


def rects_overlap(platform: dict[str, Any], rect: list[int | float]) -> bool:
    px, py, pw, ph = rect_tuple(platform)
    rx, ry, rw, rh = [float(v) for v in rect]
    return px + pw >= rx and px <= rx + rw and py + ph >= ry and py <= ry + rh


def floor_platform(config: dict[str, Any], room_id: str) -> dict[str, Any] | None:
    target_id = f"{room_id}_floor"
    for platform in config["platforms"]:
        if platform.get("id") == target_id:
            return platform
    return None


def validate_platforms(config: dict[str, Any]) -> None:
    platforms = config["platforms"]
    assert_unique(platforms, "id", "platforms", config["id"])
    platform_ratio = len(platforms) / max(1, len(config["map_rooms"]))
    if platform_ratio > MAX_PLATFORMS_PER_ROOM:
        fail(f"{config['id']} platform density too high: {platform_ratio:.2f} > {MAX_PLATFORMS_PER_ROOM}")
    if len(platforms) < len(config["map_rooms"]) * 2:
        fail(f"{config['id']} 平台密度不足：{len(platforms)} < rooms*2")
    for platform in platforms:
        rect = platform.get("rect", [])
        if len(rect) != 4 or rect[2] <= 0 or rect[3] <= 0:
            fail(f"{config['id']} 平台 rect 非法：{platform.get('id')}")
    for room in config["map_rooms"]:
        rects = list(room.get("visit_rects", []))
        if "layout_rect" in room:
            rects.append(room["layout_rect"])
        if not any(rects_overlap(platform, rect) for platform in platforms for rect in rects):
            fail(f"{config['id']} 房间没有平台：{room['id']}")


def validate_layout_variety(config: dict[str, Any]) -> None:
    buckets = set()
    for room in config["map_rooms"]:
        layout = room.get("layout_rect", [])
        if len(layout) != 4:
            fail(f"{config['id']} missing layout_rect: {room.get('id')}")
        buckets.add(round(float(layout[0]) / 160.0) * 160)
    ratio = len(buckets) / max(1, len(config["map_rooms"]))
    if ratio < MIN_LAYOUT_X_BUCKET_RATIO:
        fail(f"{config['id']} layout x variety too low: {ratio:.2f} < {MIN_LAYOUT_X_BUCKET_RATIO}")


def validate_room_design_contracts(config: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    setpiece_count = 0
    for room in config["map_rooms"]:
        room_id = str(room.get("id", ""))
        archetype = str(room.get("archetype", ""))
        if not archetype:
            fail(f"{config['id']} room missing archetype: {room_id}")
        if archetype not in REQUIRED_ARCHETYPES and archetype not in OPTIONAL_MEMORY_ARCHETYPES:
            fail(f"{config['id']} room has unknown archetype: {room_id} -> {archetype}")
        for field in ["design_goal", "traversal_focus", "reward_contract", "pacing_role"]:
            if not str(room.get(field, "")).strip():
                fail(f"{config['id']} room missing design contract field {field}: {room_id}")
        if str(room.get("setpiece", "")).strip():
            setpiece_count += 1
            for field in ["micro_objective", "landmark", "mechanic_prompt", "playtest_note"]:
                if not str(room.get(field, "")).strip():
                    fail(f"{config['id']} setpiece room missing {field}: {room_id}")
        counts[archetype] = counts.get(archetype, 0) + 1

    missing = sorted(REQUIRED_ARCHETYPES - set(counts))
    if missing:
        fail(f"{config['id']} missing required room archetypes: {missing}")
    if counts.get("ability_tutorial", 0) < 3:
        fail(f"{config['id']} ability tutorial rooms too low: {counts.get('ability_tutorial', 0)}")
    if counts.get("shortcut_lock", 0) < 5:
        fail(f"{config['id']} shortcut lock rooms too low: {counts.get('shortcut_lock', 0)}")
    if counts.get("reward_pocket", 0) + counts.get("hidden_reward", 0) < 6:
        fail(f"{config['id']} optional reward memory rooms too low")
    if counts.get("preboss_run", 0) < 1 or counts.get("boss_arena", 0) != 1:
        fail(f"{config['id']} boss approach contract invalid: {counts}")
    if "ch01" in str(config.get("id", "")) and setpiece_count < 18:
        fail(f"{config['id']} CH01 vertical slice setpiece count too low: {setpiece_count} < 18")
    counts["setpiece_rooms"] = setpiece_count
    return counts


def validate_enemy_density(config: dict[str, Any]) -> None:
    ratio = len(config["enemy_spawns"]) / max(1, len(config["map_rooms"]))
    if ratio > MAX_ENEMIES_PER_ROOM:
        fail(f"{config['id']} enemy density too high: {ratio:.2f} > {MAX_ENEMIES_PER_ROOM}")


def validate_base_connection_geometry(config: dict[str, Any], physics: PlayerPhysics) -> None:
    """Check base-movement route and branch rooms have plausible bridge or step chains."""
    platform_ids = {platform["id"] for platform in config["platforms"]}
    checked = 0
    for link in config["connections"]:
        link_type = str(link.get("type", ""))
        if link_type not in BASE_TRAVERSAL_TYPES:
            continue
        a = str(link["from"])
        b = str(link["to"])
        a_floor = floor_platform(config, a)
        b_floor = floor_platform(config, b)
        if a_floor is None or b_floor is None:
            fail(f"{config['id']} 主路连接缺 floor 平台：{a}->{b}")
        bridge_markers = [
            f"bridge_{a}_to_{b}",
            f"bridge_{b}_to_{a}",
            f"shaft_bridge_{a}_to_{b}",
            f"shaft_bridge_{b}_to_{a}",
        ]
        step_prefixes = [
            f"step_{a}_to_{b}_",
            f"step_{b}_to_{a}_",
        ]
        support_prefixes = [
            f"step_{a}_to_{b}_",
            f"step_{b}_to_{a}_",
            f"bridge_{a}_to_{b}",
            f"bridge_{b}_to_{a}",
            f"shaft_bridge_{a}_to_{b}",
            f"shaft_bridge_{b}_to_{a}",
        ]
        has_bridge = any(marker in platform_ids for marker in bridge_markers) or any(
            any(pid.startswith(prefix) for pid in platform_ids)
            for prefix in [
                f"bridge_{a}_to_{b}_",
                f"bridge_{b}_to_{a}_",
                f"shaft_bridge_{a}_to_{b}_",
                f"shaft_bridge_{b}_to_{a}_",
            ]
        )
        has_steps = any(any(pid.startswith(prefix) for pid in platform_ids) for prefix in step_prefixes)
        has_supports = has_bridge or has_steps
        h_gap = rect_horizontal_gap(a_floor, b_floor)
        v_delta = rect_vertical_delta(a_floor, b_floor)
        if h_gap > SAFE_HORIZONTAL_GAP and not has_supports:
            fail(f"{config['id']} 主路水平断裂：{a}->{b} gap={h_gap:.1f}")
        if v_delta > SAFE_JUMP_HEIGHT and not has_supports:
            fail(f"{config['id']} 主路垂直断裂：{a}->{b} delta={v_delta:.1f}")
        if not platforms_reachable_with_supports(config, a_floor, b_floor, support_prefixes, physics):
            fail(
                f"{config['id']} base route not reachable by player physics: "
                f"{a}->{b} gap={h_gap:.1f} delta={v_delta:.1f} "
                f"jump={physics.jump_height:.1f} reach={physics.combined_reach:.1f}"
            )
        checked += 1
    if checked < 35:
        fail(f"{config['id']} 主路几何检查数量过少：{checked}")


def validate_positions(config: dict[str, Any]) -> None:
    point_specs: list[tuple[str, list[int | float]]] = [
        ("player_start", config["player_start"]),
        ("boss.position", config["boss"]["position"]),
        ("boss_checkpoint", config["boss_checkpoint"]),
    ]
    for group in ["enemy_spawns", "npcs", "save_points", "interactives"]:
        for item in config.get(group, []):
            point_specs.append((f"{group}.{item.get('id')}", item["position"]))
    for hazard in config.get("hazards", []):
        if "position" in hazard:
            point_specs.append((f"hazards.{hazard.get('id')}", hazard["position"]))
        elif "rect" in hazard:
            rect = hazard["rect"]
            point_specs.append((f"hazards.{hazard.get('id')}", [rect[0] + rect[2] / 2, rect[1] + rect[3] / 2]))
    for collectible in config.get("collectibles", []):
        point_specs.append((f"collectibles.{collectible.get('id')}", collectible["position"]))
    for label, position in point_specs:
        if room_for_position(config, position) is None:
            fail(f"{config['id']} 点位不在任何房间内：{label} {position}")


def validate_refs(config: dict[str, Any]) -> None:
    platform_ids = {p["id"] for p in config["platforms"]}
    connection_ids = {str(link.get("id")) for link in config.get("connections", [])}
    ai_profiles = set(config.get("ai_profiles", {}).keys())
    for enemy in config.get("enemy_spawns", []):
        if enemy.get("platform_id") not in platform_ids:
            fail(f"{config['id']} 敌人引用不存在平台：{enemy.get('id')} -> {enemy.get('platform_id')}")
        if ai_profiles and enemy.get("kind") not in ai_profiles:
            fail(f"{config['id']} 敌人 kind 不在 ai_profiles：{enemy.get('kind')}")
    for segment in config.get("parkour_segments", []):
        for platform_id in segment.get("platforms", []):
            if platform_id not in platform_ids:
                fail(f"{config['id']} parkour 引用不存在平台：{platform_id}")
    for gate in config.get("locked_gates", []):
        rect = gate.get("rect", [])
        if gate.get("connection_id") not in connection_ids:
            fail(f"{config['id']} locked gate references missing connection: {gate.get('id')}")
        if len(rect) != 4 or rect[2] <= 0 or rect[3] <= 0:
            fail(f"{config['id']} locked gate rect invalid: {gate.get('id')}")


def validate_progression_contracts(config: dict[str, Any]) -> None:
    item_ids = {
        str(item.get("item_id"))
        for item in config.get("collectibles", [])
        if item.get("kind") == "item" and item.get("item_id")
    }
    gates_by_id = {str(gate.get("id")): gate for gate in config.get("locked_gates", [])}
    ability_links = [link for link in config["connections"] if link.get("type") == "ability_gate"]
    shortcut_links = [link for link in config["connections"] if link.get("type") == "shortcut"]
    if len(ability_links) < 5:
        fail(f"{config['id']} ability gate count too low: {len(ability_links)}")
    if len(shortcut_links) < 5:
        fail(f"{config['id']} shortcut count too low: {len(shortcut_links)}")
    shortcut_value_total = sum(int(link.get("shortcut_value", {}).get("distance_saved", 0)) for link in shortcut_links)
    if shortcut_value_total < len(shortcut_links):
        fail(f"{config['id']} shortcut total value too low: {shortcut_value_total} < {len(shortcut_links)}")
    if len(gates_by_id) != len(ability_links):
        fail(f"{config['id']} locked_gates mismatch ability links: {len(gates_by_id)} != {len(ability_links)}")
    for link in ability_links:
        gate_id = str(link.get("gate_id", ""))
        required_ability = str(link.get("required_ability", ""))
        if gate_id not in gates_by_id:
            fail(f"{config['id']} ability gate missing locked gate body: {gate_id}")
        gate = gates_by_id[gate_id]
        if gate.get("connection_id") != link.get("id"):
            fail(f"{config['id']} locked gate connection mismatch: {gate_id}")
        if gate.get("required_ability") != required_ability:
            fail(f"{config['id']} locked gate ability mismatch: {gate_id}")
        if required_ability not in item_ids:
            fail(f"{config['id']} ability gate requires missing collectible: {required_ability}")
    shortcut_ids = {str(link.get("shortcut_id")) for link in shortcut_links}
    lever_count = 0
    for interactive in config.get("interactives", []):
        if interactive.get("kind") != "lever":
            continue
        lever_count += 1
        shortcut_id = str(interactive.get("shortcut_id", ""))
        if shortcut_id not in shortcut_ids:
            fail(f"{config['id']} lever opens unknown shortcut: {interactive.get('id')} -> {shortcut_id}")
        opened = interactive.get("opens_connection", {})
        if not isinstance(opened, dict) or not opened.get("id"):
            fail(f"{config['id']} lever missing opens_connection id: {interactive.get('id')}")
        if opened.get("initial_directionality") != "from_to_only" or opened.get("opened_directionality") != "two_way":
            fail(f"{config['id']} lever shortcut directionality mismatch: {interactive.get('id')}")
    if lever_count < 5:
        fail(f"{config['id']} shortcut lever count too low: {lever_count}")


def progression_graph(config: dict[str, Any], abilities: set[str], shortcuts_open: bool = False) -> dict[str, set[str]]:
    room_ids = {room["id"] for room in config["map_rooms"]}
    graph = {room_id: set() for room_id in room_ids}
    for link in config["connections"]:
        link_type = str(link.get("type", ""))
        if link_type == "ability_gate" and str(link.get("required_ability", "")) not in abilities:
            continue
        a = str(link["from"])
        b = str(link["to"])
        if a in graph and b in graph:
            graph[a].add(b)
            if link_type != "shortcut" or shortcuts_open:
                graph[b].add(a)
    return graph


def ability_collectible_rooms(config: dict[str, Any]) -> dict[str, str]:
    room_ids = {str(room["id"]) for room in config["map_rooms"]}
    result: dict[str, str] = {}
    for collectible in config.get("collectibles", []):
        if collectible.get("kind") != "item":
            continue
        item_id = str(collectible.get("item_id", ""))
        room_id = str(collectible.get("room_id", ""))
        if room_id:
            if room_id not in room_ids:
                fail(f"{config['id']} ability collectible references missing room_id: {collectible.get('id')} -> {room_id}")
            room = next(room for room in config["map_rooms"] if str(room["id"]) == room_id)
        else:
            room = room_for_position(config, collectible.get("position", []))
        if not item_id or room is None:
            fail(f"{config['id']} ability collectible not placed in a room: {collectible.get('id')}")
        result[item_id] = str(room["id"])
    return result


def validate_ability_unlock_order(config: dict[str, Any]) -> dict[str, Any]:
    start_room = room_for_position(config, config["player_start"])
    if start_room is None:
        fail(f"{config['id']} ability order validation missing start room")
    boss_room = next(room for room in config["map_rooms"] if room.get("kind") == "boss")
    exit_room = config["map_rooms"][-1]
    ability_rooms = ability_collectible_rooms(config)
    if len(ability_rooms) < 3:
        fail(f"{config['id']} ability collectible count too low for progression: {len(ability_rooms)}")
    acquired: set[str] = set()
    acquisition_order: list[str] = []
    initial_reachable_count = len(reachable_nodes(progression_graph(config, acquired, shortcuts_open=False), str(start_room["id"])))
    while True:
        graph = progression_graph(config, acquired)
        reachable = reachable_nodes(graph, str(start_room["id"]))
        newly_found = sorted(
            ability_id
            for ability_id, room_id in ability_rooms.items()
            if ability_id not in acquired and room_id in reachable
        )
        if not newly_found:
            break
        for ability_id in newly_found:
            acquired.add(ability_id)
            acquisition_order.append(ability_id)
    missing = sorted(set(ability_rooms) - acquired)
    if missing:
        details = ", ".join(f"{ability_id}@{ability_rooms[ability_id]}" for ability_id in missing)
        fail(f"{config['id']} ability progression softlock, unreachable abilities before gates: {details}")
    final_reachable = reachable_nodes(progression_graph(config, acquired, shortcuts_open=True), str(start_room["id"]))
    if str(boss_room["id"]) not in final_reachable:
        fail(f"{config['id']} boss unreachable after ability progression")
    if str(exit_room["id"]) not in final_reachable:
        fail(f"{config['id']} exit unreachable after ability progression")
    locked_requirements = {str(link.get("required_ability", "")) for link in config["connections"] if link.get("type") == "ability_gate"}
    if not locked_requirements.issubset(acquired):
        fail(f"{config['id']} not all gate requirements are obtainable: {sorted(locked_requirements - acquired)}")
    return {
        "acquired": acquisition_order,
        "initial_reachable_rooms": initial_reachable_count,
        "reachable_rooms_after_unlocks": len(final_reachable),
    }


def validate_debug_map(config: dict[str, Any]) -> None:
    debug_map = config.get("debug_map", {})
    if not isinstance(debug_map, dict):
        fail(f"{config['id']} missing debug_map")
    counts = debug_map.get("connection_counts", {})
    for tier in ["critical_path", "optional_branch", "opened_shortcut", "ability_locked"]:
        if int(counts.get(tier, 0)) <= 0:
            fail(f"{config['id']} debug_map missing tier count: {tier}")
    connection_ids = {str(link.get("id")) for link in config["connections"]}
    for list_name in ["main_route", "side_branches", "shortcuts"]:
        values = debug_map.get(list_name, [])
        if not isinstance(values, list) or not values:
            fail(f"{config['id']} debug_map missing {list_name}")
        for connection_id in values:
            if str(connection_id) not in connection_ids:
                fail(f"{config['id']} debug_map references missing connection: {connection_id}")
    gate_ids = {str(gate.get("id")) for gate in config.get("locked_gates", [])}
    for gate in debug_map.get("ability_gates", []):
        if str(gate.get("gate_id")) not in gate_ids:
            fail(f"{config['id']} debug_map references missing ability gate: {gate}")


def validate_boss_runback(config: dict[str, Any], graph: dict[str, set[str]]) -> None:
    boss_room = next((room for room in config["map_rooms"] if room.get("kind") == "boss"), None)
    if not boss_room:
        fail(f"{config['id']} 缺少 boss 房")
    save_rooms = []
    for save in config.get("save_points", []):
        room = room_for_position(config, save["position"])
        if room:
            save_rooms.append(room["id"])
    if not save_rooms:
        fail(f"{config['id']} 缺少存档点")
    nearest_values = [d for d in (distance(graph, room_id, boss_room["id"]) for room_id in save_rooms) if d is not None]
    if not nearest_values or min(nearest_values) > 3:
        fail(f"{config['id']} Boss 前 3 步内没有存档点")


def validate_chapter_chain(configs: list[dict[str, Any]]) -> None:
    for current, nxt in zip(configs, configs[1:]):
        transition = current.get("chapter_transition", {})
        if transition.get("to_runtime_config_id") != nxt.get("id"):
            fail(f"{current['id']} generated chain id mismatch: {transition.get('to_runtime_config_id')} != {nxt.get('id')}")
        expected_path = "res://data/generated/" + str(nxt.get("_file_name", ""))
        if transition.get("next_config_path") != expected_path:
            fail(f"{current['id']} generated chain path mismatch: {transition.get('next_config_path')} != {expected_path}")
    if configs:
        last_transition = configs[-1].get("chapter_transition", {})
        if last_transition.get("next_config_path"):
            fail(f"{configs[-1]['id']} last generated chapter should not point to another config")


def validate_main_level_runtime_contract() -> None:
    source = MAIN_LEVEL.read_text(encoding="utf-8")
    required_snippets = [
        "locked_gate_bodies",
        "unlocked_abilities",
        "func _refresh_ability_gates()",
        "func _unlock_ability_gate",
        "func _debug_collect_all_abilities()",
        "opened_shortcuts",
        "func _debug_open_all_shortcuts()",
        "opened_shortcut_total",
        "current_room_archetype",
        "current_room_setpiece",
        "current_room_micro_objective",
        "required_ability",
        "locked_gate_remaining",
    ]
    for snippet in required_snippets:
        if snippet not in source:
            fail(f"main_level.gd missing generated ability gate runtime contract: {snippet}")


def validate_tooling_contract() -> None:
    package = load_json(PACKAGE_JSON)
    scripts = package.get("scripts", {})
    build_script = str(scripts.get("build:generated-maps", ""))
    test_script = str(scripts.get("test:generated-maps", ""))
    for snippet in ["render_ch01_setpiece_preview.py"]:
        if snippet not in build_script:
            fail(f"package build:generated-maps missing {snippet}")
    for snippet in ["probe_ch01_generated_route.py"]:
        if snippet not in test_script:
            fail(f"package test:generated-maps missing {snippet}")


def validate_config(path: Path, physics: PlayerPhysics) -> dict[str, Any]:
    config = load_json(path)
    for field in REQUIRED_FIELDS:
        if field not in config:
            fail(f"{config.get('id', path.name)} 缺字段 {field}")
    for list_field in ["map_rooms", "platforms", "enemy_spawns", "hazards", "npcs", "save_points", "connections", "interactives"]:
        if not isinstance(config[list_field], list):
            fail(f"{config['id']} {list_field} 不是数组")
    assert_unique(config["map_rooms"], "id", "map_rooms", config["id"])
    assert_unique(config["platforms"], "id", "platforms", config["id"])
    if len(config["map_rooms"]) < 55:
        fail(f"{config['id']} 房间数不足 55")
    if len(config["enemy_spawns"]) < 12:
        fail(f"{config['id']} 敌人不足 12")
    if len(config["save_points"]) < 5:
        fail(f"{config['id']} 存档点不足 5")
    if int(config["world"]["width"]) > 36000:
        fail(f"{config['id']} 世界宽度仍过长：{config['world']['width']}")
    if not any(item.get("kind") == "chapter_exit" for item in config["interactives"]):
        fail(f"{config['id']} 缺少 chapter_exit 交互")
    validate_ranges(config)
    graph = validate_connections(config)
    start_room = room_for_position(config, config["player_start"])
    boss_room = next(room for room in config["map_rooms"] if room.get("kind") == "boss")
    exit_room = config["map_rooms"][-1]
    if not start_room:
        fail(f"{config['id']} player_start 不在房间内")
    if distance(graph, start_room["id"], boss_room["id"]) is None:
        fail(f"{config['id']} 出生点无法连到 Boss")
    if distance(graph, start_room["id"], exit_room["id"]) is None:
        fail(f"{config['id']} 出生点无法连到出口")
    validate_platforms(config)
    validate_layout_variety(config)
    archetype_counts = validate_room_design_contracts(config)
    validate_enemy_density(config)
    validate_base_connection_geometry(config, physics)
    validate_positions(config)
    validate_refs(config)
    validate_progression_contracts(config)
    ability_order = validate_ability_unlock_order(config)
    validate_debug_map(config)
    validate_boss_runback(config, graph)
    ability_gate_count = len([link for link in config["connections"] if link.get("type") == "ability_gate"])
    shortcut_count = len([link for link in config["connections"] if link.get("type") == "shortcut"])
    shortcut_steps_saved = sum(int(link.get("shortcut_value", {}).get("distance_saved", 0)) for link in config["connections"] if link.get("type") == "shortcut")
    return {
        "id": config["id"],
        "rooms": len(config["map_rooms"]),
        "platforms": len(config["platforms"]),
        "enemies": len(config["enemy_spawns"]),
        "hazards": len(config["hazards"]),
        "npcs": len(config["npcs"]),
        "saves": len(config["save_points"]),
        "connections": len(config["connections"]),
        "shortcuts": shortcut_count,
        "shortcut_steps_saved": shortcut_steps_saved,
        "ability_gates": ability_gate_count,
        "archetypes": archetype_counts,
        "ability_order": ability_order["acquired"],
        "initial_reachable_rooms_without_shortcuts": ability_order["initial_reachable_rooms"],
        "reachable_rooms_after_unlocks": ability_order["reachable_rooms_after_unlocks"],
        "world_width": config["world"]["width"],
        "width_per_room": round(float(config["world"]["width"]) / max(1, len(config["map_rooms"])), 1),
    }


def main() -> None:
    if len(CONFIGS) < 6:
        fail(f"生成配置不足 6 个：{len(CONFIGS)}")
    physics = read_player_physics()
    validate_main_level_runtime_contract()
    validate_tooling_contract()
    results = [validate_config(path, physics) for path in CONFIGS]
    chain_configs = []
    for path in CONFIGS:
        config = load_json(path)
        config["_file_name"] = path.name
        chain_configs.append(config)
    validate_chapter_chain(chain_configs)
    print(
        json.dumps(
            {
                "ok": True,
                "player_physics": {
                    "speed": physics.speed,
                    "jump_velocity": physics.jump_velocity,
                    "gravity": physics.gravity,
                    "dash_speed": physics.dash_speed,
                    "dash_time": physics.dash_time,
                    "jump_height": round(physics.jump_height, 1),
                    "combined_reach": round(physics.combined_reach, 1),
                },
                "configs": results,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
