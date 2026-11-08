# Grounded run presentation

Ordinary grounded running uses a continuous two-bone gait with the existing
character's 16 newly drawn upper-body poses and fixed-size painted leg parts. The 24 PNGs
are fallback/export/ghost cels, not the production rig's animation clock.

The 125-world-pixel cycle is shared with Player's collision-resolved distance
phase and its two footstep contacts. During each 34% stance interval the sole
moves backward by exactly the corresponding body travel. Swing uses a closed
Hermite arc with matching contact velocity. Each thigh/shin remains 32.5 art
pixels long; the pelvis lowers within reach on an incline instead of stretching
a bone. Authored impact/compression/push/flight keys produce a visible 10-art-pixel
weight transfer. The boot rolls from heel to flat support to toe, keeping the
current contact point planted. Both feet clear the ground during flight. The
far leg uses the same shapes with darker shading. The tunic hem,
overlapping joints and painted end-cap cleanup avoid exposed assembly seams.

`provenance.json` records the reused imagegen leg parts. `upper_body_generation.json`
contains the exact built-in imagegen prompt for the 16 new arm/torso/cloth poses.
The upper drawings share one scale and a fixed ribcage-to-pelvis registration.
`upper_registration.json` records their source anchors and pixel hashes.
`source/rig_parts.png.import` enables mipmaps for the minified painted parts.
`build_receipt.json` pins the source and fallback pixel hashes.

Build: `python tools/build_grounded_run.py --engine /path/to/godot` under a
native display or Xvfb. Check the stored pack without rendering:
`python tools/build_expanded_hero_run.py --check`.

`grounded_run_validation.gd` checks bone length, contact and loop continuity,
world-space support on both sides/slopes/scales, and the actual Player's soles
under acceleration, braking and multiple travel speeds. It also checks material
restoration when stopping, attacking, jumping, landing and respawning.
