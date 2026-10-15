# World startup region worker preflight

This increment continues W00b2b after PR #60. The scope is the initial World region configuration, which previously reached `_prepare_config_and_route` with an empty prepared configuration and performed a synchronous JSON content read, parse, and route overlay.

The production path uses the loader's existing single configuration reader and the incremental World configuration validator before region construction. New-game default entry, saved-region entry overrides, synchronous compatibility, and non-World demo/Boss startup must preserve their established semantics. The operation must keep the startup loader, route, file-stamp, and host/tree leases through validation and publication, and preserve the source save on failure.

## Verification and limits

The initial region is read and parsed by `config_read_job` after startup has prepared the route manifest and resolved the saved-region path. The existing validator performs its detached copy and route overlay in bounded steps; startup admits at most eight validator operations per batch under the existing 2ms admission rule. Default entry resolution happens after the route overlay; a saved entry override takes precedence. A missing default entry retains `[120, 500]`; a malformed, non-finite, or out-of-bounds default fails validation before construction.

The startup lease records the resolved path, saved-entry flag and value, source-file stamp, loader generation, and route generation. It is checked across worker wait, validation, preparation, construction, final UI handoff, and publication boundaries. Changing a path or entry after validation cannot substitute an unchecked configuration or position. Failures do not publish the initial region or save the partial world; the existing root retry control remains available. Host detach/free/shutdown invalidates the owned task and discards the worker ticket.

The validator's new optional default-entry mode leaves existing explicit travel-entry calls unchanged. `main_level.gd`, its explicit synchronous initializer, and non-World `--demo-config`/Boss trial startup are unchanged. Metrics separately record startup bytes, worker thread/CPU time, wait frames, validator batches, validator work/wall time, and maximum admitted operations and batch work.

Independent read-only review found a path/entry race during asynchronous startup; the implementation now snapshots and compares the complete startup selection. The final review reported no blocking findings. Initial testing also corrected a resume fixture to save its chosen checkpoint through `active_spawn`, preserving the real save semantics and the resume-position assertions.

Runtime verification and frozen hashes are recorded below. This is a startup sub-milestone; it does not complete W00b2b or establish a strict frame-time guarantee. The prepared configuration still has a synchronous deep copy in the existing construction handoff. Coordinate-layout first access, shared startup metadata, catalog indexing/key enumeration, file metadata probes, and other indivisible operations retain synchronous costs. This increment only moves the initial region configuration content read/parse and route-overlay validation onto the worker/budgeted path; it does not make all startup JSON work asynchronous.

## Final verification

Godot 4.6.1 with software GL: eleven distinct related suites passed without engine or script errors. The implementation agent ran `world_startup_config_background` (89 checks), `world_startup_budget`, `world_prepare_budget` (174), and `world_preflight_budget` (4,290). Root independently ran `world_host` (539), `save_product` (37), `world_async_loading` (492), `boss_trial`, `world_config_background` (38), `world_neighbor_config` (93), and then `world_catalog_background` (50) in isolation. Logs were checked against the runner's exact success markers and strict error diagnostics. Existing ObjectDB-at-exit warnings remain in some suites.

`npm test`, campaign static audits, both resource-import passes, 16 runner unit tests, and patch whitespace checks passed. The new startup suite verifies worker execution and zero initial-config content reads through the main-thread host loader; complete prepared-config parity with the synchronous validator; new-game and saved-region selection; fallback and invalid default entries; read/validator faults; mutation of path/entry during wait, validation, actual construction, and final handoff; generation/stamp invalidation; host detach/free/shutdown; retry availability; and source-save isolation.

[Verification metadata](../../artifacts/startup_region_worker/verification.json) records frozen source hashes and log checksums. This branch is based on PR #60 (`ec01763`) and must not merge before its dependency. The new full 94-suite remote CI remains a separate gate.
