# PR #59 survey-map fixture repair

The full remote run of `ee17998` completed 92 suites with one failure: `survey_map_knowledge` reported two failed assertions out of 17. The failure was reproduced locally under real software GL before editing. The other 91 remote suites passed; later workflow steps after the regression gate were skipped.

PR #59 makes the atlas invalidate configuration, terrain, and contour caches when its observed route generation changes. The survey fixture wrote its synthetic region directly into `ATLAS.configurations` before the atlas acquired a generation lease. The first world-atlas query correctly cleared that unleased fixture, removing its synthetic hazard and ability/action gates. Production invalidation and knowledge rules are correct and remain unchanged.

The repair first seeds old-generation sentinels and calls the production `configuration()` API. Three new assertions verify that the atlas acquired a valid current generation, cleared all three old cache categories, and retained a fixture injected under the current generation. All original 17 knowledge assertions, including both failing world-marker assertions, remain intact. Only the survey validation script changes; the production atlas, runner's 92-suite list, completion marker, and timeout are unchanged.

## Verification

Godot 4.6.1 software GL: `survey_map_knowledge` now passes 20 checks, `world_map` 657, `world_startup_budget` passes, `cartography` 4,055, and `world_route_access` 553. Root independently reran survey/cartography/route access; a separate implementation agent ran survey/map/startup, and a read-only reviewer approved the lifecycle repair. Final logs contain no engine or script errors. Existing ObjectDB-at-exit warnings remain in some suites. `git diff --check` passed.

[Verification metadata](../../artifacts/pr59_survey_fixture_fix/verification.json) records the failed run, exact reproduction checksum, final source hash, and passing log checksums. These five focused suites do not replace a new full remote CI run. The same repair is propagated into dependent PR #60 and PR #61 without including their upgrades in PR #59.
