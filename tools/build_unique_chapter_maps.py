"""Rebuild unique branch+loop level geometry for the demo chapters.

Each chapter gets a distinct spatial motif instead of the shared template that
ch03-ch06 currently reuse. The script only rewrites *geometry / topology*
fields (platforms, map_rooms, connections, save_points, parkour_segments,
locked_gates) and re-anchors existing entities (enemy_spawns, hazards,
interactives, boss, player_start) onto the new geometry. All other authored
content (ai_profiles, npcs, story, asset policy, sprite data, boss stats...) is
preserved untouched.

Reachability is enforced with the player's real movement constants so the
generated paths stay traversable even though validate_multilayer_maps.py does
not check jump reach for ch03-ch06.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "godot" / "data"
PLAYER = ROOT / "godot" / "scripts" / "player_controller.gd"

# ---- player movement envelope (read from the controller) --------------------

def _export_float(source: str, name: str) -> float:
    m = re.search(rf"@export var {re.escape(name)}: float = (-?\d+(?:\.\d+)?)", source)
    if m is None:
        raise SystemExit(f"missing exported player value: {name}")
    return float(m.group(1))


_PLAYER_SRC = PLAYER.read_text(encoding="utf-8")
JUMP_V = abs(_export_float(_PLAYER_SRC, "jump_velocity"))
GRAVITY = _export_float(_PLAYER_SRC, "gravity")
MAX_JUMP_H = JUMP_V * JUMP_V / (2 * GRAVITY)
SAFE_UP = MAX_JUMP_H * 0.90          # safe upward step
SAFE_GAP = 240.0                     # safe horizontal gap between platform edges


# ---- geometry builder -------------------------------------------------------

class Platform:
    __slots__ = ("id", "x", "y", "w", "h", "mat", "color")

    def __init__(self, pid, x, y, w, h, mat, color):
        self.id, self.x, self.y, self.w, self.h, self.mat, self.color = pid, x, y, w, h, mat, color

    @property
    def left(self):
        return self.x

    @property
    def right(self):
        return self.x + self.w

    @property
    def top(self):
        return self.y

    @property
    def cx(self):
        return self.x + self.w * 0.5

    def dict(self):
        return {"id": self.id, "rect": [self.x, self.y, self.w, self.h], "color": self.color, "material": self.mat}


class MapBuilder:
    def __init__(self, mat_floor, mat_bridge, color_floor, color_bridge):
        self.platforms: list[Platform] = []
        self._by_id: dict[str, Platform] = {}
        self.mat_floor, self.mat_bridge = mat_floor, mat_bridge
        self.color_floor, self.color_bridge = color_floor, color_bridge

    def floor(self, pid, x, y, w, h=34, bridge=False):
        p = Platform(pid, x, y, w, h,
                     self.mat_bridge if bridge else self.mat_floor,
                     self.color_bridge if bridge else self.color_floor)
        if pid in self._by_id:
            raise SystemExit(f"duplicate platform id: {pid}")
        self.platforms.append(p)
        self._by_id[pid] = p
        return p

    def stair(self, prefix, x0, y0, y1, count, dx, w=180, h=22):
        """A climbable/descending run of steps from y0 toward y1."""
        ids = []
        dy = (y1 - y0) / count
        for i in range(count):
            x = x0 + dx * i
            y = y0 + dy * (i + 1)
            ids.append(self.floor(f"{prefix}_{i+1}", round(x), round(y), w, h, bridge=True))
        return ids

    def tower(self, prefix, x_left, span, y_bottom, y_top, step_dy=108, ledge_w=200, h=24):
        """A zig-zag climbing tower: ledges alternate left/right side of the
        tower footprint, stepping upward within jump reach. Returns the ledge
        list ordered bottom -> top. span<=640 keeps the cross-jump <=240px."""
        if span - 2 * ledge_w > SAFE_GAP:
            raise SystemExit(f"{prefix}: tower cross gap {span - 2*ledge_w} > {SAFE_GAP}")
        n = max(1, int(round((y_bottom - y_top) / step_dy)))
        ledges = []
        for i in range(n + 1):
            y = y_bottom - (y_bottom - y_top) * i / n
            on_left = (i % 2 == 0)
            x = x_left if on_left else x_left + span - ledge_w
            ledges.append(self.floor(f"{prefix}_{i}", round(x), round(y), ledge_w, h, bridge=True))
        return ledges

    def ladder(self, prefix, x, y_bottom, y_top, w=170, h=20, step=110):
        """A straight vertical ladder: ledges stacked at one x, climbable up and
        droppable down. Reads very differently from a zig-zag tower."""
        n = max(1, int(round((y_bottom - y_top) / step)))
        return [self.floor(f"{prefix}_{i}", x, round(y_bottom - (y_bottom - y_top) * i / n),
                           w, h, bridge=True) for i in range(n + 1)]

    def junction(self, prefix, ground_y, x_up, x_down, bridge_y, span=600, ledge_w=200):
        """A forced-vertical crossing over a chasm: climb the left tower up to a
        bridge, walk across, descend the right tower to the next ground island.
        Returns dict with up/down ledge lists, the two top landings and bridge."""
        up = self.tower(f"{prefix}_up", x_up, span, ground_y - 100, bridge_y, ledge_w=ledge_w)
        up_top = self.floor(f"{prefix}_up_top", x_up + span - ledge_w, bridge_y, ledge_w, 24, bridge=True)
        bridge = self.floor(f"{prefix}_bridge", x_up + span, bridge_y, x_down - (x_up + span), 26, bridge=True)
        dn_top = self.floor(f"{prefix}_dn_top", x_down, bridge_y, ledge_w, 24, bridge=True)
        dn = self.tower(f"{prefix}_dn", x_down, span, ground_y - 100, bridge_y, ledge_w=ledge_w)
        return {"up": up, "up_top": up_top, "bridge": bridge, "dn_top": dn_top, "dn": dn}

    def get(self, pid):
        return self._by_id[pid]

    # ---- reachability check -------------------------------------------------
    def _edge(self, a: Platform, b: Platform) -> bool:
        gap = max(0.0, a.left - b.right, b.left - a.right)
        if gap > SAFE_GAP:
            return False
        if b.top < a.top - SAFE_UP:          # b too high to jump onto
            return False
        return True

    def reachable_from(self, start_id):
        seen = {start_id}
        stack = [self._by_id[start_id]]
        while stack:
            cur = stack.pop()
            for p in self.platforms:
                if p.id in seen:
                    continue
                if self._edge(cur, p):
                    seen.add(p.id)
                    stack.append(p)
        return seen

    def assert_reachable(self, start_id, targets):
        seen = self.reachable_from(start_id)
        missing = [t for t in targets if t not in seen]
        if missing:
            raise SystemExit(f"unreachable platforms from {start_id}: {missing}")
        # vertical walls (taller than wide) are decorative blockers, not footing
        isolated = [p.id for p in self.platforms if p.id not in seen and p.h <= p.w]
        if isolated:
            raise SystemExit(f"isolated platforms (not reachable from {start_id}): {isolated}")


# ---- room helper ------------------------------------------------------------

def rooms_from_spec(spec, width):
    """spec: list of (id, name, span, depth, kind). spans must sum to width."""
    rooms = []
    cursor = 0
    guide = "横向主线保持可读；竖井连接上下层，背面捷径回到熟悉区域。"
    danger = "下层更宽但陷阱多，上层更安全但跳跃窗口更窄。"
    for rid, name, span, depth, kind, objective in spec:
        rng = [cursor, cursor + span]
        cursor += span
        rooms.append({
            "id": rid, "name": name, "range": rng, "depth": depth, "kind": kind,
            "objective": objective, "guide": guide, "danger": danger,
            "next": "",
        })
    if cursor != width:
        raise SystemExit(f"room spans sum to {cursor}, expected width {width}")
    # link next
    for i, r in enumerate(rooms):
        r["next"] = rooms[i + 1]["name"] if i + 1 < len(rooms) else "—"
    return rooms


def anchor_enemies(config, builder: MapBuilder, assignments):
    """assignments: list of platform ids, one per enemy spawn (in order)."""
    spawns = config["enemy_spawns"]
    if len(assignments) != len(spawns):
        raise SystemExit(f"enemy assignment count {len(assignments)} != spawns {len(spawns)}")
    for spawn, pid in zip(spawns, assignments):
        p = builder.get(pid)
        spawn["platform_id"] = pid
        spawn["position"] = [round(p.cx), round(p.top - 30)]


def write_config(name, config):
    path = DATA_DIR / name
    path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {name}: platforms={len(config['platforms'])} rooms={len(config['map_rooms'])} "
          f"connections={len(config['connections'])}")


def load(name):
    return json.loads((DATA_DIR / name).read_text(encoding="utf-8-sig"))


# =============================================================================
# CH03 — 盐白书库: central reading-well with symmetric upper/lower loops,
# parallel stacks linked by shafts, a back-opening lever shortcut, and a
# return climb to a high index bridge before the contract-judge arena.
# =============================================================================

def build_ch03():
    name = "demo_ch03_saltwhite_archive.json"
    cfg = load(name)
    b = MapBuilder("salt_marble", "vellum_bridge", "4b493c", "b9a06a")

    GROUND = 1980

    # Ground is split into islands by chasms; every crossing uses a DIFFERENT
    # vertical mechanic so no two sections read alike.
    b.floor("g_entry", 0, GROUND, 2000, 40)
    b.floor("g_well", 2520, GROUND, 2100, 40)        # 2520..4620
    b.floor("g_stacks", 5200, GROUND, 2400, 40)      # 5200..7600
    b.floor("g_hall", 8120, GROUND, 2480, 40)        # 8120..10600
    b.floor("g_return", 11120, GROUND, 2480, 40)     # 11120..13600
    b.floor("g_descent", 14120, GROUND, 1680, 40)    # 14120..15800
    boss_floor = b.floor("boss_floor", 15800, GROUND, 1660, 44)
    b.floor("boss_back_wall", 17460, GROUND - 270, 38, 270)
    b.floor("exit_runup", 17560, GROUND, 560, 40)
    exit_floor = b.floor("exit_floor", 18120, GROUND, 680, 40)

    # SECTION A (gap 2000..2520): zig-zag spire UP, long bridge, straight ladder DOWN
    spireA = b.tower("c3_spireA", 1400, 560, 1880, 360, step_dy=120, ledge_w=180)
    bridgeA = b.floor("c3_bridgeA", 1960, 360, 760, 26, bridge=True)
    ladderA = b.ladder("c3_ladderA", 2580, 1880, 460, step=110)

    # SECTION B (gap 4620..5200): deep SUB-GROUND well — drop in, cross floor, climb out
    pit_in = b.ladder("c3_pit_in", 4660, 2240, 1880, w=160, step=110)
    pit_floor = b.floor("c3_pit_floor", 4620, 2320, 580, 40)
    pit_out = b.ladder("c3_pit_out", 5040, 2240, 1880, w=160, step=110)

    # SECTION C: twin-tower LOOP on the stacks island + a rift_hook reward overhead
    loopA = b.tower("c3_loopA", 5500, 560, 1880, 540, ledge_w=180)
    loopB = b.tower("c3_loopB", 6300, 560, 1880, 540, ledge_w=180)
    loop_bridge = b.floor("c3_loop_bridge", 5500, 540, 1360, 26, bridge=True)
    reward = b.floor("c3_reward", 6050, 420, 300, 22, bridge=True)

    # SECTION C-cross (gap 7600..8120): a diagonal STAIRCASE pyramid up-over-down
    su = b.stair("c3_su", 6950, 1990, 560, 13, dx=52, w=150)
    mid_bridge = b.floor("c3_midbridge", 7560, 540, 720, 24, bridge=True)
    sd = b.stair("c3_sd", 8160, 560, 1990, 13, dx=34, w=150)

    # SECTION D (gap 10600..11120): a tight narrow CHIMNEY climb, then a ladder down
    chimney = b.tower("c3_chimney", 9980, 360, 1880, 300, step_dy=100, ledge_w=150)
    chimney_bridge = b.floor("c3_chimney_bridge", 9980, 300, 1340, 26, bridge=True)
    chimney_ladder = b.ladder("c3_chim_ladder", 11140, 1880, 360, w=160, step=108)

    # SECTION E (gap 13600..14120): the TALLEST climb to the apex, long stair DESCENT to boss
    apex = b.tower("c3_apex", 12900, 600, 1880, 240, step_dy=115, ledge_w=180)
    apex_bridge = b.floor("c3_apex_bridge", 12900, 240, 1340, 26, bridge=True)
    descent_stair = b.stair("c3_desc", 14160, 240, 1990, 15, dx=30, w=160)

    b.assert_reachable("g_entry", [
        "g_well", "g_stacks", "g_hall", "g_return", "g_descent",
        bridgeA.id, ladderA[-1].id, pit_floor.id, pit_out[-1].id,
        loopA[-1].id, loopB[-1].id, loop_bridge.id, reward.id,
        mid_bridge.id, chimney[-1].id, chimney_bridge.id,
        apex[-1].id, apex_bridge.id, descent_stair[-1].id,
        boss_floor.id, exit_floor.id,
    ])

    width = cfg["world"]["width"]
    rooms = rooms_from_spec([
        ("ch03_room_1", "盐封入口", 950, 0, "entry", "盐封入口：从底层广场起步，正前方是直插书顶的入口尖塔。"),
        ("ch03_room_2", "入口尖塔", 600, -2, "upper", "入口尖塔：之字攀爬约 1500px 登顶，塔顶钩索壁龛是奖励分支。"),
        ("ch03_room_3", "塔顶索桥", 700, -1, "vertical", "塔顶索桥：从高处俯冲进入下一段阅读井。"),
        ("ch03_room_4", "阅读双井·左", 600, 1, "lower", "阅读双井左塔：从井底向上攀爬。"),
        ("ch03_room_5", "阅读双井·桥", 700, -2, "upper", "双井顶桥：左右两塔在顶部相连，构成纵向回环。"),
        ("ch03_room_6", "阅读双井·右", 850, 1, "vertical", "阅读双井右塔：登顶后由顶桥折返，或继续向右。"),
        ("ch03_room_7", "书脊连廊", 1000, 0, "field", "书脊连廊：底层清怪过渡。"),
        ("ch03_room_8", "书架左塔", 900, 1, "lower", "书架左塔：攀爬进入双塔栈区。"),
        ("ch03_room_9", "书架顶桥", 800, -2, "upper", "书架顶桥：连接左右双塔，斜冲奖励台高悬其上。"),
        ("ch03_room_10", "书架右塔", 900, 1, "vertical", "书架右塔：纵向回环的另一侧。"),
        ("ch03_room_11", "汇流竖井", 900, 0, "vertical", "汇流竖井：两道升降井通往上层环廊。"),
        ("ch03_room_12", "上层环廊", 1300, -2, "upper", "上层环廊：拉杆在此从背面打开回井捷径。"),
        ("ch03_room_13", "回归塔基", 1400, 1, "lower", "回归塔基：最高回归塔的底座。"),
        ("ch03_room_14", "回归升降塔", 1300, -1, "vertical", "回归升降塔：全章最高的纵向攀爬。"),
        ("ch03_room_15", "顶阁索桥", 1400, -3, "upper", "顶阁索桥：全章最高点，俯冲下降进入终段。"),
        ("ch03_room_16", "契约庭前廊", 1100, 0, "field", "契约庭前廊：Boss 前最后的存档与补给。"),
        ("ch03_room_17", "盐白契约庭", 1850, 0, "boss", "盐白契约庭：与盐白契约判官决战。"),
        ("ch03_room_18", "盐页出口", 1550, 0, "exit", "盐页出口：通往第四章断弦温室。"),
    ], width)

    connections = [{"from": f"ch03_room_{i}", "to": f"ch03_room_{i+1}", "type": "passage"} for i in range(1, 18)]
    connections += [
        {"from": "ch03_room_2", "to": "ch03_room_3", "type": "vertical"},
        {"from": "ch03_room_4", "to": "ch03_room_5", "type": "vertical"},
        {"from": "ch03_room_6", "to": "ch03_room_5", "type": "loop"},
        {"from": "ch03_room_8", "to": "ch03_room_9", "type": "vertical"},
        {"from": "ch03_room_10", "to": "ch03_room_9", "type": "loop"},
        {"from": "ch03_room_11", "to": "ch03_room_12", "type": "vertical"},
        {"from": "ch03_room_12", "to": "ch03_room_11", "type": "shortcut",
         "shortcut_id": "ch03_back_drop", "opens_from": "lever"},
        {"from": "ch03_room_14", "to": "ch03_room_15", "type": "vertical"},
    ]

    cfg["map_rooms"] = rooms
    cfg["connections"] = connections
    cfg["platforms"] = [p.dict() for p in b.platforms]

    cfg["locked_gates"] = [{
        "id": "ch03_reward_gate", "rect": [6030, 300, 36, 120], "color": "6f5b9a",
        "material": "rift_seal", "required_ability": "rift_hook",
        "required_ability_name": "裂隙钩索",
    }]

    cfg["parkour_segments"] = [
        {"id": "ch03_spire_climb", "room_id": "ch03_room_2",
         "technique": "zig-zag spire climb, bridge, ladder descent",
         "platforms": [spireA[0].id, spireA[len(spireA)//2].id, spireA[-1].id,
                       bridgeA.id, ladderA[-1].id]},
        {"id": "ch03_well_loop", "room_id": "ch03_room_9",
         "technique": "twin-tower vertical loop over the stacks",
         "platforms": [loopA[0].id, loopA[-1].id, loop_bridge.id, loopB[-1].id, loopB[0].id]},
        {"id": "ch03_return_climb", "room_id": "ch03_room_14",
         "technique": "tallest zig-zag climb to the apex bridge",
         "platforms": [apex[0].id, apex[len(apex)//2].id, apex[-1].id, apex_bridge.id]},
        {"id": "ch03_preboss_drop", "room_id": "ch03_room_15",
         "technique": "long staircase descent from the apex into the arena",
         "platforms": [apex_bridge.id, descent_stair[0].id, descent_stair[-1].id]},
    ]

    save_specs = [
        ("save_well_respite", "阅读井存档点", [700, GROUND - 60], False, "入口岛底的存档点。"),
        ("save_hidden_upper_respite", "盐白书库隐藏存档点", [13500, 240], True, "藏在最高索桥上的稀疏存档点。"),
        ("save_late_runback", "盐白书库Boss前存档点", [14600, GROUND - 60], False, "Boss 跑图前的后段存档点。"),
    ]
    cfg["save_points"] = [
        {"id": sid, "label": label, "position": pos, "hidden": hidden, "note": note}
        for sid, label, pos, hidden, note in save_specs
    ]

    for inter in cfg["interactives"]:
        if inter.get("kind") == "lever":
            inter["position"] = [9000, GROUND - 80]
        elif inter.get("kind") == "boss_gate":
            inter["position"] = [16100, GROUND - 80]
        elif inter.get("kind") in ("chapter_exit", "ending_exit"):
            inter["position"] = [18500, GROUND - 70]

    npc_x = {
        "npc_salt_librarian_ye": 360, "npc_quiet_reader": 1200,
        "npc_fugitive_scribe": 3600, "npc_sealed_archivist": 9000,
    }
    for i, npc in enumerate(cfg.get("npcs", [])):
        x = npc_x.get(npc.get("id"), 600 + i * 800)
        npc["position"] = [x, GROUND - 70]

    cfg["player_start"] = [120, GROUND - 80]
    cfg["boss_checkpoint"] = [14600, GROUND - 80]
    if isinstance(cfg.get("boss"), dict):
        cfg["boss"]["position"] = [16600, GROUND - 80]
        if isinstance(cfg["boss"].get("arena"), list) and len(cfg["boss"]["arena"]) >= 4:
            cfg["boss"]["arena"] = [15800, GROUND - 240, 1660, 260]

    enemy_platforms = [
        "g_entry", spireA[4].id, bridgeA.id, "g_well", pit_floor.id,
        loopA[3].id, loop_bridge.id, "g_stacks", su[6].id, "g_hall",
        chimney[6].id, chimney_bridge.id, "g_return", apex[6].id,
    ]
    anchor_enemies(cfg, b, enemy_platforms)

    hazard_spots = [
        ("ch03_hazard_01", "fake_moss_floor", [1100, GROUND - 20]),
        ("ch03_hazard_02", "bell_gap", [2580, 1000]),
        ("ch03_hazard_03", "spore_chest", [4900, 2300]),
        ("ch03_hazard_04", "falling_clapper", [5040, 2100]),
        ("ch03_hazard_05", "bell_gap", [6050, 520]),
        ("ch03_hazard_06", "falling_clapper", [7560, 540]),
        ("ch03_hazard_07", "spore_chest", [10100, 1000]),
        ("ch03_hazard_08", "fake_moss_floor", [12900, 900]),
        ("ch03_hazard_09", "bell_gap", [14160, 700]),
        ("ch03_hazard_10", "spore_chest", [14800, GROUND - 20]),
    ]
    cfg["hazards"] = [
        {"id": hid, "kind": kind, "rect": [pos[0], pos[1], 110, 24], "damage": 1,
         "message": "纵向扩建路线上出现预警陷阱。"}
        for hid, kind, pos in hazard_spots
    ]

    cfg["world"]["height"] = 2400
    cfg["world"]["fall_y"] = 2520

    write_config(name, cfg)


def auto_rooms(prefix, entries, width):
    """entries: list of (name, depth, kind, objective). Spans are distributed
    evenly across the world width (remainder folded into the last room)."""
    n = len(entries)
    base = width // n
    spans = [base] * n
    spans[-1] += width - base * n
    spec = [(f"{prefix}_room_{i+1}", name, spans[i], depth, kind, obj)
            for i, (name, depth, kind, obj) in enumerate(entries)]
    return rooms_from_spec(spec, width)


def seq_conn(prefix, n):
    return [{"from": f"{prefix}_room_{i}", "to": f"{prefix}_room_{i+1}", "type": "passage"}
            for i in range(1, n)]


def finish_chapter(name, cfg, b, *, rooms, connections, gates, parkour, saves,
                   enemy_pids, hazards, lever_pos, boss_gate_pos, exit_pos,
                   npc_pos, player_start, boss_checkpoint, boss_pos, boss_arena,
                   height, fall_y):
    cfg["map_rooms"] = rooms
    cfg["connections"] = connections
    cfg["platforms"] = [p.dict() for p in b.platforms]
    cfg["locked_gates"] = gates
    cfg["parkour_segments"] = parkour
    cfg["save_points"] = [
        {"id": sid, "label": label, "position": pos, "hidden": hidden, "note": note}
        for sid, label, pos, hidden, note in saves
    ]
    for inter in cfg["interactives"]:
        kind = inter.get("kind")
        if kind == "lever":
            inter["position"] = list(lever_pos)
        elif kind == "boss_gate":
            inter["position"] = list(boss_gate_pos)
        elif kind in ("chapter_exit", "ending_exit"):
            inter["position"] = list(exit_pos)
    for i, npc in enumerate(cfg.get("npcs", [])):
        npc["position"] = list(npc_pos.get(npc.get("id"), [600 + i * 900, height - 90]))
    cfg["player_start"] = list(player_start)
    cfg["boss_checkpoint"] = list(boss_checkpoint)
    if isinstance(cfg.get("boss"), dict):
        cfg["boss"]["position"] = list(boss_pos)
        if isinstance(cfg["boss"].get("arena"), list) and len(cfg["boss"]["arena"]) >= 4:
            cfg["boss"]["arena"] = list(boss_arena)
    anchor_enemies(cfg, b, enemy_pids)
    cfg["hazards"] = [
        {"id": hid, "kind": kind, "rect": [pos[0], pos[1], 110, 24], "damage": 1,
         "message": "纵向路线上的预警陷阱。"}
        for hid, kind, pos in hazards
    ]
    cfg["world"]["height"] = height
    cfg["world"]["fall_y"] = fall_y
    write_config(name, cfg)


# =============================================================================
# CH04 — 断弦温室: climb once on the left, then traverse the high CANOPY across
# the top with hanging-vine drops to lower pockets (loops) and a trunk shaft
# back to a mid ground, before descending to the root-boss arena.
# =============================================================================

def build_ch04():
    name = "demo_ch04_broken_string_greenhouse.json"
    cfg = load(name)
    b = MapBuilder("greenhouse_loam", "glassvine_bridge", "29422d", "426a4b")
    GROUND, H, FALL = 1700, 2000, 2100

    g_start = b.floor("c4_g_start", 0, GROUND, 1400, 40)
    clb = b.tower("c4_climb", 850, 540, 1600, 540, step_dy=115, ledge_w=170)

    # high canopy main line (hop along the top)
    cy = [540, 470, 600, 500, 560, 460, 600, 520, 560, 480, 600, 520, 560]
    canopy = [b.floor(f"c4_c{i}", 1400 + i * 900, yy, 760, 26, bridge=True)
              for i, yy in enumerate(cy)]
    hi = b.floor("c4_hi", 6000, 400, 320, 22, bridge=True)   # high flower (upper band)

    # hanging-vine drops to lower pockets (vertical loops off the canopy)
    pockets, vines = {}, {}
    for idx in (2, 6, 10):
        cx = 1400 + idx * 900
        vines[idx] = b.ladder(f"c4_vine{idx}", cx + 320, 1520, 720, w=160, step=110)
        pockets[idx] = b.floor(f"c4_pocket{idx}", cx + 60, 1560, 540, 34)

    # central trunk back down to a mid ground island
    g_mid = b.floor("c4_g_mid", 7600, GROUND, 1200, 40)
    trunk = b.tower("c4_trunk", 7900, 540, 1600, 560, step_dy=115, ledge_w=170)

    # descent to the boss approach
    g_preboss = b.floor("c4_g_preboss", 13000, GROUND, 2800, 40)
    desc = b.ladder("c4_desc", 13200, 1600, 600, w=170, step=110)
    boss_floor = b.floor("c4_boss_floor", 15800, GROUND, 1660, 44)
    b.floor("c4_boss_back_wall", 17460, GROUND - 270, 38, 270)
    b.floor("c4_exit_runup", 17560, GROUND, 560, 40)
    exit_floor = b.floor("c4_exit_floor", 18120, GROUND, 680, 40)

    b.assert_reachable("c4_g_start", [
        canopy[-1].id, hi.id, pockets[2].id, pockets[6].id, pockets[10].id,
        g_mid.id, g_preboss.id, boss_floor.id, exit_floor.id,
    ])

    rooms = auto_rooms("ch04", [
        ("温室门厅", 0, "entry", "温室门厅：从苗圃地面攀上玻璃藤架进入树冠层。"),
        ("攀藤架", -2, "vertical", "攀藤架：之字攀上高处的树冠主线。"),
        ("树冠西廊", -1, "upper", "树冠西廊：沿顶层连跳推进，脚下是悬空苗圃。"),
        ("垂藤·西袋", 2, "lower", "西垂藤：藤蔓垂降到下层花袋，可回到树冠。"),
        ("树冠中廊", -1, "upper", "树冠中廊：连续跳台，注意花隙落差。"),
        ("高悬花台", -3, "upper", "高悬花台：钩到最高处的花台奖励。"),
        ("垂藤·中袋", 2, "lower", "中垂藤：下层花袋，回环重回树冠。"),
        ("主干竖井", 0, "vertical", "主干竖井：沿温室主干上下，连通中层地面。"),
        ("中层苗圃", 1, "lower", "中层苗圃：树冠下的地面绿洲。"),
        ("树冠东廊", -1, "upper", "树冠东廊：继续顶层推进。"),
        ("垂藤·东袋", 2, "lower", "东垂藤：最后一处下层花袋回环。"),
        ("断弦桥", -1, "upper", "断弦桥：高处长桥跨越温室裂口。"),
        ("树冠尽廊", -1, "upper", "树冠尽廊：树冠主线的终点。"),
        ("垂降梯", 0, "vertical", "垂降梯：从树冠垂降回到根部地面。"),
        ("根部前廊", 1, "field", "根部前廊：Boss 前的存档补给。"),
        ("断弦根庭", 0, "boss", "断弦根庭：与根缚之主决战。"),
        ("根隙通道", 1, "lower", "根隙通道：清理残余后通向出口。"),
        ("温室出口", 0, "exit", "温室出口：通往第五章黑曜朝圣路。"),
    ], cfg["world"]["width"])

    connections = seq_conn("ch04", 18) + [
        {"from": "ch04_room_3", "to": "ch04_room_4", "type": "vertical"},
        {"from": "ch04_room_4", "to": "ch04_room_5", "type": "loop"},
        {"from": "ch04_room_8", "to": "ch04_room_9", "type": "vertical"},
        {"from": "ch04_room_9", "to": "ch04_room_8", "type": "shortcut",
         "shortcut_id": "ch04_trunk_drop", "opens_from": "lever"},
        {"from": "ch04_room_11", "to": "ch04_room_10", "type": "loop"},
    ]

    parkour = [
        {"id": "ch04_parkour_climb", "room_id": "ch04_room_2",
         "technique": "vine-trellis climb to the canopy",
         "platforms": [clb[0].id, clb[len(clb)//2].id, clb[-1].id, canopy[0].id]},
        {"id": "ch04_sprint_chain", "room_id": "ch04_room_5",
         "technique": "canopy hop chain across the top",
         "platforms": [canopy[3].id, canopy[4].id, canopy[5].id, canopy[6].id]},
        {"id": "ch04_lower_upper_return", "room_id": "ch04_room_7",
         "technique": "hanging-vine drop and climb back",
         "platforms": [canopy[6].id, vines[6][0].id, pockets[6].id, vines[6][-1].id]},
        {"id": "ch04_preboss_crossway", "room_id": "ch04_room_14",
         "technique": "vine descent into the root arena",
         "platforms": [canopy[-1].id, desc[0].id, desc[-1].id, g_preboss.id]},
    ]

    finish_chapter(
        name, cfg, b,
        rooms=rooms, connections=connections, gates=[], parkour=parkour,
        saves=[
            ("save_canopy_foot", "温室门厅存档点", [400, GROUND - 60], False, "入口苗圃存档点。"),
            ("save_hidden_flower", "断弦温室隐藏存档点", [6050, 370], True, "藏在高悬花台上的稀疏存档点。"),
            ("save_root_runback", "断弦温室Boss前存档点", [13400, GROUND - 60], False, "Boss 跑图前存档点。"),
        ],
        enemy_pids=["c4_g_start", "c4_c1", "c4_c2", "c4_pocket2", "c4_c4", "c4_hi",
                    "c4_g_mid", "c4_c7", "c4_c9", "c4_pocket10", "c4_c11", "c4_c12",
                    "c4_g_preboss", "c4_pocket6"],
        hazards=[
            ("ch04_hazard_01", "thorn_burst", [700, GROUND - 20]),
            ("ch04_hazard_02", "pollen_cloud", [2160, 470]),
            ("ch04_hazard_03", "thorn_burst", [3500, 1540]),
            ("ch04_hazard_04", "pollen_cloud", [5040, 500]),
            ("ch04_hazard_05", "thorn_burst", [6000, 380]),
            ("ch04_hazard_06", "pollen_cloud", [7600, GROUND - 20]),
            ("ch04_hazard_07", "thorn_burst", [9740, 1540]),
            ("ch04_hazard_08", "pollen_cloud", [11540, 520]),
            ("ch04_hazard_09", "thorn_burst", [12200, 520]),
            ("ch04_hazard_10", "pollen_cloud", [14500, GROUND - 20]),
        ],
        lever_pos=[8000, GROUND - 80], boss_gate_pos=[16000, GROUND - 80],
        exit_pos=[18450, GROUND - 70],
        npc_pos={
            "npc_old_gardener": [400, GROUND - 70], "npc_broken_singer": [3560, 1500],
            "npc_beeswax_vendor": [7800, GROUND - 70], "npc_root_prisoner": [10800, 1500],
        },
        player_start=[120, GROUND - 80], boss_checkpoint=[13400, GROUND - 80],
        boss_pos=[16600, GROUND - 80], boss_arena=[15800, GROUND - 240, 1660, 260],
        height=H, fall_y=FALL,
    )


# =============================================================================
# CH05 — 黑曜朝圣路: a high SAFE RIDGE and a low DANGER RAVINE run in parallel;
# ravine stepping-stones cross the chasms tightly while the ridge offers a
# safer gappy road, with cross-links letting pilgrims switch roads (loops).
# =============================================================================

def build_ch05():
    name = "demo_ch05_obsidian_pilgrim_road.json"
    cfg = load(name)
    b = MapBuilder("obsidian_basalt", "ember_bridge", "272734", "6e3d32")
    LOW, RIDGE, H, FALL = 1620, 560, 1900, 2000

    # low danger road: ground segments broken by chasms
    low_xs = [(0, 2000), (2600, 1800), (5000, 1800), (7400, 1800), (9800, 1800), (12200, 1800)]
    lows = [b.floor(f"c5_low{i}", x, LOW, w, 40) for i, (x, w) in enumerate(low_xs)]
    # tight ravine stepping-stones across each chasm (low road stays passable but risky)
    stones = []
    for i in range(len(low_xs) - 1):
        gap_l = low_xs[i][0] + low_xs[i][1]
        s1 = b.floor(f"c5_stone{i}a", gap_l + 80, LOW + 100, 180, 22, bridge=True)
        s2 = b.floor(f"c5_stone{i}b", gap_l + 360, LOW + 100, 180, 22, bridge=True)
        stones += [s1, s2]

    # high safe ridge: a near-continuous gappy road across the top
    ridge = [b.floor(f"c5_ridge{i}", 1700 + i * 960, RIDGE, 760, 26, bridge=True)
             for i in range(13)]
    peak_step = b.floor("c5_peak_step", 6480, 500, 260, 22, bridge=True)
    peak = b.floor("c5_peak", 6520, 400, 260, 22, bridge=True)   # watch peak (upper band)

    # cross-links between the two roads (alternating climb styles) -> switch/loops
    link0 = b.ladder("c5_link0", 1600, LOW - 80, RIDGE + 30, w=160, step=110)    # entry climb
    link1 = b.stair("c5_link1", 3200, RIDGE + 40, LOW - 40, 11, dx=46, w=150)    # drop to low1
    link2 = b.tower("c5_link2", 6000, 540, LOW - 60, RIDGE + 30, step_dy=110, ledge_w=170)
    link3 = b.ladder("c5_link3", 10400, LOW - 80, RIDGE + 30, w=160, step=110)

    g_preboss = b.floor("c5_preboss", 14000, LOW, 1800, 40)
    desc = b.stair("c5_desc", 13950, RIDGE + 40, LOW - 40, 11, dx=40, w=160)
    boss_floor = b.floor("c5_boss_floor", 15800, LOW, 1660, 44)
    b.floor("c5_boss_back_wall", 17460, LOW - 270, 38, 270)
    b.floor("c5_exit_runup", 17560, LOW, 560, 40)
    exit_floor = b.floor("c5_exit_floor", 18120, LOW, 680, 40)

    b.assert_reachable("c5_low0", [
        ridge[-1].id, peak.id, lows[-1].id, stones[-1].id,
        link2[-1].id, g_preboss.id, boss_floor.id, exit_floor.id,
    ])

    rooms = auto_rooms("ch05", [
        ("朝圣起点", 1, "entry", "朝圣起点：低路沟壑起步，可攀上高处山脊。"),
        ("初登山脊", -2, "vertical", "初登山脊：爬上安全的高路。"),
        ("山脊西段", -1, "upper", "山脊西段：安全但跳台间隙大。"),
        ("沟壑踏石·一", 2, "lower", "沟壑踏石：低路险跨，脚下是熔渊。"),
        ("分道口", 0, "vertical", "分道口：高低两路在此交换。"),
        ("瞭望峰", -3, "upper", "瞭望峰：钩到最高的瞭望点。"),
        ("沟壑踏石·二", 2, "lower", "第二处沟壑踏石。"),
        ("山脊中段", -1, "upper", "山脊中段：继续高路推进。"),
        ("熔渊低道", 1, "lower", "熔渊低道：危险但有补给的低路。"),
        ("换道竖梯", 0, "vertical", "换道竖梯：在高低路之间回环。"),
        ("沟壑踏石·三", 2, "lower", "第三处沟壑踏石。"),
        ("山脊东段", -1, "upper", "山脊东段：高路接近尾声。"),
        ("会合台", 0, "field", "会合台：两路在此合流。"),
        ("降脊阶", 0, "vertical", "降脊阶：从山脊下到 Boss 前广场。"),
        ("朝圣前庭", 1, "field", "朝圣前庭：Boss 前存档补给。"),
        ("黑曜祭坛", 0, "boss", "黑曜祭坛：与盲钟骑士决战。"),
        ("余烬通道", 1, "lower", "余烬通道：清场后通向出口。"),
        ("朝圣出口", 0, "exit", "朝圣出口：通往第六章无星纺核。"),
    ], cfg["world"]["width"])

    connections = seq_conn("ch05", 18) + [
        {"from": "ch05_room_3", "to": "ch05_room_4", "type": "branch"},
        {"from": "ch05_room_4", "to": "ch05_room_5", "type": "loop"},
        {"from": "ch05_room_8", "to": "ch05_room_9", "type": "branch"},
        {"from": "ch05_room_10", "to": "ch05_room_8", "type": "shortcut",
         "shortcut_id": "ch05_ridge_drop", "opens_from": "lever"},
        {"from": "ch05_room_9", "to": "ch05_room_12", "type": "loop"},
    ]

    parkour = [
        {"id": "ch05_parkour_climb", "room_id": "ch05_room_2",
         "technique": "ravine-to-ridge ladder climb",
         "platforms": [link0[0].id, link0[len(link0)//2].id, link0[-1].id, ridge[0].id]},
        {"id": "ch05_sprint_chain", "room_id": "ch05_room_3",
         "technique": "ridge precision hop chain",
         "platforms": [ridge[2].id, ridge[3].id, ridge[4].id, ridge[5].id]},
        {"id": "ch05_lower_upper_return", "room_id": "ch05_room_5",
         "technique": "switch ravine road to ridge and back",
         "platforms": [lows[2].id, link2[0].id, link2[-1].id, ridge[5].id]},
        {"id": "ch05_preboss_crossway", "room_id": "ch05_room_14",
         "technique": "ridge stair descent to the altar approach",
         "platforms": [ridge[-1].id, desc[0].id, desc[-1].id, g_preboss.id]},
    ]

    finish_chapter(
        name, cfg, b,
        rooms=rooms, connections=connections, gates=[], parkour=parkour,
        saves=[
            ("save_road_start", "朝圣起点存档点", [400, LOW - 60], False, "起点低路存档点。"),
            ("save_hidden_peak", "黑曜朝圣路隐藏存档点", [6560, 370], True, "藏在瞭望峰上的稀疏存档点。"),
            ("save_altar_runback", "黑曜朝圣路Boss前存档点", [14300, LOW - 60], False, "Boss 跑图前存档点。"),
        ],
        enemy_pids=["c5_low0", "c5_ridge1", "c5_stone0a", "c5_ridge3", "c5_low2",
                    "c5_peak", "c5_ridge6", "c5_low3", "c5_stone3a", "c5_ridge9",
                    "c5_low4", "c5_ridge11", "c5_low5", "c5_preboss"],
        hazards=[
            ("ch05_hazard_01", "ember_vent", [700, LOW - 20]),
            ("ch05_hazard_02", "ash_gust", [2160, 460]),
            ("ch05_hazard_03", "ember_vent", [2760, LOW + 140]),
            ("ch05_hazard_04", "ash_gust", [5040, 460]),
            ("ch05_hazard_05", "ember_vent", [6560, 380]),
            ("ch05_hazard_06", "ash_gust", [7160, LOW + 140]),
            ("ch05_hazard_07", "ember_vent", [9800, LOW - 20]),
            ("ch05_hazard_08", "ash_gust", [11540, 460]),
            ("ch05_hazard_09", "ember_vent", [12140, LOW + 140]),
            ("ch05_hazard_10", "ash_gust", [14500, LOW - 20]),
        ],
        lever_pos=[9000, LOW - 80], boss_gate_pos=[16000, LOW - 80],
        exit_pos=[18450, LOW - 70],
        npc_pos={
            "npc_obsidian_guide": [400, LOW - 70], "npc_blind_bell_knight": [9000, LOW - 70],
            "npc_lantern_sister": [6560, RIDGE - 40], "npc_deserter_flagbearer": [5200, LOW - 70],
        },
        player_start=[120, LOW - 80], boss_checkpoint=[14300, LOW - 80],
        boss_pos=[16600, LOW - 80], boss_arena=[15800, LOW - 240, 1660, 260],
        height=H, fall_y=FALL,
    )


# =============================================================================
# CH06 — 无星纺核: a single colossal central WELL dominates the map; pilgrims
# spiral DOWN one inner wall to the core chamber and climb the far wall back
# up, flanked by approach grounds, ending at the crown-core arena.
# =============================================================================

def build_ch06():
    name = "demo_ch06_silent_crown_core.json"
    cfg = load(name)
    b = MapBuilder("crown_bone", "void_bridge", "3c4358", "343a64")
    GROUND, H, FALL = 1700, 2800, 2900

    # left approach + an entry lookout (upper/middle band)
    g_left = b.floor("c6_g_left", 0, GROUND, 6000, 40)
    lookout = b.tower("c6_lookout", 1200, 560, 1600, 400, step_dy=110, ledge_w=170)
    look_top = b.floor("c6_look_top", 1200, 400, 360, 22, bridge=True)

    # THE CORE: a deep well; descend the left wall, cross the bottom, climb the far wall
    left_wall = b.tower("c6_leftwall", 6000, 600, 2560, 1640, step_dy=115, ledge_w=200)
    core_bottom = b.floor("c6_core_bottom", 6000, 2600, 5900, 44)   # well floor under both walls
    right_wall = b.tower("c6_rightwall", 11300, 600, 2560, 1640, step_dy=115, ledge_w=200)
    right_rim = b.floor("c6_right_rim", 11500, 1660, 700, 26, bridge=True)  # wall top -> east rim
    # radial echo chambers hanging off the walls, plus a mid span across the void
    echo_a = b.floor("c6_echo_a", 6650, 2150, 360, 24, bridge=True)
    echo_b = b.floor("c6_echo_b", 11050, 2150, 360, 24, bridge=True)
    core_span = b.floor("c6_core_span", 6500, 1900, 900, 22, bridge=True)  # mid ledge off the left wall

    g_right = b.floor("c6_g_right", 12000, GROUND, 3800, 40)
    boss_floor = b.floor("c6_boss_floor", 15800, GROUND, 1660, 44)
    b.floor("c6_boss_back_wall", 17460, GROUND - 270, 38, 270)
    b.floor("c6_exit_runup", 17560, GROUND, 560, 40)
    exit_floor = b.floor("c6_exit_floor", 18120, GROUND, 680, 40)

    b.assert_reachable("c6_g_left", [
        look_top.id, left_wall[-1].id, core_bottom.id, echo_a.id, echo_b.id,
        core_span.id, right_wall[-1].id, right_rim.id, g_right.id,
        boss_floor.id, exit_floor.id,
    ])

    rooms = auto_rooms("ch06", [
        ("纺核外缘", 1, "entry", "纺核外缘：从外缘地面走向中央深井。"),
        ("观井塔", -3, "upper", "观井塔：登上高处俯瞰无星深井。"),
        ("井缘西", 0, "field", "井缘西：深井左侧的入口缘地。"),
        ("回声·首环", 0, "vertical", "回声首环：沿井壁螺旋下潜。"),
        ("回声·二环", 1, "lower", "回声二环：井壁中段的回声壁龛。"),
        ("悬心桥", -1, "upper", "悬心桥：横跨深井虚空的悬桥。"),
        ("回声·三环", 2, "lower", "回声三环：更深一层的螺旋。"),
        ("纺核底室", 2, "lower", "纺核底室：深井最底的核心之厅。"),
        ("回响壁龛", 1, "lower", "回响壁龛：底室旁的支线壁龛。"),
        ("攀壁·首段", 0, "vertical", "攀壁首段：从核心沿右壁向上攀。"),
        ("攀壁·二段", -1, "upper", "攀壁二段：螺旋攀升接近井缘。"),
        ("井缘东", 0, "field", "井缘东：深井右侧的出口缘地。"),
        ("外缘回廊", -1, "upper", "外缘回廊：井缘上的高处回廊。"),
        ("升核竖道", 0, "vertical", "升核竖道：通往 Boss 前广场。"),
        ("纺核前庭", 1, "field", "纺核前庭：Boss 前存档补给。"),
        ("无星之冠", 0, "boss", "无星之冠：与缄冠之主决战。"),
        ("冠隙通道", 1, "lower", "冠隙通道：清场后通向终局之门。"),
        ("终局之门", 0, "exit", "终局之门：朝圣的尽头。"),
    ], cfg["world"]["width"])

    connections = seq_conn("ch06", 18) + [
        {"from": "ch06_room_2", "to": "ch06_room_3", "type": "vertical"},
        {"from": "ch06_room_6", "to": "ch06_room_8", "type": "branch"},
        {"from": "ch06_room_8", "to": "ch06_room_9", "type": "loop"},
        {"from": "ch06_room_11", "to": "ch06_room_6", "type": "shortcut",
         "shortcut_id": "ch06_void_span", "opens_from": "lever"},
        {"from": "ch06_room_4", "to": "ch06_room_10", "type": "loop"},
    ]

    parkour = [
        {"id": "ch06_parkour_climb", "room_id": "ch06_room_2",
         "technique": "lookout spire climb",
         "platforms": [lookout[0].id, lookout[len(lookout)//2].id, lookout[-1].id, look_top.id]},
        {"id": "ch06_sprint_chain", "room_id": "ch06_room_4",
         "technique": "spiral descent down the well wall",
         "platforms": [left_wall[-1].id, left_wall[len(left_wall)//2].id, left_wall[0].id, core_bottom.id]},
        {"id": "ch06_lower_upper_return", "room_id": "ch06_room_10",
         "technique": "climb the far well wall back to the rim",
         "platforms": [core_bottom.id, right_wall[0].id, right_wall[len(right_wall)//2].id, right_wall[-1].id]},
        {"id": "ch06_preboss_crossway", "room_id": "ch06_room_11",
         "technique": "far-wall ascent over the rim to the arena approach",
         "platforms": [right_wall[-1].id, right_rim.id, g_right.id]},
    ]

    finish_chapter(
        name, cfg, b,
        rooms=rooms, connections=connections, gates=[], parkour=parkour,
        saves=[
            ("save_rim_west", "纺核外缘存档点", [400, GROUND - 60], False, "外缘地面存档点。"),
            ("save_hidden_core", "无星纺核隐藏存档点", [8900, 2560], True, "藏在纺核底室的稀疏存档点。"),
            ("save_rim_east", "无星纺核Boss前存档点", [14200, GROUND - 60], False, "Boss 跑图前存档点。"),
        ],
        enemy_pids=["c6_g_left", "c6_look_top", "c6_leftwall_2", "c6_echo_a", "c6_leftwall_5",
                    "c6_core_bottom", "c6_core_span", "c6_echo_b", "c6_rightwall_5", "c6_rightwall_2",
                    "c6_g_right", "c6_right_rim", "c6_core_span", "c6_leftwall_7"],
        hazards=[
            ("ch06_hazard_01", "void_pulse", [700, GROUND - 20]),
            ("ch06_hazard_02", "echo_shard", [1300, 420]),
            ("ch06_hazard_03", "void_pulse", [6200, 2000]),
            ("ch06_hazard_04", "echo_shard", [6900, 2100]),
            ("ch06_hazard_05", "void_pulse", [8400, 1880]),
            ("ch06_hazard_06", "echo_shard", [6800, 1860]),
            ("ch06_hazard_07", "void_pulse", [10980, 2100]),
            ("ch06_hazard_08", "echo_shard", [11400, 2000]),
            ("ch06_hazard_09", "void_pulse", [12500, GROUND - 20]),
            ("ch06_hazard_10", "echo_shard", [14600, GROUND - 20]),
        ],
        lever_pos=[8900, 2560], boss_gate_pos=[16000, GROUND - 80],
        exit_pos=[18450, GROUND - 70],
        npc_pos={
            "npc_first_pilgrim_echo": [400, GROUND - 70], "npc_crown_tongue": [13000, GROUND - 70],
            "npc_six_mark_keeper": [8900, 2560], "npc_black_tide_child": [6900, 2560],
        },
        player_start=[120, GROUND - 80], boss_checkpoint=[14200, GROUND - 80],
        boss_pos=[16600, GROUND - 80], boss_arena=[15800, GROUND - 240, 1660, 260],
        height=H, fall_y=FALL,
    )


def build_all():
    build_ch03()
    build_ch04()
    build_ch05()
    build_ch06()


if __name__ == "__main__":
    build_all()
