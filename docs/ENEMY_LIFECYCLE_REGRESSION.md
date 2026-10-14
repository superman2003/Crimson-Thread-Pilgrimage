# Enemy attack and effect lifecycle hardening

Baseline: main `6bf697b69463cab79418f2572ca3fad86bbbf198`. The three changed runtime files were fetched at that exact revision; the older local snapshot was not used as the runtime baseline. Open PRs #38, #44 and #45 were reviewed for scope separation. No resource proposal, shared controller, audio director or CI changes are included.

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

The shared regression runner is not edited in this category. Add `enemy_lifecycle_regression` to its suite list in the coordinated integration change.

Local verification used Godot **4.6.3** and an isolated minimal project containing the unmodified production dependencies `hand_drawn_assets.gd` and `hit_flash.gdshader`, the three changed runtime scripts, and the three test scripts. No renderer, audio assets or autoload substitutions were made to the scripts being tested. Writable XDG data/cache roots were supplied for this container.

- New adversarial suite: **31 checks passed, zero engine/script errors**, including actual physics contact-triggered death, reentrant damage/death, freed/detached/nonresident owners, repeated cancellation, stale queued effects, respawn, warning pause/resume and minimal combat targets lacking optional UI-lock/death properties.
- Existing lifetime suite: **29 checks passed, zero engine/script errors**.
- Existing visibility/occlusion suite: **36 checks passed, zero engine/script errors**. Independent integration caught an optional-property `bool(null)` regression; null-safe boolean comparisons and five minimal-target assertions address it.
- Running the initial 26-check suite against the exact original runtime files exits 1 and reports 25 failing assertions, including physics-flush errors. Some assertions share cumulative hit counters, so these are not claimed as 25 independent defects.
- Full project import, six-region traversal, graphics/audio asset validation and device/gameplay acceptance were **not run** by this category. The partial source snapshot does not contain the complete assets/addons.

This category requires no new main-level hooks or API changes. No publishing, merge or deployment was performed.
