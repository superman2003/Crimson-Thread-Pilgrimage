# Grounded protagonist run

The former run sequence could change leg proportions, and the later rigid-part
draft kept bone lengths while allowing the support foot to slide. This change
uses one continuous distance-driven gait and a fixed set of painted leg parts.
The actual support sole cancels body travel, with fixed thigh/shin lengths and
a continuous swing into the next contact. The upper body uses 16 new imagegen
drawings matching the original v4 art, with arm swing, shoulder/hip motion and
scarf/cape follow-through. Fixed ribcage registration preserves body volume,
and the painted tunic covers the overlapping leg joints.

Impact, compression, passing, push, toe-off and flight are explicit weight
keys. The pelvis travels through roughly 10 art pixels instead of the former
near-static oscillation. A longer 125-world-pixel stride slows the cycle to match
that weight transfer. Heel/flat/toe contact points are pinned during stance,
and the swing arc gives both feet visible flight clearance.

The production rig follows the full fractional phase rather than switching
between baked poses. Twenty-four cels remain available for ghosts and exports.
Attack, jump, dash, hurt, idle and death keep their authored sequences and
materials. Player and camera share physics interpolation; vertical framing
retains its own single filter, and ordinary room boundaries no longer pin X.

Validation on Godot 4.6.1:

- Two resource import passes complete without engine errors.
- `grounded_run`: fixed-bone geometry, contact and loop seams; both directions,
  multiple scales/slopes; actual Player acceleration, reduced/increased speed,
  stop, attack, jump, landing and respawn. Observed live support slip is below
  the 0.02-world-pixel threshold. It also requires a visible weight-transfer
  range, flight clearance and all 16 upper-body drawings during real running.
- `player_motion_continuity`, `hero_animation`, `player_melee_feedback`,
  `room_camera_stability`, `camera_focus`, `ability_movement` pass.
- Native NVIDIA OpenGL capture at 144 render frames / 60 physics ticks keeps
  the player marker at x=639.5 pixels in both running directions.
- Asset hashes, runner contracts and CI shard partition checks pass.
- Native `player_idle_motion`, `player_layered_idle` and real-time `seal_combat`
  pixel checks pass. Static/UI/contact effects keep their original render clock;
  interpolation is explicitly enabled on Player and its camera. The original
  hit-flash material remains attached through the run/idle/action transitions.

The native gameplay review includes forward movement and reversal:

![Native grounded run review](../reviews/grounded_run/gameplay.gif)

The visual style and motion remain reviewable separately from numerical foot
planting. The rig uses painted overlapping parts; it does not replace the other
authored actions or change gameplay movement speed.
