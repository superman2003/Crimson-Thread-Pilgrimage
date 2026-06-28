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

    # Ground is split into islands separated by chasms (death pits). The only
    # way across each chasm is up a tower, across the bridge and down the next
    # tower -> the X mainline is *forced* through ~1500px of vertical climb.
    b.floor("g_entry", 0, GROUND, 2000, 40)
    b.floor("g_well", 2520, GROUND, 2280, 40)
    b.floor("g_stacks", 5320, GROUND, 2280, 40)
    b.floor("g_hall", 8120, GROUND, 2480, 40)
    b.floor("g_return", 11120, GROUND, 2480, 40)
    b.floor("g_descent", 14120, GROUND, 1680, 40)
    boss_floor = b.floor("boss_floor", 15800, GROUND, 1660, 44)
    b.floor("boss_back_wall", 17460, GROUND - 270, 38, 270)
    b.floor("exit_runup", 17560, GROUND, 560, 40)
    exit_floor = b.floor("exit_floor", 18120, GROUND, 680, 40)

    # forced-vertical crossings between islands (climb -> bridge -> descend)
    j1 = b.junction("c3_j1", GROUND, 1380, 2540, 360)   # entry spire
    j2 = b.junction("c3_j2", GROUND, 4180, 5340, 300)   # reading well
    j3 = b.junction("c3_j3", GROUND, 6980, 8140, 440)   # book-spine span
    j4 = b.junction("c3_j4", GROUND, 9980, 11140, 260)  # apex (highest)
    j5 = b.junction("c3_j5", GROUND, 12980, 14140, 360) # descent to boss

    # optional twin-tower loop on the stacks island (climb one side, cross, drop other)
    loopA = b.tower("c3_loopA", 5600, 600, 1880, 520)
    loopB = b.tower("c3_loopB", 6500, 600, 1880, 520)
    loop_bridge = b.floor("c3_loop_bridge", 5600, 520, 1500, 26, bridge=True)

    # rift_hook reward branch above the apex of the reading-well bridge
    reward = b.floor("c3_reward", 4900, 180, 300, 22, bridge=True)

    b.assert_reachable("g_entry", [
        "g_well", "g_stacks", "g_hall", "g_return", "g_descent",
        j1["bridge"].id, j2["bridge"].id, j3["bridge"].id, j4["bridge"].id, j5["bridge"].id,
        j5["dn"][0].id, loopA[-1].id, loopB[-1].id, loop_bridge.id, reward.id,
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
        "id": "ch03_reward_gate", "rect": [4870, 70, 36, 120], "color": "6f5b9a",
        "material": "rift_seal", "required_ability": "rift_hook",
        "required_ability_name": "裂隙钩索",
    }]

    cfg["parkour_segments"] = [
        {"id": "ch03_spire_climb", "room_id": "ch03_room_2",
         "technique": "zig-zag tower climb to the crossing bridge",
         "platforms": [j1["up"][0].id, j1["up"][len(j1["up"])//2].id, j1["up"][-1].id,
                       j1["up_top"].id, j1["bridge"].id]},
        {"id": "ch03_well_loop", "room_id": "ch03_room_9",
         "technique": "twin-tower vertical loop over the stacks",
         "platforms": [loopA[0].id, loopA[-1].id, loop_bridge.id, loopB[-1].id, loopB[0].id]},
        {"id": "ch03_return_climb", "room_id": "ch03_room_14",
         "technique": "tallest vertical climb to the apex bridge",
         "platforms": [j4["up"][0].id, j4["up"][len(j4["up"])//2].id, j4["up"][-1].id, j4["bridge"].id]},
        {"id": "ch03_preboss_drop", "room_id": "ch03_room_15",
         "technique": "apex drop down the descent tower into the arena",
         "platforms": [j5["bridge"].id, j5["dn_top"].id, j5["dn"][-1].id, j5["dn"][0].id]},
    ]

    save_specs = [
        ("save_well_respite", "阅读井存档点", [700, GROUND - 60], False, "入口岛底的存档点。"),
        ("save_hidden_upper_respite", "盐白书库隐藏存档点", [10860, 260], True, "藏在最高索桥上的稀疏存档点。"),
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
        "g_entry", j1["up"][3].id, j1["bridge"].id, "g_well", j2["up"][3].id,
        j2["bridge"].id, loopA[3].id, "g_stacks", j3["bridge"].id, "g_hall",
        j4["up"][3].id, j4["bridge"].id, "g_return", j5["bridge"].id,
    ]
    anchor_enemies(cfg, b, enemy_platforms)

    hazard_spots = [
        ("ch03_hazard_01", "fake_moss_floor", [1100, GROUND - 20]),
        ("ch03_hazard_02", "bell_gap", [2200, 400]),
        ("ch03_hazard_03", "spore_chest", [4900, 180]),
        ("ch03_hazard_04", "falling_clapper", [5000, 400]),
        ("ch03_hazard_05", "bell_gap", [6000, 520]),
        ("ch03_hazard_06", "falling_clapper", [7800, 440]),
        ("ch03_hazard_07", "spore_chest", [9000, GROUND - 20]),
        ("ch03_hazard_08", "fake_moss_floor", [10860, 260]),
        ("ch03_hazard_09", "bell_gap", [13800, 360]),
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


def build_all():
    build_ch03()


if __name__ == "__main__":
    build_all()
