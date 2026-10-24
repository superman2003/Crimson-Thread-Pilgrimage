# E03 — original damp-knot travel reward

This branch starts at published N02 head `7a29ffc244e2299c72d3b33975b6cf363718c191`, retaining all quiet-sole/N02/capacity/movement work. Production implementation is `f781b29b`; the final capture-only test correction is `92199dee6b5b1ee43a44fc268bbaa8d798334d01`. No production Player, trap, damage, invulnerability or pogo code changed in this batch. Only the existing catalog reward is connected to the existing build modifier and exclusivity mechanism, with a distinct icon.

## Original promise and exact sources

`charm_audit.json.gz` enumerates every `inventory.catalog` entry whose original category is `Charms` across all demo chapters. There are exactly two: quiet_sole/静靴 was already mapped; damp_knot/防潮线结 was the only unmapped entry. Its unchanged authored description is “锈泵修女编的防潮线结，陷阱触发判定略微缩小。” Its original sources are `col_damp_knot`, ch02 `wheel_interior`, position (5710,4290), waterwheel interior behind a dash gate; and rain-smith Liu's original nonconsuming worker_badge wish (`item_worker_badge_returned`, reward `damp_knot`). No shop or new gameplay promise was invented from campaign dialogue.

Damp keeps its original name and item ID. Actual inventory possession unlocks a separate one-capacity travel accessory. Only equipped and active damp scales environmental trap trigger width/height to 80%; ownership alone does nothing. All three crests' travel slots accept it. Both damp and quiet sole use `trap_trigger_reduction`, so equipping both active entries is rejected atomically with both original names. Both production UI details explicitly explain their mutual exclusion; a preview/saved plan cannot quietly stack them. Existing quiet-only equipment and plans remain valid. Damage after a hit, the Player 34×84 body and original spike pogo geometry stay unchanged.

## Final checks and visual review

`source_before.json.gz` and `source_after.json.gz` cover 9,125 tracked Godot/tools/.gitattributes inputs. Every raw SHA-256 matched around the final runs and after restoring the mutant catalog. Sources were normalized before freezing. Each engine process had an explicit 180-second timeout.

- CPU: legacy_travel_rewards 36/36, quiet sole 22/22, spike pogo 14/14, build system 100 checks, build slots 48, wish atomic 34: six suites passed, no engine errors or warnings.
- Native Windows OpenGL compatibility, Dummy audio, fixed 60 FPS, verbose: 38/38 including a real production `_toggle_build` visibility gate and screenshot; exit zero, no engine errors or warnings. The original name, icon and 20% description are visually readable in `final_native/damp_build_detail.png`.
- Same-final native no-effect reverse: clear only damp's modifier map, keeping its own ID, real unlock/equipment, group, UI, quiet sole and all other final code intact. Five functional assertions fail (plan profile, trap sizes, outer-edge safety, inner entry and reactivated rebuilt trap), exit one, no engine errors or warnings. Final catalog bytes were restored exactly.
- Explicit audio ownership capture, cache release and bounded drain completed with pending zero in both final native runs. This reports this fixture's complete cleanup, not a claim to have fixed the separately investigated quiet-validator exit warning.
- Runner completion contract passes: 31 tests, 30 POSIX subprocess cases explicitly skipped on Windows. Cumulative suite registration is 144 default plus four narrative, 148 total; prior suites are retained.

The new suite loads the exact inherited W03 earned seed in a real World. Its actual worker_badge supplies an explicitly positioned NPC fixture using the unchanged authored Liu quest through production UI `_topic`. This earns the original damp item and writes it through N02's real transaction. It is a component acquisition, not a natural traversal claim. No existing naturally earned damp save was used or inferred from backpack quantities.

The suite then creates a clearly labelled migration fixture: it retains that actually awarded inventory but removes the new Build unlock to represent the pre-mapping schema. A second real World reads the production-valid disk file and derives damp's unlock from inventory. Equipped damp and both quiet/damp plans are persisted to another real World checkpoint, read back through production WorldState, then restored through the Build model. Pre-damp quiet-only serialized equipment (without the new unlock) also restores. Native output preserves both actual checkpoint files; these are component/migration fixtures, not claimed natural route saves.

The subsequent positioned floor fixture uses the production Player, real right input, production hazard factory and real Area collision. It explicitly checks damp itself is active and quiet inactive. Original outer edge is safe; continued movement into the inner trigger takes exactly one authored damage. Stationary unequip/re-equip changes actual overlaps; dormant expansion, returning crest and trap rebuilding restore/synchronize shapes. Distinct trap resources and original pogo geometry are verified. The known-but-unrepaired bell crest used for dormancy is explicitly a component fixture.

## Retained failures and source scope

Baseline01 is a test parse error. Baseline02 cleanly exposes seven missing catalog/unlock/plan/group behaviors; after its failed damp equip, quiet was still equipped, so its later physics pass is not claimed as a damp negative. The same-final modifier reverse provides the isolated physics negative instead.

The first frozen CPU/native pass used `f781b29b`: text assertions were correct, but manual review found its PNG only showed the World HUD because the build overlay closed on the next frame. That image and all its original evidence are retained under `hidden_panel_*`; they are not offered as UI display proof. A capture-only correction uses production `_toggle_build`, selects damp and checks `is_visible_in_tree`. The corrected visible screenshot was manually reviewed. Final six CPU suites and positive/reverse native logs use the new `92199dee` frozen input manifest.

The small original-style vector icon was imported in an isolated minimal Godot project at the identical resource path, then only its generated import/cache files were copied into this checkout. The exact command, raw SVG/import/cache hashes and import output are archived; the main project was not mass-reimported.

`index.json` records every archived raw/compressed length and SHA-256; gzip members all have mtime zero. The positive native PNG is also committed directly for review. Earlier PR210/213/215 evidence remains unchanged, and this branch does not claim those pending branches have merged into main.
