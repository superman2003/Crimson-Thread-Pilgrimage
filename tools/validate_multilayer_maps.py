from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "godot" / "data"

EXPECTED = {
    "demo_ch01_moss_bell_court.json": (14800, 16),
    "demo_ch02_rain_foundry_canal.json": (20000, 24),
    "demo_ch03_saltwhite_archive.json": (18800, 18),
    "demo_ch04_broken_string_greenhouse.json": (18800, 18),
    "demo_ch05_obsidian_pilgrim_road.json": (18800, 18),
    "demo_ch06_silent_crown_core.json": (18800, 18),
}


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def ranges_are_contiguous(rooms: list[dict], width: int) -> bool:
    cursor = 0
    for room in rooms:
        start, end = room["range"]
        if start != cursor or end <= start:
            return False
        cursor = end
    return cursor == width


def point_in_rect(position: list, rect: list) -> bool:
    if len(position) < 2 or len(rect) < 4:
        return False
    x, y = float(position[0]), float(position[1])
    left, top, width, height = [float(value) for value in rect[:4]]
    return left <= x <= left + width and top <= y <= top + height


def room_for_position(rooms: list[dict], position: list) -> dict | None:
    for room in rooms:
        rect = room.get("layout_rect") or room.get("play_rect")
        if isinstance(rect, list) and point_in_rect(position, rect):
            return room
        for visit_rect in room.get("visit_rects", []):
            if isinstance(visit_rect, list) and point_in_rect(position, visit_rect):
                return room
    if len(position) < 1:
        return None
    x = float(position[0])
    for room in rooms:
        start, end = room["range"]
        if start <= x <= end:
            return room
    return None


def validate_positions(config: dict, file_name: str) -> None:
    rooms = config["map_rooms"]
    positions: list[tuple[str, list]] = [
        ("player_start", config.get("player_start", [])),
        ("boss_checkpoint", config.get("boss_checkpoint", [])),
        ("boss", config.get("boss", {}).get("position", [])),
    ]
    for key in ("enemy_spawns", "save_points", "npcs", "interactives"):
        for item in config.get(key, []):
            positions.append((f"{key}.{item.get('id', '')}", item.get("position", [])))
    for label, position in positions:
        assert_true(isinstance(position, list) and len(position) >= 2, f"{file_name}: {label} missing position")
        assert_true(room_for_position(rooms, position) is not None, f"{file_name}: {label} outside map rooms")


def validate_refs(config: dict, file_name: str) -> None:
    rooms = {room["id"] for room in config["map_rooms"]}
    platforms = {platform["id"] for platform in config["platforms"]}
    for connection in config.get("connections", []):
        assert_true(connection.get("from") in rooms, f"{file_name}: bad connection from {connection}")
        assert_true(connection.get("to") in rooms, f"{file_name}: bad connection to {connection}")
    assert_true(config.get("connections"), f"{file_name}: missing explicit room connections")
    for enemy in config.get("enemy_spawns", []):
        assert_true(enemy.get("platform_id") in platforms, f"{file_name}: enemy platform missing {enemy.get('id')}")
        assert_true(enemy.get("kind") in config.get("ai_profiles", {}), f"{file_name}: enemy AI profile missing {enemy.get('kind')}")
    for segment in config.get("parkour_segments", []):
        for platform_id in segment.get("platforms", []):
            assert_true(platform_id in platforms, f"{file_name}: parkour platform missing {segment.get('id')}->{platform_id}")


def validate_multilayer(config: dict, file_name: str) -> None:
    rooms = config["map_rooms"]
    kinds = {room.get("kind") for room in rooms}
    depths = {int(room.get("depth", 0)) for room in rooms}
    for required in ("upper", "lower", "vertical", "boss", "exit"):
        assert_true(required in kinds, f"{file_name}: missing {required} room")
    assert_true(min(depths) < 0 and max(depths) > 0, f"{file_name}: depth range does not span upper/lower")
    platform_ys = [float(platform["rect"][1]) for platform in config["platforms"] if float(platform["rect"][3]) <= 90]
    assert_true(any(y <= 430 for y in platform_ys), f"{file_name}: no upper playable platforms")
    assert_true(any(y >= 600 for y in platform_ys), f"{file_name}: no lower playable platforms")
    assert_true(any(492 <= y <= 560 for y in platform_ys), f"{file_name}: no middle playable platforms")


def main() -> None:
    total_rooms = 0
    total_platforms = 0
    for file_name, (min_width, min_rooms) in EXPECTED.items():
        config = load(DATA_DIR / file_name)
        width = int(config.get("world", {}).get("width", 0))
        rooms = config.get("map_rooms", [])
        assert_true(width >= min_width, f"{file_name}: width {width} < {min_width}")
        assert_true(len(rooms) >= min_rooms, f"{file_name}: rooms {len(rooms)} < {min_rooms}")
        assert_true(ranges_are_contiguous(rooms, width), f"{file_name}: room ranges are not contiguous")
        assert_true(len(config.get("platforms", [])) >= len(rooms) * 2, f"{file_name}: not enough platforms")
        assert_true(len(config.get("enemy_spawns", [])) >= 12, f"{file_name}: expanded maps need at least 12 enemy spawns")
        validate_multilayer(config, file_name)
        validate_positions(config, file_name)
        validate_refs(config, file_name)
        total_rooms += len(rooms)
        total_platforms += len(config.get("platforms", []))
    print(f"MULTILAYER_MAP_VALIDATION_PASS chapters={len(EXPECTED)} rooms={total_rooms} platforms={total_platforms}")


if __name__ == "__main__":
    main()
