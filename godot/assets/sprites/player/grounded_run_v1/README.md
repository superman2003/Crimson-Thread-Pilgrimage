# Grounded run presentation

Ordinary grounded running uses a continuous two-bone gait with the existing
character's painted upper body and fixed-size painted leg parts. The 24 PNGs
are fallback/export/ghost cels, not the production rig's animation clock.

The 95-world-pixel cycle is shared with Player's collision-resolved distance
phase and its two footstep contacts. During each 38% stance interval the sole
moves backward by exactly the corresponding body travel. Swing uses a closed
Hermite arc with matching contact velocity. Each thigh/shin remains 31 art
pixels long; the pelvis lowers within reach on an incline instead of stretching
a bone. The far leg uses the same shapes with darker shading. The tunic hem,
overlapping joints and painted end-cap cleanup avoid exposed assembly seams.

`provenance.json` records the reused imagegen parts, complete original prompt,
source hash and upper-body reference. No new paid generation is required.
`source/rig_parts.png.import` enables mipmaps for the minified painted parts.
`build_receipt.json` pins the source and fallback pixel hashes.

Build: `python tools/build_grounded_run.py --engine /path/to/godot` under a
native display or Xvfb. Check the stored pack without rendering:
`python tools/build_expanded_hero_run.py --check`.

`grounded_run_validation.gd` checks bone length, contact and loop continuity,
world-space support on both sides/slopes/scales, and the actual Player's soles
under acceleration, braking and multiple travel speeds. It also checks material
restoration when stopping, attacking, jumping, landing and respawning.
