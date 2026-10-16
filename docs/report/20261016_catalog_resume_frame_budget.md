# Windows resume writeback: remove redundant startup waits

## Failure and diagnosis

PR #95 `2bf90970` on main `2d60b550` failed the Windows release candidate at [job 116992926589](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38906989271/job/116992926589): the first process created a save, but the resumed process did not produce a new `.bak` before the original 120-frame exit. The matching Linux candidate passed. Both Windows verbose logs contain no ERROR, ObjectDB warning or leaked resource; this is distinct from the older token-lifetime failure already fixed.

The same frozen source in explicit Godot 4.6.1 real software GL reached readiness at 122 frames fresh and 124 on cold resume. When allowed to complete, the resumed process retained the probe and wrote its backup. These source-project diagnostic runs locate readiness headroom, not the exact missed Windows frame or exported-release acceptance. The source had no additional asynchronous resume stage; restored state and actual operation durations affect existing batch boundaries.

## Minimal change and preserved contracts

Only `world_region_loader.gd` changes in production. Three scheduling blocks already present in downstream #96 are backported without its startup-config worker feature:

- Manifest ownership copies remain at most 512 edges per operation, now using up to eight operations under the existing 2ms admission window before yielding.
- Catalog chunks remain at most 64 entries, retaining route-first/first-region-wins order, private staging and per-chunk context/file-stamp validation. The two source dictionaries share a bounded frame batch; the final populated staging still crosses a real cancellation window before publication.
- The outer prepare loop avoids a second empty frame immediately after the async catalog method has already yielded and validated. Catalog jobs remain alone in their batch. Every synchronous prepare batch, including the final one, still yields before build planning.

The 6906-edge manifest previously forced 14 waits; measured after the fix it uses 8/7 on this machine, with the same time budget. Each of six short catalogs previously had two merge waits plus the redundant outer wait; now it has one merge wait and no redundant outer wait. Single operations remain non-preemptible; this is not a hard 2ms guarantee. No timeout, save protocol, startup publication boundary, shutdown contract, release tool, workflow or gameplay setting is relaxed.

## Observed change and acceptance

The same isolated first-start/resume source harness changed from 122/124 ready frames to 115/104. All four observations completed without ERROR/ObjectDB; both resume pairs passed the probe and new-backup challenge after readiness. Build batch counts also vary with timing, so these are observations rather than universal frame guarantees. An initial system-4.6.3 probe was excluded and retained separately; all formal comparison and strict verification use the explicit 4.6.1 binary.

Strict double import and the four affected GL checks preserve the original 180-second suite gates. Catalog's original 71 checks are retained plus 10 checks for caps and deterministic scheduler boundaries. Import, per-suite results, warnings, frozen hashes and original 120-frame Linux release evidence are recorded in [the machine-readable evidence](../../artifacts/modern_catalog_integration/resume_frame_budget_verification.json). New-head Windows and complete remote CI remain mandatory and are not replaced by local source probes or the old #96 green result.

Independent read-only review found no new reproducible P1/P2. A non-blocking boundary remains: exactly exhausting eight chunks can still leave a zero-operation internal yield; the current six region catalogs do not reach it. The deterministic new scheduler probe mocks the catalog callback, while original real-worker fault coverage and actual World observations remain separate evidence.

The default collection remains 107 suites. Original Windows failure and all earlier logs remain historical failures. Full W00b2b, hard frame budgets, natural six-region play, visual continuity and unattributed long-run resource warnings remain OPEN.
