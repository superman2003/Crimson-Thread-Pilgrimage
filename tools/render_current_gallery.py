"""Render the current asset gallery from manifests and chapter configuration.

Run from a checkout with Python 3.10+ and Pillow: python tools/render_current_gallery.py
Outputs are diagrams/contact sheets, not captured gameplay frames.
"""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/current_gallery'
FONT = ROOT / 'godot/assets/fonts/NotoSansSC.ttf'
STEMS = ['demo_ch01_moss_bell_court', 'demo_ch02_rain_foundry_canal',
         'demo_ch03_saltwhite_archive', 'demo_ch04_broken_string_greenhouse',
         'demo_ch05_obsidian_pilgrim_road', 'demo_ch06_silent_crown_core']
THEMES = ['moss_cavern', 'rain_foundry', 'salt_archive', 'string_greenhouse',
          'obsidian_pilgrim', 'silent_crown']
BG = '#111a22'
INK = '#edf0e8'


def font(size):
    return ImageFont.truetype(str(FONT), size)


def label(draw, xy, text, size=24, fill=INK):
    draw.text(xy, text, font=font(size), fill=fill)


def save(im, name):
    im.convert('RGB').save(OUT / name, quality=88, optimize=True)
    return name


def cutout(kind):
    folder = ROOT / 'godot/assets/sprites/original_creatures' / kind
    manifest = json.loads((folder / 'manifest.json').read_text())
    idle = next(a for a in manifest['animations'] if a['name'] == 'idle')
    frame = idle['frames'][0]
    source = ROOT / 'godot' / frame['atlas'].removeprefix('res://')
    with Image.open(source) as atlas:
        x, y, w, h = frame['region']
        assert w > 0 and h > 0 and x + w <= atlas.width and y + h <= atlas.height
        crop = atlas.convert('RGBA').crop((x, y, x + w, y + h))
    return crop


def sheet(items, title, name, columns=4, cell=(400, 330)):
    cw, ch = cell
    rows = math.ceil(len(items) / columns)
    im = Image.new('RGB', (cw * columns, rows * ch + 125), BG)
    draw = ImageDraw.Draw(im)
    label(draw, (28, 18), title, 36)
    label(draw, (28, 74), '当前素材 · idle 首帧 · 独立适配展示尺寸，非实际体型比例', 22, '#a9bebf')
    for i, item in enumerate(items):
        x, y = (i % columns) * cw, (i // columns) * ch + 125
        draw.rounded_rectangle((x + 8, y + 8, x + cw - 8, y + ch - 8), 14, '#1c2930')
        art = cutout(item['kind'])
        art.thumbnail((cw - 45, ch - 100), Image.Resampling.LANCZOS)
        im.paste(art, (x + (cw - art.width) // 2, y + 15 + (ch - 100 - art.height) // 2), art)
        parts = item['kind'].split('_')
        lines, line = [], ''
        for part in parts:
            candidate = line + ('_' if line else '') + part
            if draw.textlength(candidate, font=font(20)) > cw - 30:
                lines.append(line); line = part
            else:
                line = candidate
        lines.append(line)
        for j, line in enumerate(lines):
            label(draw, (x + 16, y + ch - 78 + j * 23), line, 20)
        chapter = THEMES.index(item['theme']) + 1
        motion = {'ground': '地面', 'flight': '飞行', 'stationary': '定点'}.get(item['motion'], item['motion'])
        detail = item.get('display_name', motion)
        label(draw, (x + 16, y + ch - 29), f'第 {chapter} 章 · {detail}', 17, '#a9bebf')
    save(im, name)


def full_map(config, number):
    im = Image.new('RGB', (2200, 1900), BG)
    draw = ImageDraw.Draw(im)
    title = config.get('chapter_name', config['name'])
    label(draw, (35, 18), f'第 {number} 章 · {title} · 完整地图布局', 42)
    label(draw, (35, 85), '由当前章节 JSON 生成；保持世界坐标比例，非实机全景截图。', 25, '#a9bebf')
    w, h = config['world']['width'], config['world']['height']
    scale = min(2100 / w, 1590 / h)
    ox, oy = (2200 - w * scale) / 2, 155
    def pt(p): return (ox + p[0] * scale, oy + p[1] * scale)
    draw.rectangle((ox, oy, ox + w * scale, oy + h * scale), fill='#16242c', outline='#425861', width=2)
    # Room bounds provide topology context; actual playable terrain is drawn above.
    for room in config.get('map_rooms', []):
        rect = room.get('layout_rect')
        if not rect: continue
        x, y, rw, rh = rect
        a, b = pt((x, y)), pt((x + rw, y + rh))
        draw.rectangle((*a, *b), outline='#41525a', width=2)
        label(draw, (a[0] + 5, a[1] + 4), room.get('name', room['id']), 18, '#afbec2')
    for terrain in config.get('terrain', []):
        surface = terrain['surface']
        depth = terrain.get('depth', 100)
        polygon = surface + [[x, y + depth] for x, y in reversed(surface)]
        draw.polygon([pt(p) for p in polygon], fill='#658078')
        draw.line([pt(p) for p in surface], fill='#c7e0ae', width=4)
    for platform in config.get('platforms', []):
        if platform.get('terrain_id'): continue
        x, y, pw, ph = platform['rect']
        draw.rectangle((*pt((x, y)), *pt((x + pw, y + max(ph, 15)))), fill='#9aaba1')
    def marker(position, color, r=5, symbol=None):
        if not position: return
        x, y = pt(position)
        draw.ellipse((x-r, y-r, x+r, y+r), fill=color, outline=BG, width=1)
        if symbol: label(draw, (x+7, y-13), symbol, 21, color)
    for obj in config.get('enemy_spawns', []): marker(obj.get('position'), '#e78c7c', 4)
    for obj in config.get('collectibles', []): marker(obj.get('position'), '#d8c488', 4)
    for obj in config.get('save_points', []): marker(obj.get('position'), '#8dcbea', 7, 'S')
    for obj in config.get('npcs', []): marker(obj.get('position'), '#c4a0e6', 6, 'N')
    for obj in config.get('interactives', []):
        if obj.get('kind') == 'chapter_exit': marker(obj.get('position'), '#83e6a6', 8, 'E')
    marker(config['player_start'], '#ffffff', 8, 'P')
    marker(config.get('boss', {}).get('position'), '#ff5c7a', 12, 'B')
    label(draw, (35, 1790), 'P 出生点   B Boss   E 章节出口   S 存档   N NPC   ● 小怪（珊瑚红） / 拾取物（金色）', 25)
    label(draw, (35, 1840), f'世界范围 {w} × {h} · 地形表面/平台/房间边界均来自当前配置', 23, '#a9bebf')
    return save(im, config['id'] + '_full_map.jpg')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    designs = json.loads((ROOT / 'godot/data/original_creature_designs.json').read_text())['designs']
    monsters = [d for d in designs if not d['boss']]
    bosses = [d for d in designs if d['boss']]
    assert len(monsters) == 40 and len(bosses) == 6
    assert len({d['kind'] for d in designs}) == 46
    for stem in STEMS:
        boss = json.loads((ROOT / 'godot/data' / (stem + '.json')).read_text())['boss']
        next(d for d in bosses if d['kind'] == boss['kind'])['display_name'] = boss['name']
    sheet(monsters, '40 种小怪 · 六章素材总览', 'monsters_all.jpg', 8, (350, 330))
    sheet(bosses, '6 位 Boss · 六章素材总览', 'bosses_all.jpg', 3, (650, 500))
    chapters = []
    overview = Image.new('RGB', (2400, 1590), BG)
    for index, (stem, theme) in enumerate(zip(STEMS, THEMES)):
        config_path = ROOT / 'godot/data' / (stem + '.json')
        config = json.loads(config_path.read_text())
        map_file = full_map(config, index + 1)
        enemy_file = f'ch{index + 1:02d}_enemies.jpg'
        chapter_monsters = [d for d in monsters if d['theme'] == theme]
        sheet(chapter_monsters, f'第 {index + 1} 章 · {len(chapter_monsters)} 种小怪', enemy_file)
        with Image.open(OUT / map_file) as source:
            thumb = source.copy(); thumb.thumbnail((790, 780), Image.Resampling.LANCZOS)
            overview.paste(thumb, ((index % 3) * 800 + (800-thumb.width)//2, (index//3)*790))
        chapters.append({'chapter': index + 1, 'config': stem, 'name': config.get('chapter_name', config['name']),
                         'map': map_file, 'enemies': enemy_file, 'monster_count': len(chapter_monsters),
                         'boss': config['boss']['kind'], 'boss_name': config['boss']['name'],
                         'config_sha256': hashlib.sha256(config_path.read_bytes()).hexdigest()})
    save(overview, 'map_overview.jpg')
    (OUT / 'index.json').write_text(json.dumps({'monster_count': 40, 'boss_count': 6,
        'map_type': 'configuration layout diagram, not gameplay screenshot', 'chapters': chapters}, ensure_ascii=False, indent=2) + '\n')
    print(f'Rendered {len(list(OUT.glob("*.jpg")))} images; 40 monsters, 6 bosses, 6 complete layouts.')


if __name__ == '__main__':
    main()
