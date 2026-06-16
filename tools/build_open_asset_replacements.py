from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[1]
KENNEY_ROOT = ROOT / "artifacts" / "source_assets" / "kenney" / "platformer-art-deluxe"
DEMO_DIR = ROOT / "godot" / "assets" / "sprites" / "demo"
PLAYER_DIR = ROOT / "godot" / "assets" / "sprites" / "lumen"
FRAME_DIR = PLAYER_DIR / "frames"
SHEET_DIR = PLAYER_DIR / "sheets"
MANIFEST_PATH = PLAYER_DIR / "lumen_animations_manifest.json"
PREVIEW_PATH = PLAYER_DIR / "lumen_animation_preview.png"
ASSET_MANIFEST = ROOT / "godot" / "assets" / "sprites" / "open_asset_manifest.json"


def src(relative: str) -> Path:
    path = KENNEY_ROOT / relative
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def open_rgba(relative: str) -> Image.Image:
    return Image.open(src(relative)).convert("RGBA")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def tint(image: Image.Image, color: tuple[int, int, int], strength: float = 0.28) -> Image.Image:
    base = image.convert("RGBA")
    overlay = Image.new("RGBA", base.size, (*color, 0))
    alpha = base.getchannel("A")
    overlay.putalpha(alpha.point(lambda value: int(value * strength)))
    return Image.alpha_composite(base, overlay)


def fit_to_canvas(
    image: Image.Image,
    canvas_size: tuple[int, int],
    target_height: int,
    x_offset: int = 0,
    y_offset: int = 0,
) -> Image.Image:
    source = image.convert("RGBA")
    scale = target_height / max(1, source.height)
    target_size = (max(1, int(source.width * scale)), max(1, int(source.height * scale)))
    source = source.resize(target_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_size[0] - source.width) // 2 + x_offset
    y = canvas_size[1] - source.height + y_offset
    canvas.alpha_composite(source, (x, y))
    return canvas


def tile_pattern(tile_paths: list[str], size: tuple[int, int], tint_color: tuple[int, int, int] | None = None) -> Image.Image:
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    tiles = [open_rgba(path) for path in tile_paths]
    x = 0
    index = 0
    while x < size[0]:
        tile = tiles[index % len(tiles)]
        if tint_color is not None:
            tile = tint(tile, tint_color, 0.22)
        tile = tile.resize((70, 70), Image.Resampling.LANCZOS)
        output.alpha_composite(tile, (x, max(0, size[1] - 70)))
        x += 70
        index += 1
    return output.resize(size, Image.Resampling.LANCZOS)


def compose_asset(layers: list[tuple[Image.Image, tuple[int, int]]], size: tuple[int, int]) -> Image.Image:
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    for image, position in layers:
        output.alpha_composite(image.convert("RGBA"), position)
    return output


def make_backgrounds() -> dict[str, str]:
    width, height = 8192, 720
    base_bg = open_rgba("Base pack/bg_castle.png").resize((720, 720), Image.Resampling.BICUBIC)
    mushroom_bg = open_rgba("Mushroom expansion/Backgrounds/bg_grasslands.png").resize((720, 720), Image.Resampling.BICUBIC)
    sky = Image.new("RGBA", (width, height), (90, 128, 166, 255))
    draw = ImageDraw.Draw(sky)
    for y in range(height):
        t = y / height
        r = int(58 + 38 * (1 - t))
        g = int(92 + 55 * (1 - t))
        b = int(126 + 64 * (1 - t))
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    far = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    mid = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    near = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for x in range(-180, width, 690):
        far.alpha_composite(tint(base_bg, (38, 58, 70), 0.42), (x, 72))
    for x in range(-120, width, 720):
        mid.alpha_composite(tint(mushroom_bg, (36, 74, 58), 0.28), (x, 60))

    grass = open_rgba("Base pack/Tiles/grassMid.png")
    stone = open_rgba("Base pack/Tiles/stoneMid.png")
    bush = open_rgba("Base pack/Items/bush.png")
    plant = open_rgba("Base pack/Items/plant.png")
    for x in range(0, width, 70):
        near.alpha_composite(grass, (x, 615))
        if x % 280 == 0:
            near.alpha_composite(stone, (x, 545))
        if x % 350 == 0:
            near.alpha_composite(bush, (x + 10, 574))
        if x % 490 == 0:
            near.alpha_composite(plant, (x + 28, 573))

    fog = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    fog_draw = ImageDraw.Draw(fog)
    for x in range(-240, width, 520):
        fog_draw.ellipse((x, 470, x + 480, 650), fill=(190, 225, 205, 34))

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
    layers["bg_ch01_composite_preview"] = composite.resize((1365, 120), Image.Resampling.LANCZOS)
    layers["map_background_ch01"] = composite
    for name, image in layers.items():
        save_png(image, DEMO_DIR / f"{name}.png")
    return {f"{name}.png": "Kenney Platformer Art Deluxe backgrounds/tiles/items" for name in layers}


def make_demo_sprites() -> dict[str, str]:
    used: dict[str, str] = {}
    mappings: dict[str, Image.Image] = {
        "platform_moss_stone.png": tile_pattern(
            ["Base pack/Tiles/grassLeft.png", "Base pack/Tiles/grassMid.png", "Base pack/Tiles/grassRight.png"],
            (128, 128),
            (38, 78, 45),
        ),
        "platform_bronze_bridge.png": tile_pattern(
            ["Base pack/Tiles/bridge.png", "Base pack/Tiles/bridgeLogs.png"],
            (128, 128),
            (140, 96, 46),
        ),
        "platform_boss_stone.png": tile_pattern(
            ["Base pack/Tiles/castleLeft.png", "Base pack/Tiles/castleMid.png", "Base pack/Tiles/castleRight.png"],
            (128, 128),
            (92, 62, 46),
        ),
        "enemy_moss_larva.png": fit_to_canvas(tint(open_rgba("Base pack/Enemies/snailWalk1.png"), (76, 144, 74), 0.18), (116, 116), 78),
        "enemy_bronze_moth.png": fit_to_canvas(tint(open_rgba("Base pack/Enemies/flyFly1.png"), (194, 134, 64), 0.22), (116, 116), 82),
        "enemy_spore_bellmaker.png": fit_to_canvas(tint(open_rgba("Base pack/Enemies/slimeWalk1.png"), (112, 174, 92), 0.26), (116, 116), 74),
        "enemy_gear_sentinel.png": fit_to_canvas(tint(open_rgba("Base pack/Enemies/blockerMad.png"), (152, 108, 62), 0.22), (116, 116), 86),
        "boss_rust_crown_guardian.png": fit_to_canvas(tint(open_rgba("Base pack/Enemies/pokerMad.png"), (150, 86, 50), 0.18), (124, 124), 104),
        "hazard_spikes.png": fit_to_canvas(open_rgba("Base pack/Items/spikes.png"), (96, 96), 72),
        "hazard_bell.png": fit_to_canvas(open_rgba("Base pack/Items/weightChained.png"), (96, 96), 86),
        "trap_fake_moss_floor.png": tile_pattern(["Base pack/Tiles/grassHalfMid.png", "Base pack/Tiles/grassMid.png"], (112, 72), (62, 98, 54)),
        "trap_bell_gap.png": fit_to_canvas(open_rgba("Base pack/Items/springboardDown.png"), (112, 72), 62),
        "trap_spore_chest.png": fit_to_canvas(open_rgba("Base pack/Tiles/boxItemAlt.png"), (112, 72), 64),
        "trap_falling_clapper.png": fit_to_canvas(open_rgba("Base pack/Items/weightChained.png"), (112, 96), 86),
        "trap_shortcut_revenge.png": fit_to_canvas(open_rgba("Base pack/Items/bomb.png"), (112, 72), 62),
        "trap_false_lamp.png": fit_to_canvas(open_rgba("Base pack/Items/gemYellow.png"), (112, 72), 56),
        "pickup_bell_key.png": fit_to_canvas(open_rgba("Base pack/Items/keyYellow.png"), (96, 96), 72),
        "shortcut_lever.png": fit_to_canvas(open_rgba("Base pack/Items/switchMid.png"), (96, 96), 70),
    }
    door = compose_asset(
        [
            (open_rgba("Base pack/Tiles/door_closedTop.png").resize((70, 70), Image.Resampling.LANCZOS), (29, 8)),
            (open_rgba("Base pack/Tiles/door_closedMid.png").resize((70, 70), Image.Resampling.LANCZOS), (29, 70)),
            (open_rgba("Base pack/Tiles/lock_yellow.png").resize((40, 40), Image.Resampling.LANCZOS), (44, 72)),
        ],
        (128, 152),
    )
    mappings["boss_gate.png"] = door
    for name, image in mappings.items():
        save_png(image, DEMO_DIR / name)
        used[name] = "Kenney Platformer Art Deluxe"
    return used


def player_frame(relative: str, target_height: int = 104) -> Image.Image:
    return fit_to_canvas(open_rgba(relative), (128, 128), target_height)


def draw_attack_arc(frame: Image.Image, step: int, total: int, color: tuple[int, int, int, int]) -> Image.Image:
    output = frame.copy()
    draw = ImageDraw.Draw(output)
    start = -42 + step * 12
    end = 34 + step * 10
    bbox = (54, 28, 126, 98)
    draw.arc(bbox, start=start, end=end, fill=color, width=5)
    draw.arc((58, 33, 121, 94), start=start, end=end, fill=(255, 255, 255, 130), width=2)
    return output


def make_player_animation_frames() -> dict[str, list[Image.Image]]:
    walk = [f"Base pack/Player/p3_walk/PNG/p3_walk{i:02d}.png" for i in range(1, 12)]
    stand = "Base pack/Player/p3_stand.png"
    jump = "Base pack/Player/p3_jump.png"
    hurt = "Base pack/Player/p3_hurt.png"
    duck = "Base pack/Player/p3_duck.png"
    front = "Base pack/Player/p3_front.png"

    frames: dict[str, list[Image.Image]] = {
        "idle": [player_frame(stand, 104), player_frame(front, 104), player_frame(stand, 104), player_frame(front, 104), player_frame(stand, 104), player_frame(front, 104)],
        "run": [player_frame(path, 104) for path in walk[:8]],
        "jump_start": [player_frame(duck, 94), player_frame(jump, 104), player_frame(jump, 106), player_frame(jump, 108)],
        "jump_loop": [player_frame(jump, 108), player_frame(jump, 106), player_frame(jump, 108)],
        "fall": [player_frame(jump, 104), player_frame(jump, 102), player_frame(jump, 100), player_frame(jump, 98)],
        "land": [player_frame(jump, 98), player_frame(duck, 88), player_frame(front, 100), player_frame(stand, 104)],
        "dash": [player_frame(duck, 88) for _ in range(6)],
        "wall_slide": [player_frame(jump, 100) for _ in range(4)],
        "hurt": [player_frame(hurt, 100), player_frame(hurt, 98), player_frame(duck, 86), player_frame(stand, 104)],
        "death": [player_frame(hurt, 98), player_frame(hurt, 94), player_frame(duck, 86), player_frame(duck, 80), player_frame(duck, 72), player_frame(duck, 66), player_frame(duck, 60), player_frame(duck, 54)],
    }

    base_attack = [player_frame(stand, 104), player_frame(front, 104), player_frame(jump, 102), player_frame(front, 104), player_frame(stand, 104), player_frame(stand, 104)]
    frames["attack_1"] = [draw_attack_arc(frame, i, 6, (248, 222, 118, 210)) for i, frame in enumerate(base_attack)]
    attack_2_base = [player_frame(stand, 104), player_frame(front, 104), player_frame(jump, 104), player_frame(jump, 106), player_frame(front, 104), player_frame(stand, 104), player_frame(stand, 104)]
    frames["attack_2"] = [draw_attack_arc(frame, i, 7, (134, 234, 220, 210)) for i, frame in enumerate(attack_2_base)]
    frames["air_attack"] = [draw_attack_arc(player_frame(jump, 106), i, 6, (255, 246, 150, 210)) for i in range(6)]
    frames["hook_throw"] = [draw_attack_arc(player_frame(front, 104), i, 7, (118, 224, 244, 210)) for i in range(7)]
    return frames


def write_player_assets() -> dict[str, str]:
    animations = make_player_animation_frames()
    manifest_anims = []
    preview_rows: list[Image.Image] = []
    for name, images in animations.items():
        anim_dir = FRAME_DIR / name
        anim_dir.mkdir(parents=True, exist_ok=True)
        frame_paths = []
        for index, image in enumerate(images):
            frame_path = anim_dir / f"{name}_{index:02d}.png"
            save_png(image, frame_path)
            frame_paths.append(f"res://assets/sprites/lumen/frames/{name}/{name}_{index:02d}.png")

        sheet = Image.new("RGBA", (128 * len(images), 128), (0, 0, 0, 0))
        for index, image in enumerate(images):
            sheet.alpha_composite(image, (index * 128, 0))
        sheet_path = SHEET_DIR / f"kenney_p3_{name}_sheet.png"
        save_png(sheet, sheet_path)
        preview_rows.append(sheet)

        manifest_anims.append(
            {
                "name": name,
                "fps": 12 if name in {"run", "jump_start", "land", "hook_throw"} else 14 if "attack" in name or name == "dash" else 8,
                "loop": name in {"idle", "run", "jump_loop", "fall", "wall_slide"},
                "frame_count": len(images),
                "sheet": f"res://assets/sprites/lumen/sheets/kenney_p3_{name}_sheet.png",
                "frames": frame_paths,
            }
        )

    max_width = max(row.width for row in preview_rows)
    preview = Image.new("RGBA", (max_width, 128 * len(preview_rows)), (34, 38, 42, 255))
    y = 0
    for row in preview_rows:
        preview.alpha_composite(row, (0, y))
        y += 128
    save_png(preview, PREVIEW_PATH)

    manifest = {
        "character": "kenney_p3_open_source_player",
        "frame_size": [128, 128],
        "anchor": "bottom_center",
        "source": "Kenney Platformer Art Deluxe / Base pack / Player / p3",
        "origin_note": "Open-source CC0 replacement generated from Kenney Platformer Art Deluxe p3 player frames; action arcs are runtime-readable overlays composed for this prototype.",
        "animations": manifest_anims,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return {"lumen_animations_manifest.json": "Kenney Platformer Art Deluxe p3 player"}


def main() -> None:
    if not KENNEY_ROOT.exists():
        raise SystemExit(f"Missing Kenney source pack: {KENNEY_ROOT}")
    used: dict[str, str] = {}
    used.update(make_backgrounds())
    used.update(make_demo_sprites())
    used.update(write_player_assets())
    manifest = {
        "generated_by": "tools/build_open_asset_replacements.py",
        "primary_source": "Kenney Platformer Art Deluxe",
        "license": "Creative Commons CC0",
        "source_url": "https://kenney.nl/assets/platformer-art-deluxe",
        "local_source": str(KENNEY_ROOT.relative_to(ROOT)).replace("\\", "/"),
        "runtime_targets": used,
    }
    ASSET_MANIFEST.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"OPEN_ASSET_REPLACEMENT_PASS targets={len(used)} source=Kenney_CC0")


if __name__ == "__main__":
    main()
