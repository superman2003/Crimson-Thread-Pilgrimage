"""Drawing blueprints: rooms, badges, connections, points, legends, overviews and the generated docs.

Moved out of build_silksong_scale_map_blueprints.py unchanged; build_silksong_scale_map_blueprints.py imports these names back."""
from __future__ import annotations
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]


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
