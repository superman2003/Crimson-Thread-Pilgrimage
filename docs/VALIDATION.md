# Upgrade validation

## Commands

```sh
npm test
npm run test:campaign
GODOT=/path/to/Godot_v4.6.1-stable_linux.x86_64 npm run test:godot
GODOT=/path/to/Godot_v4.6.1-stable_linux.x86_64 npm run test:world-neighbor-config -- --software-gl
```

Import Godot resources before the runtime suites (`--headless --path godot --editor --import --quit`). Every suite has its own temporary save directory. The runner fails on a missing script, timeout, nonzero process exit, `SCRIPT ERROR:` or `ERROR:` even when the engine exits with code zero. `--suite NAME` can select one suite, and `--log-dir DIRECTORY` preserves engine output. CI uploads these logs even when a regression fails.

`npm test` checks JavaScript, the six active runtime maps, and negative fixtures for the validation tools. Active maps include the `world_routes.json` platform/terrain overrides and additions. Map checks accept overlapping X ranges for vertically stacked rooms and validate their actual two-dimensional outlines. Player recovery checks use the actual 34 × 84 collision body, its clearance, and supporting landings.

`npm run test:map-quality:all` and `npm run test:generated-maps` also examine the older generated maps. These remain explicit strict checks. The older generated map set currently has 54 recovery markers embedded in platforms; those defects are reported as failures, not hidden by the active-map checks. Generated maps are a separate layout pipeline from the active campaign.

Repeated collision silhouettes are visible review warnings. Different names alone do not prove that rooms feel distinct; the five original first-region rooms identified by the earlier audit now have distinct local geometry and rendered comparisons (see [CH01_ROOM_RECONSTRUCTION.md](CH01_ROOM_RECONSTRUCTION.md)). Several ability workshop groups still share a platform template and require further level-design review.

## Evidence and limits

- Static map checks establish consistent data and valid recovery geometry. They do not establish jump feasibility or complete traversal.
- Runtime route suites that inject scene positions, suppress damage or disable enemies verify the indicated route segment or state transition. Their output is not a damage-enabled campaign completion.
- Enemy visibility validation uses real static-body physics to block sight and damage through a wall, then removes the wall and verifies that damage resumes. It also checks warning Tween cancellation, status expiry, cooldown timing and respawn cleanup.
- The process-runner negative fixtures exercise real subprocess failures, zero-exit script errors, absent scripts, timeouts and signal termination. A killed Python validator must fail the caller.
- `world_neighbor_config` reads all six authored configurations through the loader's shared worker and incrementally validates them before publishing. It covers foreground priority, completed-ticket ownership, changed entrances/file leases, generation/range cancellation, failed-file retry, source/save isolation and teardown. Its frozen source and explicit target descriptors establish those contracts, not natural exploration, FPS or a hard 2 ms frame limit.

## Outstanding product acceptance

T04 still requires a new save, damage enabled, six-region completion using multiple exploration orders and builds, plus sessions with unfamiliar players. Record actual confusion, blocked progression, difficulty changes and repeated travel, then reproduce and fix each issue. Automated acceptance does not replace these sessions.

T03 still requires sustained sessions on the supported hardware: repeated cross-region travel, memory and frame-time sampling, heavy combat effects, audio cleanup and controller input. Current lifetime regressions detect stale effects/Tweens but do not establish a performance budget.

T05 still requires building the final distribution, launching it independently of the editor, checking the available entry points, menus, settings, resources, endings and known issues. CI checks source/runtime regressions; it does not itself certify the release package.
