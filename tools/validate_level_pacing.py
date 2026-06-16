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
    if width < 6000:
        raise AssertionError(f"world width too small: {width}")
    if fall_y <= 720:
        raise AssertionError(f"fall_y should sit below visible court: {fall_y}")

    enemies = config.get("enemy_spawns", [])
    if len(enemies) > 5:
        raise AssertionError(f"too many normal enemies: {len(enemies)}")

    positions = [(item["id"], float(item["position"][0])) for item in enemies]
    min_spacing = min(abs(a[1] - b[1]) for a, b in combinations(positions, 2))
    if min_spacing < 420:
        raise AssertionError(f"enemy spacing too tight: {min_spacing:.1f}px")

    allowed_types = {"melee", "lunge", "aoe"}
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

    print(f"LEVEL_PACING_PASS width={width} enemies={len(enemies)} min_enemy_spacing={min_spacing:.1f}px melee_only=true fall_y={fall_y}")


if __name__ == "__main__":
    main()
