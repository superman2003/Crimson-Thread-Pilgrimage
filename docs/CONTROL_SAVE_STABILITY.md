# Control and save-lifecycle stability upgrade

This independent change is based on main `3bd62d199662fcd3a248e8d7a849ab00cea6c26a`.
It does not include or replace the separate World preparation/preflight PR stack.

## Player-visible changes

- A completed final region recreates its three ending choices after loading or
  revisiting it. Reconstruction is idempotent and uses the authored boss arena.
- Startup `--save-slot` and `--new-game` options apply once, not again after an
  in-game slot switch or region transition. Starting a new journey requires a
  successful `.previous` backup before the current file can be removed.
- An incompatible saved build is preserved on disk. The player is told that
  autosaving is paused; live session progress can continue between regions.
  Explicit backup recovery or a new journey is required before normal saving.
- Damage that actually lands cancels dash motion so the next physics tick does
  not overwrite knockback. Ignored damage and ordinary dash contact immunity
  retain their existing rules. Full shrine restoration and death respawn clear
  snare; generic relocation does not grant free status cleansing.
- Input capture suppresses global shortcut/volume polling, including its final
  accept/cancel frame. F9 remains reserved for a new journey. Controller bindings
  are independent of a temporary device index, and malformed settings cannot
  erase working bindings or send non-finite values into sliders.

No save schema, item progression, map geometry, balance tables or artwork is
changed. This is not a complete six-region playthrough or release certification.

## Regression coverage

The standard Godot runner now includes `world_resume_regression`,
`player_state_cleanup` and `input_settings_regression`. The first uses real World
scenes; the controller suite deliberately disables presentation while exercising
actual damage/movement/rest logic; the settings suite exercises the actual adapter.

Local validation used Godot 4.6.3, Python 3.12 and Node 24:

- Controller: 9 checks passed. Reverting the fix produces 4 failures, then the
  patched version passes again.
- Settings adapter: 23 checks passed in an isolated project using a system-font
  fixture. This is control/state validation, not Chinese-font or visual QA.
- Save lifecycle: 26 checks passed against exact extracted implementation methods
  and real world/build models. This does not replace the real-scene suite in CI.
- Existing pure-model suites passed: world_state, build_system (72), seal_system
  (14), save_product (23), seal_acquisition (66).
- JavaScript syntax, game-data and static-smoke checks passed. Active map audits
  passed 1,429 geometry and 648 uniqueness checks plus 6 negative fixtures;
  repeated ability-workshop silhouettes remain reported review warnings.
- Campaign, chapter, route, narrative and upgrade data checks passed.
- Runner/import negative fixtures passed 20 tests. The runner rejects non-finite
  timeouts and invalid suite names before launching tests.

The cloud workspace has source/data but not the original binary/LFS assets.
Consequently the aggregate `npm test` stops at the runtime-smoke asset request
(404), and a full local World import/playthrough has **not** passed. Full hydrated
Godot 4.6.1 integration is delegated to the existing GitHub Actions workflow and
must be checked on the exact published commit before merge.

## Import gate and known editor limitation

`tools/run_godot_import.py` records both resource-import passes and fails on
nonzero exit, timeout, `SCRIPT ERROR:` or `ERROR:`, even with exit code zero.
CI explicitly uses `--recovery-mode` for **resource import only**, disabling editor
plugins/tool scripts during that step. All gameplay regression suites still run
normally afterward. Godot 4.6.1 supports this option.

This separation is intentional: earlier green CI logs contained MetroidvaniaSystem
editor-plugin UID errors during import. Those editor-plugin defects are not fixed
or certified here. An isolated real-SVG/intentional-plugin-error experiment verifies
that ordinary import reports the plugin error, recovery import imports the SVG
without running it, and genuine recovery-mode errors still fail the wrapper.
