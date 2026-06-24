from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
GENERATED_DIR = ROOT / "godot" / "data" / "generated"
OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "godot_generated_preview"
CONFIGS = sorted(GENERATED_DIR.glob("*.generated.json"))

SCALE_X = 0.14
SCALE_Y = 1.2
MARGIN_X = 140
MARGIN_Y = 260


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


FONT_TITLE = load_font(44, True)
FONT_BODY = load_font(22)
FONT_SMALL = load_font(15)
CONNECTION_COLORS = {
    "critical_path": "#d55346",
    "optional_branch": "#4e6ca8",
    "opened_shortcut": "#2f9d73",
    "ability_locked": "#8e54b7",
}


def sx(x: float) -> int:
    return MARGIN_X + int(x * SCALE_X)


def sy(y: float) -> int:
    return MARGIN_Y + int(y * SCALE_Y)


def draw_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, fill: str, font: ImageFont.ImageFont) -> None:
    draw.text(xy, value, fill=fill, font=font)


def room_center(room: dict[str, Any]) -> tuple[int, int]:
    layout = room.get("layout_rect", [0, 420, 0, 360])
    x, y, w, h = [float(v) for v in layout]
    return sx(x + w * 0.5), sy(y + h * 0.45)


def render(path: Path) -> Path:
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    world = config["world"]
    width = max(1800, sx(world["width"]) + MARGIN_X)
    height = 1900
    img = Image.new("RGB", (width, height), "#f4efe3")
    draw = ImageDraw.Draw(img)
    draw_text(draw, (MARGIN_X, 70), config["name"], "#20242b", FONT_TITLE)
    draw_text(
        draw,
        (MARGIN_X, 130),
        f"{len(config['map_rooms'])}房 / {len(config['platforms'])}平台 / {len(config['enemy_spawns'])}敌人 / {len(config['connections'])}连接",
        "#606775",
        FONT_BODY,
    )

    room_colors = {
        "gate": "#cfe8d8",
        "boss": "#e9aaa0",
        "exit": "#c5deda",
        "upper": "#c8d4ec",
        "lower": "#e8d4a8",
        "field": "#e2ddc8",
    }
    rooms_by_id = {room["id"]: room for room in config["map_rooms"]}
    for connection in config["connections"]:
        a = rooms_by_id.get(connection.get("from"))
        b = rooms_by_id.get(connection.get("to"))
        if not a or not b:
            continue
        color = CONNECTION_COLORS.get(connection.get("progression_tier", ""), "#7a746b")
        width_px = 5 if connection.get("progression_tier") == "critical_path" else 3
        draw.line((*room_center(a), *room_center(b)), fill=color, width=width_px)

    for room in config["map_rooms"]:
        layout = room.get("layout_rect", [0, 420, 0, 360])
        x, y, w, h = layout
        rect = (sx(x), sy(y), sx(x + w), sy(y + h))
        color = room_colors.get(room.get("kind", "field"), "#ddd2bf")
        draw.rounded_rectangle(rect, radius=9, fill=color, outline="#7a746b", width=2)
        draw_text(draw, (rect[0] + 5, rect[1] + 5), room["id"], "#20242b", FONT_SMALL)

    for p in config["platforms"]:
        x, y, w, h = p["rect"]
        draw.rectangle((sx(x), sy(y), sx(x + w), sy(y + h)), fill="#39424d")

    for h in config["hazards"]:
        if "rect" in h:
            x, y, w, hh = h["rect"]
            draw.rectangle((sx(x), sy(y), sx(x + w), sy(y + hh)), fill="#e17732")

    for e in config["enemy_spawns"]:
        x, y = e["position"]
        draw.ellipse((sx(x) - 5, sy(y) - 5, sx(x) + 5, sy(y) + 5), fill="#7a4a32")

    for s in config["save_points"]:
        x, y = s["position"]
        draw.ellipse((sx(x) - 9, sy(y) - 9, sx(x) + 9, sy(y) + 9), fill="#2b8ac6")

    bx, by = config["boss"]["position"]
    draw.ellipse((sx(bx) - 18, sy(by) - 18, sx(bx) + 18, sy(by) + 18), fill="#9f2b2b")
    out_path = OUT_DIR / f"{path.stem}_preview.png"
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(out_path)
    return out_path


def main() -> None:
    outputs = [render(path) for path in CONFIGS]
    if outputs:
        images = [Image.open(path).convert("RGB") for path in outputs]
        thumb_w = 1800
        thumb_h = 420
        sheet = Image.new("RGB", (thumb_w * 2, thumb_h * 3), "#f4efe3")
        for i, img in enumerate(images):
            img.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            x = (i % 2) * thumb_w
            y = (i // 2) * thumb_h
            sheet.paste(img, (x, y))
        sheet_path = OUT_DIR / "generated_six_chapter_preview_contact_sheet.png"
        sheet.save(sheet_path)
    else:
        sheet_path = OUT_DIR / "generated_six_chapter_preview_contact_sheet.png"
    print(json.dumps({"ok": True, "previews": [str(p) for p in outputs], "contact_sheet": str(sheet_path)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
