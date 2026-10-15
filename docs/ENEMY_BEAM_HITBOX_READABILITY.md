# Enemy beam warning readability

Beam windup used to show a thin centerline, so players could not judge the beam's actual width before it became active. The warning now fills and outlines the beam channel using the configured `radius` and `length`, while retaining the centerline. The active beam keeps its existing halo and core widths and adds a clear outline at the core edges. Both states use the same four channel corners, so the visible beam radius stays consistent from warning to activation.

`radius` describes half the beam's visual width. The player collision check measures the player's center against the beam centerline and accepts a distance below `radius + 19`. The extra 19 pixels represent the player's 17-pixel half-width plus a 2-pixel allowance; they are not an increase to the beam radius. The warning outlines the beam itself, while the larger center-point threshold accounts for the player's body.

This presentation change leaves `_hits_player`, damage, warning duration, active lifetime, and cancellation behavior unchanged. It only changes the beam branch in `enemy_attack_effect.gd`; projectile, wave, pool, and eruption visuals keep their existing behavior.

The existing `enemy_effect_lifetime` regression creates a beam through the real `EnemyActor._effect` path, checks its configured diagonal direction, radius, length, damage, and timing, then checks the four visual channel corners and the adjacent player-center hit threshold. Run it with:

```sh
node tools/run_python_tool.mjs tools/run_godot_regressions.py --suite enemy_effect_lifetime
```
