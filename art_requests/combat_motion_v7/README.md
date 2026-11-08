# Combat motion v7

The user reported that attacks still appear to skip frames. The review found
sparse four-drawing creature phases and mismatched Boss in-betweens which changed
body scale and pose between older drawings. This batch adds independently authored
transition drawings and a versioned runtime layer.

Each job references twelve chronological pairs, including windup-to-release,
release-to-recovery and recovery-to-idle seams. Built-in `image_gen` draws two
new poses for every pair, on a six-column, four-row transparent source sheet.
The prompt and output provenance are retained beside each source PNG.

`tools/build_combat_motion_v7.py` registers and packs complete source figures. It
calibrates height and rig position continuously between the reviewed endpoints;
cropping, uniform scaling and atlas packing are mechanical preparation, not
claims of new hand-drawn poses. It does not blend/morph pixels or duplicate source
frames to inflate counts. Existing source atlases and their generation records
remain byte-exact. The derived `combat_motion_v7*.json/png` layer takes priority
only when present. Twelve-pose phases own their full combat clock instead of
jumping into an unrelated old charge/travel loop.

Preparation:

```
python tools/build_combat_motion_v7.py --prepare
```

Register only completed, receipted deliveries during development:

```
python tools/build_combat_motion_v7.py --available
```

Final reproducibility check:

```
python tools/build_combat_motion_v7.py --check
```

Technical separation, anchoring, source hashes and frame counts are necessary
checks. They do not replace native animation review. A source sheet with clipped
or merged figures must be redelivered rather than hidden by padding or masks.
Rendered before/after review uses `tools/capture_combat_pose_review.py`; it runs
on an invisible Windows desktop with isolated saves, without opening a game
window on the user's active desktop.
