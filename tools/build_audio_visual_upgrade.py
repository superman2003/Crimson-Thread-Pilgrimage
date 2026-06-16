from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
BREAD = ROOT / "artifacts" / "source_repos" / "bread-adventure"
GODOT = ROOT / "godot"

AUDIO_COPIES = {
    BREAD / "asset" / "music" / "cave.ogg": GODOT / "assets" / "audio" / "bgm" / "ch01_cave_loop.ogg",
    BREAD / "asset" / "music" / "boss_early.ogg": GODOT / "assets" / "audio" / "bgm" / "boss_rust_crown_loop.ogg",
    BREAD / "asset" / "sound" / "player_attack.ogg": GODOT / "assets" / "audio" / "sfx" / "player_attack.ogg",
    BREAD / "asset" / "sound" / "butter_attack_1.ogg": GODOT / "assets" / "audio" / "sfx" / "player_hook.ogg",
    BREAD / "asset" / "sound" / "player_dash.ogg": GODOT / "assets" / "audio" / "sfx" / "player_dash.ogg",
    BREAD / "asset" / "sound" / "player_jump.ogg": GODOT / "assets" / "audio" / "sfx" / "player_jump.ogg",
    BREAD / "asset" / "sound" / "player_heal.ogg": GODOT / "assets" / "audio" / "sfx" / "player_heal.ogg",
    BREAD / "asset" / "sound" / "player_hit.ogg": GODOT / "assets" / "audio" / "sfx" / "player_hurt.ogg",
    BREAD / "asset" / "sound" / "enemy_hit.ogg": GODOT / "assets" / "audio" / "sfx" / "enemy_hit.ogg",
    BREAD / "asset" / "sound" / "hammer_hit.ogg": GODOT / "assets" / "audio" / "sfx" / "heavy_hit.ogg",
    BREAD / "asset" / "sound" / "coin_collect.ogg": GODOT / "assets" / "audio" / "sfx" / "pickup.ogg",
    BREAD / "asset" / "sound" / "switch_ball_switch.ogg": GODOT / "assets" / "audio" / "sfx" / "lever.ogg",
    BREAD / "asset" / "sound" / "dialog_open.ogg": GODOT / "assets" / "audio" / "sfx" / "interact.ogg",
}


def ensure_source_exists(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing source asset: {path}")


def copy_audio_assets() -> list[Path]:
    copied: list[Path] = []
    for source, dest in AUDIO_COPIES.items():
        ensure_source_exists(source)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        copied.append(dest)
    return copied


def load_tile(name: str, size: tuple[int, int] = (64, 64)) -> Image.Image:
    path = BREAD / "asset" / "texture" / "tile" / name
    ensure_source_exists(path)
    tile = Image.open(path).convert("RGBA")
    return tile.resize(size, Image.Resampling.NEAREST)


def tile_fill(base: Image.Image, tile: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    for y in range(y0, y1, tile.height):
        for x in range(x0, x1, tile.width):
            base.alpha_composite(tile, (x, y))


def tint(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (*color, 255))
    return Image.blend(image, overlay, strength)


def add_noise(draw: ImageDraw.ImageDraw, width: int, height: int, color: tuple[int, int, int, int]) -> None:
    # Deterministic detail pattern: enough texture without random build noise.
    for x in range(0, width, 17):
        y = 22 + ((x * 7) % max(1, height - 38))
        draw.line((x, y, min(width, x + 38), min(height, y + 11)), fill=color, width=2)
    for x in range(10, width, 49):
        y = 12 + ((x * 5) % max(1, height - 28))
        draw.ellipse((x, y, x + 5, y + 3), fill=color)


def make_platform(
    dest: Path,
    lower_tile: Image.Image,
    upper_tile: Image.Image,
    accent: tuple[int, int, int, int],
    top: tuple[int, int, int, int],
    shadow: tuple[int, int, int, int],
) -> None:
    width, height = 256, 96
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    tile_fill(img, lower_tile, (0, 22, width, height))
    tile_fill(img, upper_tile, (0, 0, width, 34))
    draw = ImageDraw.Draw(img, "RGBA")

    draw.rectangle((0, 0, width, 8), fill=top)
    draw.rectangle((0, 28, width, 34), fill=accent)
    draw.rectangle((0, height - 14, width, height), fill=shadow)
    draw.line((0, 34, width, 34), fill=(12, 18, 16, 220), width=2)
    draw.line((0, height - 15, width, height - 15), fill=(10, 12, 12, 220), width=2)

    for x in range(18, width, 42):
        draw.rectangle((x, 33, x + 14, 40), fill=(20, 26, 24, 210))
        draw.ellipse((x + 3, 30, x + 11, 38), fill=accent)
    add_noise(draw, width, height, (0, 0, 0, 48))
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)


def make_map_background(dest: Path) -> None:
    width, height = 1280, 720
    img = Image.new("RGBA", (width, height), (9, 15, 17, 255))
    draw = ImageDraw.Draw(img, "RGBA")
    for i in range(18):
        x = i * 82 - 50
        draw.rectangle((x, 0, x + 28, height), fill=(24, 42, 36, 95))
        draw.arc((x - 88, 130, x + 156, 560), 180, 360, fill=(105, 92, 48, 115), width=4)
    for y in range(94, height, 78):
        draw.line((0, y, width, y - 28), fill=(80, 112, 82, 55), width=3)
    for i in range(72):
        x = (i * 137) % width
        y = (i * 61) % height
        draw.ellipse((x, y, x + 3, y + 3), fill=(140, 188, 120, 70))
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)


def build_visual_assets() -> list[Path]:
    out_dir = GODOT / "assets" / "sprites" / "gothicvania" / "demo"
    stone = ImageEnhance.Contrast(load_tile("stone.webp")).enhance(1.15)
    grass = ImageEnhance.Color(load_tile("grass_dirt.webp")).enhance(1.20)
    wood = ImageEnhance.Contrast(load_tile("wood_plank.webp")).enhance(1.25)
    metal = ImageEnhance.Contrast(load_tile("metal.webp")).enhance(1.35)
    sand_brick = ImageEnhance.Contrast(load_tile("sand_brick.webp")).enhance(1.12)

    outputs = [
        out_dir / "platform_moss_stone.png",
        out_dir / "platform_bronze_bridge.png",
        out_dir / "platform_boss_stone.png",
        out_dir / "map_background_ch01.png",
    ]
    make_platform(
        outputs[0],
        tint(stone, (30, 55, 44), 0.18),
        tint(grass, (45, 94, 52), 0.16),
        (92, 156, 76, 235),
        (116, 190, 72, 245),
        (16, 26, 22, 235),
    )
    make_platform(
        outputs[1],
        tint(wood, (98, 62, 32), 0.16),
        tint(metal, (154, 108, 55), 0.22),
        (198, 142, 64, 235),
        (232, 181, 84, 245),
        (42, 30, 22, 240),
    )
    make_platform(
        outputs[2],
        tint(sand_brick, (86, 32, 24), 0.24),
        tint(stone, (90, 44, 34), 0.18),
        (204, 92, 62, 235),
        (232, 132, 82, 245),
        (34, 18, 17, 240),
    )
    make_map_background(outputs[3])
    return outputs


def write_notice() -> Path:
    notice = GODOT / "assets" / "NOTICE.md"
    notice.write_text(
        "\n".join(
            [
                "# Third Party Asset Notice",
                "",
                "This prototype imports selected audio and texture-derived material from Bread Adventure.",
                "",
                "- Source: https://github.com/wheafun/bread-adventure",
                "- License: Apache License 2.0",
                "- Imported: music/cave.ogg, music/boss_early.ogg, selected sound/*.ogg",
                "- Texture-derived materials: stone, grass_dirt, wood_plank, metal, sand_brick tiles were processed into platform textures.",
                "",
                "The generated platform composites and wiring code in this project are project-local modifications.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return notice


def main() -> None:
    audio = copy_audio_assets()
    visuals = build_visual_assets()
    notice = write_notice()
    for path in audio + visuals + [notice]:
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
