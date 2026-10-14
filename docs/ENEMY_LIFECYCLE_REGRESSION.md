# Enemy attack and effect lifecycle hardening

Baseline: main `278aec8a5df8ee94097878d0c80e961a0e4f78a2`. The three changed runtime files were reviewed against that exact revision; the older local snapshot was not used as the runtime baseline. Open PRs #38, #44 and #45 were reviewed for scope separation. No resource proposal, shared controller or audio director changes are included.

## Contract and fixes

- Effects are single-use nodes, not pooled objects. Expiry, collision, successful projectile/reflected hit and explicit cancellation share an immediate terminal state. A queued node cannot deal another hit before deferred deletion.
- An effect created with an owner cannot outlive that owner's removal, death or loss of world residency. Intentionally ownerless effects remain supported. Existing owner cancellation on exit is preserved.
- Player, melee and reflected-enemy hits consume their one-hit latch before calling target code. Reentrant damage callbacks cannot deliver the same hit twice; cancellation during damage prevents a trailing snare. Combo attacks retain their intentional per-beat latch reset.
- Death is idempotent, clears attack state and leaves the enemy target group immediately. Collision monitoring changes are deferred so lethal damage during a physics contact callback does not mutate the flushing physics state. Late contact callbacks and new effect requests are rejected.
- Living-enemy `reset_for_respawn` cancels old hazards/pose tweens, removes transient attack lines, resets boss phase/attack clocks and reconstructs initial cooldowns. It intentionally does not revive a dying or queued node.
- UI-lock pause checks do not depend on AI lure/interference target selection. Contact and melee callbacks honor UI lock; effect warning clocks remain frozen until resume.
- The legacy dummy follows the same dead/queued contact and hit guards, including deferred collision shutdown.

## Reproduce

In a complete checkout:

```sh
python tools/run_godot_regressions.py --suite enemy_lifecycle_regression --suite enemy_effect_lifetime --suite enemy_visibility
```

The shared regression runner now includes `enemy_lifecycle_regression` in the coordinated integration change, so the adversarial suite runs in the default CI collection.

Local verification used Godot **4.6.3** and an isolated minimal project containing the unmodified production dependencies `hand_drawn_assets.gd` and `hit_flash.gdshader`, the three changed runtime scripts, and the three test scripts. No renderer, audio assets or autoload substitutions were made to the scripts being tested. Writable XDG data/cache roots were supplied for this container.

- New adversarial suite: **31 checks passed, zero engine/script errors**, including actual physics contact-triggered death, reentrant damage/death, freed/detached/nonresident owners, repeated cancellation, stale queued effects, respawn, warning pause/resume and minimal combat targets lacking optional UI-lock/death properties.
- Existing lifetime suite: **29 checks passed, zero engine/script errors**.
- Existing visibility/occlusion suite: **36 checks passed, zero engine/script errors**. Independent integration caught an optional-property `bool(null)` regression; null-safe boolean comparisons and five minimal-target assertions address it.
- Running the initial 26-check suite against the exact original runtime files exits 1 and reports 25 failing assertions, including physics-flush errors. Some assertions share cumulative hit counters, so these are not claimed as 25 independent defects.
- Full project import, six-region traversal, graphics/audio asset validation and device/gameplay acceptance were **not run** by this category. The partial source snapshot does not contain the complete assets/addons.

This category requires no new main-level hooks or API changes. No publishing, merge or deployment was performed.

## PR #46 integration correction (2026-10-14)

The original Actions run `38530425686` completed 72 runtime suites with one failure: `world_enemy_residency` expected a single accepted player attack to damage the resident enemy. The other 71 suites, including all three enemy lifecycle/effect/visibility suites, passed.

A diagnostic run with the real enemy AI at its last windup frame reproduced the same assertion failure: the lunge damaged the player, `attack_timer` became zero before the active hit, and enemy HP stayed at 2. This is a valid combat interruption; accepting input alone does not guarantee a hit.

The residency fixture now temporarily enables the existing player debug invulnerability flag only around its first partial-hit measurement and restores the previous value immediately afterward. It still uses the production player attack, hitbox, line of sight, enemy `take_hit`, and residency checks. Later melee kill/reward and lethal player damage/respawn probes run with normal damage. The runner gives this frame-counted suite a fixed 60 FPS clock, and the fixture prints acceptance, observed frames, and before/after HP for diagnosis. No gameplay runtime or failure/error checks were changed by this correction.

Complete-project local verification used Godot **4.6.1** with real Mesa software OpenGL:

- Resource import: two passes, zero errors.
- Corrected residency suite: **56/56**; the same adverse last-windup fixture also passed **56/56** (diagnostic timing code was removed afterward).
- Lifecycle **31/31**, effect lifetime **29/29**, visibility **36/36**; all four targeted suites passed the strict runner with zero engine/script errors.
- `npm test`, `npm run test:campaign`, Python regression-runner tests (**10/10**), and changed-file `git diff --check` passed.

Existing intermittent audio ObjectDB exit warnings remain visible. The full 72-suite run and remaining GPU probes were not rerun locally; the updated PR triggers a new Actions run.
