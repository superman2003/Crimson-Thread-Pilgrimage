from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "silksong_scale"
INDEX_PATH = OUT_DIR / "map_blueprint_index.json"


PALETTE = {
    "bg": "#f4efe3",
    "card": "#fffaf0",
    "ink": "#20242b",
    "muted": "#5f6774",
    "line": "#333842",
    "main": "#d23b3b",
    "platform": "#53606f",
    "hazard": "#de6f31",
    "enemy": "#7c4a32",
    "reward": "#b78b16",
    "npc": "#477a48",
    "save": "#2b8ac6",
    "boss": "#9f2b2b",
    "ability": "#8e54b7",
    "shortcut": "#2f9d73",
    "door": "#1a6566",
}


PLACEMENT_COLORS = {
    "save": PALETTE["save"],
    "npc": PALETTE["npc"],
    "reward": PALETTE["reward"],
    "miniboss": PALETTE["hazard"],
    "ability": PALETTE["ability"],
    "boss": PALETTE["boss"],
    "exit": PALETTE["door"],
}


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


FONT_TITLE = load_font(46, True)
FONT_H2 = load_font(26, True)
FONT_BODY = load_font(20)
FONT_SMALL = load_font(16)
FONT_TINY = load_font(13)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def rect_for_micro(card_x: int, card_y: int, card_w: int, card_h: int) -> tuple[int, int, int, int]:
    return (card_x + 48, card_y + 110, card_x + card_w - 48, card_y + card_h - 86)


def make_micro_layout(room: dict[str, Any], placements: list[dict[str, Any]], all_rooms: dict[str, dict[str, Any]]) -> dict[str, Any]:
    idx = int(room["index"])
    lane = room.get("lane", "main")
    role = room.get("role", "side_branch")
    intensity = int(room.get("intensity", 1))
    exits = room.get("exits", [])

    doors = []
    for target in exits[:6]:
        target_room = all_rooms.get(target)
        if not target_room:
            continue
        delta = int(target_room["index"]) - idx
        if delta > 0:
            side = "right"
        elif delta < 0:
            side = "left"
        elif target_room.get("lane") == "upper":
            side = "top"
        else:
            side = "bottom"
        doors.append({"side": side, "to": target, "kind": "main" if abs(delta) <= 4 else "shortcut"})

    if not doors:
        doors = [{"side": "left", "to": "上一房", "kind": "main"}, {"side": "right", "to": "下一房", "kind": "main"}]

    platforms = [{"id": "floor", "x": 0.08, "y": 0.82, "w": 0.84, "kind": "floor"}]
    if lane == "upper":
        platforms.extend(
            [
                {"id": "upper_step_a", "x": 0.12, "y": 0.52, "w": 0.24, "kind": "ledge"},
                {"id": "upper_step_b", "x": 0.52, "y": 0.38, "w": 0.28, "kind": "ledge"},
            ]
        )
    elif lane == "lower":
        platforms.extend(
            [
                {"id": "lower_island_a", "x": 0.18, "y": 0.66, "w": 0.22, "kind": "breakable"},
                {"id": "lower_island_b", "x": 0.58, "y": 0.62, "w": 0.22, "kind": "ledge"},
            ]
        )
    else:
        platforms.extend(
            [
                {"id": "main_mid_a", "x": 0.18, "y": 0.58, "w": 0.25, "kind": "ledge"},
                {"id": "main_mid_b", "x": 0.56, "y": 0.50, "w": 0.25, "kind": "ledge"},
            ]
        )

    if idx % 5 == 0 or role == "hub":
        platforms.append({"id": "vertical_spine", "x": 0.48, "y": 0.22, "w": 0.08, "kind": "shaft"})
    if role == "boss":
        platforms = [
            {"id": "boss_floor", "x": 0.08, "y": 0.82, "w": 0.84, "kind": "boss_floor"},
            {"id": "boss_left", "x": 0.14, "y": 0.56, "w": 0.18, "kind": "phase_platform"},
            {"id": "boss_right", "x": 0.68, "y": 0.56, "w": 0.18, "kind": "phase_platform"},
            {"id": "boss_upper", "x": 0.39, "y": 0.34, "w": 0.22, "kind": "phase_platform"},
        ]

    hazards = []
    if idx % 3 == 0 or intensity >= 3:
        hazards.append({"kind": "spikes", "x": 0.28, "y": 0.86, "w": 0.18, "label": "刺/酸池"})
    if idx % 4 == 0:
        hazards.append({"kind": "saw", "x": 0.70, "y": 0.70, "w": 0.12, "label": "移动机关"})
    if role == "boss":
        hazards.extend(
            [
                {"kind": "danger_zone", "x": 0.20, "y": 0.72, "w": 0.20, "label": "阶段1危险区"},
                {"kind": "danger_zone", "x": 0.62, "y": 0.72, "w": 0.20, "label": "阶段2危险区"},
            ]
        )

    enemies = []
    enemy_count = 0 if role in {"start"} else min(4, max(1, intensity + (idx % 2)))
    for n in range(enemy_count):
        enemies.append({"kind": "patrol", "x": 0.24 + n * 0.16, "y": 0.76 - (n % 2) * 0.18, "label": f"E{n + 1}"})

    pickups = []
    for p in placements:
        pickups.append({"kind": p["kind"], "x": 0.18 + (len(pickups) % 4) * 0.2, "y": 0.30 + (len(pickups) // 4) * 0.18, "label": p["label"], "note": p["note"]})
    if not pickups and role != "boss":
        pickups.append({"kind": "lore", "x": 0.76, "y": 0.30, "label": "L", "note": "环境叙事/小货币"})

    return {
        "room_id": room["id"],
        "doors": doors,
        "platforms": platforms,
        "hazards": hazards,
        "enemies": enemies,
        "pickups": pickups,
        "design_note": f"{room['cluster']} / {role} / 强度{intensity}：先保证门位和平台，再细化敌人与奖励。",
    }


def draw_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, fill: str, font: ImageFont.ImageFont, anchor: str | None = None) -> None:
    draw.text(xy, value, fill=fill, font=font, anchor=anchor)


def draw_room_card(
    draw: ImageDraw.ImageDraw,
    room: dict[str, Any],
    placements: list[dict[str, Any]],
    x: int,
    y: int,
    w: int,
    h: int,
) -> None:
    role = room.get("role", "side_branch")
    outline = PALETTE["boss"] if role == "boss" else PALETTE["main"] if role == "main_route" else "#4b5664"
    draw.rounded_rectangle((x + 8, y + 10, x + w + 8, y + h + 10), radius=16, fill="#c8bda9")
    draw.rounded_rectangle((x, y, x + w, y + h), radius=16, fill=PALETTE["card"], outline=outline, width=4)
    draw_text(draw, (x + 24, y + 18), f"{room['id']}  {room['name']}", PALETTE["ink"], FONT_H2)
    draw_text(draw, (x + 24, y + 54), f"{room['cluster']} / {role} / 强度{room.get('intensity', 1)}", PALETTE["muted"], FONT_SMALL)

    inner = rect_for_micro(x, y, w, h)
    ix1, iy1, ix2, iy2 = inner
    draw.rounded_rectangle(inner, radius=8, fill="#f7f2e8", outline="#6d717a", width=3)
    layout = room["micro_layout"]

    for platform in layout["platforms"]:
        px = ix1 + int((ix2 - ix1) * platform["x"])
        py = iy1 + int((iy2 - iy1) * platform["y"])
        pw = int((ix2 - ix1) * platform["w"])
        color = PALETTE["platform"]
        if platform["kind"] in {"breakable", "phase_platform"}:
            color = PALETTE["ability"]
        if platform["kind"] in {"boss_floor", "floor"}:
            color = PALETTE["line"]
        if platform["kind"] == "shaft":
            draw.rectangle((px, iy1 + 28, px + max(12, pw), iy2 - 40), fill="#c6ceda", outline=PALETTE["platform"], width=2)
            draw_text(draw, (px + 8, iy1 + 34), "竖井", PALETTE["muted"], FONT_TINY)
            continue
        draw.rounded_rectangle((px, py, px + pw, py + 14), radius=5, fill=color)
        draw_text(draw, (px, py + 18), platform["kind"], PALETTE["muted"], FONT_TINY)

    for hazard in layout["hazards"]:
        hx = ix1 + int((ix2 - ix1) * hazard["x"])
        hy = iy1 + int((iy2 - iy1) * hazard["y"])
        hw = int((ix2 - ix1) * hazard["w"])
        if hazard["kind"] in {"spikes", "danger_zone"}:
            points = []
            step = max(12, hw // 6)
            for i in range(0, hw, step):
                points.extend([(hx + i, hy + 18), (hx + i + step // 2, hy - 10), (hx + i + step, hy + 18)])
            draw.line(points, fill=PALETTE["hazard"], width=4)
        else:
            draw.ellipse((hx, hy, hx + 42, hy + 42), outline=PALETTE["hazard"], width=5)
        draw_text(draw, (hx, hy + 30), hazard["label"], PALETTE["hazard"], FONT_TINY)

    for enemy in layout["enemies"]:
        ex = ix1 + int((ix2 - ix1) * enemy["x"])
        ey = iy1 + int((iy2 - iy1) * enemy["y"])
        draw.ellipse((ex - 16, ey - 16, ex + 16, ey + 16), fill=PALETTE["enemy"], outline=PALETTE["ink"], width=2)
        draw_text(draw, (ex, ey - 9), enemy["label"], "#ffffff", FONT_TINY, anchor="ma")

    for pickup in layout["pickups"]:
        px = ix1 + int((ix2 - ix1) * pickup["x"])
        py = iy1 + int((iy2 - iy1) * pickup["y"])
        color = PLACEMENT_COLORS.get(pickup["kind"], PALETTE["reward"])
        draw.ellipse((px - 18, py - 18, px + 18, py + 18), fill=color, outline=PALETTE["ink"], width=2)
        draw_text(draw, (px, py - 10), pickup["label"], "#ffffff", FONT_TINY, anchor="ma")

    for door in layout["doors"][:6]:
        side = door["side"]
        color = PALETTE["shortcut"] if door["kind"] == "shortcut" else PALETTE["door"]
        if side == "left":
            dx, dy = ix1, (iy1 + iy2) // 2
            rect = (dx - 10, dy - 34, dx + 10, dy + 34)
            label_xy = (dx + 18, dy - 10)
        elif side == "right":
            dx, dy = ix2, (iy1 + iy2) // 2
            rect = (dx - 10, dy - 34, dx + 10, dy + 34)
            label_xy = (dx - 118, dy - 10)
        elif side == "top":
            dx, dy = (ix1 + ix2) // 2, iy1
            rect = (dx - 42, dy - 10, dx + 42, dy + 10)
            label_xy = (dx - 42, dy + 22)
        else:
            dx, dy = (ix1 + ix2) // 2, iy2
            rect = (dx - 42, dy - 10, dx + 42, dy + 10)
            label_xy = (dx - 42, dy - 34)
        draw.rectangle(rect, fill=color)
        draw_text(draw, label_xy, str(door["to"])[:10], color, FONT_TINY)

    note = room["micro_layout"]["design_note"]
    if len(note) > 50:
        note = note[:50]
    draw_text(draw, (x + 24, y + h - 44), note, PALETTE["muted"], FONT_TINY)
    if placements:
        labels = " ".join(f"{p['label']}:{p['note'][:8]}" for p in placements[:4])
        draw_text(draw, (x + 24, y + h - 24), labels, PALETTE["muted"], FONT_TINY)


def render_detail_sheet(bp: dict[str, Any], path: Path) -> None:
    rooms = bp["rooms"]
    cols = 8
    card_w = 1400
    card_h = 660
    gap = 38
    margin_x = 170
    header_h = 310
    rows = math.ceil(len(rooms) / cols)
    width = margin_x * 2 + cols * card_w + (cols - 1) * gap
    height = header_h + rows * card_h + (rows - 1) * gap + 170
    img = Image.new("RGB", (width, height), PALETTE["bg"])
    draw = ImageDraw.Draw(img)
    draw_text(draw, (margin_x, 70), f"{bp['title']} 房间内部细节图册", PALETTE["ink"], FONT_TITLE)
    draw_text(draw, (margin_x, 132), f"{bp['target_scale']['rooms']}房 / 每卡含门位、平台、危险区、敌人、奖励/NPC/存档/Boss点位", PALETTE["muted"], FONT_BODY)
    draw_text(draw, (margin_x, 178), "用途：先按总拓扑排区域，再按本图册逐房间在 Godot/Tiled/绘图软件里搭灰盒。", PALETTE["muted"], FONT_BODY)

    legend_x = width - 1880
    legend_y = 48
    draw.rounded_rectangle((legend_x, legend_y, legend_x + 1680, legend_y + 190), radius=16, fill="#fffaf0", outline="#64615a", width=3)
    legend = [
        ("门", PALETTE["door"]),
        ("捷径门", PALETTE["shortcut"]),
        ("平台", PALETTE["platform"]),
        ("危险", PALETTE["hazard"]),
        ("敌人", PALETTE["enemy"]),
        ("奖励/NPC/存档", PALETTE["reward"]),
        ("Boss/能力", PALETTE["boss"]),
    ]
    for i, (label, color) in enumerate(legend):
        lx = legend_x + 28 + (i % 4) * 390
        ly = legend_y + 34 + (i // 4) * 74
        draw.rectangle((lx, ly, lx + 46, ly + 22), fill=color)
        draw_text(draw, (lx + 62, ly - 4), label, PALETTE["ink"], FONT_SMALL)

    placements_by_room: dict[str, list[dict[str, Any]]] = {}
    for placement in bp.get("placements", []):
        placements_by_room.setdefault(placement["room"], []).append(placement)

    for i, room in enumerate(rooms):
        row = i // cols
        col = i % cols
        x = margin_x + col * (card_w + gap)
        y = header_h + row * (card_h + gap)
        draw_room_card(draw, room, placements_by_room.get(room["id"], []), x, y, card_w, card_h)

    draw_text(draw, (margin_x, height - 76), "注：内部图册是灰盒复绘指南；平台、陷阱和敌人位置可按手感微调，但门位、奖励、Boss前存档应保持。", PALETTE["muted"], FONT_BODY)
    img.save(path)


def main() -> None:
    index = read_json(INDEX_PATH)
    detail_sheets: dict[str, str] = {}
    for chapter_id, item in sorted(index["chapters"].items()):
        bp_path = Path(item["json"])
        bp = read_json(bp_path)
        room_lookup = {room["id"]: room for room in bp["rooms"]}
        placements_by_room: dict[str, list[dict[str, Any]]] = {}
        for placement in bp.get("placements", []):
            placements_by_room.setdefault(placement["room"], []).append(placement)
        for room in bp["rooms"]:
            room["micro_layout"] = make_micro_layout(room, placements_by_room.get(room["id"], []), room_lookup)
        write_json(bp_path, bp)
        sheet_path = OUT_DIR / f"{bp['id']}_{bp['slug']}_room_detail_sheet.png"
        render_detail_sheet(bp, sheet_path)
        detail_sheets[chapter_id] = str(sheet_path)
        index["chapters"][chapter_id]["detail_sheet_png"] = str(sheet_path)
    index["detail_sheets"] = detail_sheets
    write_json(INDEX_PATH, index)
    print(json.dumps({"ok": True, "detail_sheets": detail_sheets}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
