# CI runtime sharding repair · 2026-10-26

The latest integration runs on PRs #256, #275, #278, #283, #287–#290,
#319, #322 and #332 had cancelled runtime jobs. Their runner logs show
cancellation after 60.16–60.33 minutes: the job-wide 60 minute limit
interrupted the serial full suite, even while individual suites completed.
Cancelled runs are incomplete validation, not successful validation.

The runtime job now uses three independent, non-fail-fast matrix shards.
Round-robin selection partitions that branch's complete registered suite
list, including narrative suites. A contract proves exact once-only coverage,
no duplicate/empty partitions, unchanged default full-suite behavior, and
rejection of invalid shard parameters. Explicit --suite cannot be combined
with sharding. Software GL, individual 180 second budgets, strict completion
markers, engine-error rejection, the 60 minute job limit, and every visual
probe are retained. Each shard uploads distinct logs even on failure.

Local checks: shard coverage and original workflow contract tests pass for
every changed branch. Full hosted GL validation must complete on the new
head; it is not replaced by these local scheduling checks.

PRs #288–#290 also contained a real resupply regression hidden inside the
cancelled full run: old tests expected two 5-coin charges after the catalogue
price changed to 4. The earlier #291 correction is applied unchanged, with
exact remaining-wallet, material and stock assertions. Their actual branch
BuildSystem/catalogue pass the headless fixture: 43 checks, zero failures.
