# Third Party Notices

This project uses third-party assets and plugins under their own licenses. The game code is MIT licensed, but third-party art, audio, and plugins remain under the licenses listed below.

## Redistributable runtime assets

| Asset | Local path | License / terms | Use |
|---|---|---|---|
| Kenney assets | `godot/assets/third_party/kenney_*`, `godot/assets/sprites/ui/kenney` | CC0 1.0 | UI, platform tiles, props |
| GothicVania Cemetery / Ansimuz | `godot/assets/third_party/gothicvania_cemetery`, `godot/assets/sprites/gothicvania` | Public Domain / commercial-friendly local record | CH01 redistributable art, cemetery backgrounds, player/demo sprites |
| Dark Fantasy Platformer Bestiary | `godot/assets/third_party/dark_fantasy_bestiary` | Creative Commons Attribution; see local NOTICE and original OpenGameArt page | Enemy and boss runtime keyframes |
| Godot Platformer 2D | `godot/assets/third_party/godot_platformer_2d` | MIT | Chapter 6 background elements |
| Metroidvania System | `godot/addons/MetroidvaniaSystem` | MIT | Map/metroidvania plugin |

## Restricted local-only assets

The following packs may exist in local development caches but are not part of the public release payload and are excluded by `.gitignore`:

| Asset | Local paths | Public repo action |
|---|---|---|
| Maaot / Mossy Cavern | `godot/assets/third_party/mossy_cavern`, `artifacts/third_party/mossy-cavern` | Do not commit asset files; documented only |
| Arhimed122 / Abyss Bug Sprite Pack | `godot/assets/sprites/enemies/itch`, `godot/assets/sprites/player/abyss_hero`, `artifacts/third_party/enemy_packs/abyss` | Do not commit extracted frames or source pack |
| MonoPixelArt / Forest Monsters 2D Pixel Art FREE | `godot/assets/sprites/enemies/itch/spore_bellmaker`, `artifacts/third_party/enemy_packs/forest` | Do not commit extracted frames or source pack |

See `docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md` for the detailed Chinese release-boundary record.

## Source links

- Kenney: https://kenney.nl/assets
- GothicVania Cemetery: https://opengameart.org/content/gothicvania-cemetery-pack
- Dark Fantasy Platformer Bestiary: https://opengameart.org/content/dark-fantasy-platformer-bestiary
- Godot Platformer 2D: https://github.com/GDQuest/godot-platformer-2d
- Metroidvania System: https://github.com/KoBeWi/Metroidvania-System
- Mossy Cavern: https://maaot.itch.io/mossy-cavern
- Abyss Bug Sprite Pack: https://arhimed122.itch.io/abyss-bug-sprite-pack
- Forest Monsters 2D Pixel Art: https://monopixelart.itch.io/forest-monsters-pixel-art
