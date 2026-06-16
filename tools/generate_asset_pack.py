from __future__ import annotations

import csv
import json
import math
import os
import random
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(os.environ.get("CRIMSON_ASSET_OUT", r"D:\3a大作_绯线远征素材"))
VERSION = "20260615_asset_planning_pass"


@dataclass(frozen=True)
class Palette:
    sky_top: str
    sky_bottom: str
    ground: str
    ground_alt: str
    accent: str
    danger: str
    mist: str


CHAPTERS: list[dict[str, Any]] = [
    {
        "index": 1,
        "roman": "I",
        "id": "moss_forge",
        "name": "翠锈钟庭",
        "motif": "钟苔、齿轮、孢雾",
        "palette": Palette("#173923", "#6a7b45", "#24341d", "#64733d", "#d5bd62", "#afe36f", "#9dd368"),
        "map": {
            "size": [3600, 900],
            "segments": ["苔阶教学区", "钟轮升降井", "孢雾冲刺廊", "锈冠钟厅"],
            "hazards": ["缓伤孢雾", "摆钟锤", "齿轮平台"],
            "boss_arena": "椭圆钟厅，中央大摆锤，左右两侧可攀平台",
        },
        "enemies": ["苔齿幼虫", "铜翅蛾", "孢囊钟匠", "齿轮巡卫", "钟苔精英"],
        "boss": "锈冠守卫",
    },
    {
        "index": 2,
        "roman": "II",
        "id": "glass_archive",
        "name": "镜雨档案馆",
        "motif": "玻璃雨、折光书页、索引棱镜",
        "palette": Palette("#0c2742", "#3f8aa1", "#173346", "#7fd5e4", "#e7fbff", "#91f7ff", "#a7f4ff"),
        "map": {
            "size": [3800, 920],
            "segments": ["折光门厅", "悬书走廊", "玻璃雨井", "司书高台"],
            "hazards": ["碎晶尖刺", "镜面反弹弹幕", "移动书脊平台"],
            "boss_arena": "三层镜台，Boss 可召唤分身弹幕",
        },
        "enemies": ["折光雀", "玻璃步卒", "索引棱镜", "镜页潜伏者", "棱镜校订者"],
        "boss": "镜雨司书",
    },
    {
        "index": 3,
        "roman": "III",
        "id": "ember_loom",
        "name": "余烬织炉",
        "motif": "熔线、煤灰、炉桥",
        "palette": Palette("#3a1010", "#a94b2b", "#3b211b", "#ffb15c", "#ffd39c", "#ff5b35", "#ff7d4b"),
        "map": {
            "size": [3900, 940],
            "segments": ["煤灰坡道", "熔线吊桥", "炉压升降场", "焰织屠房"],
            "hazards": ["熔岩池", "喷火炉口", "过热平台"],
            "boss_arena": "长条炉桥，周期性火柱切割空间",
        },
        "enemies": ["煤壳犬", "火梭织工", "炉甲突击者", "灰烬鳐", "熔线监工"],
        "boss": "焰织屠夫",
    },
    {
        "index": 4,
        "roman": "IV",
        "id": "moon_salt",
        "name": "盐月水渠",
        "motif": "浅潮、盐晶、月桥",
        "palette": Palette("#17193a", "#7761a8", "#232640", "#c6d7f3", "#f6f2cf", "#a6ecff", "#aadfff"),
        "map": {
            "size": [4000, 960],
            "segments": ["盐晶浅滩", "回潮水门", "月桥上升段", "歌姬水殿"],
            "hazards": ["潮汐喷泉", "滑盐坡", "水幕减速区"],
            "boss_arena": "半圆水殿，地面潮水周期上涨",
        },
        "enemies": ["潮面幽灯", "盐壳巡游者", "月渠吹笛手", "银潮潜袭者", "盐晶骑士"],
        "boss": "盐月歌姬",
    },
    {
        "index": 5,
        "roman": "V",
        "id": "bone_orchard",
        "name": "骨枝空园",
        "motif": "骨枝、风铃、悬空园圃",
        "palette": Palette("#112f31", "#b6c7a1", "#2b3126", "#e7e1c8", "#65e0bd", "#d9f0e0", "#e2eed0"),
        "map": {
            "size": [4200, 980],
            "segments": ["断枝入园", "风铃垂直井", "悬圃连跳区", "风骑空台"],
            "hazards": ["横向强风", "断裂骨桥", "风铃震荡波"],
            "boss_arena": "多浮台空战场，Boss 冲刺后露出破绽",
        },
        "enemies": ["空园骨燕", "风铃守望者", "根骨行者", "枝冠刺客", "骨枝园丁"],
        "boss": "骨枝风骑",
    },
    {
        "index": 6,
        "roman": "VI",
        "id": "starless_core",
        "name": "无星纺核",
        "motif": "黑线、星屑、倒悬核心",
        "palette": Palette("#080713", "#231041", "#151221", "#8e5eff", "#ff5dc8", "#7efcff", "#ff5dc8"),
        "map": {
            "size": [4400, 1020],
            "segments": ["黑线入口", "倒悬平台群", "星蚀裂隙", "纺核终厅"],
            "hazards": ["虚空脉冲", "重力翻转门", "星蚀追踪弹"],
            "boss_arena": "双层核心环，Boss 多阶段弹幕与冲刺",
        },
        "enemies": ["黑线骑兵", "星蚀浮影", "纺核观测者", "暗纹行者", "终端织卫"],
        "boss": "无星纺主",
    },
]


WEAPONS = [
    {"id": "thread_needle", "name": "绯线针", "type": "轻刃", "damage": 5, "range": 72, "cooldown": 0.24, "role": "默认高速连击"},
    {"id": "bell_sabre", "name": "钟脊弯刃", "type": "弯刃", "damage": 8, "range": 86, "cooldown": 0.42, "role": "破甲慢斩"},
    {"id": "glass_glaive", "name": "折光长镰", "type": "长柄", "damage": 7, "range": 118, "cooldown": 0.48, "role": "安全距离清怪"},
    {"id": "ember_hook", "name": "余烬钩索", "type": "钩刃", "damage": 6, "range": 96, "cooldown": 0.36, "role": "拉近与空中追击"},
    {"id": "moon_lance", "name": "盐月短枪", "type": "突刺", "damage": 9, "range": 104, "cooldown": 0.56, "role": "蓄力突刺"},
]


PLAYER = {
    "name": "线誓者",
    "hp": 8,
    "walk_speed": 260,
    "air_speed": 295,
    "jump_velocity": -710,
    "dash_speed": 760,
    "dash_cooldown": 0.74,
    "invuln_after_hit": 0.95,
}


ENEMY_ARCHETYPES = [
    {"role": "crawler", "hp": 8, "damage": 1, "speed": 58, "attack_cooldown": 1.2},
    {"role": "flyer", "hp": 7, "damage": 1, "speed": 62, "attack_cooldown": 1.4},
    {"role": "shooter", "hp": 9, "damage": 1, "speed": 0, "attack_cooldown": 1.45},
    {"role": "charger", "hp": 12, "damage": 2, "speed": 78, "attack_cooldown": 1.6},
    {"role": "elite", "hp": 16, "damage": 2, "speed": 88, "attack_cooldown": 1.1},
]


DIRS = {
    "manifest": ROOT / "00_manifest",
    "characters": ROOT / "01_characters",
    "weapons": ROOT / "02_weapons",
    "monsters": ROOT / "03_monsters",
    "bosses": ROOT / "04_bosses",
    "chapters": ROOT / "05_chapters",
    "tiles": ROOT / "06_tiles",
    "vfx_ui": ROOT / "07_vfx_ui",
    "design": ROOT / "08_design_data",
}

MANIFEST: list[dict[str, Any]] = []


def main() -> None:
    prepare_dirs()
    generate_characters()
    generate_weapons()
    generate_chapter_assets()
    generate_vfx_ui()
    write_design_data()
    write_manifest()
    print(json.dumps({
        "status": "ASSET_GENERATION_PASS",
        "root": str(ROOT),
        "asset_count": len(MANIFEST),
        "png_count": sum(1 for item in MANIFEST if item["path"].endswith(".png")),
        "version": VERSION,
    }, ensure_ascii=False, indent=2))


def prepare_dirs() -> None:
    for path in DIRS.values():
        path.mkdir(parents=True, exist_ok=True)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for item in candidates:
        if item and Path(item).exists():
            return ImageFont.truetype(item, size=size)
    return ImageFont.load_default()


def hx(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha


def blend(a: str, b: str, t: float) -> tuple[int, int, int, int]:
    ca = hx(a)
    cb = hx(b)
    return tuple(int(ca[i] + (cb[i] - ca[i]) * t) for i in range(3)) + (255,)


def save(img: Image.Image, path: Path, category: str, asset_id: str, description: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    MANIFEST.append({
        "id": asset_id,
        "category": category,
        "path": str(path),
        "size": [img.width, img.height],
        "description": description,
    })


def draw_center_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: str, size: int, bold: bool = False) -> None:
    fnt = font(size, bold)
    box = draw.textbbox((0, 0), text, font=fnt)
    draw.text((xy[0] - (box[2] - box[0]) / 2, xy[1] - (box[3] - box[1]) / 2), text, fill=fill, font=fnt)


def gradient(width: int, height: int, top: str, bottom: str) -> Image.Image:
    img = Image.new("RGBA", (width, height))
    px = img.load()
    for y in range(height):
        color = blend(top, bottom, y / max(1, height - 1))
        for x in range(width):
            px[x, y] = color
    return img


def generate_characters() -> None:
    sheet = Image.new("RGBA", (768, 192), (0, 0, 0, 0))
    labels = ["idle", "run_a", "run_b", "jump", "dash", "attack"]
    for idx, label in enumerate(labels):
        frame = Image.new("RGBA", (128, 192), (0, 0, 0, 0))
        draw_hero(frame, idx)
        sheet.alpha_composite(frame, (idx * 128, 0))
    save(sheet, DIRS["characters"] / "hero_linebound_sprite_sheet.png", "character", "hero_sprite_sheet", "线誓者 6 帧动作精灵表")

    portrait = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(portrait)
    draw.rounded_rectangle([18, 18, 494, 494], radius=34, fill=(15, 17, 26, 240), outline=hx("#ff5dc8"), width=4)
    hero = Image.new("RGBA", (256, 384), (0, 0, 0, 0))
    draw_hero(hero, 5)
    portrait.alpha_composite(hero, (128, 80))
    draw_center_text(draw, (256, 452), "线誓者", "#f6f0df", 34, True)
    save(portrait, DIRS["characters"] / "hero_linebound_portrait.png", "character", "hero_portrait", "主角头像立绘")

    stats_card = make_card("主角数值", PLAYER, "#ff5dc8", "#080713")
    save(stats_card, DIRS["characters"] / "hero_linebound_stats_card.png", "data_card", "hero_stats_card", "主角基础数值卡")


def draw_hero(img: Image.Image, frame: int) -> None:
    draw = ImageDraw.Draw(img)
    w, h = img.size
    cx = w // 2 + int(math.sin(frame * 1.3) * 5)
    cy = 76 + int(math.cos(frame * 1.1) * 4)
    face = -1 if frame == 1 else 1

    thread = [(cx - 14 * face, cy + 48), (cx - 58 * face, cy + 70), (cx - 86 * face, cy + 46)]
    draw.line(thread, fill=hx("#ff5dc8", 190), width=3)
    draw.ellipse([cx - 22, cy - 40, cx + 22, cy + 8], fill=hx("#f6f0df"), outline=hx("#171821"), width=2)
    draw.line([cx - 19, cy - 25, cx - 34, cy - 53], fill=hx("#f6f0df"), width=4)
    draw.line([cx + 19, cy - 25, cx + 34, cy - 53], fill=hx("#f6f0df"), width=4)
    draw.ellipse([cx - 10, cy - 21, cx - 4, cy - 9], fill=hx("#171821"))
    draw.ellipse([cx + 4, cy - 21, cx + 10, cy - 9], fill=hx("#171821"))
    cloak = [(cx - 24, cy + 8), (cx - 36, cy + 88), (cx + 34, cy + 88), (cx + 24, cy + 8)]
    draw.polygon(cloak, fill=hx("#c12f55"), outline=hx("#742036"))
    draw.rectangle([cx - 23, cy + 40, cx + 23, cy + 52], fill=hx("#742036"))
    if frame == 4:
        draw.line([cx - 60 * face, cy + 32, cx + 62 * face, cy + 18], fill=hx("#ffe6a7"), width=7)
        draw.line([cx - 70 * face, cy + 42, cx + 30 * face, cy + 26], fill=hx("#ff5dc8", 130), width=12)
    else:
        draw.line([cx + 12 * face, cy + 28, cx + 62 * face, cy + 4], fill=hx("#ffe6a7"), width=5)
    leg_offset = 10 if frame in (1, 3) else -8 if frame == 2 else 0
    draw.line([cx - 10, cy + 88, cx - 18 - leg_offset, cy + 132], fill=hx("#f6f0df"), width=5)
    draw.line([cx + 10, cy + 88, cx + 18 + leg_offset, cy + 132], fill=hx("#f6f0df"), width=5)


def generate_weapons() -> None:
    for idx, weapon in enumerate(WEAPONS):
        img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw_weapon_shape(draw, idx, weapon)
        draw_center_text(draw, (128, 226), weapon["name"], "#f6f0df", 20, True)
        save(img, DIRS["weapons"] / f"{idx + 1:02d}_{weapon['id']}.png", "weapon", weapon["id"], f"{weapon['name']} 武器图标")

        card = make_card(weapon["name"], weapon, "#ffe6a7", "#171821")
        save(card, DIRS["weapons"] / f"{idx + 1:02d}_{weapon['id']}_stats_card.png", "data_card", f"{weapon['id']}_stats", "武器数值卡")


def draw_weapon_shape(draw: ImageDraw.ImageDraw, idx: int, weapon: dict[str, Any]) -> None:
    draw.rounded_rectangle([34, 34, 222, 222], radius=24, fill=(18, 20, 30, 210), outline=hx("#ff5dc8"), width=3)
    colors = ["#ffe6a7", "#d5bd62", "#e7fbff", "#ffb15c", "#f6f2cf"]
    color = hx(colors[idx])
    if idx == 0:
        draw.line([64, 174, 190, 48], fill=color, width=8)
        draw.line([94, 184, 62, 154], fill=hx("#ff5dc8"), width=4)
    elif idx == 1:
        draw.arc([58, 42, 214, 206], 245, 64, fill=color, width=10)
        draw.line([78, 178, 48, 210], fill=hx("#742036"), width=10)
    elif idx == 2:
        draw.line([42, 188, 198, 48], fill=color, width=8)
        draw.polygon([(176, 38), (220, 66), (186, 96)], fill=hx("#91f7ff"), outline=color)
    elif idx == 3:
        draw.line([70, 194, 174, 62], fill=color, width=8)
        draw.arc([134, 44, 218, 128], 280, 90, fill=hx("#ff5b35"), width=8)
    else:
        draw.line([58, 196, 188, 46], fill=color, width=7)
        draw.polygon([(188, 46), (214, 78), (174, 82)], fill=hx("#a6ecff"), outline=color)
        draw.ellipse([88, 122, 134, 168], outline=hx("#a6ecff"), width=5)


def generate_chapter_assets() -> None:
    for chapter in CHAPTERS:
        generate_background(chapter)
        generate_map_preview(chapter)
        generate_tile_atlas(chapter)
        generate_monsters(chapter)
        generate_boss(chapter)


def generate_background(chapter: dict[str, Any]) -> None:
    pal: Palette = chapter["palette"]
    img = gradient(1600, 900, pal.sky_top, pal.sky_bottom)
    draw = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(chapter["id"])
    for layer in range(3):
        alpha = 55 + layer * 18
        for i in range(9):
            x = -80 + i * 220 + rng.randint(-35, 35)
            y = 90 + layer * 130 + rng.randint(-20, 32)
            draw_environment_motif(draw, chapter["index"], x, y, 150 + layer * 32, alpha)
    draw.rectangle([0, 730, 1600, 900], fill=hx(pal.ground, 235))
    save(img, DIRS["chapters"] / f"ch{chapter['index']:02d}_{chapter['id']}_background.png", "chapter_background", f"ch{chapter['index']:02d}_background", f"{chapter['name']} 背景层")


def draw_environment_motif(draw: ImageDraw.ImageDraw, chapter_index: int, x: int, y: int, size: int, alpha: int) -> None:
    color = (255, 255, 255, alpha)
    if chapter_index == 1:
        draw.ellipse([x, y, x + size, y + size], outline=color, width=8)
        draw.ellipse([x + 34, y + 34, x + size - 34, y + size - 34], outline=color, width=5)
    elif chapter_index == 2:
        pts = [(x + size * 0.5, y), (x + size, y + size * 0.78), (x + size * 0.14, y + size)]
        draw.polygon(pts, outline=color)
    elif chapter_index == 3:
        draw.rectangle([x, y + size * 0.25, x + size * 0.26, y + size], fill=color)
        draw.rectangle([x + size * 0.42, y, x + size * 0.72, y + size], fill=color)
    elif chapter_index == 4:
        for offset in range(0, size, max(24, size // 5)):
            draw.arc([x + offset, y, x + offset + size // 2, y + size // 2], 0, 180, fill=color, width=5)
    elif chapter_index == 5:
        draw.line([x + size // 2, y + size, x + size // 2, y], fill=color, width=8)
        draw.line([x + size // 2, y + size // 2, x, y + size // 4], fill=color, width=6)
        draw.line([x + size // 2, y + size // 2, x + size, y + size // 4], fill=color, width=6)
    else:
        for i in range(5):
            box = [x + i * 12, y + i * 12, x + size - i * 12, y + size - i * 12]
            draw.arc(box, i * 24, 220 + i * 18, fill=color, width=5)


def generate_map_preview(chapter: dict[str, Any]) -> None:
    pal: Palette = chapter["palette"]
    img = gradient(1600, 900, pal.sky_top, pal.sky_bottom)
    draw = ImageDraw.Draw(img, "RGBA")
    draw.rectangle([0, 760, 1600, 900], fill=hx(pal.ground, 255))
    draw.rectangle([0, 748, 1600, 760], fill=hx(pal.ground_alt, 180))

    segments = chapter["map"]["segments"]
    for i, segment in enumerate(segments):
        x0 = 60 + i * 370
        x1 = x0 + 310
        draw.rounded_rectangle([x0, 96, x1, 170], radius=14, fill=(0, 0, 0, 110), outline=hx(pal.accent), width=2)
        draw_center_text(draw, ((x0 + x1) // 2, 124), f"{chapter['roman']}-{i + 1}", "#ffffff", 22, True)
        draw_center_text(draw, ((x0 + x1) // 2, 152), segment, "#f6f0df", 20)
        for j in range(3):
            py = 620 - j * 95 - ((i + j) % 2) * 34
            draw.rounded_rectangle([x0 + j * 92, py, x0 + j * 92 + 180, py + 28], radius=8, fill=hx(pal.ground, 235), outline=hx(pal.ground_alt), width=2)
        if i < len(segments) - 1:
            draw.line([x1 + 18, 134, x1 + 48, 134], fill=hx(pal.accent), width=4)
            draw.polygon([(x1 + 48, 134), (x1 + 34, 124), (x1 + 34, 144)], fill=hx(pal.accent))

    for i, hazard in enumerate(chapter["map"]["hazards"]):
        x = 180 + i * 430
        y = 700 - i * 70
        draw.diamond((x, y), 34, fill=hx(pal.danger, 210), outline=hx("#ffffff", 180))
        draw_center_text(draw, (x + 120, y), hazard, "#ffffff", 22)

    draw.rounded_rectangle([1220, 520, 1535, 718], radius=28, fill=(0, 0, 0, 145), outline=hx(pal.danger), width=4)
    draw_center_text(draw, (1378, 566), "Boss 场", pal.danger, 30, True)
    draw_center_text(draw, (1378, 610), chapter["boss"], "#ffffff", 26, True)
    draw_center_text(draw, (800, 52), f"{chapter['name']} 地图预览", "#ffffff", 34, True)
    save(img, DIRS["chapters"] / f"ch{chapter['index']:02d}_{chapter['id']}_map_preview.png", "map_preview", f"ch{chapter['index']:02d}_map_preview", f"{chapter['name']} 关卡地图策划图")


def generate_tile_atlas(chapter: dict[str, Any]) -> None:
    pal: Palette = chapter["palette"]
    img = Image.new("RGBA", (1024, 512), hx("#000000", 0))
    draw = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(chapter["id"] + "_tile")
    for row in range(2):
        for col in range(4):
            x = col * 256
            y = row * 256
            base = pal.ground if row == 0 else pal.ground_alt
            draw.rectangle([x, y, x + 255, y + 255], fill=hx(base, 255), outline=hx(pal.accent, 120), width=3)
            for _ in range(44):
                sx = x + rng.randint(0, 244)
                sy = y + rng.randint(0, 244)
                size = rng.randint(4, 24)
                color = pal.accent if rng.random() > 0.45 else pal.danger
                draw.rectangle([sx, sy, sx + size, sy + size], fill=hx(color, rng.randint(38, 120)))
            draw_center_text(draw, (x + 128, y + 224), f"T{row + 1}-{col + 1}", "#ffffff", 24, True)
    save(img, DIRS["tiles"] / f"ch{chapter['index']:02d}_{chapter['id']}_tile_atlas.png", "tile_atlas", f"ch{chapter['index']:02d}_tile_atlas", f"{chapter['name']} 8 格 tile atlas")


def generate_monsters(chapter: dict[str, Any]) -> None:
    for idx, name in enumerate(chapter["enemies"]):
        role = ENEMY_ARCHETYPES[idx]["role"]
        img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw_creature(img, chapter, idx, boss=False)
        path = DIRS["monsters"] / f"ch{chapter['index']:02d}_{chapter['id']}" / f"{idx + 1:02d}_{role}.png"
        save(img, path, "monster", f"ch{chapter['index']:02d}_{role}", f"{chapter['name']} 普通怪：{name}")

        card_data = enemy_stats(chapter, idx)
        card = make_card(name, card_data, chapter["palette"].danger, chapter["palette"].sky_top)
        card_path = DIRS["monsters"] / f"ch{chapter['index']:02d}_{chapter['id']}" / f"{idx + 1:02d}_{role}_stats_card.png"
        save(card, card_path, "data_card", f"ch{chapter['index']:02d}_{role}_stats", f"{name} 数值卡")


def generate_boss(chapter: dict[str, Any]) -> None:
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw_creature(img, chapter, 6, boss=True)
    save(img, DIRS["bosses"] / f"ch{chapter['index']:02d}_{chapter['id']}_boss.png", "boss", f"ch{chapter['index']:02d}_boss", f"{chapter['name']} Boss：{chapter['boss']}")

    data = boss_stats(chapter)
    card = make_card(chapter["boss"], data, chapter["palette"].danger, chapter["palette"].sky_top)
    save(card, DIRS["bosses"] / f"ch{chapter['index']:02d}_{chapter['id']}_boss_stats_card.png", "data_card", f"ch{chapter['index']:02d}_boss_stats", f"{chapter['boss']} Boss 数值卡")


def draw_creature(img: Image.Image, chapter: dict[str, Any], variant: int, boss: bool) -> None:
    draw = ImageDraw.Draw(img, "RGBA")
    pal: Palette = chapter["palette"]
    w, h = img.size
    cx, cy = w // 2, h // 2
    scale = 1.8 if boss else 1.0
    color = hx(pal.danger if boss else pal.ground_alt, 235)
    accent = hx(pal.accent, 245)
    dark = hx(pal.ground, 245)
    idx = chapter["index"]

    draw.ellipse([cx - 72 * scale, cy - 68 * scale, cx + 72 * scale, cy + 68 * scale], fill=(0, 0, 0, 45))
    if idx == 1:
        draw_gear(draw, cx, cy, int(54 * scale), 12, color, accent)
        draw.ellipse([cx - 32 * scale, cy - 36 * scale, cx + 32 * scale, cy + 18 * scale], fill=dark)
    elif idx == 2:
        polygon(draw, cx, cy, int(62 * scale), 6, -math.pi / 2, color, accent)
        polygon(draw, cx, cy - int(10 * scale), int(38 * scale), 3, 0, hx("#ffffff", 75), accent)
    elif idx == 3:
        pts = [
            (cx, cy - 78 * scale),
            (cx + 58 * scale, cy - 4 * scale),
            (cx + 28 * scale, cy + 70 * scale),
            (cx - 42 * scale, cy + 62 * scale),
            (cx - 62 * scale, cy - 6 * scale),
        ]
        draw.polygon(pts, fill=color, outline=accent)
        draw.rectangle([cx - 36 * scale, cy - 12 * scale, cx + 36 * scale, cy + 8 * scale], fill=dark)
    elif idx == 4:
        draw.ellipse([cx - 72 * scale, cy - 46 * scale, cx + 72 * scale, cy + 44 * scale], fill=color, outline=accent, width=max(3, int(5 * scale)))
        for i in range(-2, 3):
            draw.arc([cx - 34 * scale + i * 22 * scale, cy + 16 * scale, cx - 2 * scale + i * 22 * scale, cy + 58 * scale], 0, 180, fill=accent, width=max(2, int(4 * scale)))
    elif idx == 5:
        draw.line([cx, cy - 90 * scale, cx, cy + 76 * scale], fill=accent, width=max(5, int(9 * scale)))
        draw.line([cx - 70 * scale, cy - 38 * scale, cx + 70 * scale, cy + 42 * scale], fill=accent, width=max(4, int(7 * scale)))
        draw.line([cx + 70 * scale, cy - 42 * scale, cx - 70 * scale, cy + 38 * scale], fill=accent, width=max(4, int(7 * scale)))
        draw.ellipse([cx - 44 * scale, cy - 34 * scale, cx + 44 * scale, cy + 54 * scale], fill=color)
    else:
        draw.ellipse([cx - 54 * scale, cy - 54 * scale, cx + 54 * scale, cy + 54 * scale], fill=dark, outline=accent, width=max(4, int(6 * scale)))
        for i in range(3):
            box = [cx - (80 - i * 18) * scale, cy - (30 - i * 4) * scale, cx + (80 - i * 18) * scale, cy + (30 - i * 4) * scale]
            draw.ellipse(box, outline=hx(pal.accent, 210), width=max(3, int(4 * scale)))
    draw_eyes(draw, cx, cy, scale, pal)
    if boss:
        draw_center_text(draw, (cx, h - 42), chapter["boss"], "#ffffff", 30, True)
    else:
        draw_center_text(draw, (cx, h - 26), chapter["enemies"][variant], "#ffffff", 20, True)


def draw_gear(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, teeth: int, fill: tuple[int, int, int, int], outline: tuple[int, int, int, int]) -> None:
    points = []
    for i in range(teeth * 2):
        r = radius if i % 2 == 0 else int(radius * 0.76)
        a = (i / (teeth * 2)) * math.tau
        points.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    draw.polygon(points, fill=fill, outline=outline)
    draw.ellipse([cx - radius * 0.35, cy - radius * 0.35, cx + radius * 0.35, cy + radius * 0.35], fill=(0, 0, 0, 70), outline=outline)


def polygon(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, sides: int, rotation: float, fill: tuple[int, int, int, int], outline: tuple[int, int, int, int]) -> None:
    points = []
    for i in range(sides):
        a = rotation + i / sides * math.tau
        points.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
    draw.polygon(points, fill=fill, outline=outline)


def draw_eyes(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float, pal: Palette) -> None:
    r = max(3, int(5 * scale))
    draw.ellipse([cx - 20 * scale - r, cy - 10 * scale - r, cx - 20 * scale + r, cy - 10 * scale + r], fill=hx("#11131b"))
    draw.ellipse([cx + 20 * scale - r, cy - 10 * scale - r, cx + 20 * scale + r, cy - 10 * scale + r], fill=hx("#11131b"))
    draw.ellipse([cx - 6 * scale, cy + 10 * scale, cx + 6 * scale, cy + 22 * scale], fill=hx(pal.accent, 230))


def generate_vfx_ui() -> None:
    items = [
        ("vfx_slash_arc", "斩击弧光", "#ffe6a7"),
        ("vfx_dash_trail", "冲刺残影", "#ff5dc8"),
        ("vfx_hit_sparks", "命中火花", "#ffb15c"),
        ("vfx_boss_break", "Boss 破防", "#7efcff"),
        ("ui_health_orb", "生命珠", "#ff4f75"),
        ("ui_thread_meter", "绯线计量", "#ff5dc8"),
        ("ui_chapter_gate", "章节门", "#d5bd62"),
        ("ui_save_seal", "存档印记", "#65e0bd"),
        ("vfx_mist_poison", "孢雾", "#afe36f"),
        ("vfx_glass_shard", "碎晶", "#91f7ff"),
        ("vfx_ember_flame", "余烬火", "#ff5b35"),
        ("vfx_void_pulse", "虚空脉冲", "#8e5eff"),
    ]
    for idx, (asset_id, label, color) in enumerate(items):
        img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img, "RGBA")
        draw.rounded_rectangle([32, 32, 224, 224], radius=28, fill=(10, 11, 18, 185), outline=hx(color), width=4)
        if "slash" in asset_id:
            draw.arc([44, 54, 226, 220], 205, 340, fill=hx(color), width=16)
        elif "dash" in asset_id:
            for i in range(5):
                draw.line([54, 76 + i * 28, 210 - i * 14, 52 + i * 28], fill=hx(color, 210 - i * 25), width=9)
        elif "sparks" in asset_id or "break" in asset_id:
            for i in range(14):
                a = i / 14 * math.tau
                draw.line([128, 128, 128 + math.cos(a) * (36 + i * 4), 128 + math.sin(a) * (36 + i * 4)], fill=hx(color), width=4)
        elif "orb" in asset_id or "meter" in asset_id:
            draw.ellipse([70, 70, 186, 186], fill=hx(color, 220), outline=hx("#ffffff", 200), width=5)
        elif "gate" in asset_id:
            draw.ellipse([72, 42, 184, 214], outline=hx(color), width=12)
            draw.ellipse([96, 76, 160, 182], fill=hx(color, 80))
        elif "seal" in asset_id:
            polygon(draw, 128, 128, 70, 8, math.pi / 8, hx(color, 80), hx(color))
            draw.ellipse([94, 94, 162, 162], outline=hx(color), width=7)
        elif "mist" in asset_id:
            for i in range(4):
                draw.ellipse([42 + i * 34, 96 - i * 6, 140 + i * 28, 174 + i * 8], fill=hx(color, 90))
        elif "shard" in asset_id:
            for i in range(5):
                polygon(draw, 72 + i * 28, 128 + (i % 2) * 16, 30, 3, -math.pi / 2, hx(color, 170), hx("#ffffff", 180))
        elif "flame" in asset_id:
            draw.polygon([(128, 48), (178, 142), (144, 214), (94, 214), (72, 140)], fill=hx(color, 210))
        else:
            for i in range(5):
                draw.ellipse([58 + i * 8, 58 + i * 8, 198 - i * 8, 198 - i * 8], outline=hx(color, 230 - i * 30), width=5)
        draw_center_text(draw, (128, 226), label, "#ffffff", 18, True)
        save(img, DIRS["vfx_ui"] / f"{idx + 1:02d}_{asset_id}.png", "vfx_ui", asset_id, label)


def make_card(title: str, data: dict[str, Any], accent: str, bg: str) -> Image.Image:
    img = Image.new("RGBA", (512, 384), hx(bg, 255))
    draw = ImageDraw.Draw(img, "RGBA")
    draw.rounded_rectangle([18, 18, 494, 366], radius=22, outline=hx(accent), width=4, fill=(0, 0, 0, 60))
    draw.text((42, 36), title, fill="#ffffff", font=font(30, True))
    y = 92
    for key, value in data.items():
        if key in {"id", "name"}:
            continue
        text = f"{key}: {value}"
        draw.text((50, y), text, fill="#f6f0df", font=font(20))
        y += 34
        if y > 330:
            break
    return img


def enemy_stats(chapter: dict[str, Any], enemy_idx: int) -> dict[str, Any]:
    base = ENEMY_ARCHETYPES[enemy_idx]
    scale = chapter["index"] - 1
    return {
        "name": chapter["enemies"][enemy_idx],
        "role": base["role"],
        "hp": base["hp"] + scale * 2,
        "damage": base["damage"] + (1 if scale >= 4 and enemy_idx >= 3 else 0),
        "speed": base["speed"] + scale * 5,
        "attack_cooldown": round(max(0.72, base["attack_cooldown"] - scale * 0.06), 2),
        "weakness": WEAPONS[(enemy_idx + chapter["index"]) % len(WEAPONS)]["name"],
    }


def boss_stats(chapter: dict[str, Any]) -> dict[str, Any]:
    idx = chapter["index"]
    return {
        "name": chapter["boss"],
        "hp": 34 + idx * 8,
        "contact_damage": 2 + (1 if idx >= 5 else 0),
        "phase_count": 2 if idx < 4 else 3,
        "attack_cooldown": round(1.65 - idx * 0.09, 2),
        "enrage_at_hp_percent": 35,
        "reward": "解锁下一章门印" if idx < 6 else "终局黑线断裂",
    }


def write_design_data() -> None:
    combat = {
        "version": VERSION,
        "player": PLAYER,
        "weapons": WEAPONS,
        "chapters": [
            {
                "chapter": item["name"],
                "enemies": [enemy_stats(item, idx) for idx in range(len(item["enemies"]))],
                "boss": boss_stats(item),
            }
            for item in CHAPTERS
        ],
    }
    maps = {
        "version": VERSION,
        "chapters": [
            {
                "id": item["id"],
                "name": item["name"],
                "motif": item["motif"],
                **item["map"],
            }
            for item in CHAPTERS
        ],
    }
    write_json(DIRS["design"] / "combat_values.json", combat, "design_data", "combat_values", "角色、武器、怪物、Boss 数值")
    write_json(DIRS["design"] / "map_plan.json", maps, "design_data", "map_plan", "6 章地图结构与机关策划")
    readme = DIRS["design"] / "README.md"
    readme.write_text(
        "# 绯线远征素材包\n\n"
        f"- 版本：{VERSION}\n"
        f"- 输出根目录：`{ROOT}`\n"
        "- 素材生成方式：Python + Pillow 程序化原创生成，不引用外部图片或音频。\n"
        "- 主要内容：主角、武器、普通怪、Boss、地图预览、背景、tile atlas、VFX/UI 图标、数值 JSON。\n",
        encoding="utf-8",
    )
    MANIFEST.append({
        "id": "asset_pack_readme",
        "category": "design_data",
        "path": str(readme),
        "size": [0, 0],
        "description": "素材包说明",
    })


def write_json(path: Path, data: dict[str, Any], category: str, asset_id: str, description: str) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    MANIFEST.append({
        "id": asset_id,
        "category": category,
        "path": str(path),
        "size": [0, 0],
        "description": description,
    })


def write_manifest() -> None:
    json_path = DIRS["manifest"] / "asset_manifest.json"
    manifest_entries = [
        *MANIFEST,
        {
            "id": "asset_manifest_json",
            "category": "manifest",
            "path": str(json_path),
            "size": [0, 0],
            "description": "素材总清单 JSON",
        },
        {
            "id": "asset_manifest_csv",
            "category": "manifest",
            "path": str(DIRS["manifest"] / "asset_manifest.csv"),
            "size": [0, 0],
            "description": "素材总清单 CSV",
        },
    ]
    json_path.write_text(json.dumps({
        "version": VERSION,
        "root": str(ROOT),
        "count": len(manifest_entries),
        "items": manifest_entries,
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    csv_path = DIRS["manifest"] / "asset_manifest.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["id", "category", "path", "size", "description"])
        writer.writeheader()
        for item in manifest_entries:
            writer.writerow({**item, "size": "x".join(map(str, item["size"]))})

    MANIFEST[:] = manifest_entries


def _diamond(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, **kwargs: Any) -> None:
    x, y = center
    draw.polygon([(x, y - radius), (x + radius, y), (x, y + radius), (x - radius, y)], **kwargs)


if not hasattr(ImageDraw.ImageDraw, "diamond"):
    ImageDraw.ImageDraw.diamond = _diamond  # type: ignore[attr-defined]


if __name__ == "__main__":
    if ROOT.drive.upper() == "C:":
        raise SystemExit("拒绝输出到 C 盘，请设置 CRIMSON_ASSET_OUT 到 D 盘。")
    main()
