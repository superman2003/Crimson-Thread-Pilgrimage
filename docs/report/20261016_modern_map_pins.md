# U04: modern personal map pins integration result

## Outcome

Local source integration and the focused validation are complete; remote CI is pending for the published head. Final local branch `codex/u04-map-pins-modern-integration` points to `cc6201014dc60c6bafa2fde4da6079c5341826f8`. This worker did not push, open a PR, or merge.

The frozen tree tested at `58483219f95e4d0cefabdedea1c78aedd2b74cfe` has exactly the same game scripts and JSON data as the final local head. The final commit only adds the three Godot-generated, uniqueness-checked pin script UIDs. Parent owns Main hookup, regression runner, workflows and publication documentation.

## Exact scope and provenance

- Original batch: `5cf7303577f0daa77a8de7b312d5e76dc53f4f88`; exact parent `a5dfb8ff8649a7f6c8e9c211374bcb1e12728020`.
- Initial dependency: private checkpoint `3e23b5e785e9a93d695db7c56f39e33f3d9aad4e`; parent synced the current workshop main/private checkpoint combination before runtime. Parent reported final prerequisite PR #97 head `e7a371005ec8743517a6de62f2ea1f9ed4ea379f` differs from the tested prerequisite only in publication evidence/docs, not production scripts/data. This worker did not treat that report as remote CI verification.
- Seven worker-owned files, +692 lines: model 88, runtime 194, validation 402, modern viewport +5, three UID lines.
- Model is byte-identical to the original batch. The runtime differs only by merged modern navigation tooltip. The viewport only adds the original right-click signal and guarded dispatch; all modern keyboard/stick/shoulder/reset/focus/disconnect logic remains intact.
- No alternate save transaction or cyclic Main avoidance preload. Pin updates use the actual Main private checkpoint save and reject blocked operations before changing the pin key.
- All 48 original assertion call-site lines remain verbatim, including hidden-room knowledge, bad records/read-only behavior, cap/duplicates, actual mouse transformations, failed save original pin/checkpoint identity and bytes, live flag/wallet isolation, cross-region/restart and detached/freed/closed controls.

The independent static review found two new fixture mistakes before runtime: initial atlas reads initialize empty journal entries, and the shared navigation helper changes presentation on close/reopen. Both were fixed only in the new validation. The fixture warms views before the exact state snapshot, labels helper sequences by their starting view, records actual mode, then explicitly restores and verifies requested flag/camera/title before independent rate tests and marker projection checks. Review concluded no remaining P0/P1/P2 findings; this is a bounded review, not a product-wide guarantee.

## Actual checks

Engine: Godot `4.6.1.stable.official.14d19694e` at the explicitly requested local path. Runtime renderer: OpenGL 4.5 Mesa 25.0.7, llvmpipe LLVM 19.1.7, TCP Xvfb. Canonical absolute XDG DATA/CONFIG/CACHE/STATE/RUNTIME paths; runtime permission 0700.

1. First cold import hit the unchanged 180-second gate at roughly 76% resource progress. No engine error was found; all game script/data hashes were unchanged. This is retained as a failed attempt in `import-cold-timeout/`.
2. The exact same strict two-pass import command, using only its own newly generated ordinary cache, passed in 25.819 seconds. Neither timeout nor error policy was relaxed; no foreign engine cache was copied. `GODOT_IMPORT passes=2 failures=0`. Recovery mode validates resources, not editor-plugin behavior.
3. Import's `default_bus_layout.tres` automatic changes were saved as a patch and restored byte-for-byte from HEAD before runtime. Only the three owned UID files were committed; unrelated generated UIDs/import files and hydrated third-party noise were not staged.
4. Six strict real-GL suites passed in 102.811 seconds, with zero engine errors and correct markers:
   - map_player_pins: 127 checks
   - cartography: 4,215 checks
   - world_map: 671 checks
   - survey_map_knowledge: 20 checks
   - world_coordinates: 865 checks
   - world_save_candidate: 103 checks
5. A separate same-source capture run passed in 24.509 seconds with 129 checks, including actual region/world screenshot writes and post-capture closed/freed-host checks. Exit 0, no engine error, final completion marker present. V-Sync unsupported warning is retained; no V-Sync capability is claimed.
6. All game scripts, JSON data and runner hashes are equal before/after every successful stage and equal across the three successful stages.

Earlier npm test and campaign checks passed on the pre-workshop-sync baseline; they are not relabeled as final-head npm results. Parent separately reported 23 runner tests on the updated 104-suite union. No full default-suite or remote exact-head CI pass is claimed by this worker.

## Real pixels and input evidence

Both images are actual 1280×720 viewport captures after `RenderingServer.frame_post_draw`, visually opened and reviewed by the worker:

- `capture/region.webp`: SHA-256 `a445a1bb93557c227200fbfad5b02eb65981e9bd667b06718748d4fa19aab662`. 铸雨渠 regional map shows the known room, own ★3, toolbar/type/list/current-position/delete controls and navigation instructions.
- `capture/world.webp`: SHA-256 `87c55d08120ee592c3a2d4ff6a401542127c36c8e07f8fea81086f0ecf0b17a3`. World map shows pins in both known regions, existing titles and the same toolbar/navigation instructions.

The world overview's closely spaced pins 1 and 2 overlap at base zoom. This is the unchanged original no-decluttering behavior; exact projection, matching list IDs and zoom navigation pass. No aesthetic rewrite was added to this batch.

The capture manifest contains 55 input samples with real camera transforms, title/view IDs, pin counts and fixture flags. Six independent samples cover regional and world presentation at 30/60/120 ticks per second: each advances approximately 560 pixels over one simulated second, while checking the requested world flag, camera view index and displayed title. The shared modern navigation checks also exercise shoulder zoom, left-stick deadzone/pan, active/unrelated controller disconnect, Home/Y reset, focus loss, close/reopen and invalid scale defenses.

These are synthetic input dispatch and authored charted-room fixtures with paused actors. They are not physical-controller feel tests or natural exploration. No assets were newly generated or reconstructed; source images were original. The capture manifest contains 127 check records at capture time; the final log reaches 129 after the two later lifecycle checks. Do not mistake the at-capture snapshot for the final check count.

## Final source SHA-256

- map_player_pins.gd: `e6ac8876fdc6b92dd3e150d8e0fd5a3fa9d8b9dbcee7b20a3aa4617561619019`
- map_player_pins_runtime.gd: `ee34cbd69bf8ae16a115e94ce5b4d5e9785e3f5c2cc5d3046dc0d110eee60f15`
- map_player_pins_validation.gd: `845d8a9e320dc6e71a372407621a82b96bd66d79ecde7a2a0176f61a76dcde8d`
- survey_map_view.gd: `f539254d7893eed7c7a33cb64f7e0a2d2cb41821bec7eca97daa00fef6dcc0db`
- Main with parent hookup: `e08cdf09aa03686b833bef2b804c0785e7975405153c896f62cd11f98a08020e`
- WorldState prerequisite: `79ef8213a79e8d0352533b4f619ed2f9f44a4e1f119df86cc139f1d26e893528`

UID values/hashes and their sole matches are in `uid-verification.json`. Full machine evidence is in `verification.json`; exact invocations, source maps, timing and XDG environment in `import-process.json`, `focused-process.json`, `capture-process.json`. Source lineage/assertion preservation is in `static-source-manifest.json`. All 5,156 Godot LFS resources were independently verified against pointer SHA-256 OID and size, with 0 invalid/missing entries, in `resource-materialization.json`.

## Remaining boundaries

Publication evidence now matches prerequisite #97 e7a37100. Remote exact-head CI remains pending. This batch does not finish all U04 map features, W00b2b, departure failure safety, six-region natural gameplay, hardware controller testing, long-term resource stability or asynchronous storage. The GL slot has been explicitly released; no engine remains running for this worker.

## Publication integration and CI coverage

The final prerequisite is #97 `e7a371005ec8743517a6de62f2ea1f9ed4ea379f`, based on main `07ae21d4`. Its final five documentation/evidence files were synchronized after GL; all 415 tracked Godot GDScript/JSON files remain byte-identical to the GL-tested map tree. Final npm test, campaign and 23 runner tests passed. U04 stays partial; this PR's own production delta is the pin model/runtime/validation, modern viewport dispatch and four-line Main hookup.

The existing private-checkpoint workflow retains all six original suites and adds four map suites. Full runtime and all eight original pixel commands use the same independent jobs as #94 to avoid consuming the pixel checks' time inside the full-suite job; neither job's 45-minute budget nor suite/error gates is relaxed. The desktop PR base filter includes bounded `codex/w00-*-modern-integration` dependencies so this stacked PR actually exercises Windows/Linux packaging; push remains main only. Five workflow integrity tests and 22 release tests passed (the #97 base lacks the later #95 verbose-log test, so do not relabel this as 23).

No new art assets, screenshot PNG bytes, gameplay invulnerability or fixture progression grants are shipped. The two local viewport capture hashes and synthetic-input provenance are preserved in `artifacts/modern_map_pins/verification.json` and `input_capture_manifest.json`. Close pin labels at overview zoom still overlap; dynamic obstacles, floors, decluttering and U04's full natural exploration acceptance remain OPEN.
