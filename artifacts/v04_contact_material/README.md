# V04 final contact material batch

This batch connects the last three supplied sources: FX_H2_skill_slash, FX_H2_blade_trace and FX_H2_hit_spark. The delivery list now records 52/52 runtime-connected sources. This is an art subitem only; V02/V04 and the 46 final acceptance items remain OPEN. Base is published PR219 a0439603e837bf51aa17e446ea8a8ee86793b47a; PR219 and its dependencies must precede this PR.

## Runtime boundaries

- Skill slash replaces the old secondary accent only for actual accepted cleave/crosscut and Bell basic attack_2. The four other actual skill Inputs retain their respective legacy presentation, with no generic slash.
- Blade trace keeps the actual measured root/tip, AnimatedSprite transform, signed sweep, thresholds and min(0.10, active_seconds) lifetime. Only its draw material changes. static_invariants.json records hashes of exactly identical old/new blade_points and BladeTrace process/accumulate bodies.
- Enemy accepted take_hit allocates a cosmetic invocation serial before any rejection/reentrant callback. Damage, HP acceptance and all return branches remain unchanged. Its single receiver-owned HitSpark now uses the source cells, preserving receiver transform, visibility, process inheritance and 0.16 lifetime. Player melee refines only the still-live same receiver+same invocation visual; it changes anchor/direction, never age/size/damage. Unknown/rejected/dropped tokens create no fallback. Independent hits, recursive calls and same-frame targets remain separate.
- Receiver-only take_hit boundaries retain their own spark without a Player callback. Receiverless actual spike pogo keeps Player ContactNick. Accepted fatal hits retain feedback. Guard/zero/dying/nonresident rejection produces none.
- Contact80/action60/state60 stay below danger100/warning110. Existing 12 contact/8 action/24 secondary pools are unchanged. Pool exhaustion discards only decoration. Low-flash starts at a subdued static source cel. Scene exit/reset/accepted attacker damage clean owned accents; receiver feedback remains owned by that receiver.

## Source provenance

The atlas contains 18 actual nonuniform sidecar cels (six per family), cropped from the supplied PNGs after exact source SHA verification. build_player_contact_art.py and manifest.json preserve source/sidecar hash and crop/anchor contracts. No substitute images are generated. Source restorations and unrelated import deltas are not part of this commit.

## Evidence and scope

- cpu_02: component 171/0; natural World 0; existing melee feedback112/0, spike pogo and combat resource cycle clean.
- reverse_01: SAME final component fixture with archived old Player+Melee+Enemy primitive implementation. 28 material-specific assertions fail, no parse/script errors. All 29 gameplay parameter traces are byte-identical to cpu_02 and native_01 (trace_comparison.json).
- native_01: component190/0 including 19 captures, natural World0 with3 captures, enemy effect lifetime46/0. All three clean exit0. All22 actual native PNGs inspected; original enemy hit-flash shader is deliberately visible in accepted-hit frames.
- native_01 budget: retained failure of old secondary fixture's two-piece-dash assumption. Native budget own44 checks passed except forwarded two stale secondary assertions. Published 6c800bc4738a98eb4400479f6f79f3b174b172b1 replaces that assumption with explicit atomic two-piece batch and full-pool single-node dash checks. Its exact fixture blob is adopted, source recorded in published_fixture_provenance.json; no budget numbers changed. native_budget_02: secondary52/0, combat44/0, clean exit0.
- The first native bundle has its COMPLETE original29 hashed inputs in native_01_inputs.tar.gz. cpu_02/reverse_01/native_01 use identical source.json. The later budget bundle freezes35 inputs: the runner now additionally enumerates six regression fixtures and the published secondary fixture is used. Only the runner differs among the earlier29 paths; production inputs are identical. Earlier runs are not represented as using the later runner/secondary fixture.
- Python default completion contract:31 tests,1 passed/30 Windows skips. Default suite grows149→150 and contains player_contact_art; existing contracts are retained.

## Natural World versus component

World uses the exact published earned_camp_seed.json SHA91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b in a private save. StockHP5/max6, energy100, wallet287 and no dash are verified. Normal movement/J first displays the measured blade; normal movement then skill_1 performs a paid cleave against authored resident E07. Actual energy100→75 cost25→95 after hit reward, targetHP2→-1, wallet287→295 and playerHP5 are observed. No player/enemy position, HP, unlock, cooldown, invulnerability or direct damage writes occur in this World fixture. The component explicitly positions actors/selects legal skills and labels direct receiver boundaries; it is not natural-route evidence.

## Retained failures

component_probe_01 preserves the wrong fixture cooldown field failure. world_probe_01 preserves a wrong can_cast dictionary key: no cast occurred and normal movement passed the platform; world_probe_02 corrected it to production available and passed. cpu_01 preserves two suites that explicitly require real GL and reject Dummy headless; those were later executed under real GL. All probe/failure logs remain, including the first native budget failure. pre_* raw originals are retained; baseline_player_execution.gd differs from pre_player_controller.gd ONLY by redirecting the Melee preload to its archived original, so reverse execution really uses old primitives.

Every engine process has a180-second timeout, fixed60/Dummy audio. Native uses gl_compatibility under the single GPU token, released only after all actual processes terminate. Frozen inputs are checked before/after every engine. logs.json indexes every raw log's byte length/SHA and gzipSHA; each gzip has mtime0. index.json records published evidence hashes. Raw logs remain locally; their exact gzip bytes are published.
