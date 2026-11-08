# Music v2.5 — fully integrated 2026-11-08

## Full runtime pack

The user requested full integration and a PR on 2026-11-08. All 30 new cues
are generated, including the explicitly authorized replacement for the one
ambiguous disconnected Boss request; the original receipt is retained.
Together with three existing approved cues, 33 audio files cover 34 roles.
CH06 ordinary combat intentionally removes music per specification section 2.7.

The runtime [music_pack.json](../../godot/assets/audio/bgm/ai_generated/music_pack.json)
records every path, loop flag, duration, source/target hash and generation receipt.
The [integration report](../../docs/report/20261108_music_v25_integration.md)
explains the state transitions and limitations.

Independent combat accompaniment replaces exploration instead of being mixed as
phase-aligned stems. The short greenhouse combat master remains about 107 seconds
after loop editing. Wordless voice cues explicitly permit voices; other new cues
force instrumental output. Notes, BPM and phrasing still require human listening.

The current sixth guardian and final Crown share one runtime actor: the roll-call
cue announces entry for eight seconds, then the quiet first movement starts;
phase changes cancel the entry callback. Travel jingles follow the actual shrine
return transition and announce arrival only on success.

Retained masters and receipts are in `vercel_pack_20261107/incoming/`. Preparation
caches are ignored because they can be reconstructed offline. Rebuild with:

```sh
python tools/build_approved_music.py
python tools/build_game_music_pack.py
```

The first command builds the original three approved loops; the second prepares
all 30 new loops/one-shots and installs the complete runtime catalog. Neither
command makes a paid network request. Explicit new generation uses
`generate_vercel_music_pack.py --generate`; existing receipts prevent resubmission.

## Future generation provider

New music uses Vercel AI Gateway with `elevenlabs/music-v2.5`, configured in
`provider_config.json`. Credentials are loaded from `AI_GATEWAY_API_KEY` or the
ignored root `.env.local`; the game itself does not receive the key.
The three approved tracks retain their original generation receipts below.

`python tools/generate_vercel_music.py --check` performs a read-only authentication
check. To create one new instrumental track, supply `--prompt-file prompt.txt
--output art_requests/ai_music_v1/incoming/new_track.mp3`; the default request is
115 seconds. A receipt is written before submission and updated on success;
timeouts are never automatically resubmitted. Audition and probe new audio before
connecting it to runtime assets.

Protocol and options: [Vercel audio documentation](https://vercel.com/docs/ai-gateway/modalities/text-to-speech#generate-music-and-sound-effects-with-elevenlabs).

The user approved all three previously generated tracks for in-game use.
The original MP3s and generation receipt are preserved here. No new paid
generation is required to build or run this integration.

`python tools/build_approved_music.py` builds the runtime Ogg files in
`godot/assets/audio/bgm/ai_generated/`. It verifies source hashes, blends the
last three seconds into the first three seconds with an equal-power crossfade,
then normalizes each full mix to -18 LUFS / -2 dBTP. Runtime loops are about
117 seconds. The manifest records decoded duration, output loudness and hashes.

Runtime assignments:

- 苔钟庭 · 旧钟下的微光: CH01 exploration.
- 断弦温室 · 藤影与残弦: CH04 exploration.
- 苔钟守母 · 铜钟与针锋: `rust_crown_guardian` boss battle, all phases.

These are independently composed full mixes, not aligned stems. Each region uses its independent encounter cue during normal combat; the exploration player pauses and later resumes its phrase. Boss and shrine music retain the existing fade,
pause, and resume behavior. Other chapters now use the Vercel pack described above.

Provider provenance: ElevenLabs Music v2.5 through fal.ai; see the generation
receipt for request IDs and prompts. The AI outputs are recorded separately
from the project's synthesized CC0 music. Provider-generated output is not
relabelled as third-party CC0.

## Listen and validate

Open [the complete playlist](vercel_pack_20261107/listen_all.m3u8) in a local
player. It references the installed game files, so a checkout can audition the
same 33 cues without regenerating audio.

Validation:

```sh
python tools/run_godot_regressions.py --suite ai_music_pack --suite audio_construction --suite hidden_drone --suite boss_trial
python tools/run_music_layer_contract.py --engine /path/to/godot --log-dir /path/to/logs
```

The pack suite checks all delivered native streams, loop/one-shot endings,
actual cue mappings, encounter/shrine/Boss transitions, the Crown entrance and
three movements, travel results, transit/hidden ambience and native retirement.
The music layer contract also checks phrase retention, user-volume settings and
playback ownership across director replacement.
