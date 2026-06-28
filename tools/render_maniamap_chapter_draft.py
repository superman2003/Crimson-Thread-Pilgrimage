from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts" / "maniamap" / "maniamap_chapter_draft.json"
OUT = ROOT / "artifacts" / "maniamap" / "maniamap_chapter_draft.png"


COLORS = {
    "blue": (46, 90, 255, 220),
    "green": (62, 205, 72, 220),
    "purple": (184, 58, 210, 220),
    "red": (255, 48, 48, 230),
    "exit": (80, 235, 235, 230),
    "synthetic": (80, 235, 235, 230),
}


def main() -> None:
    draft = json.loads(SOURCE.read_text(encoding="utf-8"))
    rooms = draft["rooms"]
    min_x = min(room["rect"][0] for room in rooms)
    min_y = min(room["rect"][1] for room in rooms)
    max_x = max(room["rect"][0] + room["rect"][2] for room in rooms)
    max_y = max(room["rect"][1] + room["rect"][3] for room in rooms)
    width, height, padding = 1400, 900, 40
    scale = min((width - padding * 2) / (max_x - min_x), (height - padding * 2) / (max_y - min_y))
    image = Image.new("RGBA", (width, height), (8, 12, 14, 255))
    draw = ImageDraw.Draw(image, "RGBA")

    def tx(value: float) -> int:
        return int(padding + (value - min_x) * scale)

    def ty(value: float) -> int:
        return int(padding + (value - min_y) * scale)

    rooms_by_id = {room["id"]: room for room in rooms}
    for connection in draft["connections"]:
        start = rooms_by_id.get(connection["from"])
        end = rooms_by_id.get(connection["to"])
        if start is None or end is None:
            continue
        ax = start["rect"][0] + start["rect"][2] * 0.5
        ay = start["rect"][1] + start["rect"][3] * 0.5
        bx = end["rect"][0] + end["rect"][2] * 0.5
        by = end["rect"][1] + end["rect"][3] * 0.5
        draw.line((tx(ax), ty(ay), tx(bx), ty(by)), fill=(220, 230, 210, 90), width=2)

    for room in rooms:
        x, y, room_width, room_height = room["rect"]
        rect = (tx(x), ty(y), tx(x + room_width), ty(y + room_height))
        draw.rectangle(rect, fill=COLORS.get(room.get("color_region", ""), (140, 140, 140, 210)), outline=(245, 245, 220, 220), width=2)
        label = room["id"].replace("mm_room_", "R") + " " + room.get("color_region", room["kind"])
        draw.text((rect[0] + 4, rect[1] + 4), label, fill=(255, 255, 240, 255))

    draw.text(
        (24, 12),
        f"ManiaMap draft rooms={len(rooms)} connections={len(draft['connections'])}",
        fill=(246, 226, 142, 255),
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"MANIAMAP_DRAFT_RENDER_PASS out={OUT}")


if __name__ == "__main__":
    main()
