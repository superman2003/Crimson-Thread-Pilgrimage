# E03 — equipped quiet sole trap triggers

Implemented on `d69e0244dfb8fbe9beba4969422f7accbf1ef594`, which merges exact main `d38072579659ac88ca61082b485454dfd96f8cc6`. This branch has 140 default Godot suites plus four narrative suites (144 total); it does not claim the separately pending movement/capacity integration.

Quiet sole is a real, one-capacity travel accessory unlocked by the existing inventory relic. Holding it alone does nothing. Equipping it scales each environmental trap trigger's authored width and height to 80%. Removal and dormant slots restore 100%. The Player's 34×84 body, enemy attacks, damage, invulnerability, and authored spike pogo surface are unchanged. Each trap owns its own shape. Synchronization runs only when the applied build profile changes, with deferred shape-size changes safe inside physics callbacks; newly built traps use the current profile. Loadout details show current/projected trigger percentages.

## Frozen final validation

`source_before.json.gz` and `source_after.json.gz` cover all 9,103 tracked Godot/tools inputs, including tests, fixture, and assets. Every raw SHA-256 matched after the formal runs and after restoring the reverse mutation. Sources were normalized before this freeze. Each engine subprocess had a 180-second timeout. Native runs used Windows/OpenGL compatibility, Dummy audio and fixed 60 FPS; CPU runs use the regression runner with fixed 60 FPS for quiet sole. `final_native/results.json.gz` records exact commands and outcomes.

- Final CPU: quiet sole (22), spike pogo (14), build system (99), build slots (48), real World build transaction (30), World state, seal system (16), upgrade integration (30): eight suites, zero failures.
- Final native verbose: quiet sole 22/22 and production build UI fixture 37/37, exit zero with zero engine errors and zero warnings in these two recorded runs.
- Same-final native reverse: replace only `_hazard_trigger_multiplier`'s derived result with `1.0`, preserving all other final inputs. Exit one with five expected functional failures and no engine errors. This specifically rejects the old no-op behavior. The production bytes were restored exactly.

The core suite loads the exact earned W03 return-save bytes into a real World, confirms inventory-based legacy unlock and no ownership-only effect, then uses a deliberately positioned component fixture with the production trap factory, Player, input movement and Area collisions. Real right input reaches the original outer edge safely, then continuing input enters the shrunken inner trigger and loses exactly one HP. Stationary equipment changes update real overlap: removing at the outer edge expands the Area and hurts, equipping exits it. Distinct trap sizes, authored pogo geometry, dormant slots, region-style trap rebuilding, loadout preview purity and equipment serialization are checked. This is component positioning, not a new natural traversal claim. The dormant-slot fixture explicitly represents a known but unrepaired bell crest.

## Provenance and retained limitations

`godot/tests/fixtures/quiet_sole_earned_return.json` is byte-identical to `earned_return_seed.json.gz`, copied from the existing earned W03 evidence associated with PR #210. That prior route proves the actual relic pickup; it did not prove this new equipment effect. Its evidence was not changed. The 40 new minor-enemy PNGs matched the read-only combat-presentation-v2 checkout by raw SHA; import parameters matched after line-ending normalization. Only regenerable ctex/md5 cache was copied. `minor_cache_provenance.json.gz` records both raw import hashes.

All failed diagnostics remain archived. Diagnostic01 reached a missing-key script error and its identified process was terminated; runner stdout also hit a Windows GBK print error. Diagnostic02 exposed an invalid dormant-slot fixture. Diagnostic03 exposed the old UI mock missing `build_profile`, the old all-accessories-must-have-charm-event assumption, and a Dummy-renderer screenshot error; these led to the corrected fixtures. Diagnostic04 reflects a temporary test text-decoding mistake; that test was restored from Git and edited explicitly as UTF-8 before diagnostic05 passed.

A prior native precheck had an unclassified ObjectDB exit warning. The same-final reverse reproduced it under verbose logging, identifying twelve Ogg audio/playback instances, while both final positive native runs were clean. This intermittent audio retirement warning is retained and is not claimed fixed or causally attributed to quiet sole. The core suite does not capture images. No hazard-damage or invulnerability behavior was changed to suppress it. The separate damp-knot promise remains future work; it was not remapped to a different accessory.

Archive index entries give uncompressed size/SHA-256 and gzip size/SHA-256. Every gzip member uses mtime 0. Decompress relative to this folder to inspect the original logs and manifests.


## Subsequent runner count correction

The original 6d5ee6bd source registered 144 suites but left the runner contract at 143. The existing Python contract actually failed on this mismatch; the isolated `ci_count_fix` logs preserve that failure and the corrected 31-test run (one executed, thirty platform skips). The expected count is now 144 and explicitly requires quiet_sole_traps. This changes no gameplay, fixture or completion marker; the earlier frozen engine evidence continues to describe its original source, not a rerun of this later static assertion.
