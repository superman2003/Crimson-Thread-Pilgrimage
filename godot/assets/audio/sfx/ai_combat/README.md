# Original combat sound effects

30 original text-to-audio cues generated with `elevenlabs/sound-effects-v2`
through Vercel AI Gateway. Generation did not use any reference-game recording.

- Eight release/contact families have three separately generated variants:
  blade, heavy, claw, wing, seed, root, bell, impact.
- Three preparation families have two variants: prep_light, prep_heavy, prep_cast.
- Source MP3s, prompts and provider receipts: `art_requests/combat_sfx_v1/`.
- Preparation tool: `tools/generate_combat_sfx_ai.py`.
- Runtime manifest and per-clip JSON preserve source/output hashes, duration,
  constant loudness gain and native-decode verification.
- Preparation trims silence, applies short fades and limits measured true peak.
  Those technical checks do not constitute human artistic approval; audition
  status remains `pending_human_audition` until reviewed.

The original alert severity and blockability rules remain separate from material
selection. Preparation plays at windup, release at the active transition, and the
contact layer only after accepted melee contact. Variants avoid immediate
repetition and use a separate RNG from gameplay choices.

Run `tools/music_library.py --open` for individual audition and six regional
previews. Launching the list does not start a game. Preview saves are isolated.
Run `tools/test_combat_sfx_export.py --engine <Godot 4.6.1>` to validate all clips
from a compiled PCK outside the source project.

These outputs are not part of the project's synthesized CC0 packs. See
`THIRD_PARTY_NOTICES.md` and the applicable ElevenLabs/Vercel terms.
