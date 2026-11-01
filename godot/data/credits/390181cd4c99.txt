# Third Party Asset Notice

This prototype uses free/open or project-owned runtime assets for the current playable slice. Assets with redistribution limits are documented in `docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md` and should not be committed to public releases.

## Crimson Thread Original Map Art

- Local path: `godot/assets/sprites/original_map`
- Generator: `tools/build_original_map_materials.py`
- License basis: project-owned original art, redistributable with this project.
- Project usage: six chapter-specific parallax backgrounds, map panels, and collision-readable platform materials.
- Reproducibility: all raster assets use deterministic local seeds and no third-party game imagery.

## Ansimuz / OpenGameArt GothicVania Cemetery

- Source: https://opengameart.org/content/gothicvania-cemetery-pack
- Local path: `godot/assets/sprites/gothicvania`
- Recorded license: Public domain / CC0-like, commercial use allowed, credit not required for artwork.
- Project usage: player hero, enemy sprites, boss sprite, background layers, platforms, hazards, gates, and key art.

## Kenney Assets

- Source: https://kenney.nl/assets/platformer-art-deluxe and related Kenney CC0 packs.
- Local paths: `godot/assets/sprites/ui/kenney`, selected art in `godot/assets/sprites/gothicvania/demo`.
- Recorded license: Creative Commons CC0.
- Project usage: UI, keys, small props, signs, and future particle/sound candidates.

## Bread Adventure

- Source: https://github.com/wheafun/bread-adventure
- License: Apache License 2.0
- Project usage: texture-derived platform materials. Historical note: the 11 root SFX OGGs and 2 BGM OGGs under `godot/assets/audio/` originally came from this pack, but the vendored copies turned out to be silent/placeholder renders; on 2026-07-26 all 13 files were replaced in place by project-generated CC0 synthesis (`tools/generate_sfx_pack.py` core-action recipes and `tools/generate_music_pack.py` ch01 tracks). No Bread Adventure audio content remains in the repository.

## OpenGameArt Dark Fantasy Platformer Bestiary

- Source: https://opengameart.org/content/dark-fantasy-platformer-bestiary
- Local path: `godot/assets/third_party/dark_fantasy_bestiary`
- License: Creative Commons Attribution 4.0 International (CC BY 4.0).
- Project usage: enemy and boss sprites cropped from the provided PNG sheets.

Runtime slash, hit, windup, pickup, and ability feedback is implemented with Godot shapes, tweens, particles, and the free/open assets above; no generated character/enemy art is required.

## Restricted local-only asset packs

The following asset packs may exist in local development caches but are not public-release assets and are not committed to public releases or the open-source repository:

- Mossy Cavern by Maaot: project use is allowed, but asset redistribution/repackaging is restricted.
- Abyss Bug Sprite Pack by Arhimed122: project use is allowed, but standalone asset-pack redistribution is restricted.
- Forest Monsters 2D Pixel Art by MonoPixelArt: redistribution/modification is restricted.

See `docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md` for exact paths and release actions.

## Crimson Thread Synthesized SFX Pack

- Local path: `godot/assets/audio/sfx/generated`
- Builder: `tools/generate_sfx_pack.py` (deterministic offline synthesis, Python stdlib wave + numpy; no third-party recordings or samples are used as input)
- License: project-generated (CC0), redistributable with this project.
- Project usage: bell/thread/tide family gameplay SFX per spec 20260726160400000 §4 — pogo D5 bronze bell, guard bells, wall grip attach and slide loop, hit-confirm tiers, six enemy death materials, shrine wrap/rest six-region lullaby variants, ability-gate unlock family sounds, chapter transition, low-HP heartbeat loop, and ending stingers. Registered per event in `godot/data/audio_visual_manifest.json` `sfx_catalog` (statuses `wired` / `asset_ready`); the audition reel lives at `output/audio_preview/sfx_sampler.wav`.

## Crimson Thread Synthesized Music Pack

- Local path: `godot/assets/audio/bgm/generated`
- Builder: `tools/generate_music_pack.py` (deterministic offline synthesis with numpy, encoded to OGG via ffmpeg; no third-party recordings or samples are used as input)
- License: project-generated (CC0), redistributable with this project.
- Project usage: chapter explore loops (ch02–ch06), combat layer stems (ch01–ch06), boss loops (ch02–ch06), the three final-boss movements, six shrine lullabies, three ending cadence tracks, bellway loop/jingles, and the hidden black-tide drone — all derived from the Silent Toll motif per spec 20260726160400000 §2/§3. Registered in `godot/data/audio_visual_manifest.json` (`chapter_audio_visual` music entries and the `global_music` block); inventory at `output/audio_preview/music_pack_inventory.json`. Rebuild: `npm run build:audio-music`.

## Crimson Thread Synthesized Ambience & Combat Pack

- Local paths: `godot/assets/audio/ambience`, `godot/assets/audio/sfx/generated` (chapter beats, combat completion, boss kits, UI jingles), `godot/assets/audio/sfx/generated_footsteps`
- Builder: `tools/generate_ambience_pack.py` (deterministic per-file seeded synthesis, 16-bit 44.1 kHz mono; no third-party recordings or samples are used as input)
- License: project-generated (CC0), redistributable with this project.
- Project usage: six chapter ambience bed loops plus 48 sparse one-shots and the ch02 far-anvil strike (spec §4.6), fifteen chapter beat sounds, the player attack-swing/landing family, enemy hit material tiers, six per-chapter boss SFX kits (roar/phase shift/light/heavy attacks), three UI jingles, and glass/wet footstep families calibrated to the Kenney sets. Registered in `godot/data/audio_visual_manifest.json` (`ambience_zones`, `sfx_catalog`, chapter beats); inventory at `output/audio_preview/ambience_pack_inventory.json`. Rebuild: `npm run build:audio-ambience`.

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
  - Project usage: texture layers over existing events — lever metal latch, shortcut door open, coin-handle layer for currency pickups, cloth layer for item pickups (existing Bread Adventure OGGs are kept, layered not replaced).
