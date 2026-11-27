# Third Party & Project Asset Notice

This project uses free/open third-party assets, MIT-licensed plugins, and project-owned/AI-assisted runtime assets. See the repository root `THIRD_PARTY_NOTICES.md` for full provenance links and legal boundaries. Assets with redistribution limits are documented in `docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md` and are never committed to public releases.

## Project-Authored & AI-Assisted Visual Packs

- Local paths: `godot/assets/sprites/flat_maps/`, `godot/assets/sprites/original_creatures/`, `godot/assets/sprites/original_npcs/`, `godot/assets/sprites/original_items/`, `godot/assets/sprites/player/thread_doll_v1/`, `godot/assets/vfx/`
- License basis: project-owned original and `image_gen`-assisted artwork built strictly from project-owned designs and prompts (provenance retained under `art_requests/`).
- Project usage: six chapter-specific painted world materials and parallax props, protagonist thread-doll animations, 40+ original enemies and six Bosses (including combat motion v7, v8/redraw atlases, and boss behavior clips), 25 original NPCs, items, and combat VFX. Superseded legacy atlases and generation receipts are excluded from desktop release `.pck` exports.

## UI Fonts and Lettering (SIL OFL 1.1)

- Local paths: `godot/assets/fonts/GlobalTypeface.otf`, `godot/assets/fonts/OFL-NotoSerifCJK.txt`, `godot/assets/fonts/OFL.txt`
- License: SIL Open Font License 1.1.
- Project usage: `GlobalTypeface.otf` (Feng Ming Inscription / 缝名刻宋) is a renamed derivative of Noto Serif CJK SC Regular built with `tools/build_inscription_font.py` and `tools/apply_global_font.py`. Noto Sans SC (`OFL.txt`) is retained in-repo for historical rollback and excluded from release `.pck` exports.

## Bundled Godot Plugins (MIT)

- **Metroidvania System**: `godot/addons/MetroidvaniaSystem` (MIT, https://github.com/KoBeWi/Metroidvania-System; license retained in directory).
- **Beehave**: `godot/addons/beehave` (MIT, v2.9.3, https://github.com/bitbrain/beehave/tree/v2.9.3; license and `UPSTREAM.json` retained in directory).

## Ansimuz / OpenGameArt GothicVania Cemetery

- Source: https://opengameart.org/content/gothicvania-cemetery-pack
- Local paths: `godot/assets/third_party/gothicvania_cemetery`, `godot/assets/sprites/gothicvania`
- Recorded license: Public domain / CC0-like, commercial use allowed, credit not required for artwork.
- Project usage: redistributable cemetery backgrounds and historical demo/reference sprites.

## Godot Platformer 2D (MIT)

- Source: https://github.com/GDQuest/godot-platformer-2d
- Local path: `godot/assets/third_party/godot_platformer_2d`
- License: MIT.
- Project usage: Chapter 6 background elements.

## Kenney Assets (CC0)

- Source: https://kenney.nl/assets/platformer-art-deluxe and related Kenney CC0 packs.
- Local paths: `godot/assets/third_party/kenney_*`, `godot/assets/sprites/ui/kenney`, `godot/assets/audio/sfx/kenney/{impact,interface,rpg}`.
- Recorded license: Creative Commons CC0 1.0.
- Project usage: UI chrome, platform tiles, small props, footsteps, and UI/RPG audio texture layers.

## Bread Adventure (Apache License 2.0)

- Source: https://github.com/wheafun/bread-adventure
- License: Apache License 2.0.
- Project usage: historical texture-derived platform materials. Historical note: the 11 root SFX OGGs and 2 BGM OGGs under `godot/assets/audio/` originally came from this pack, but the vendored copies were silent/placeholder renders; on 2026-07-26 all 13 files were replaced in place by project-generated CC0 synthesis (`tools/generate_sfx_pack.py` core-action recipes and `tools/generate_music_pack.py` ch01 tracks). No Bread Adventure audio content remains in the repository.

## OpenGameArt Dark Fantasy Platformer Bestiary (Excluded from Releases)

- Source: https://opengameart.org/content/dark-fantasy-platformer-bestiary
- Local path: `godot/assets/third_party/dark_fantasy_bestiary`
- License: Creative Commons Attribution 4.0 International (CC BY 4.0).
- Project usage: historical enemy reference keyframes only; excluded from desktop release `.pck` exports after original hand-drawn creature art replaced them.

## Restricted Local-Only Asset Packs

The following asset packs may exist in local development caches but are not public-release assets and are not committed to public releases or the open-source repository:

- Mossy Cavern by Maaot: project use is allowed, but asset redistribution/repackaging is restricted.
- Abyss Bug Sprite Pack by Arhimed122: project use is allowed, but standalone asset-pack redistribution is restricted.
- Forest Monsters 2D Pixel Art by MonoPixelArt: redistribution/modification is restricted.

See `docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md` for exact paths and release actions.

## AI-Generated Score and Combat SFX (ElevenLabs)

- **Music v2.5 game score**: `godot/assets/audio/bgm/ai_generated/` (33 tracks generated via ElevenLabs Music v2.5 through fal.ai / Vercel AI Gateway; receipts in `art_requests/ai_music_v1/`).
- **AI combat sound effects**: `godot/assets/audio/sfx/ai_combat/` (30 cues generated via ElevenLabs Sound Effects v2 through Vercel AI Gateway; receipts in `art_requests/combat_sfx_v1/`).
- Terms: maintained separately from project-synthesized CC0 audio and subject to the applicable ElevenLabs/Vercel terms. No API credentials are distributed.

## Crimson Thread Synthesized SFX Pack

- Local path: `godot/assets/audio/sfx/generated`, `godot/assets/audio/sfx/` (11 core action OGGs)
- Builder: `tools/generate_sfx_pack.py` (deterministic offline synthesis, Python stdlib wave + numpy; no third-party recordings or samples are used as input)
- License: project-generated (CC0), redistributable with this project.
- Project usage: bell/thread/tide family gameplay SFX per spec 20260726160400000 §4 — pogo D5 bronze bell, guard bells, wall grip attach and slide loop, hit-confirm tiers, six enemy death materials, shrine wrap/rest six-region lullaby variants, ability-gate unlock family sounds, chapter transition, low-HP heartbeat loop, and ending stingers. Registered per event in `godot/data/audio_visual_manifest.json` `sfx_catalog`.

## Crimson Thread Synthesized Music Pack

- Local path: `godot/assets/audio/bgm/generated` (excluded from release `.pck` after `bgm/ai_generated/` superseded it; ch01 legacy fallbacks remain at `godot/assets/audio/bgm/`)
- Builder: `tools/generate_music_pack.py` (deterministic offline synthesis with numpy, encoded to OGG via ffmpeg; no third-party recordings or samples are used as input)
- License: project-generated (CC0), redistributable with this project.
- Project usage: offline synthesized reference/fallback score derived from the Silent Toll motif per spec 20260726160400000 §2/§3. Rebuild: `npm run build:audio-music`.

## Crimson Thread Synthesized Ambience & Combat Pack

- Local paths: `godot/assets/audio/ambience`, `godot/assets/audio/sfx/generated` (chapter beats, combat completion, boss kits, UI jingles), `godot/assets/audio/sfx/generated_footsteps`
- Builder: `tools/generate_ambience_pack.py` (deterministic per-file seeded synthesis, 16-bit 44.1 kHz mono; no third-party recordings or samples are used as input)
- License: project-generated (CC0), redistributable with this project.
- Project usage: six chapter ambience bed loops plus 48 sparse one-shots and the ch02 far-anvil strike (spec §4.6), fifteen chapter beat sounds, the player attack-swing/landing family, enemy hit material tiers, six per-chapter boss SFX kits, three UI jingles, and glass/wet footstep families. Rebuild: `npm run build:audio-ambience`.

## Seal Combat Audio & NPC Insect Language Voices

- Local paths: `godot/assets/audio/seals/`, `godot/assets/audio/npc_insect_language_v1/`
- License: project-generated (CC0), redistributable with this project.
- Project usage: combat seal prepare/active/hit WAV cues and per-NPC synthesized phonetic speech stems played by `godot/scripts/npc_insect_language.gd`.

## Kenney Audio Packs (Impact / Interface / RPG)

Only the files actually used are vendored; each subdirectory carries the pack's original `License.txt`. All three packs: Creative Commons Zero (CC0), free for personal/educational/commercial use, credit not mandatory. Downloaded: 2026-07-26. Vendored copies were re-encoded on 2026-07-26 with peak normalization (0.85) to remove >0 dBFS decode overshoot and align loudness with the project's synthesized UI kit (CC0 permits modification).

- Kenney Impact Sounds
  - Source: https://kenney.nl/assets/impact-sounds
  - Local path: `godot/assets/audio/sfx/kenney/impact` (20 of 130 files)
  - Project usage: material footsteps — grass (moss courts), concrete (foundry bronze; also pitched down 0.82 for obsidian stone), snow (salt archive), wood (greenhouse fiber).
- Kenney Interface Sounds
  - Source: https://kenney.nl/assets/interface-sounds
  - Local path: `godot/assets/audio/sfx/kenney/interface` (10 of 100 files)
  - Project usage: UI events — inventory/map open and close, dialogue close, menu cursor ticks, toast ping, ending-gate confirm/cancel.
- Kenney RPG Audio
  - Source: https://kenney.nl/assets/rpg-audio
  - Local path: `godot/assets/audio/sfx/kenney/rpg` (5 of 50 files)
  - Project usage: texture layers over existing events — lever metal latch, shortcut door open, coin-handle layer for currency pickups, cloth layer for item pickups (layered over the project-generated CC0 core SFX OGGs that replaced the earlier Bread Adventure OGGs on 2026-07-26).
