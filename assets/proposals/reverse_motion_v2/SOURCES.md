# Sources and permission

All pose coordinates, vector paths, costume simplifications, atlas assembly and drawing code in this pack were newly authored for the Crimson Thread Pilgrimage motion proposal. No third-party sprites, traced third-party characters, stock artwork or downloaded motion clips are included. No image-generation model was used: the SVG paths are native editable sources and PNGs are their deterministic raster exports.

Identity reference only, not embedded or copied as image pixels:

- `godot/assets/sprites/player/generated_hero_v3/manifest.json` at baseline `6544cceff5e812b5295b97204d7c55a4b8933de9`.
- Existing V3 `frames/idle_00.png`, visually inspected for dark ponytail, red scarf, teal split cape, dark tunic, brown boots and brass needle.
- `docs/HERO_HOOK_V4_SOURCE.md`, current identity description dated 2026-10-12.
- `godot/data/world_narrative.json`, crest terminology and practical craft-based identities.

The older Lumen Spoolwright redesign note describes a different identity. This proposal follows the later V3 reference only and does not resolve that historical design divergence. The new simplified silhouette is explicitly a research candidate, not a production-ready replacement for the detailed V3 art.

This newly authored pack and its generator are provided under the repository's MIT License, copyright (c) 2026 Crimson Thread Pilgrimage contributors; see the repository root `LICENSE`. This statement does not relicense or make provenance claims about the existing identity-reference images. No reference image pixels are redistributed here.

Rasterization tools: Inkscape 1.2.2 and Pillow 12.3.0. The contact-sheet labels use the host's DejaVu Sans font; no font files are included in this pack. Generated animation SVGs have no text or font dependency. The contact sheet is a review artifact and is opaque by design; every animation atlas has true alpha transparency.

Local `.gitattributes` keeps PNG files as ordinary Git blobs so an authenticated/raw repository fetch receives real image bytes rather than LFS pointers.
