# Third Party Asset Notice

This prototype uses free/open or project-owned runtime assets for the current playable slice. Assets with redistribution limits are documented in `docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md` and should not be committed to public releases.

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
- Project usage: selected OGG BGM/SFX and texture-derived platform materials.

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
