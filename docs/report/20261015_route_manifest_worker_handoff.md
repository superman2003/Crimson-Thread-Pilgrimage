# World route manifest worker handoff (PR #59)

This increment closes the cold-start gap left by neighbor route-overlay budgeting. A cold persistent World now reads and parses `world_routes.json` on the loader's existing single config-read worker. The parsed worker result remains private while the existing explicit-stack variant-copy job transfers ownership in 512-edge steps; the loader publishes the cache only after the worker ticket, loader generation, and file timestamp still match. The worker result is transferred by reference into loader-owned staging, then replaced with the completed detached copy before atomic cache publication.

World startup now defers saved-region path resolution until that publication completes. Production World callers in the validator, portal/passage, prefetch, atlas and runtime route accessors use cache-only APIs. The legacy synchronous route APIs remain available for explicit synchronous compatibility and oracle paths. A cache miss or stale timestamp returns no path; the shared loader refreshes it. Background refresh yields to a foreground phase, drops its staging without publication, and prefetch retries after the foreground operation returns to idle. Startup and foreground region construction pin the route generation and fail closed if it changes before publication/commit. The atlas drops route-derived cached geometry when the route generation changes.

A real cold World startup and a cold saved resume to Rain Foundry verify `worker_is_main=false`, zero synchronous manifest parses, correct saved local position and route-overlay parity against the retained synchronous `apply_to` oracle. A controlled runtime fixture invalidates the cache, starts the existing loader's background refresh, takes foreground ownership during handoff, verifies the staging did not publish and the sole worker can serve a foreground config ticket, then returns to idle and verifies refresh succeeds without a synchronous parse.

## Verification

Godot 4.6.1, software GL:

- `world_startup_budget`: PASS, including cold new-game startup, cold saved resume, overlay oracle comparison, controlled background-refresh takeover/retry, and existing startup failure/teardown probes.
- `world_preflight_budget`: PASS.
- `world_config_background`: PASS (38 checks).
- `world_neighbor_config`: PASS (85 checks), including the first-publication case where a pre-seeded desired neighbor lease must survive cache initialization.
- `world_passage`: PASS (52 checks).
- `world_map`: PASS (657 checks, 0 failures).

The clean frozen-source run completed all six suites with 0 failures. Startup, config-background, neighbor-config and map runs emitted the existing ObjectDB-at-exit warning; the runner reported no engine/script errors. This focused run does not replace the full 92-suite CI gate.

Cold World startup observed 1.750 s wall time over 93 frames from after scene attachment; this includes manifest read/parse, staged handoff, and region build. The shared worker reported 4.201 ms CPU for route-manifest read/parse. Handoff copied 5,190 edges over 11 yielded batches; `begin` measured 16 μs and the longest `step(512)` measured 1,342 μs (512 edges). These are observations on this local software-GL environment, not frame-time or hardware guarantees. A single dictionary `keys()` enumeration and other indivisible leaf operations remain non-preemptible; batch/edge limits do not promise a hard upper bound on any frame.

`cached_data()` still returns a whole-manifest deep copy for a legacy synchronous seal-practice caller. This increment guarantees that cold/stale manifest file-content reads and JSON parsing do not fall through to the main thread on the production World path; cache freshness still checks file metadata synchronously. It does not claim every cached query or caller copy is bounded. The full existing 92-suite CI remains the remote validation gate. PR #59 is stacked on PR #58 and must not be merged before its dependency.

## PR review repair (2026-10-15)

Restored the complete 7,024-line `main_level.gd` after terminal-output capture had replaced most of the script. All 382 methods from the dependency branch remain, together with the intended cache-only startup resolution and route access changes.

Passage admission now retains its validated destination config path. If routes expire during traversal, terminal preflight can use that path to acquire the loader's foreground manifest refresh, then validate the destination against the newly published route generation. The physical roundtrip fixture invalidates routes after each admission and checks successful arrival, generation advancement, and zero synchronous manifest parses.

Both stale-route and changed-route-generation prefetch invalidation now enqueue detached entities for the existing bounded retirement process before dropping config leases. A deterministic fixture holds the loader generation fixed and checks both cases with five bodies, at most two retirements on the first poll, and eventual release of every body.

Repair validation on Godot 4.6.1 with software GL: resource import passed both passes; `world_startup_budget`, `world_passage` (58 checks), `world_neighbor_config` (93), `world_preflight_budget` (4,290), `world_config_background` (38), and `world_map` (657) all passed (`suites=6 failures=0`, no engine/script errors). The CI-blocking passage GPU probe also passed (`PASSAGE_PIXELS probes=5 failures=0`), as did `npm test` and the patch whitespace check. Existing ObjectDB-at-exit warnings remain in some suites. These focused checks do not claim the full remote CI gate has passed.
