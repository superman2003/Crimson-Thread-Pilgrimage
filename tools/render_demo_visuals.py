from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
DATA_DIR = GODOT / "data"
OUT_DIR = ROOT / "artifacts" / "godot_showcase"
MAP_DIR = OUT_DIR / "chapter_maps"
BESTIARY_DIR = OUT_DIR / "bestiary"

CHAPTER_FILES = [
    "demo_ch01_moss_bell_court.json",
    "demo_ch02_rain_foundry_canal.json",
    "demo_ch03_saltwhite_archive.json",
    "demo_ch04_broken_string_greenhouse.json",
    "demo_ch05_obsidian_pilgrim_road.json",
    "demo_ch06_silent_crown_core.json",
]

THEME_BACKGROUNDS = {
    "moss_cavern": "res://assets/sprites/gothicvania/demo/bg_ch01_sky.png",
    "rain_foundry": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_073.png",
    "salt_archive": "res://assets/third_party/gothicvania_cemetery/graveyard.png",
    "string_greenhouse": "res://assets/third_party/kenney_platformer_deluxe/bg.png",
    "obsidian_pilgrim": "res://assets/third_party/kenney_platformer_deluxe/bg_castle.png",
    "silent_crown": "res://assets/third_party/godot_platformer_2d/mountains.png",
}


def main() -> None:
    MAP_DIR.mkdir(parents=True, exist_ok=True)
    BESTIARY_DIR.mkdir(parents=True, exist_ok=True)
    chapters = [load_json(DATA_DIR / name) for name in CHAPTER_FILES]
    map_paths = [render_chapter_map(chapter, index + 1) for index, chapter in enumerate(chapters)]
    map_sheet = render_map_contact_sheet(map_paths)
    bestiary_sheet = render_configured_bestiary(chapters)
    source_sheet = render_source_bestiary()
    print("RENDER_DEMO_VISUALS_PASS")
    for path in map_paths + [map_sheet, bestiary_sheet, source_sheet]:
        print(path)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def res_path(path: str) -> Path:
    if path.startswith("res://"):
        return GODOT / path.removeprefix("res://")
    return ROOT / path


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


FONT_16 = font(16)
FONT_18 = font(18)
FONT_22 = font(22)
FONT_30 = font(30)


def render_chapter_map(chapter: dict[str, Any], chapter_index: int) -> Path:
    width, height = 1920, 900
    margin_x, top, bottom = 70, 98, 70
    world = chapter.get("world", {})
    world_width = float(world.get("width", 4096))
    world_height = float(world.get("height", 720))
    scale_x = (width - margin_x * 2) / world_width
    scale_y = (height - top - bottom) / max(world_height, 1.0)
    theme = chapter.get("art_theme", "moss_cavern")
    image = background_canvas(theme, width, height)
    draw = ImageDraw.Draw(image, "RGBA")

    title = f"CH{chapter_index:02d}  {chapter.get('name', chapter.get('id', 'chapter'))}"
    draw.text((34, 22), title, fill=(246, 226, 142, 255), font=FONT_30)
    draw.text((34, 60), f"{chapter.get('map_title', '')}  width={int(world_width)}  enemies={len(chapter.get('enemy_spawns', []))}",
              fill=(172, 232, 220, 255), font=FONT_18)

    def sx(x: float) -> int:
        return int(margin_x + x * scale_x)

    def sy(y: float) -> int:
        return int(top + y * scale_y)

    uses_layout_rects = any(isinstance(room.get("layout_rect"), list) and len(room.get("layout_rect", [])) >= 4 for room in chapter.get("map_rooms", []))
    for room_index, room in enumerate(chapter.get("map_rooms", [])):
        color = (80, 120, 125, 38) if room_index % 2 == 0 else (140, 110, 70, 34)
        label = str(room.get("id", room_index))
        layout_rect = room.get("layout_rect", [])
        if uses_layout_rects and isinstance(layout_rect, list) and len(layout_rect) >= 4:
            x, y, w, h = [float(v) for v in layout_rect[:4]]
            draw.rectangle((sx(x), sy(y), sx(x + w), sy(y + h)), fill=color, outline=(180, 220, 210, 58), width=1)
            draw.text((sx(x) + 4, sy(y) + 4), label[:16], fill=(170, 210, 204, 210), font=FONT_16)
            continue
        left, right = room.get("range", [0, 0])[:2]
        draw.rectangle((sx(float(left)), top, sx(float(right)), height - bottom), fill=color)
        draw.line((sx(float(left)), top, sx(float(left)), height - bottom), fill=(180, 220, 210, 38), width=1)
        draw.text((sx(float(left)) + 5, height - bottom + 12), label[:22], fill=(150, 180, 174, 210), font=FONT_16)

    for platform in chapter.get("platforms", []):
        x, y, w, h = [float(v) for v in platform.get("rect", [0, 0, 0, 0])[:4]]
        platform_id = str(platform.get("id", ""))
        lowered = platform_id.lower()
        color = hex_to_rgba(str(platform.get("color", "333333")), 235)
        if "wall" in lowered or "gate" in lowered or "locked" in lowered:
            color = (77, 104, 112, 220)
            outline = (127, 219, 220, 185)
        else:
            outline = (215, 238, 190, 150)
        rect = (sx(x), sy(y), sx(x + w), sy(y + h))
        draw.rectangle(rect, fill=color, outline=outline, width=1)
        if "boss" in str(platform.get("material", "")) or "boss" in lowered:
            draw.rectangle(rect, outline=(255, 184, 76, 210), width=2)

    for hazard in chapter.get("hazards", []):
        px, py = [float(v) for v in hazard.get("position", [0, 0])[:2]]
        diamond(draw, sx(px), sy(py), 7, (255, 86, 61, 235))

    for save in chapter.get("save_points", []):
        px, py = [float(v) for v in save.get("position", [0, 0])[:2]]
        draw.ellipse((sx(px) - 9, sy(py) - 18, sx(px) + 9, sy(py)), fill=(95, 248, 218, 230), outline=(220, 255, 246, 230), width=2)

    for npc in chapter.get("npcs", []):
        px, py = [float(v) for v in npc.get("position", [0, 0])[:2]]
        draw.rounded_rectangle((sx(px) - 7, sy(py) - 26, sx(px) + 7, sy(py)), radius=4, fill=(89, 176, 255, 225))

    for enemy in chapter.get("enemy_spawns", []):
        draw_actor_icon(image, enemy, sx, sy, 46, (245, 86, 72, 255))

    boss = chapter.get("boss", {})
    if boss:
        draw_actor_icon(image, boss, sx, sy, 78, (255, 196, 65, 255))
        bx, by = [float(v) for v in boss.get("position", [0, 0])[:2]]
        draw.text((sx(bx) - 34, sy(by) - 96), "BOSS", fill=(255, 211, 92, 255), font=FONT_18)

    exit_area = first_exit(chapter.get("interactives", []))
    if exit_area:
        px, py = [float(v) for v in exit_area.get("position", [0, 0])[:2]]
        draw.rectangle((sx(px) - 10, sy(py) - 44, sx(px) + 10, sy(py) + 4), fill=(92, 236, 255, 230))
        draw.text((sx(px) + 14, sy(py) - 42), "EXIT", fill=(141, 240, 255, 240), font=FONT_18)

    legend_x = width - 470
    draw.rounded_rectangle((legend_x, 18, width - 30, 84), radius=8, fill=(0, 0, 0, 132), outline=(180, 236, 220, 68), width=1)
    legend = "red=enemy  gold=boss  cyan=save/exit  blue=NPC  teal=wall/gate"
    draw.text((legend_x + 16, 42), legend, fill=(225, 238, 220, 245), font=FONT_16)
    out = MAP_DIR / f"{chapter.get('id', f'ch{chapter_index:02d}')}_map.png"
    image.save(out)
    return out


def background_canvas(theme: str, width: int, height: int) -> Image.Image:
    bg_path = THEME_BACKGROUNDS.get(theme, THEME_BACKGROUNDS["moss_cavern"])
    path = res_path(bg_path)
    base = Image.new("RGBA", (width, height), (8, 14, 16, 255))
    if path.exists():
        source = Image.open(path).convert("RGBA")
        source.thumbnail((width, height), Image.Resampling.LANCZOS)
        tile = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        for x in range(0, width, max(1, source.width)):
            for y in range(0, height, max(1, source.height)):
                tile.alpha_composite(source, (x, y))
        base = Image.alpha_composite(base, tile)
    shade = Image.new("RGBA", (width, height), (0, 0, 0, 155))
    return Image.alpha_composite(base, shade)


def draw_actor_icon(image: Image.Image, actor: dict[str, Any], sx, sy, target_height: int, fallback_color: tuple[int, int, int, int]) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    px, py = [float(v) for v in actor.get("position", [0, 0])[:2]]
    x, y = sx(px), sy(py)
    sprite = crop_actor(actor)
    if sprite is None:
        draw.ellipse((x - 8, y - 28, x + 8, y - 10), fill=fallback_color)
        return
    scale = target_height / max(1, sprite.height)
    size = (max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale)))
    sprite = sprite.resize(size, Image.Resampling.NEAREST)
    image.alpha_composite(sprite, (x - sprite.width // 2, y - sprite.height))


def crop_actor(actor: dict[str, Any]) -> Image.Image | None:
    path_text = str(actor.get("sprite", ""))
    if not path_text:
        return None
    path = res_path(path_text)
    if not path.exists():
        return None
    if path.suffix.lower() == ".json":
        manifest = load_json(path)
        frame_path = first_manifest_frame(manifest)
        if frame_path is None:
            return None
        image = Image.open(res_path(frame_path)).convert("RGBA")
        return trim_transparent(image)
    image = Image.open(path).convert("RGBA")
    region = actor.get("sprite_region", [])
    if isinstance(region, list) and len(region) >= 4:
        x, y, w, h = [int(float(v)) for v in region[:4]]
        image = image.crop((x, y, x + w, y + h))
    return trim_transparent(image)


def first_manifest_frame(manifest: dict[str, Any]) -> str | None:
    for animation in manifest.get("animations", []):
        if not isinstance(animation, dict):
            continue
        if str(animation.get("name", "")) != "idle":
            continue
        frames = animation.get("frames", [])
        if frames:
            return str(frames[0])
    for animation in manifest.get("animations", []):
        if not isinstance(animation, dict):
            continue
        frames = animation.get("frames", [])
        if frames:
            return str(frames[0])
    return None


def trim_transparent(image: Image.Image) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


def render_map_contact_sheet(paths: list[Path]) -> Path:
    thumbs: list[Image.Image] = []
    for path in paths:
        image = Image.open(path).convert("RGBA")
        image.thumbnail((900, 420), Image.Resampling.LANCZOS)
        thumbs.append(image.copy())
    sheet = Image.new("RGBA", (1900, 1450), (6, 10, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((34, 24), "Six Chapter Map Overview", fill=(246, 226, 142, 255), font=FONT_30)
    for index, thumb in enumerate(thumbs):
        col = index % 2
        row = index // 2
        x = 34 + col * 930
        y = 82 + row * 442
        sheet.alpha_composite(thumb, (x, y))
        draw.rectangle((x, y, x + thumb.width, y + thumb.height), outline=(170, 220, 210, 110), width=2)
    out = OUT_DIR / "six_chapter_maps_contact_sheet.png"
    sheet.save(out)
    return out


def render_configured_bestiary(chapters: list[dict[str, Any]]) -> Path:
    entries = configured_monster_entries(chapters)
    card_w, card_h = 440, 220
    cols = 3
    rows = math.ceil(len(entries) / cols)
    sheet = Image.new("RGBA", (cols * card_w + 40, rows * card_h + 96), (10, 13, 15, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((24, 24), "Configured Monsters and Bosses", fill=(246, 226, 142, 255), font=FONT_30)
    for index, entry in enumerate(entries):
        col = index % cols
        row = index // cols
        x = 20 + col * card_w
        y = 78 + row * card_h
        draw.rounded_rectangle((x, y, x + card_w - 16, y + card_h - 14), radius=8,
                               fill=(22, 29, 32, 255), outline=(93, 142, 136, 150), width=1)
        frames = actor_frames(entry["actor"])
        if frames:
            if len(frames) == 1:
                sprite = frames[0]
                sprite.thumbnail((132, 132), Image.Resampling.NEAREST)
                sheet.alpha_composite(sprite, (x + 18 + (132 - sprite.width) // 2, y + 28 + (132 - sprite.height) // 2))
            else:
                labels = ["I", "W", "A", "H", "D"]
                for frame_index, frame in enumerate(frames[:5]):
                    slot_x = x + 16 + frame_index * 36
                    slot_y = y + 42
                    draw.rectangle((slot_x, slot_y, slot_x + 32, slot_y + 76), fill=(11, 16, 18, 230),
                                   outline=(92, 150, 144, 150), width=1)
                    sprite = frame.copy()
                    sprite.thumbnail((30, 56), Image.Resampling.NEAREST)
                    sheet.alpha_composite(sprite, (slot_x + 1 + (30 - sprite.width) // 2, slot_y + 9 + (56 - sprite.height) // 2))
                    draw.text((slot_x + 11, slot_y + 58), labels[frame_index], fill=(185, 225, 216, 230), font=FONT_16)
        chapter_label = f"CH{entry['chapter']:02d} {'BOSS' if entry['boss'] else 'ENEMY'}"
        draw.text((x + 214, y + 24), chapter_label, fill=(255, 200, 91, 255), font=FONT_16)
        draw.text((x + 214, y + 50), entry["kind"][:26], fill=(232, 240, 226, 255), font=FONT_18)
        draw.text((x + 214, y + 78), Path(str(entry["actor"].get("sprite", ""))).name[:30], fill=(154, 190, 185, 245), font=FONT_16)
        draw.text((x + 214, y + 104), f"region {entry['actor'].get('sprite_region', [])}", fill=(132, 158, 154, 245), font=FONT_16)
    out = BESTIARY_DIR / "configured_monsters_contact_sheet.png"
    sheet.save(out)
    return out


def actor_frames(actor: dict[str, Any]) -> list[Image.Image]:
    path_text = str(actor.get("sprite", ""))
    if not path_text:
        return []
    path = res_path(path_text)
    if not path.exists():
        return []
    if path.suffix.lower() != ".json":
        sprite = crop_actor(actor)
        return [sprite] if sprite is not None else []
    manifest = load_json(path)
    paths: list[str] = []
    for name in ["idle", "walk", "attack", "hurt", "death"]:
        for animation in manifest.get("animations", []):
            if not isinstance(animation, dict) or str(animation.get("name", "")) != name:
                continue
            frames = animation.get("frames", [])
            if frames:
                paths.append(str(frames[0]))
                break
    result: list[Image.Image] = []
    for frame_path in paths:
        real_path = res_path(frame_path)
        if real_path.exists():
            result.append(trim_transparent(Image.open(real_path).convert("RGBA")))
    return result


def configured_monster_entries(chapters: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for chapter_index, chapter in enumerate(chapters, start=1):
        for actor in list(chapter.get("enemy_spawns", [])) + ([chapter.get("boss", {})] if chapter.get("boss") else []):
            kind = str(actor.get("kind", "monster"))
            signature = json.dumps({
                "chapter": chapter_index,
                "kind": kind,
                "sprite": actor.get("sprite", ""),
                "region": actor.get("sprite_region", []),
                "boss": actor is chapter.get("boss", {}),
            }, sort_keys=True)
            if signature in seen:
                continue
            seen.add(signature)
            result.append({
                "chapter": chapter_index,
                "kind": kind,
                "boss": actor is chapter.get("boss", {}),
                "actor": actor,
            })
    return result


def render_source_bestiary() -> Path:
    source_dir = GODOT / "assets" / "third_party" / "dark_fantasy_bestiary"
    files = sorted(source_dir.glob("*.png"))
    card_w, card_h = 310, 180
    cols = 3
    rows = math.ceil(len(files) / cols)
    sheet = Image.new("RGBA", (cols * card_w + 40, rows * card_h + 96), (10, 13, 15, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((24, 24), "Dark Fantasy Bestiary Source PNGs", fill=(246, 226, 142, 255), font=FONT_30)
    for index, path in enumerate(files):
        col = index % cols
        row = index // cols
        x = 20 + col * card_w
        y = 78 + row * card_h
        draw.rounded_rectangle((x, y, x + card_w - 14, y + card_h - 12), radius=8,
                               fill=(22, 29, 32, 255), outline=(93, 142, 136, 150), width=1)
        sprite = trim_transparent(Image.open(path).convert("RGBA"))
        sprite.thumbnail((118, 118), Image.Resampling.NEAREST)
        sheet.alpha_composite(sprite, (x + 18 + (118 - sprite.width) // 2, y + 24 + (118 - sprite.height) // 2))
        draw.text((x + 152, y + 28), path.name[:24], fill=(232, 240, 226, 255), font=FONT_16)
        draw.text((x + 152, y + 58), f"{path.stat().st_size // 1024} KB", fill=(154, 190, 185, 245), font=FONT_16)
    out = BESTIARY_DIR / "dark_fantasy_source_contact_sheet.png"
    sheet.save(out)
    return out


def first_exit(interactives: list[dict[str, Any]]) -> dict[str, Any] | None:
    for item in interactives:
        if item.get("kind") in {"chapter_exit", "ending_exit"}:
            return item
    return None


def diamond(draw: ImageDraw.ImageDraw, x: int, y: int, radius: int, color: tuple[int, int, int, int]) -> None:
    draw.polygon([(x, y - radius), (x + radius, y), (x, y + radius), (x - radius, y)], fill=color)


def hex_to_rgba(hex_text: str, alpha: int) -> tuple[int, int, int, int]:
    text = hex_text.strip().removeprefix("#")
    if len(text) != 6:
        return (64, 72, 70, alpha)
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), alpha)


if __name__ == "__main__":
    main()
