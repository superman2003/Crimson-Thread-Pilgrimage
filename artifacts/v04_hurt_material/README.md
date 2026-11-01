# V04 hurt, death and respawn materials

This batch uses the delivered source images and actual sidecar cels: hurt_snap 6, death_unweave 8, respawn_weave 8. `manifest.json` records source PNG/sidecar SHA-256, actual cell/crop rectangles, body anchors, scale and bounded atlas paint rectangles. No replacement art was generated. The rebuild tool checks both PNG and sidecar hashes; rebuilding yields atlas SHA-256 `47bdac08c294a0cffff31c41660b557666df85acd2091401bf551db1f1433cf3`.

Accepted nonlethal HP loss creates a world-anchored snap at the original contact spark anchor. Rejected, guarded, invulnerable and zero-damage requests create none. Lethal damage creates death material only, sampled from the existing 0.9-second death timer. Only `_hard_respawn` creates the weave, sampled from the existing 0.18-second reveal. Ordinary shrine restore and region repositioning do not. The shader, HP/energy reward, knockback, invulnerability, input and death clocks remain unchanged. All three families share the existing state budget and absolute layer 75, below danger 100 and warning 110. Pause, low-flash initial state, traversal reset and scene exit are covered.

## Final evidence

The identical final source bytes in `cpu_03/source.json`, `reverse_02/source.json` and `native_01/source.json` were frozen before and checked after every engine run. Each engine had a 180-second bound, Dummy audio and fixed 60 fps. `native_01` used an exclusive gl_compatibility token; both engine processes reached exit 0 before the token was released.

- CPU: component 99 checks / 0 failures; actual World 0 failures; G02 respawn 4 fixture deaths / 0 failures; state cleanup 0 failures; combat resource cycle 146 checks / 0 failures across 3 crests, actual input.
- Native GL: component 111 checks / 0 failures including 12 saved PNGs; actual World 0 failures and one saved PNG. Visual QA inspected hurt/death/respawn, reduced-flash first states and the World contact. The original damage flash is visible in the World image and retained.
- Reverse: the exact 8f692a pre-hurt Player is archived as `pre_hurt_player_controller_8f692a.gd`. The same final component fixture intentionally fails 15 material assertions (90 checks), exits 1, and has no script/parse failure. The prior 967 version and its earlier reverse evidence are retained separately.
- Portable runner contracts: 31 tests, 1 passed, 30 platform-specific executable tests skipped on Windows. Default contracts retain movement, minor enemy and capacity suites and now include hurt, total 146.

The World proof restores the original earned camp bytes (SHA-256 `91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b`) through a private test save. Existing HP remains 5, new maximum is 6, energy 100, wallet 287, and no dash. Normal move/jump Input reaches the authored bellwheel collision at frame 158, approximately (923.4606,2042.92), takes HP 5 to 4, shows exactly one hurt_snap and naturally retires it. This script never writes player position, HP, abilities or damage state and never calls take_damage. This is automated Input playback, not a human playtest. Component checks intentionally call the real Player's take_damage in a positioned fixture; their death/respawn evidence is a boundary fixture, not a natural World death route.

Reproduce from repository root:

```powershell
python tools/run_player_hurt_art.py --engine $engine --output artifacts/v04_hurt_material/new_cpu
python tools/run_player_hurt_art.py --engine $engine --output artifacts/v04_hurt_material/new_reverse --reverse --suite player_hurt_art
python tools/run_player_hurt_art.py --engine $engine --output artifacts/v04_hurt_material/new_native --native
```

Reserve the shared native GL token before the last command. The CPU suite must finish before native starts. Each output directory must be new.

## Retained failures and scope

`world_probe_01` is the empty direct GUI-shell launch; probes 02 and 03 took a safe route above the enemy and correctly failed to establish injury. Probe 04 found the normal contact. `cpu_01` retains missing newly merged minor atlas cache errors; `cpu_02` retains missing newly merged boss atlas cache errors. `cpu_03` follows the narrowly scoped cache import/copy recorded by provenance JSON, with no source import rewrite. Earlier raw `headless_01` and isolated-import records are preserved. Every raw log is published as gzip with mtime 0; `log_index.json` records original length and SHA-256. Final images and runner results are indexed by `evidence_index.json`.

This is the scoped materials batch. All 46 final game acceptance items remain OPEN. No main merge or auto-merge is performed. Historical restored assets, imports and unrelated UID changes in this worktree are preserved and excluded from the batch.
