# World checkpoint candidates and remaining upgrade roadmap

This batch continues PR #64 (`21d9399`). It also reconciles the complete remaining scope: [46 task packages and the 22-batch optimistic / 28–36-batch realistic estimate](../REMAINING_UPGRADE_ROADMAP.md). The estimate includes this batch, groups work by independently verifiable outcomes, is not a mathematical minimum or a promise of a fixed PR count, and excludes additional CI repair batches. Current progress/ledger priorities follow the revised plan; chronological reports retain their original evidence.

## Save transaction

Previously `_save_world` cloned the complete old state for rollback, mutated the published region through `capture_region`, then cloned the complete state again through `capture_global`. Global donor containers could remain aliased with the resulting in-memory checkpoint. A later write failure installed the defensive old copy.

The new combined `prepare_checkpoint` uses private shallow patch tables for the root, region table and current region, validates the complete region/global pair and derived checkpoint coordinates, and makes one final complete defensive copy. It does not mutate or publish the old state. The successful caller owns the detached candidate, including unmodified historical regions and death-cache data. The legacy `capture_region`, `capture_global` and `write` APIs remain available.

`write_candidate` persists a complete borrowed candidate using the existing validation / temporary write and read-back / backup / rename protocol; it does not publish it. Main transfers ownership into `world_state.data` only after persistence succeeds. Capture or write failure retains the old state object and contents. A valid incompatible-save block publishes the complete candidate in memory only, continues to return false, and exposes successful capture through the existing `world_save_capture_ok` contract. Failed capture resets that flag and cannot qualify for blocked-memory travel.

No yield or thread is added to the checkpoint boundary. Callers still use the existing bool to decide their live business rollback. In particular, paid transactions retain their rollback behavior, while earned progression is not automatically removed after storage failure. Death-cache calls which update shared state before `_save_world` retain their original ordering; the save does not rewind to a checkpoint before that business operation.

## Scope and limits

This removes redundant complete-state/region copies from the combined Main checkpoint path and prevents its donor aliasing. It does not make saving incremental or asynchronous. The candidate still has one synchronous complete copy. `build.serialize`, validation, coordinate first read, JSON serialization, existing-file / temporary read-back migration, backup and disk operations retain synchronous costs and may make additional copies. No hard frame-time, average FPS, full W00 or full save-product completion is claimed.

Implementation and independent read-only review use separate subagents; root independently repeats focused runtime checks. New-suite fixtures and existing regressions cover value parity with the old capture path, ownership isolation, failed capture/write, blocked memory state, primary/backup handling, real paid transactions, death-cache ordering, departure rollback and fresh World restart. Positioned or granted test fixtures are not natural economic or six-region playthrough acceptance.

Final strict results, source/log hashes and any rejected first attempts are recorded in `artifacts/world_save_candidate/verification.json` before publication. Full remote CI is a separate exact-head gate.

## Verification history and observations

The first strict new-suite replay exited 1 because its full persisted/live build Dictionary comparison rejected JSON number representations. The final diagnostic records `json_equal=true` and exactly 13 float/int type differences: the two active slots, six skill levels, four tool counts and version. The final check normalizes the complete live build through JSON before comparison; no fields or wallet checks are removed. The original failed log is retained separately and is not counted as a pass.

Final subagent new-suite acceptance is 70 checks and zero SCRIPT ERROR/ERROR, including real public blocked-resupply rejection before mutation. A synthetic six-region/history comparison observed old capture (including its Main rollback copy) at 39,745µs and candidate preparation at 40,370µs in that replay. These are single-run observations without a performance threshold; they do not show a speedup. Validation/build/serialization costs can dominate the copies removed. Root's independent replay records its own observations separately.

Final frozen-version strict acceptance: 13 distinct software-GL suites, all accepted logs with zero SCRIPT ERROR/ERROR. The subagent ran candidate (70), save_product (37), build_transaction_runtime (30) and departure (71); root independently ran candidate (70), world_state, coordinates (865), resume (38), async (492), host (539), narrative (187), death-cache (5), build_slots (48) and passage (62). Both focused runner groups exited 0. ObjectDB exit warnings remain in some logs and are recorded individually; root's candidate replay itself had no such warning. No local full 98-suite acceptance is claimed.

Final npm test (16 runner and 11 import-tool tests), campaign audits, two recovery-mode resource imports and git diff checks passed. The complete 46-ID table was independently checked against the revised priorities, with 22 P0 + 2 P0-continuous + 21 P1 + 1 P2; all IDs appear once in roadmap/current progress/current ledger. Runtime consumers of shared state were also reviewed: live map/HUD/quest/inventory views read live fields, while shared data is used for checkpoint restore and explicit death-cache operations; no dependency on the removed checkpoint donor aliases was found. The full 98-suite remote run remains a separate gate; PR #64 at 21d9399 was still running its 97-suite CI during this publication check.
