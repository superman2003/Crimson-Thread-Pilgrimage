from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
GOTHIC_ROOT = ROOT / "artifacts" / "source_assets" / "opengameart" / "gothicvania" / "cemetery" / "gothicvania-cemetery-files" / "PNG"
KENNEY_ROOT = ROOT / "artifacts" / "source_assets" / "kenney" / "platformer-art-deluxe"
OUT_ROOT = ROOT / "godot" / "assets" / "sprites" / "gothicvania"
DEMO_DIR = OUT_ROOT / "demo"
PLAYER_DIR = OUT_ROOT / "player"
FRAME_DIR = PLAYER_DIR / "frames"
SHEET_DIR = PLAYER_DIR / "sheets"
MANIFEST_PATH = PLAYER_DIR / "manifest.json"
PREVIEW_PATH = PLAYER_DIR / "preview.png"
ASSET_MANIFEST = OUT_ROOT / "asset_manifest.json"


def gothic(relative: str) -> Path:
    path = GOTHIC_ROOT / relative
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def kenney(relative: str) -> Path:
    path = KENNEY_ROOT / relative
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def open_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def fit_to_canvas(image: Image.Image, canvas_size: tuple[int, int], target_height: int, x_offset: int = 0, y_offset: int = 0) -> Image.Image:
    source = image.convert("RGBA")
    scale = target_height / max(1, source.height)
    target_size = (max(1, int(source.width * scale)), max(1, int(source.height * scale)))
    source = source.resize(target_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_size[0] - source.width) // 2 + x_offset
    y = canvas_size[1] - source.height + y_offset
    canvas.alpha_composite(source, (x, y))
    return canvas


def tint(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    base = image.convert("RGBA")
    overlay = Image.new("RGBA", base.size, (*color, 0))
    overlay.putalpha(base.getchannel("A").point(lambda value: int(value * strength)))
    return Image.alpha_composite(base, overlay)


def tile_horizontal(source: Image.Image, size: tuple[int, int], y: int = 0) -> Image.Image:
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    x = 0
    while x < size[0]:
        output.alpha_composite(source, (x, y))
        x += source.width
    return output


def make_backgrounds() -> dict[str, str]:
    width, height = 8192, 720
    base = open_rgba(gothic("Environment/background.png")).resize((1234, 720), Image.Resampling.NEAREST)
    mountains = open_rgba(gothic("Environment/mountains.png")).resize((770, 716), Image.Resampling.NEAREST)
    graveyard = open_rgba(gothic("Environment/graveyard.png")).resize((1540, 492), Image.Resampling.NEAREST)
    tree_1 = open_rgba(gothic("Environment/sliced-objects/tree-1.png")).resize((256, 288), Image.Resampling.NEAREST)
    tree_2 = open_rgba(gothic("Environment/sliced-objects/tree-2.png")).resize((288, 288), Image.Resampling.NEAREST)
    bush = open_rgba(gothic("Environment/sliced-objects/bush-large.png")).resize((96, 58), Image.Resampling.NEAREST)

    sky = tile_horizontal(base, (width, height))
    far = tile_horizontal(tint(mountains, (20, 28, 45), 0.35), (width, height), 36)
    mid = tile_horizontal(tint(graveyard, (22, 26, 38), 0.18), (width, height), 228)

    fog = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    fog_draw = ImageDraw.Draw(fog)
    for x in range(-160, width, 420):
        fog_draw.rectangle((x, 452, x + 330, 478), fill=(162, 186, 178, 38))
        fog_draw.rectangle((x + 80, 515, x + 460, 542), fill=(112, 140, 130, 28))

    near = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for x in range(-60, width, 420):
        near.alpha_composite(tree_1 if (x // 420) % 2 == 0 else tree_2, (x, 310))
    for x in range(0, width, 176):
        near.alpha_composite(bush, (x, 592))

    layers = {
        "bg_ch01_sky": sky,
        "bg_ch01_far_silhouettes": far,
        "bg_ch01_mid_arches": mid,
        "bg_ch01_fog": fog,
        "bg_ch01_near_vines": near,
    }
    composite = sky.copy()
    for name in ("bg_ch01_far_silhouettes", "bg_ch01_mid_arches", "bg_ch01_fog", "bg_ch01_near_vines"):
        composite.alpha_composite(layers[name])
    layers["bg_ch01_composite_preview"] = composite.resize((1365, 120), Image.Resampling.NEAREST)

    for name, image in layers.items():
        save_png(image, DEMO_DIR / f"{name}.png")
    return {f"demo/{name}.png": "Ansimuz GothicVania Cemetery art" for name in layers}


def make_tile_texture(crops: list[tuple[int, int, int, int]], tint_color: tuple[int, int, int] | None = None) -> Image.Image:
    tileset = open_rgba(gothic("Environment/tileset.png"))
    output = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    tiles = [tileset.crop(crop).resize((32, 32), Image.Resampling.NEAREST) for crop in crops]
    for y in range(0, 128, 32):
        for x in range(0, 128, 32):
            tile = tiles[((x // 32) + (y // 32)) % len(tiles)]
            output.alpha_composite(tile, (x, y))
    if tint_color is not None:
        output = tint(output, tint_color, 0.16)
    return output


def make_door() -> Image.Image:
    statue = open_rgba(gothic("Environment/sliced-objects/statue.png")).resize((72, 112), Image.Resampling.NEAREST)
    stone = open_rgba(gothic("Environment/sliced-objects/stone-4.png")).resize((76, 42), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (128, 152), (0, 0, 0, 0))
    canvas.alpha_composite(stone, (26, 106))
    canvas.alpha_composite(statue, (28, 16))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((26, 34, 101, 134), outline=(188, 143, 74, 230), width=3)
    draw.ellipse((55, 80, 73, 98), outline=(238, 191, 86, 230), width=3)
    return canvas


def make_demo_sprites() -> dict[str, str]:
    used: dict[str, str] = {}
    skeleton = open_rgba(gothic("Sprites/skeleton/skeleton-1.png"))
    skeleton_clothed = open_rgba(gothic("Sprites/skeleton-clothed/skeleton-clothed-1.png"))
    ghost = open_rgba(gothic("Sprites/ghost/ghost-1.png"))
    gato = open_rgba(gothic("Sprites/hell-gato/hell-gato-1.png"))
    statue = open_rgba(gothic("Environment/sliced-objects/statue.png"))
    stone_1 = open_rgba(gothic("Environment/sliced-objects/stone-1.png"))
    stone_2 = open_rgba(gothic("Environment/sliced-objects/stone-2.png"))
    stone_3 = open_rgba(gothic("Environment/sliced-objects/stone-3.png"))
    bush = open_rgba(gothic("Environment/sliced-objects/bush-small.png"))

    boss_base = fit_to_canvas(tint(gato, (95, 32, 34), 0.2), (124, 124), 112)
    halo = fit_to_canvas(tint(ghost, (200, 72, 78), 0.28), (124, 124), 102, x_offset=0, y_offset=-6)
    boss = Image.alpha_composite(halo, boss_base)

    mappings: dict[str, Image.Image] = {
        "platform_moss_stone.png": make_tile_texture([(0, 0, 16, 16), (16, 0, 32, 16), (32, 0, 48, 16), (48, 0, 64, 16)], (54, 88, 60)),
        "platform_bronze_bridge.png": make_tile_texture([(64, 0, 80, 16), (80, 0, 96, 16), (96, 0, 112, 16), (112, 0, 128, 16)], (116, 78, 44)),
        "platform_boss_stone.png": make_tile_texture([(0, 48, 16, 64), (16, 48, 32, 64), (32, 48, 48, 64), (48, 48, 64, 64)], (92, 55, 48)),
        "enemy_moss_larva.png": fit_to_canvas(skeleton, (116, 116), 88),
        "enemy_bronze_moth.png": fit_to_canvas(ghost, (116, 116), 96),
        "enemy_spore_bellmaker.png": fit_to_canvas(skeleton_clothed, (116, 116), 92),
        "enemy_gear_sentinel.png": fit_to_canvas(gato, (116, 116), 86),
        "boss_rust_crown_guardian.png": boss,
        "hazard_spikes.png": fit_to_canvas(stone_1, (96, 96), 52),
        "hazard_bell.png": fit_to_canvas(statue, (96, 96), 84),
        "trap_fake_moss_floor.png": fit_to_canvas(bush, (112, 72), 50),
        "trap_bell_gap.png": fit_to_canvas(stone_2, (112, 72), 52),
        "trap_spore_chest.png": fit_to_canvas(stone_3, (112, 72), 52),
        "trap_falling_clapper.png": fit_to_canvas(statue, (112, 96), 88),
        "trap_shortcut_revenge.png": fit_to_canvas(stone_1, (112, 72), 52),
        "trap_false_lamp.png": fit_to_canvas(tint(ghost, (228, 190, 80), 0.22), (112, 72), 58),
        "boss_gate.png": make_door(),
    }

    # GothicVania Cemetery does not ship keys or switches; use Kenney CC0 but keep them in the new runtime path.
    mappings["pickup_bell_key.png"] = fit_to_canvas(open_rgba(kenney("Base pack/Items/keyYellow.png")), (96, 96), 70)
    mappings["shortcut_lever.png"] = fit_to_canvas(open_rgba(kenney("Base pack/Items/switchMid.png")), (96, 96), 70)

    for name, image in mappings.items():
        save_png(image, DEMO_DIR / name)
        if name in {"pickup_bell_key.png", "shortcut_lever.png"}:
            used[f"demo/{name}"] = "Kenney Platformer Art Deluxe CC0"
        else:
            used[f"demo/{name}"] = "Ansimuz GothicVania Cemetery art"
    return used


def player_frame(relative: str, target_height: int = 112) -> Image.Image:
    return fit_to_canvas(open_rgba(gothic(relative)), (128, 128), target_height)


def source_frames(folder: str, prefix: str, count: int) -> list[str]:
    return [f"Sprites/hero/{folder}/{prefix}-{i}.png" for i in range(1, count + 1)]


def draw_arc(frame: Image.Image, step: int, color: tuple[int, int, int, int]) -> Image.Image:
    output = frame.copy()
    draw = ImageDraw.Draw(output)
    draw.arc((48, 40, 124, 110), start=-60 + step * 22, end=30 + step * 22, fill=color, width=4)
    return output


def make_player_assets() -> dict[str, str]:
    anim_sources: dict[str, list[Image.Image]] = {
        "idle": [player_frame(path, 112) for path in source_frames("hero-idle", "hero-idle", 4)] * 2,
        "run": [player_frame(path, 112) for path in source_frames("hero-run", "hero-run", 6)] + [player_frame("Sprites/hero/hero-run/hero-run-1.png", 112), player_frame("Sprites/hero/hero-run/hero-run-2.png", 112)],
        "jump_start": [player_frame(path, 112) for path in source_frames("hero-jump", "hero-jump", 4)],
        "jump_loop": [player_frame("Sprites/hero/hero-jump/hero-jump-2.png", 112), player_frame("Sprites/hero/hero-jump/hero-jump-3.png", 112), player_frame("Sprites/hero/hero-jump/hero-jump-4.png", 112)],
        "fall": [player_frame("Sprites/hero/hero-jump/hero-jump-4.png", 110) for _ in range(4)],
        "land": [player_frame("Sprites/hero/hero-jump/hero-jump-4.png", 108), player_frame("Sprites/hero/hero-crouch/hero-crouch.png", 92), player_frame("Sprites/hero/hero-idle/hero-idle-1.png", 112), player_frame("Sprites/hero/hero-idle/hero-idle-2.png", 112)],
        "dash": [player_frame("Sprites/hero/hero-crouch/hero-crouch.png", 92) for _ in range(6)],
        "wall_slide": [player_frame("Sprites/hero/hero-jump/hero-jump-3.png", 112) for _ in range(4)],
        "attack_1": [player_frame(path, 112) for path in source_frames("hero-attack", "hero-attack", 5)] + [player_frame("Sprites/hero/hero-idle/hero-idle-1.png", 112)],
        "attack_2": [player_frame(path, 112) for path in source_frames("hero-attack", "hero-attack", 5)] + [player_frame("Sprites/hero/hero-attack/hero-attack-4.png", 112), player_frame("Sprites/hero/hero-idle/hero-idle-1.png", 112)],
        "air_attack": [draw_arc(player_frame(path, 112), i, (234, 205, 96, 230)) for i, path in enumerate(source_frames("hero-attack", "hero-attack", 5))] + [player_frame("Sprites/hero/hero-jump/hero-jump-3.png", 112)],
        "hook_throw": [draw_arc(player_frame(path, 112), i, (93, 216, 225, 230)) for i, path in enumerate(source_frames("hero-attack", "hero-attack", 5))] + [player_frame("Sprites/hero/hero-idle/hero-idle-1.png", 112), player_frame("Sprites/hero/hero-idle/hero-idle-2.png", 112)],
        "hurt": [player_frame("Sprites/hero/hero-hurt/hero-hurt.png", 108), player_frame("Sprites/hero/hero-hurt/hero-hurt.png", 104), player_frame("Sprites/hero/hero-crouch/hero-crouch.png", 92), player_frame("Sprites/hero/hero-idle/hero-idle-1.png", 112)],
        "death": [player_frame("Sprites/hero/hero-hurt/hero-hurt.png", max(46, 108 - i * 8)) for i in range(8)],
    }

    manifest_anims = []
    preview_rows: list[Image.Image] = []
    for name, images in anim_sources.items():
        frame_paths = []
        anim_dir = FRAME_DIR / name
        anim_dir.mkdir(parents=True, exist_ok=True)
        for index, image in enumerate(images):
            frame_path = anim_dir / f"{name}_{index:02d}.png"
            save_png(image, frame_path)
            frame_paths.append(f"res://assets/sprites/gothicvania/player/frames/{name}/{name}_{index:02d}.png")

        sheet = Image.new("RGBA", (128 * len(images), 128), (0, 0, 0, 0))
        for index, image in enumerate(images):
            sheet.alpha_composite(image, (index * 128, 0))
        save_png(sheet, SHEET_DIR / f"{name}_sheet.png")
        preview_rows.append(sheet)
        manifest_anims.append({
            "name": name,
            "fps": 14 if "attack" in name or name == "dash" else 12 if name in {"run", "jump_start", "land", "hook_throw"} else 8,
            "loop": name in {"idle", "run", "jump_loop", "fall", "wall_slide"},
            "frame_count": len(images),
            "sheet": f"res://assets/sprites/gothicvania/player/sheets/{name}_sheet.png",
            "frames": frame_paths,
        })

    preview = Image.new("RGBA", (max(row.width for row in preview_rows), len(preview_rows) * 128), (18, 20, 28, 255))
    for index, row in enumerate(preview_rows):
        preview.alpha_composite(row, (0, index * 128))
    save_png(preview, PREVIEW_PATH)
    MANIFEST_PATH.write_text(json.dumps({
        "character": "ansimuz_gothicvania_hero",
        "frame_size": [128, 128],
        "anchor": "bottom_center",
        "source": "Ansimuz GothicVania Cemetery / PNG / Sprites / hero",
        "origin_note": "Public-domain GothicVania hero frames normalized for the Godot player controller.",
        "animations": manifest_anims,
    }, indent=2), encoding="utf-8")
    return {"player/manifest.json": "Ansimuz GothicVania Cemetery hero"}


def main() -> None:
    if not GOTHIC_ROOT.exists():
        raise SystemExit(f"Missing GothicVania source: {GOTHIC_ROOT}")
    used: dict[str, str] = {}
    used.update(make_backgrounds())
    used.update(make_demo_sprites())
    used.update(make_player_assets())
    ASSET_MANIFEST.write_text(json.dumps({
        "generated_by": "tools/build_gothicvania_asset_replacements.py",
        "primary_source": "Ansimuz GothicVania Cemetery",
        "primary_license": "Public domain / CC0-like, commercial use allowed, credit not required for artwork",
        "primary_source_url": "https://opengameart.org/content/gothicvania-cemetery-pack",
        "secondary_source": "Kenney Platformer Art Deluxe",
        "secondary_license": "Creative Commons CC0",
        "secondary_source_url": "https://kenney.nl/assets/platformer-art-deluxe",
        "local_primary_source": str(GOTHIC_ROOT.parents[1].relative_to(ROOT)).replace("\\", "/"),
        "runtime_targets": used,
    }, indent=2), encoding="utf-8")
    print(f"GOTHICVANIA_ASSET_REPLACEMENT_PASS targets={len(used)} source=Ansimuz_GothicVania")


if __name__ == "__main__":
    main()
