# World catalog worker preparation

This increment continues W00b2b after PR #59. The scope is the first construction of the persistent World's cross-region item catalog. Region JSON content reads and parsing move to the loader's existing single configuration reader; foreground preparation owns that reader, and catalog publication remains atomic. Explicit synchronous preparation remains an independent compatibility path and comparison oracle.

The required merge contract is unchanged: visit regions in route-manifest order, allow a region's route inventory catalog to override that region's raw catalog, then preserve the first region's value for duplicate item IDs across regions. Cancellation, a changed loader or route generation, file changes, read failure, and host teardown must discard unpublished catalog staging.

## Scope and validation

The loader intercepts each catalog-region preparation job and reads regions sequentially through its existing `config_read_job`. It retains only inventory entries from the worker result, merges at most 64 keys before yielding, and validates the complete set of region file stamps before swapping the staged catalog into the host. The ordinary synchronous job remains available for explicit compatibility and oracle comparisons. Warm travel reuses the existing complete catalog.

Loader and route generations, cancellation, the original scene tree, and host liveness are checked around asynchronous boundaries. A failed target restores the source catalog reference before rollback. A stale route manifest is refreshed through the same reader before rebuilding the source; if recovery cannot construct a safe region, gameplay remains gated and the existing root retry control reloads the preserved save.

Each region records file stamp, bytes, worker thread status and CPU time, wait frames, merge work, wall time, merge batches, and maximum keys and work per merge step. Catalog jobs occupy their own preparation batches. The legacy preparation work/operation metrics include accumulated merge CPU work; `max_prepare_batch_usec` measures the surrounding synchronous admission batch, not the catalog coroutine's complete wall time or its internal merge steps.

Independent read-only review found and prompted fixes for post-catalog-commit rollback contamination and stale-manifest recovery; no blocking findings remained in the final review. Runtime verification is recorded below after final independent checks.

The new fault-injection suite temporarily changes the real route manifest to exercise file-stamp and malformed-content recovery. Run it through `tools/run_godot_regressions.py`: the runner restores original bytes and nanosecond timestamps in `finally` after normal completion, subprocess failure, or timeout. Run suites sequentially within one checkout.

This increment does not complete W00 or W00b2b, establish a hard per-frame latency bound, or validate natural six-region gameplay. Route inventory catalogs are still deeply copied in the synchronous index job; dictionary `keys()` enumeration, the final metadata-probe loop, and individual entry operations are not preemptible. Other startup metadata reads and the legacy whole-route `cached_data()` copy remain outside this increment.

## Final verification

Godot 4.6.1, software GL: nine distinct related suites passed without engine or script errors: `world_catalog_background` (50 checks), `world_prepare_budget` (174), `world_startup_budget`, `world_preflight_budget` (4,290), `world_host` (539), `save_product` (37), `world_async_loading` (492), `world_config_background` (38), and `world_neighbor_config` (93). The root independently ran the last five suites; implementation-agent logs for the first four were also checked for their exact success markers and error diagnostics. Existing ObjectDB-at-exit warnings remain in some suites.

`npm test`, campaign static audits, two resource-import passes, and patch whitespace checks passed. Runner tests pass 16 cases, including real subprocess exceptions and timeouts that restore temporary fixture-source content and nanosecond timestamps. The catalog suite verifies the synchronous oracle, route override and first-region precedence, worker ownership, warm reuse, 193-entry transfer over four batches, cancellation before and during merge, invalid input, generation and stamp invalidation, host detach/free, post-commit rollback, and enabled recovery controls without overwriting the source save.

[Verification metadata](../../artifacts/world_catalog_worker/verification.json) records frozen source hashes and log checksums. This branch depends on PR #59 (`ee17998`); do not merge before its dependency. The new full 93-suite CI is a separate remote gate.
