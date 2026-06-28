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

    # --- S1 entry & fork (0–2250) ---
    b.floor("start_ground", 0, 560, 900, 40)
    b.floor("entry_step", 760, 470, 240, 24, bridge=True)
    b.floor("entry_balcony", 1040, 392, 320, 24, bridge=True)        # upper fork
    b.floor("entry_low_drop", 980, 624, 560, 32)                      # lower fork
    b.floor("entry_mid", 1560, 540, 520, 30)
    b.floor("well_lip_left", 2080, 500, 360, 28, bridge=True)

    # --- S2 reading-well loop (2250–4400) ---
    b.floor("well_floor", 2440, 640, 1560, 34)                        # lower stacks
    b.floor("well_gallery", 2520, 384, 1400, 26, bridge=True)         # upper gallery
    b.floor("well_lshaft_1", 2500, 560, 160, 20, bridge=True)
    b.floor("well_lshaft_2", 2540, 472, 160, 20, bridge=True)
    b.floor("well_rshaft_1", 3760, 480, 160, 20, bridge=True)
    b.floor("well_rshaft_2", 3700, 580, 160, 20, bridge=True)
    b.floor("well_alcove", 2480, 282, 260, 22, bridge=True)           # rift_hook reward branch
    b.floor("well_exit_step", 4040, 540, 360, 28, bridge=True)
    b.floor("well_exit_floor", 4400, 540, 1000, 34)

    # --- S3 parallel stacks + loops + dash shortcut (5400–8400) ---
    b.floor("stacks_lower", 5400, 624, 1500, 32)
    b.floor("stacks_upper_a", 5500, 392, 700, 26, bridge=True)
    b.floor("s_sh1_1", 5460, 540, 160, 20, bridge=True)
    b.floor("s_sh1_2", 5480, 460, 160, 20, bridge=True)
    b.floor("stacks_upper_b", 6360, 392, 640, 26, bridge=True)        # dash gap from upper_a
    b.floor("stacks_lower_b", 7000, 624, 1400, 32)
    b.floor("s_sh2_1", 7060, 540, 160, 20, bridge=True)
    b.floor("s_sh2_2", 7080, 460, 160, 20, bridge=True)
    b.floor("stacks_upper_c", 7200, 360, 560, 24, bridge=True)        # diagonal-dash reward branch
    b.floor("stacks_exit_floor", 8400, 540, 900, 34)

    # --- S4 convergence hall + back lever shortcut (9300–11760) ---
    b.floor("hall_floor", 9300, 540, 1500, 34)
    b.floor("h_sh_1", 9360, 470, 160, 20, bridge=True)
    b.floor("hall_upper", 9500, 400, 760, 26, bridge=True)
    b.floor("lever_landing", 10800, 500, 360, 28, bridge=True)
    b.floor("hall_exit_floor", 11160, 540, 600, 34)

    # --- S5 return climb + high bridge (11760–14640) ---
    b.floor("return_base", 11760, 560, 420, 30)
    b.floor("ret_1", 12100, 472, 220, 22, bridge=True)
    b.floor("ret_2", 12380, 392, 240, 22, bridge=True)
    b.floor("ret_3", 12660, 320, 260, 22, bridge=True)
    b.floor("high_bridge", 12900, 300, 1300, 26, bridge=True)
    b.floor("high_bridge_drop", 14260, 430, 320, 26, bridge=True)
    b.floor("approach_floor", 14640, 540, 760, 34)

    # --- S6 boss + exit (15400–18800) ---
    b.floor("preboss_floor", 15400, 540, 850, 34)
    b.floor("boss_floor", 16250, 540, 1660, 44)
    b.floor("boss_back_wall", 17910, 315, 38, 270)
    b.floor("post_boss_step", 17900, 540, 300, 34)
    b.floor("exit_runup", 18040, 540, 480, 34)
    b.floor("exit_floor", 18420, 540, 380, 34)

    b.assert_reachable("start_ground", ["well_gallery", "well_alcove", "stacks_upper_c",
                                        "high_bridge", "boss_floor", "exit_floor"])

    width = cfg["world"]["width"]
    rooms = rooms_from_spec([
        ("ch03_room_1", "盐封入口", 950, 0, "entry", "盐封入口：先沿中层推进，左上书廊与右下书库各开一条岔路。"),
        ("ch03_room_2", "上层书廊", 600, -1, "upper", "上层书廊：窄跳安全路，俯瞰下层书库。"),
        ("ch03_room_3", "下层书库", 700, 1, "lower", "下层书库：宽阔但陷阱多，可回到入口竖井。"),
        ("ch03_room_4", "阅读井·井口", 600, 0, "vertical", "阅读井井口：左右两道书梯环绕井体，构成回环。"),
        ("ch03_room_5", "阅读井·回廊", 700, -2, "upper", "上层回廊：钩索可达隐藏壁龛奖励。"),
        ("ch03_room_6", "阅读井·底库", 850, 2, "lower", "井底书库：最深一层，绕行后从右梯回到回廊。"),
        ("ch03_room_7", "井东连廊", 1000, 0, "field", "井东连廊：清怪过渡到双层书架区。"),
        ("ch03_room_8", "书架上层栈道", 900, -1, "upper", "上层栈道：斜冲跨越书架缺口。"),
        ("ch03_room_9", "书架下层走道", 800, 1, "lower", "下层走道：与上层栈道由竖井相连成环。"),
        ("ch03_room_10", "倒置书梯", 900, 0, "vertical", "倒置书梯：上下层在此交汇。"),
        ("ch03_room_11", "跑酷书脊", 900, -1, "parkour", "跑酷书脊：连续跳台抵达高处奖励。"),
        ("ch03_room_12", "汇流大厅", 1300, 0, "field", "汇流大厅：上下两路在中层合流。"),
        ("ch03_room_13", "背门拉杆台", 1400, 1, "lower", "背门拉杆台：拉杆从背面打开回井口的捷径。"),
        ("ch03_room_14", "回归升降井", 1300, 0, "vertical", "回归升降井：攀爬竖井登上高阁索桥。"),
        ("ch03_room_15", "高阁索桥", 1400, -2, "upper", "高阁索桥：全章最高点，俯冲进入终段。"),
        ("ch03_room_16", "契约庭前廊", 1100, 0, "field", "契约庭前廊：Boss 前最后的存档与补给。"),
        ("ch03_room_17", "盐白契约庭", 1850, 0, "boss", "盐白契约庭：与盐白契约判官决战。"),
        ("ch03_room_18", "盐页出口", 1550, 0, "exit", "盐页出口：通往第四章断弦温室。"),
    ], width)

    connections = [{"from": f"ch03_room_{i}", "to": f"ch03_room_{i+1}", "type": "passage"} for i in range(1, 18)]
    connections += [
        {"from": "ch03_room_2", "to": "ch03_room_4", "type": "upper_shortcut"},
        {"from": "ch03_room_3", "to": "ch03_room_4", "type": "lower_return"},
        {"from": "ch03_room_4", "to": "ch03_room_5", "type": "vertical"},
        {"from": "ch03_room_6", "to": "ch03_room_4", "type": "loop"},
        {"from": "ch03_room_9", "to": "ch03_room_8", "type": "loop"},
        {"from": "ch03_room_13", "to": "ch03_room_4", "type": "shortcut",
         "shortcut_id": "ch03_back_to_well", "opens_from": "lever"},
        {"from": "ch03_room_15", "to": "ch03_room_16", "type": "upper_shortcut"},
    ]

    cfg["map_rooms"] = rooms
    cfg["connections"] = connections
    cfg["platforms"] = [p.dict() for p in b.platforms]

    cfg["locked_gates"] = [{
        "id": "ch03_alcove_gate", "rect": [2760, 300, 36, 110], "color": "6f5b9a",
        "material": "rift_seal", "required_ability": "rift_hook",
        "required_ability_name": "裂隙钩索",
    }]

    cfg["parkour_segments"] = [
        {"id": "ch03_well_loop", "room_id": "ch03_room_4",
         "technique": "left shaft climb into upper gallery",
         "platforms": ["well_lshaft_1", "well_lshaft_2", "well_gallery"]},
        {"id": "ch03_stack_shaft", "room_id": "ch03_room_8",
         "technique": "shaft jump, dash gap to upper catwalk",
         "platforms": ["s_sh1_1", "s_sh1_2", "stacks_upper_a", "stacks_upper_b"]},
        {"id": "ch03_return_climb", "room_id": "ch03_room_14",
         "technique": "vertical shaft to high index bridge",
         "platforms": ["return_base", "ret_1", "ret_2", "ret_3", "high_bridge"]},
        {"id": "ch03_preboss_drop", "room_id": "ch03_room_16",
         "technique": "high bridge drop into final approach",
         "platforms": ["high_bridge_drop", "approach_floor", "preboss_floor", "boss_floor"]},
    ]

    save_specs = [
        ("save_well_respite", "阅读井存档点", [1700, 510], False, "井口前的中层存档点。"),
        ("save_hidden_upper_respite", "盐白书库隐藏存档点", [13400, 290], True, "藏在高阁索桥上的稀疏存档点。"),
        ("save_late_runback", "盐白书库Boss前存档点", [14900, 510], False, "Boss 跑图前的后段存档点。"),
    ]
    cfg["save_points"] = [
        {"id": sid, "label": label, "position": pos, "hidden": hidden, "note": note}
        for sid, label, pos, hidden, note in save_specs
    ]

    for inter in cfg["interactives"]:
        if inter.get("kind") == "lever":
            inter["position"] = [10860, 470]
        elif inter.get("kind") == "boss_gate":
            inter["position"] = [16180, 500]
        elif inter.get("kind") in ("chapter_exit", "ending_exit"):
            inter["position"] = [18620, 510]

    cfg["player_start"] = [120, 500]
    cfg["boss_checkpoint"] = [15000, 500]
    if isinstance(cfg.get("boss"), dict):
        cfg["boss"]["position"] = [17050, 500]
        if isinstance(cfg["boss"].get("arena"), list) and len(cfg["boss"]["arena"]) >= 4:
            cfg["boss"]["arena"] = [16250, 360, 1660, 220]

    enemy_platforms = [
        "entry_low_drop", "entry_mid", "entry_balcony", "well_floor", "well_gallery",
        "well_exit_floor", "stacks_lower", "stacks_upper_b", "stacks_lower_b",
        "stacks_exit_floor", "hall_floor", "hall_upper", "high_bridge", "preboss_floor",
    ]
    anchor_enemies(cfg, b, enemy_platforms)

    hazard_spots = [
        ("ch03_hazard_01", "fake_moss_floor", [1320, 600]),
        ("ch03_hazard_02", "bell_gap", [2300, 360]),
        ("ch03_hazard_03", "spore_chest", [3300, 616]),
        ("ch03_hazard_04", "falling_clapper", [5900, 600]),
        ("ch03_hazard_05", "bell_gap", [6700, 368]),
        ("ch03_hazard_06", "falling_clapper", [7600, 600]),
        ("ch03_hazard_07", "spore_chest", [9900, 516]),
        ("ch03_hazard_08", "fake_moss_floor", [11000, 476]),
        ("ch03_hazard_09", "bell_gap", [13100, 276]),
        ("ch03_hazard_10", "spore_chest", [14800, 516]),
    ]
    cfg["hazards"] = [
        {"id": hid, "kind": kind, "rect": [pos[0], pos[1], 110, 24], "damage": 1,
         "message": "多层扩建路线上出现预警陷阱。"}
        for hid, kind, pos in hazard_spots
    ]

    write_config(name, cfg)


def build_all():
    build_ch03()


if __name__ == "__main__":
    build_all()
