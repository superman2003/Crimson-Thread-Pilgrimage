# PR #291 resupply regression correction (2026-10-26)

Failed CI: https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/40192346801/job/121165830121
Source head reproduced: 332b27894c81613a05d79073b3a19d958d6b8388

The canonical build_catalog.json charges 4 currency and 1 wet_chitin per mine refill. Two requested mine charges therefore cost 8 currency and 2 wet_chitin, leaving 2 from a wallet of 10. The existing regression expected cost 10 and remainder 0. Production quote and purchase code are unchanged.

Correct the two exact numeric expectations and add assertions comparing the purchase's full wallet, charges and cost to the earlier detached quote, plus explicit selected/unselected material quantities. No test is disabled and no acceptance threshold is loosened.

Reproduced the same two failures with Godot 4.6.1 (14d19694e), then the corrected test completed RESUPPLY_PLAN checks=43 failures=0. This is an isolated focused project containing the byte-identical branch build_system.gd, resupply_planner.gd and build_catalog.json plus the regression script. It uses a minimal project.godot without production autoloads or art, so this is not a full World or OpenGL acceptance run. GitHub's full 174-suite native run must validate the new head separately.

Command: Godot_v4.6.1-stable_linux.x86_64 --headless --audio-driver Dummy --path <focused-project>/godot --script res://scripts/resupply_plan_validation.gd
