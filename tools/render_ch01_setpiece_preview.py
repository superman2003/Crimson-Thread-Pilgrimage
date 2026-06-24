from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "data" / "generated" / "demo_ch01_moss_bell_court.generated.json"
OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "godot_generated_preview"
OUT_IMAGE = OUT_DIR / "demo_ch01_setpiece_annotated_preview.png"
OUT_LABELS = OUT_DIR / "demo_ch01_setpiece_labels.json"

SCALE_X = 0.14
SCALE_Y = 1.2
MARGIN_X = 140
MARGIN_Y = 260

PALETTE = {
    "entry_gate": "#2f9d73",
    "overlook_branch": "#4e6ca8",
    "reward_pocket": "#b78b16",
    "shortcut_lock": "#8e54b7",
    "region_hub": "#1a6566",
    "vertical_shaft": "#d47a2a",
    "ability_tutorial": "#d23b3b",
    "loop_gallery": "#5c6f99",
    "preboss_run": "#9f2b2b",
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


FONT_TITLE = load_font(42, True)
FONT_BODY = load_font(20)
FONT_SMALL = load_font(15)
FONT_TAG = load_font(18, True)


def sx(x: float) -> int:
    return MARGIN_X + int(x * SCALE_X)


def sy(y: float) -> int:
    return MARGIN_Y + int(y * SCALE_Y)


def load_config() -> dict[str, Any]:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8-sig"))


def draw_label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: str) -> None:
    x, y = xy
    bbox = draw.textbbox((x, y), text, font=FONT_TAG)
    pad = 5
    rect = (bbox[0] - pad, bbox[1] - pad, bbox[2] + pad, bbox[3] + pad)
    draw.rounded_rectangle(rect, radius=6, fill=fill, outline="#ffffff", width=2)
    draw.text((x, y), text, fill="#ffffff", font=FONT_TAG)


def main() -> None:
    config = load_config()
    world = config["world"]
    width = max(1800, sx(world["width"]) + MARGIN_X)
    height = 2050
    image = Image.new("RGB", (width, height), "#f4efe3")
    draw = ImageDraw.Draw(image)

    draw.text((MARGIN_X, 60), "CH01 Setpiece Annotated Preview", fill="#20242b", font=FONT_TITLE)
    draw.text(
        (MARGIN_X, 116),
        "Numbered rooms are the current hand-authored vertical slice for the generated Godot map.",
        fill="#606775",
        font=FONT_BODY,
    )

    for connection in config.get("connections", []):
        rooms = {room["id"]: room for room in config.get("map_rooms", [])}
        a = rooms.get(connection.get("from"))
        b = rooms.get(connection.get("to"))
        if not a or not b:
            continue
        ax, ay, aw, ah = [float(v) for v in a.get("layout_rect", [0, 0, 0, 0])]
        bx, by, bw, bh = [float(v) for v in b.get("layout_rect", [0, 0, 0, 0])]
        color = "#d55346" if connection.get("progression_tier") == "critical_path" else "#8d8679"
        if connection.get("progression_tier") == "opened_shortcut":
            color = "#2f9d73"
        elif connection.get("progression_tier") == "ability_locked":
            color = "#8e54b7"
        draw.line((sx(ax + aw / 2), sy(ay + ah / 2), sx(bx + bw / 2), sy(by + bh / 2)), fill=color, width=3)

    rooms = config.get("map_rooms", [])
    setpiece_rooms = [room for room in rooms if room.get("setpiece")]
    labels: list[dict[str, Any]] = []
    for room in rooms:
        x, y, w, h = [float(v) for v in room.get("layout_rect", [0, 0, 0, 0])]
        rect = (sx(x), sy(y), sx(x + w), sy(y + h))
        fill = "#e2ddc8"
        outline = "#7a746b"
        width_px = 2
        if room.get("setpiece"):
            fill = "#fff8e8"
            outline = PALETTE.get(str(room.get("archetype", "")), "#20242b")
            width_px = 5
        draw.rounded_rectangle(rect, radius=9, fill=fill, outline=outline, width=width_px)
        draw.text((rect[0] + 5, rect[1] + 5), str(room["id"]), fill="#20242b", font=FONT_SMALL)

    for index, room in enumerate(setpiece_rooms, start=1):
        x, y, w, h = [float(v) for v in room.get("layout_rect", [0, 0, 0, 0])]
        color = PALETTE.get(str(room.get("archetype", "")), "#20242b")
        label = f"{index:02d}"
        draw_label(draw, (sx(x) + 8, sy(y) + 28), label, color)
        labels.append(
            {
                "number": index,
                "room_id": room["id"],
                "setpiece": room["setpiece"],
                "archetype": room.get("archetype", ""),
                "micro_objective": room.get("micro_objective", ""),
                "landmark": room.get("landmark", ""),
            }
        )

    legend_x = MARGIN_X
    legend_y = height - 280
    draw.rounded_rectangle((legend_x, legend_y, width - MARGIN_X, height - 70), radius=14, fill="#fff8e8", outline="#7a746b", width=2)
    draw.text((legend_x + 20, legend_y + 16), "Setpiece Index", fill="#20242b", font=FONT_BODY)
    for i, item in enumerate(labels[:9]):
        draw.text((legend_x + 20, legend_y + 52 + i * 22), f"{item['number']:02d} {item['room_id']} {item['setpiece']}", fill="#20242b", font=FONT_SMALL)
    col_x = legend_x + 720
    for i, item in enumerate(labels[9:]):
        draw.text((col_x, legend_y + 52 + i * 22), f"{item['number']:02d} {item['room_id']} {item['setpiece']}", fill="#20242b", font=FONT_SMALL)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    image.save(OUT_IMAGE)
    OUT_LABELS.write_text(json.dumps({"ok": True, "labels": labels}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "image": str(OUT_IMAGE), "labels": str(OUT_LABELS), "setpiece_count": len(labels)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
