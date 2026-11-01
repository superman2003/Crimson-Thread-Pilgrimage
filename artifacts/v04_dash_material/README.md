# V02/V04 dash ribbon and hook materials

## Real source families and scope

The delivered list contains one Player dash family, not three. This batch connects `FX_H2_dash_ribbon.png` (6 cels), `FX_H2_hook_head.png` (6), `FX_H2_hook_cord.png` (4), and `FX_H2_hook_latch.png` (6). The already connected Boss bride dash is excluded. All are exact delivered PNGs checked against their existing sidecars; both atlas manifests preserve actual sidecar cell rectangles, alpha crops plus a bounded 16px margin, source anchors, scales and atlas paint rectangles. Rebuild tools validate source PNG and sidecar SHA-256. No replacement images were generated.

Dash ribbon is the documented `_spawn_dash_trail` end burst. Actual start/ongoing dash retains original current-pose ghosts. Normal timer expiry draws the ribbon between actual original start/contact-height and reached endpoint, then retracts for the existing .20s; blocked travel below24px produces none. Rejected/unearned casts, damage/death interruption and traversal reset do not synthesize a normal end. Original speed, distance, cooldown, unlock, collision and enemy-contact immunity remain untouched.

Hook head and a maximum16 tiles of cord follow the real grapple endpoints. The original traversal connection line remains even when cosmetic admission fails. Valid acquisition creates an anchor latch; normal reached-anchor recovery creates a return burst. Timeout, blocked/unavailable anchors, damage/death/jump/dash interruption do not invent a reached-anchor event. Combat hook head/cord starts at the original real active-frame hook VFX trigger; its latch requires the existing accepted production-enemy HP-loss confirmation. Original combat fallback remains available when there is no usable traversal anchor; a fallback is not claimed as a grapple or latch.

All new effects share the existing motion budget (one bounded composite for head/cord). Dash retains layer56 and hook59, below danger100/warning110. Low-flash frame3/opacity<=.35 is set before first draw. Pause, facing, budget rejection, expiry, traversal reset and scene exit are checked. Existing gameplay line, character poses and damage flash remain unchanged.

## Final frozen evidence

`cpu_01`, `reverse_01` and `native_01` use identical final input SHA-256 snapshots, checked before and after each engine. LF normalization happened before freezing. All engines use Dummy audio, fixed60fps and a180-second per-process bound. Native gl_compatibility was exclusive; all four processes exited before the token was released. Visual QA inspected both directions, actual accepted hit, reduced initial states and all three World images.

- CPU: dash component77/0, hook component88/0, both actual Worlds0, ability_movement0, player_action_buffer0, player_state_cleanup0; all clean/exit0.
- Native: dash component84/0 (7PNG), hook component96/0 (8PNG), World dash0 (1PNG), natural World hook0 (2PNG); all clean/exit0.18PNG total.
- Exact pre-batch Player bytes from published#214/tree-identical7996 are archived in `pre_dash_player_controller.gd`. The same final fixtures intentionally fail dash7 assertions (59checks) and hook14 assertions (82checks), exit1, without parse/script errors. Six actual dash Input traces are byte-identical forward/reverse: displacement+/-130, original remaining cooldown.45, HP5/energy20. `dash_gameplay_trace_comparison.json` preserves them.
- Runner contracts:31 tests,1pass/30platform skips on Windows. Cumulative default suite contracts148 preserve movement/minor/capacity/hurt and add dash/hook.

Both World scripts restore exact original earned W03 `final_native_02/earned_dash_return_seed.json` bytes (SHA-256 `3de61acca3f0263c2ebe1647ab452533313cc2ace4caa22335513e69071be137`). Initial stock HP5 is not automatically healed to the capacity-version max7; energy100, wallet329, actual dash1/echo_hook1/quiet_sole1/heart2 remain earned. Neither script writes player position, HP, unlocks or damage state, or calls take_damage.

World dash uses real Input at (1710,3752), reaches (1840,3752), shows one normal-end ribbon and retires it, preserving resources. Natural World hook walks/jumps west via the original courtyard steps, uses normal F at `moss_salt_lift_lower`, crosses the salt attic lip with normal jumps, drops past the authored platforms, and casts at the real `moss_viaduct_ring` (4300,2480). Recorded active point is about(4362.514,2550.146), HP5/max7, zero deaths; real head/cord/latch and normal recovery are captured. The route naturally picks up5 existing moss_chitin near the attic, retaining wallet329. Holding hook across3physics ticks ensures the Player's actual input poll observes it. No route repair or geometry change was made. This is automated Input playback, not a human playtest. Positioned component setup, short-timeout fixture and direct damage boundaries are explicitly labeled and do not claim natural acquisition/combat routes.

## Reproduction and retained failures

```powershell
python tools/run_player_dash_art.py --engine $engine --output artifacts/v04_dash_material/new_cpu
python tools/run_player_dash_art.py --engine $engine --output artifacts/v04_dash_material/new_reverse --reverse --suite player_dash_art --suite player_hook_art
python tools/run_player_dash_art.py --engine $engine --output artifacts/v04_dash_material/new_native --native
```

Use fresh output directories. Reserve the shared GL token before native, and wait for CPU processes to finish. The original `.log` bytes are published as `.log.gz` with mtime0, raw lengths and SHA-256 in `log_index.json`; final images/results are indexed by `evidence_index.json`. All failed probes are retained: first hook component expected two budget units although the policy correctly charges one bounded canvas composite; early World candidates tried obsolete hw stair landing heights, a salt lip wall or an intermediate shelf; later one-tick hook attempts missed the real polling boundary. Probe11 establishes the successful natural route. These failures are not declared geometry defects. Isolated atlas import logs and cache provenance are retained.

Delivery status now records these four newly connected sources plus the previously completed#214 hurt/death/respawn sources, leaving six source families pending. This branch is based on the actual published#214 commit ddeb390cf5d97800002fdd031d9783d8b39ccb8c. Prior#214/7996 sources and evidence remain intact. Only this batch's paths are staged; historical restored assets/imports/unrelated UIDs are preserved. All46 final game acceptance items remain OPEN. No main merge or auto-merge is performed.
