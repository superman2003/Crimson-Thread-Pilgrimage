# Minimum layered cloth idle candidate

This runtime package contains exactly two byte-identical imagegen PNGs: one fixed
support and one cloth atlas. Only atlas source cels **1, 3, 2, 4, 5, 6, 7** are
played, at 10 fps (0.7 seconds). Each selected region has a different decoded-RGBA
SHA-256. Cel 0 is excluded. No bitmap was redrawn, warped, resampled, interpolated,
or exported repeatedly to invent additional body frames. `manifest.json` records
source hashes, original source-tool filenames, original canvas sizes, every
selected region, decoded hashes, and per-cell alpha/boundary counts.

The author's and independent ordered-capture review cleared the minimal standalone
cloth loop. **Complete idle expressiveness/breathing and in-product idle ↔ run /
attack visual acceptance remain open.** This helper's automated checks target
registration, timing, masking and restoration contracts, not artistic acceptance.

## Registration and playback

The support keeps the reviewed uniform source-to-design scale 131/436. Cloth uses
0.72 of that source scale. In the v3 idle0 image, the two alpha>128 sole bottom rows
are 281 and 279, averaging the manifest baseline 280. In the new fixed support they
are 934 and 928, averaging 931. Runtime registration therefore uses source root
(631.5271377935312, 931), mapping to v3 (186.223262, 280). The original observed
centroid (631.5271377935312, 929.1671466548516) is retained separately as provenance;
it is not treated as the physics baseline. At production scale 0.66 the average
sole baseline is Player y=0 and the per-sole edge mismatch from v3 idle0 is about
0.0651 game pixels. Both feet remain fixed across all seven cloth cels. This is a
numeric registration statement, not a claim that action silhouettes match.

`player_layered_idle.gd` is an AnimatedSprite2D child. Its full composition mirrors
explicitly with flip_h/flip_v, inherits sprite transform and modulate, and ignores
the old per-frame idle registration offset. The original SpriteFrames, animation,
frame and gameplay state remain untouched. Independent simulation delta advances
the 0.7s loop at get_playing_speed(); the old 0.4s idle wrap does not reset it.
Tree/animation pause and time_scale are respected; returning from another action
starts the first selected cloth cel. There is no crossfade or synthetic motion.

The existing hit-flash shader overwrites input COLOR. While idle, its original
material object is shared by the layers and temporarily removed from the hidden
source sprite so self_modulate.a=0 actually masks the old art. The original
material/self_modulate/use_parent_material restore immediately on animation change
or helper removal. This preserves the shader's existing modulation semantics; it
does **not** repair that shader's COLOR behavior.

## Player integration API

Create the helper once and call `attach(sprite)` after Player assigns its flash
material in `_ready`. Call `sync_pose()` at the end of `_sync_sprite_pose_anchor`
(with an is_instance_valid guard during setup). The helper drives its own process clock, and
also subscribes to animation_changed so run/hurt/death/dash restore immediately.
Malformed required metadata is rejected before the source is changed. A failed
attachment leaves the old source visible. Detached helpers are retired, restore
the source, and cannot hide it again during later pose synchronization. Player owns setup and pose synchronization.

Focused validation: run `res://scripts/player_layered_idle_validation.gd` with
Godot 4.6.1. The renderer-independent checks cover source bytes and genuine regions,
registration, mirroring, timing, original-resource invariance, state restoration,
pause/time_scale and removal. Real-GL pixel checks cover source masking, material
sharing/nonzero flash, alpha and exit restoration. A headless run explicitly marks
pixel verification skipped and is not a replacement for real-GL verification.
The strict marker requires a reported OpenGL adapter/API, the compatibility
renderer, and all masking/flash/restoration pixel comparisons to have passed.
Real Player lifecycle probes also detach/free the helper and continue pose sync.
