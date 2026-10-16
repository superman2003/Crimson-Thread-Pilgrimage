# Initial-region read overlap without relaxing startup gates

## Observed failure and shared scope

The Windows packaged check for #100 head `97958ae15902a02d8e9c46cafcd8b8c6d588c71b`
failed its unchanged 120-frame first-start gate in
[run 38944226155, job 117119155333](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38944226155/job/117119155333).
The exit snapshot reported `stage=finish`, build 300/300, prepare 30/30 and
commit 23/30. No initial region snapshot/save was published; the runner
correctly stopped before resume. The player log has no ERROR/warning or
native crash. This is distinct from the earlier audio-mixer crash.

The initial configuration worker took 462,582 microseconds and waited 24
frames. Loader, reader, validator and first-region JSON blobs are identical
across #97–#100; that wait precedes atlas construction. #100's build used 58
batches versus 57 in the observed #99 successful package, so atlas work can
contribute later cost, but does not explain the earlier JSON wait. The same
#100 Linux head passed with two read-wait frames and 58 build batches.
The historical worker metric is aggregate; it does not establish whether
open, read, parse or scheduling uniquely caused the long wait.

## Bounded change

The sole existing JSON reader starts the initial region read after the route
manifest has been validated, while its existing bounded private-copy steps
continue. The speculative result remains private. Admission still requires
the same host, tree, loader generation, resolved path, entry settings,
manifest stamp and accepted route generation. Normal validation and region
publication remain in their original order.

An invalidated owner discards the ticket. Failed speculative launch falls
back to normal admission. Cancellation, host teardown, route/path/entry
changes and shutdown retain their existing fail-closed behavior. No second
reader thread, partial route publication or early save is introduced.
Three scalar diagnostics separate future open/read/parse durations; they do
not retrospectively identify the cause of the old aggregate measurement.

The original 120-frame packaged first-start/resume/backup gate, 180-second
suite deadlines and 8-operation/2-ms admission budgets are unchanged. The
remaining seven finish operations are retained: map construction/refresh,
dialogue references, settings references, HUD completion, cartography and
the new-journey dialogue.

## Verification

Prepared on the latest upgrade-chain tip `97958ae1`, local source commit
`aa125a4ccb5a1a0bc882551a54cd045a9f5d4361`. Test-only follow-up
`97015b6a86b09c13f0e0dd4ab085d4149a118d55` leaves both production files
byte-identical and explicitly awaits an already-ready, unconsumed read
before replacing its old host.

- Deterministic 24-frame reader availability: overlap receives the result at
  frame 24 after manifest take, while the serial control takes 32; the eight
  frames saved exactly match existing manifest-copy yields. Resume and
  rejected-speculation fallback are covered without wall-clock thresholds.
- Original focused suites pass under their unchanged 180-second limits:
  startup configuration 1,053 checks (932 original plus 121), configuration
  background 38, and startup budget. The 98 original source `_check` lines
  remain; existing context-copy cancellation cases are retained.
- The first local invocation lacked ignored import sidecars in the new
  worktree and failed dependency loading. That invalid setup log is retained;
  after restoring the sidecars, the 57-check narrow contract and the three
  complete focused suites passed. It is not counted as an initial clean pass.
- Independent source review found no substantiated production defect. Its
  already-ready host-replacement coverage gap was closed in `97015b6`; the
  expanded narrow contract passes 58 checks. The unchanged production
  three-suite results are retained rather than repeated or relabeled as a
  new full 1,054-check run.

- One actual Linux package of `aa125a4` passes the unchanged 120-frame fresh
  start, resume, writeback and backup checks. Import/export/first-start/resume
  logs contain zero ERROR, warning or ObjectDB entries; each player exits
  with one published snapshot and commit 30/30. Both production files are
  byte-identical in `97015b6`. Manifest-read overlap is seven frames; initial
  JSON reads measure 12.853 / 8.045 ms in this local sample.
  Package SHA256: `98c2a9cc9282b763bb9ec79e50a31f5de849ac1f37f204ea34b40dc3e9132370`.

New published heads still require Windows and complete CI verification.
Old green heads are not substitute evidence. A successful deterministic overlap test is
not a guarantee on arbitrarily slow machines. Existing broader ObjectDB
warnings, target-hardware performance and natural full-campaign acceptance
remain open; no retry-until-green or reduced success marker is used.
