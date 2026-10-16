# Startup malformed-overlay convergence repair

Baseline: 8ce445a76393718f37ee87d65db02d7903fb7b7e. Runtime: Godot 4.6.1.

## Confirmed baseline behavior
The exact baseline overlay and copy scripts were placed in a separate minimal project. The probe supplied valid in-memory JSON-shaped data with world_overrides = 42, called step(1, 1) exactly once, printed state, and exited. It reported one GDScript error (`is_empty` called on an int), then `done=false stage=world operations=1`. This confirms that the failing operation does not converge or advance. We did not run an unbounded baseline validation worker or attempt a hung shutdown.

The production reachability is cached_overlay_bundle → startup detached route context → the sole reader validation worker → validator route overlay. The existing worker repeatedly steps until done; its shutdown joins that worker. Hence the observed unchanged stage is a concrete regression risk in this reachable worker chain, rather than evidence from an intentionally hanging process.

## Repair
- Overlay begin accepts a Variant and explicitly fails wrong root types. Every consumed override/append/portal/remove container is guarded before dynamic methods or typed assignments; record-shaped entries are dictionaries, and catalog values are dictionaries.
- Invalid source override entries are rejected even when the destination array has no targets. Failure sets error, done and an empty result, and clears in-progress copy/merge references.
- The validator propagates the overlay error without accepting partially merged private data. Additional guards cover raw region id, enemy kind, and inventory catalog container before their dynamic casts/merge targets.
- Reusing a failed overlay job resets error/cursors/merge state. Empty overlay remains an immediate legacy no-op. Numeric remove_interactives elements retain their existing exact-type/nonmatching semantics.
- The reader is unchanged. The detached-context contract and ticket/shutdown semantics are unchanged. No arbitrary production operation count, time limit, retry, or timeout was added.

## Focused coverage
The existing startup background fixture retains all 61 original assertion call source lines (plus the unchanged `_check` declaration), corresponding to the prior 393 dynamic checks. Added coverage includes:
- A numeric world_overrides single-operation terminal assertion.
- 186 JSON type-shape cases (null, bool, integer, float, string, array or dictionary as appropriate) tested by at most 256 explicit one-operation overlay steps each.
- 34 real background failure tasks covering all consumed field/record types plus raw id, enemy kind and catalog shape. Each verifies failure, no prepared result, original data unchanged, ownership retained until take, and thread/ticket release.
- Accepted-failure discard, valid retry, immediate shutdown, and resource release.
- A valid 4096-key nested world overlay, retaining actual authored bounds/other overlay data, succeeds without an arbitrary step cutoff.
- A full startup malformed-overlay fault reaches retry without publish, preserves save and WorldState, and releases ownership before cleanup.

No real manifest or production save was modified. The fixture uses detached data and its existing isolated test save. Existing 8-operation / 2000-usec admission, 512-edge copy, 180-second runner timeout, and actual release 120-frame gate remain untouched.

## Evidence and limits
- logs/baseline-single-step-isolated.log: single baseline error and unchanged stage, process exit 0.
- logs/focused-isolated/world_startup_config_background.log: real llvmpipe GL, 835 checks pass.
- Other real GL focused suites also passed: world_preflight_budget (4335 checks), world_config_background (38 checks), and world_startup_budget (complete original marker). Runner reports suites=4 failures=0. All four logs have zero ERROR/SCRIPT ERROR and zero ObjectDB warnings.
- The first baseline invocation failed before the probe because the default data/cache directories were unwritable; the first focused runner invocation could not find the already-installed Xvfb on PATH. Those failure logs are retained in baseline-single-step.log and focused-runner.log. Re-running with isolated writable XDG directories and the existing Xvfb directory resolved setup without source or gate changes.
- Python regression-runner unit tests: 29 pass. These use fake engine processes and temp source fixtures, not Godot or the real manifest.
- This is a focused convergence/type-shape repair. It is not a complete overlay schema validator or all-field semantic validation, a general cancellation deadline for arbitrarily large valid data, a full 108-suite/release run, or a natural six-region playthrough.

## Frozen delivery

Local commit: `88071173827e637ce711a4082ec74b7d669391b0`. Exactly the three assigned source/test files are committed; reader, loader, Main, Player, workflow, runner and gate files are unchanged by this repair. No push or merge was performed. The GL window was released immediately after the fourth suite completed.
