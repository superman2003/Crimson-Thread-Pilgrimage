# Death-to-respawn presentation: finite playback and checkpoint reveal

## Startup overlap repair after the Windows failure

The follow-up keeps the sole JSON reader, source stamps, route/generation leases, authored first-region-wins order and all final cancellation yields. Initial JSON reading overlaps the existing private route-context copy. Each catalog read is taken and validated before the same reader starts only the immediately following catalog; that pending ticket is owned by this construction and overlaps the current merge. Every invalidation/return drains its own pending ticket, never another task's completed work. There is no current-region inventory reuse or #62 metadata functionality in this repair.

The final frozen combination passed strict Godot4.6.1 double import (14.852s), catalog177 (105.252s), startup469 (64.405s), and57 runner/release/workflow unit tests. Original60 startup and50 catalog assertion source lines remain. All475 registered sources were stable and these game checks had no engine ERROR/ObjectDB warning. A malformed local unittest invocation initially omitted tools from PYTHONPATH; its two import errors were retained, and the corrected invocation changed no code.

The actual Linux release builder passed isolated import/export/archive verification and the original headless120-frame first-start/resume/backup-writeback checks (288.490s total builder time). The package accurately declares base e3e7 plus dirty tested sources, rather than claiming to be a future commit build. Windows and full CI must run on the new published head. Source-only smoke also passed120, but a separate lightweight stage-sampling resume observed122 frames; this variability remains explicit. Observed catalog overlap covers five/six wait frames, not an unconditional startup-frame guarantee. Eight-operation, nominal2ms admission,512-edge copy,64-edge merge,120-frame desktop and180s suite gates are unchanged. Overlap counts are already included in wait_frames and must not be added twice; wall_usec retains helper-invocation scope. Full local evidence: `artifacts/death_respawn_presentation/startup_overlap_verification.json`.

## Published-head CI and retained blocker (2026-10-16 14:45 UTC)

PR #99 head `e3e7d0a6c243ce45b9f9aae19aecc084e596d112`, tree `0b2296b73793f85f7e3d2a2ac74cbe240ccf9513`, has terminal results: 12 of 13 workflows and 14 of 15 jobs succeeded. The failing Windows desktop job remains a blocker. GitHub test merge `af1532653c065724cd24bf8e67c0559e2703994c` has the same tree. The full110 runtime, eight GPU checks and exact-head20 motion suites passed, with respectively48,3 and5 unattributed ObjectDB warnings and no engine ERROR. These warnings are not long-term stability acceptance.

The Windows export passed first start but did not finish resumed World publication/writeback inside the original120-frame headless process window; the required `.bak` was absent. Linux passed both checks. All four startup/resume verbose logs have no engine ERROR, ObjectDB or leaked-resource error. Startup had reached UI construction; death-code causality is not established. No gate was extended, no early save was added, and Linux success cannot replace Windows. See `artifacts/death_respawn_presentation/published_e3e7_ci.json` and [the failed Windows job](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38914083535/job/117016953523).

A later11.73-second inspection-view recording clearly shows the original prone pose, terminal hold, fade, real shrine relocation/reveal and restored movement/attack. It uses a fixed inspection camera and hides the HUD only, with scripted framing and lethal damage. It keeps the original four frames and production timing, is silent and has no interpolation or retiming. Actual FPS median23; the reveal has only two captured draws, so smoothness is not accepted. This clearer clip does not erase the earlier low-FPS/HUD-occluded evidence below. See `artifacts/death_respawn_presentation/inspection_capture_verification.json`.

## Current dependency-chain verification

This change is stacked directly on #98 `2a6fc492` (tree `3230fca2`), preserving #95→#96→#97→#98 and the exact 110-suite default set. Only Player, the hit-flash shader and three existing tests differ inside `godot/`; no asset is added or rewritten. The Player/shader hashes are unchanged from the earlier frozen eleven-suite evidence.

The final combination reran actual motion (1128), layered-idle real pixels (212) and World death/respawn (17): all passed the original 180-second strict gates with no engine ERROR or ObjectDB warning. All 231 registered script/shader/scene/data/bus hashes are unchanged across those game checks. Runner29, release-builder23 and integration-workflow5 unit tests passed. Published e3e7 CI is terminal: full110, visual and focused motion pass; Windows resumed-save writeback fails. The precise head and limits are recorded above.

Two strict double-import attempts each passed both engine/error gates. Both subsequent source guards separately caught the editor serializing `default_bus_layout.tres` with a UID/default-field reorder. Both rewrites and failed guards are retained. Only that file was restored from the index, then all231 original hashes were verified before and after the game tests. This does not claim that editor import itself preserved every source byte, and no bus change is submitted. There was no third import/retry loop.

The desktop PR-base allowlist adds the current map-pin dependency and this death branch, with explicit positive/negative tests; push remains main-only. The actual Windows/Linux120-frame first-start/resume/writeback commands and strict resource checks are unchanged, so future stacked #62 also gets the same desktop gates.

See `artifacts/death_respawn_presentation/chain_verification.json` for exact sources, final tests and retained import boundary. The earlier11 suites below remain evidence at their original baseline, not an assertion that all11 were run again on this final tree.

## Scope and compatibility

The initial timer-edge checkpoint used #94 `51ff9e98` (the same tree later merged as main `2d60b550`). Publication is to be stacked on the current upgrade dependency chain; integration and new-head CI evidence will be recorded separately. This batch adds no new bitmap frame and does not mark full animation continuity or the remaining idle artwork defects complete.

The production death clock remains 0.9 seconds. The existing four-frame non-loop death animation now plays once and holds its last frame rather than restarting whenever `is_playing()` becomes false. Its final 0.16 seconds fade using the existing hit-flash shader's separate `presentation_alpha`. The expiry caller returns immediately after `_hard_respawn()`, preventing death from overriding the restored idle on that same tick. The original checkpoint relocation, HP restoration, energy reset, audio and respawn signal remain; Boss-trial's existing listener can subsequently restore energy as before.

The relocated Player reveals for 0.18 seconds. This is presentation only: there is no added invulnerability, input delay or collision exception. Existing control rules resume at the original transition. A second lethal hit, traversal reset or scene handoff clears reveal state; UI lock pauses the visual clock coherently. The layered idle body and cloth use the same material alpha, while other shader users keep the default alpha of one.

## Frozen local verification

Explicit Godot 4.6.1, strict double import and 11 affected real-GL suites passed at the hashes in `artifacts/death_respawn_presentation/verification.json`. The final five changed runtime/test sources were frozen across the checks. The suites are motion continuity (1128), layered idle (212, complete real pixels), World death/cache flush (17), state cleanup (9), hero animation (25), action buffer (32), Boss trial, melee feedback (107), combat, melee recovery and input settings (96). No engine ERROR occurred. Boss trial, combat and melee recovery each retained one unattributed ObjectDB warning; this is not long-term resource-stability acceptance.

Motion cases cover 30/60/120 Hz, both facings, exact and crossed expiry, one-shot completion/last-frame hold, fade/reveal, consecutive deaths, UI pause, handoff resets and normal damage/input during reveal. World checks retain the original five assertions and verify the real shrine signal's exact position before gravity resolves the elevated anchor, recovery to grounded idle and movement/attack. The shader is checked with both facings at alpha zero, half and one using rendered pixels; neutral-background actual Player capture independently found zero-alpha identical to background and half-alpha difference approximately 0.506 of full-alpha. The focused workflow retains all prior 18 suites and adds the existing layered-idle and World-death suites. Original 180-second limits and strict markers/ERROR rejection remain.

Runner (28) and workflow (5) unit tests passed. The new exact layered-idle marker is 212; the old 200 marker is explicitly rejected. This paragraph records the earlier frozen local checkpoint; published-head remote results are recorded above.

## Retained failures and honest evidence boundaries

- The initial timer-edge red/green test produced six expiry failures before the return, then 1012 checks with zero failures after it. Its one ObjectDB warning and source proof remain in `artifacts/action_timer_boundary/verification.json`.
- An initial motion fixture reused a just-pressed action within one engine input frame; it now advances a real input frame between independent scenarios. Product input behavior was not changed to satisfy it.
- A World fixture expected the shrine's elevated anchor Y to remain unchanged after gravity. Exact signal position and subsequent grounded behavior are now checked separately; the original five assertions remain.
- A noncanonical XDG path made the editor's ObjectDB snapshot fail. Canonical paths to the same directories passed strict double import; error rejection was not disabled.
- The expanded 212-check pixel suite initially failed the old exact-200 completion gate despite complete pixels. That failed log remains; the marker and its negative unit case were updated and the suite rerun strictly.

A real ordinary-World recording exercised lethal damage, one respawn signal at the activated shrine, reveal, landing, movement and attack with `passage=false` throughout. Its 18.33-second external recording had 1–16 rendered FPS (median 11) and existing HUD occlusion of part of the prone pose. It is engineering evidence, not accepted visual smoothness or a presentation-quality preview. A capture-only ready wait needed 21.384 seconds after two retained 15-second attempts failed; this is not evidence of passing a 15-second startup gate. The audio recorder produced no usable samples, so the recording is silent.

A separate passage-boundary inspection found the existing `world_passage.step` fatal-cancel path returns the dead Player to the passage entrance before the later shrine respawn. It is not caused by camera motion or a post-damage harness position write, and is not fixed in this batch. The defensive passage cancellation behavior remains an explicit OPEN boundary.

The existing four death frames, seven cloth regions, idle jump contacts (2→4, 6→7, 7→1), breathing, cross-action artwork, full keyframe coverage and human visual acceptance remain OPEN. Generated death artwork is still an unintegrated candidate. Coordinates and pixel alpha checks do not prove visual continuity.
