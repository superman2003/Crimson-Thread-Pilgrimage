# V04 downstrike, phase and resonance materials

## Source and action contract

Connects only the delivered `FX_H2_downstrike.png` (6 actual sidecar cels, ground), `FX_H2_phase.png` (8, body) and `FX_H2_resonance.png` (8, body). No Boss sources are reused and no replacement art is generated. The bounded 1536x576 atlas and manifest preserve PNG/sidecar SHA-256, each real non-uniform cell, alpha crop plus bounded 16px margin, source anchors, shared family scale and paint rectangles. Downstrike's ground slot is (96,164); phase/resonance use (96,96). The rebuild tool checks PNG and sidecar hashes.

Downstrike material is created only on a real airborne-to-floor edge while the unlocked thorn downstrike action remains live, at the actual floor contact position. Ordinary landing, locked ordinary downslash and interrupted actions do not imply a thorn impact. Existing pogo, attack and landing mechanics remain unchanged.

Phase shell is created after actual phase acceptance, uses entry 1–2, held 3–6 and actual stop exit 7–8. The actual phase flag owns its lifetime; damage/death/UI/reset/exit cancels it without inventing normal completion. The original body shader, phase radius cue, energy payment/drain, gate collision exceptions and original safe-position rollback are preserved.

Resonance ring is created after actual unlocked R acceptance. Its 8 material cels follow the actual attack windup, active and recovery sections (2/4/2), including each crest's original timing. Existing radius 160 cues, damage, payment 20, cooldown 1.4 and animation remain unchanged. The new body art is a cosmetic ring, not a replacement hitbox. Full budget cannot reject the real action or its costs.

Ground art shares motion budget at the original landing layer 34. Body phase/resonance share state budget at 60, below danger 100/warning 110. Facing, pause, low-flash frame 3/opacity<=.35 before first draw, expiry and reset/scene teardown are covered. No movement speed, collision, invulnerability, range, resource, latch, cooldown or action duration was changed.

## Evidence and input versions

- Component CPU: 141 checks/0. Covers all three crests and both directions, real Input acceptance/rejection, phase crossing of a real fixture gate and original release rollback, and real production EnemyActor resonance HP18 inside160 versus HP20 outside.
- Native component: 169 checks/0, including 28 PNGs. Camp World:0 failures with 3 PNGs. Original first-echo World:0 failures with 2 PNGs, retained even though NPC overlap obscures the body material. All three native engines exited cleanly under an exclusive GL token.
- The final normal-Input R World capture walks left away from the NPC before R, improving review visibility. Only that World was rerun: CPU `cpu_03_world_capture` and native `native_02_world_capture`, both clean0. Its 2 new PNGs are the preferred R images. 35 PNGs total were visually inspected.
- Exact pre-batch Player bytes from published #216 are archived. The same final component fixture against old Player intentionally reports 129 checks/33 material failures, exit 1, without parse failure.20 actual Input traces (all crest/direction actions, real phase-gate rollback and actual resonance hits) are byte-identical forward/reverse in `gameplay_trace_comparison.json`.
- CPU movement, spike pogo, cleanup and resource-cycle checks pass cleanly. Portable contract tests: 1 pass/30 Windows skips. Default cumulative contracts 149 preserve movement/minor/capacity/hurt/dash/hook and add ability.

All runs freeze source hashes before execution and verify them after, use Dummy audio/fixed 60 and a 180-second per-engine bound. LF normalization preceded freezing. `cpu_02`, `reverse_02` and `native_01` share the complete old 31-input snapshot. `native_01_inputs.tar.gz` preserves every one of those original raw inputs, including the old R World fixture that was hashed but not executed by the component/camp suites. The final R World pair freezes a new 31-input snapshot. Exactly one input differs: `player_resonance_world_validation.gd` adds normal Input walking off the NPC. The other 30 inputs, including all production code, atlas, component fixture and parameters, are byte-identical. These bundles are not claimed to have identical World fixture bytes. `input_version_comparison.json` records the distinction; `evidence_index.json` records all 31 current published input hashes. The superseded old fixture is also kept as `resonance_occluded_fixture.gd.txt`.

## Natural World proof and corrected acquisition causality

Camp proof restores the original earned camp bytes (SHA-256 `91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b`): stock HP 5 remains below max 6, energy 100/wallet 287 and no unearned dash. Normal walk/jump/down-attack reaches a genuine downstrike landing at about(403.7514,1909.945), then normal held/released phase spends 100 to 88 and retires, preserving HP/wallet.

The independent resonance proof restores only public PR209 Bride victory bytes (SHA-256 `d8e950d6fac3e1be55b4fb7bbb5b85eac09fdfdc45a6d8ed9fbc6410535e443f`): HP 5/max 6, energy 100/wallet 435, heart 1, no dash or resonance. It replays the 18 normal approach steps via the actual C5 cable and physical `world_5_6_out` into the C6 foyer. Only input steering from a prior cable snapshot was referenced; no unpublished intermediate save or production source is used. Arrival still has no resonance.

Important causal correction: `world_routes.json` places the body-enter pickup `upgrade_obtain_crown_resonance` at(3050,660), at the first echo. Normal approach collects it around(3019,700), before F. F then opens the real NPC dialogue; F itself does not grant the ability. The final fixture verifies the real collected_id, inventory and unlock. Earlier logs/fixture labels incorrectly attributed the grant to F; those original logs and exact pre-correction fixture/wrapper are preserved as `resonance_pre_causality_fixture.gd.txt` and `runner_pre_causality.py.txt`, with their original recorded SHA-256. The inference is corrected here rather than erasing the old record.

Normal C5 combat earns 16 currency en route, so the first-echo state has wallet 451. After real pickup and F dialogue, the preferred capture normally walks left to about 2900, then actually presses R: energy 100 to 80, original cooldown and active frame execute, material retires, HP remains5, zero deaths. Neither World script writes player position, HP, abilities, damage state or calls direct take_damage. The original engine's authored physical passage is used normally. This proves the foyer pickup/R segment only, not complete C6 or a human playtest. Positioned component unlock/damage/short fixtures are explicitly separate from natural World claims.

## Reproduction and retained failures

```powershell
python tools/run_player_ability_art.py --engine $engine --output artifacts/v04_ability_material/new_cpu
python tools/run_player_ability_art.py --engine $engine --output artifacts/v04_ability_material/new_reverse --reverse --suite player_ability_art
python tools/run_player_ability_art.py --engine $engine --output artifacts/v04_ability_material/new_native --native
```

Reserve the shared GL token before native and use fresh directories. A single World can be selected with `--suite player_resonance_world`. The original `.log` bytes are published as gzip with mtime0; `log_index.json` records raw lengths/SHA and gzip SHA. Failed probes remain: the initial Bell frame assertion crossed a process boundary, and component resonance cooldown was not reset between explicit fixture setups; an over-strict gate assertion included the touching floor instead of the real gate overlap. They were fixed in the fixture without changing production mechanics. The early linear resonance cel mapping was refined to true windup/active/recovery before final CPU freezing. Older acquisition-label and NPC-occluded runs remain disclosed above.

The source list is now connected 49/pending 3; skill_slash/blade_trace/hit_spark remain for a separate batch. This batch is based on actual published #216 commit 43c5d590e59b2b8e45bcc04ad2588cc5cb404fca and depends on its chain. Main 3f28501f was inspected via API: its#209 integration adds evidence/docs/playback, with no Player/Main/Build/default-suite production changes, so it did not require a production rebase or repetition of old green checks. Historical restored imports/assets/unrelated UID files and all prior batch evidence remain preserved. All 46 final game acceptance items remain OPEN. No main merge or auto-merge.
