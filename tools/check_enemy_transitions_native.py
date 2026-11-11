"""Real-GL acceptance of optional movement gestures and unchanged combat."""
from check_hero_motion_v8_native import main
from pathlib import Path

if __name__ == "__main__":
    raise SystemExit(main(
        default_suites=["enemy_motion_transitions", "character_motion_v8",
                        "enemy_ai_behavior", "enemy_combat_continuity", "enemy_hit_feedback"],
        default_output=Path("artifacts/enemy_transitions_v1/native")))
