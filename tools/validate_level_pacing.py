from __future__ import annotations

import json
from itertools import combinations
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "godot" / "data" / "demo_ch01_moss_bell_court.json"
ENEMY_ACTOR = ROOT / "godot" / "scripts" / "enemy_actor.gd"
PROJECTILE_SCRIPT = ROOT / "godot" / "scripts" / "enemy_projectile.gd"


def main() -> None:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    world = config.get("world", {})
    width = int(world.get("width", 0))
    fall_y = int(world.get("fall_y", 0))
    if width < 14000:
        raise AssertionError(f"world width too small: {width}")
    if fall_y <= 720:
        raise AssertionError(f"fall_y should sit below visible court: {fall_y}")

    rooms = config.get("map_rooms", [])
    room_kinds = {str(room.get("kind", "")) for room in rooms}
    room_depths = {int(room.get("depth", 0)) for room in rooms}
    for required_kind in {"lower", "upper", "vertical", "boss", "exit"}:
        if required_kind not in room_kinds:
            raise AssertionError(f"missing room kind: {required_kind}")
    if min(room_depths) >= 0 or max(room_depths) <= 0:
        raise AssertionError(f"map depth does not include upper/lower layers: {sorted(room_depths)}")

    enemies = config.get("enemy_spawns", [])
    if len(enemies) < 12:
        raise AssertionError(f"not enough normal enemies for expanded map: {len(enemies)}")

    positions = [(item["id"], float(item["position"][0]), float(item["position"][1])) for item in enemies]
    min_spacing = min(((a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5 for a, b in combinations(positions, 2))
    if min_spacing < 250:
        raise AssertionError(f"enemy spacing too tight: {min_spacing:.1f}px")

    platforms = config.get("platforms", [])
    platform_ys = [float(item["rect"][1]) for item in platforms]
    if not any(y <= 430 for y in platform_ys):
        raise AssertionError("no upper-route platforms found")
    if not any(y >= 600 for y in platform_ys):
        raise AssertionError("no lower-route platforms found")

    allowed_types = {"melee", "lunge", "aoe", "shockwave", "retreat", "feint"}
    for kind, profile in config.get("ai_profiles", {}).items():
        for attack in profile.get("attacks", []):
            attack_type = attack.get("type")
            if attack_type not in allowed_types:
                raise AssertionError(f"{kind}.{attack.get('id')} uses non-melee attack type: {attack_type}")

    enemy_actor_source = ENEMY_ACTOR.read_text(encoding="utf-8")
    if "PROJECTILE_SCRIPT" in enemy_actor_source or "_spawn_projectile" in enemy_actor_source:
        raise AssertionError("enemy actor still contains projectile support")
    if PROJECTILE_SCRIPT.exists():
        raise AssertionError("enemy projectile script should not exist for melee-only monsters")

    print(
        "LEVEL_PACING_PASS "
        f"width={width} rooms={len(rooms)} enemies={len(enemies)} "
        f"min_enemy_spacing={min_spacing:.1f}px layers={sorted(room_depths)} melee_only=true fall_y={fall_y}"
    )


if __name__ == "__main__":
    main()
