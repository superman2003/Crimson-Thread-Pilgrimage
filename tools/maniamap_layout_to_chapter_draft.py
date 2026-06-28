from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tmp" / "artifacts" / "maniamap" / "maniamap_big_layout.json"
OUT_DIR = ROOT / "artifacts" / "maniamap"
OUT_JSON = OUT_DIR / "maniamap_chapter_draft.json"


def load_layout() -> dict:
    return json.loads(SOURCE.read_text(encoding="utf-8"))


def source_major(source_id: str) -> int | None:
    match = re.search(r"Uid\((\d+)", source_id)
    return int(match.group(1)) if match else None


def color_region(source_id: str) -> str:
    major = source_major(source_id)
    if major is None:
        return "synthetic"
    if major <= 10:
        return "blue"
    if major <= 18:
        return "green"
    if major <= 26:
        return "purple"
    return "red"


def normalize_rooms(layout: dict) -> list[dict]:
    rooms = list(layout.get("rooms", []))
    min_x = min(room["position"][0] for room in rooms)
    min_y = min(room["position"][1] for room in rooms)
    cell_w = 640
    cell_h = 180
    result: list[dict] = []
    for index, room in enumerate(sorted(rooms, key=lambda item: (item["position"][0], item["position"][1], item["id"]))):
        x, y, z = room["position"]
        w, h = room["templateSize"]
        room_id = f"mm_room_{index:02d}"
        depth = int(round((y - min_y) / 3.5)) - 4
        if "Origin" in room.get("tags", []):
            kind = "gate"
        elif index == len(rooms) - 1:
            kind = "boss"
        elif depth <= -2:
            kind = "upper"
        elif depth >= 2:
            kind = "lower"
        elif h >= 3:
            kind = "vertical"
        else:
            kind = "field"
        result.append(
            {
                "id": room_id,
                "source_id": room["id"],
                "source_major": source_major(room["id"]),
                "color_region": color_region(room["id"]),
                "name": f"ManiaMap Room {index:02d}",
                "grid_position": [x, y, z],
                "rect": [(x - min_x) * cell_w, (y - min_y) * cell_h, max(1, w) * cell_w, max(1, h) * cell_h],
                "depth": depth,
                "kind": kind,
                "template": room.get("templateName", ""),
                "tags": room.get("tags", []),
            }
        )
    if result:
        result[-1]["kind"] = "boss"
        result.append(
            {
                "id": "mm_exit",
                "source_id": "synthetic_exit",
                "source_major": None,
                "color_region": "exit",
                "name": "ManiaMap Exit",
                "grid_position": [0, 0, 0],
                "rect": [result[-1]["rect"][0] + result[-1]["rect"][2], result[-1]["rect"][1], 360, 220],
                "depth": result[-1]["depth"],
                "kind": "exit",
                "template": "synthetic",
                "tags": [],
            }
        )
    return result


def build_connections(layout: dict, rooms: list[dict]) -> list[dict]:
    by_source = {room["source_id"]: room["id"] for room in rooms}
    connections = []
    for door in layout.get("doorConnections", []):
        from_room = by_source.get(door.get("fromRoom", ""))
        to_room = by_source.get(door.get("toRoom", ""))
        if not from_room or not to_room:
            continue
        connections.append(
            {
                "from": from_room,
                "to": to_room,
                "type": "maniamap_door",
                "from_source_id": door.get("fromRoom", ""),
                "to_source_id": door.get("toRoom", ""),
                "from_direction": door.get("fromDoor", {}).get("direction", ""),
                "to_direction": door.get("toDoor", {}).get("direction", ""),
            }
        )
    boss = next((room for room in rooms if room["kind"] == "boss"), None)
    if boss is not None:
        connections.append({"from": boss["id"], "to": "mm_exit", "type": "post_boss_exit"})
    return connections


def main() -> None:
    layout = load_layout()
    rooms = normalize_rooms(layout)
    draft = {
        "source": "mpewsey/ManiaMap BigLayoutSample",
        "seed": layout.get("Seed"),
        "room_count": len(rooms),
        "connection_count": len(layout.get("doorConnections", [])),
        "rooms": rooms,
        "connections": build_connections(layout, rooms),
        "notes": [
            "This is a topology draft only, not a playable Godot platform map.",
            "Use the room rectangles and connections as source material for map_rooms, doors, shortcuts, and route planning.",
            "A second pass must add platform geometry, enemies, save points, boss gate, and validation constraints.",
        ],
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(draft, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"MANIAMAP_CHAPTER_DRAFT_PASS rooms={len(rooms)} connections={len(draft['connections'])} out={OUT_JSON}")


if __name__ == "__main__":
    main()
