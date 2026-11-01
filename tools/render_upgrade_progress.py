#!/usr/bin/env python3
"""Render final-acceptance progress from the maintained checklist (no guessed %).

SVG/JSON generation and --check use only the Python standard library.
--png additionally needs Pillow and the repository's Noto Sans SC font.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from collections import Counter
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/UPGRADE_COMPLETION_CHECKLIST.md'
OUTPUT = ROOT / 'docs/gallery/upgrade_progress'
GROUPS = {'W': '世界与探索', 'A': '能力与镜头', 'C': '战斗与线术',
          'E': '装备与构筑', 'B': '敌人与挑战', 'G': '经济与找回',
          'N': '叙事与人物', 'U': '界面与无障碍', 'V': '美术与反馈',
          'S': '音乐与声音', 'T': '教学、稳定与发布'}


def snapshot() -> dict:
    raw = SOURCE.read_bytes()
    text = raw.decode('utf-8')
    sections = re.findall(r'^## ([A-Z]\d{2}) ([^\n]+?)（(P\d[^）\n]*)）\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    tasks = []
    for code, title, priority, body in sections:
        marks = re.findall(r'^- \[([ xX])\] 最终验收：', body, re.M)
        if len(marks) != 1:
            raise ValueError(f'{code}: expected exactly one final-acceptance checkbox')
        if code[0] not in GROUPS:
            raise ValueError(f'unknown group: {code}')
        tasks.append(dict(id=code, title=title, priority=priority,
                          accepted=marks[0].lower() == 'x'))
    if len(tasks) != 46 or len({t['id'] for t in tasks}) != 46:
        raise ValueError('expected the 46 distinct task packages in the revised plan')
    done = sum(t['accepted'] for t in tasks)
    return dict(source=SOURCE.relative_to(ROOT).as_posix(),
                source_sha256=hashlib.sha256(raw).hexdigest(), total=len(tasks),
                accepted=done, open=len(tasks)-done,
                priorities=dict(sorted(Counter(t['priority'][:2] for t in tasks).items())),
                tasks=tasks)


class Canvas:
    def __init__(self, png: bool):
        self.svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1560" height="1330" viewBox="0 0 1560 1330" role="img" aria-labelledby="title desc">',
                    '<title id="title">绯线巡礼升级进度</title>',
                    '<desc id="desc">按升级完成清单的最终验收复选框统计。局部实现与流程证据不折算整体完成率。</desc>']
        self.image = None
        self.fonts = {}
        if png:
            from PIL import Image, ImageDraw
            self.image = Image.new('RGB', (1560, 1330), '#10272b')
            self.draw = ImageDraw.Draw(self.image)

    def rect(self, x, y, w, h, color, radius=0):
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{color}"/>')
        if self.image:
            self.draw.rounded_rectangle((x, y, x+w, y+h), radius=radius, fill=color)

    def text(self, x, y, text, size=22, color='#e8e2d1'):
        self.svg.append(f'<text x="{x}" y="{y}" font-family="Noto Sans SC, Microsoft YaHei, sans-serif" font-size="{size}" fill="{color}">{escape(str(text))}</text>')
        if self.image:
            from PIL import ImageFont
            if size not in self.fonts:
                self.fonts[size] = ImageFont.truetype(str(ROOT / 'godot/assets/fonts/NotoSansSC.ttf'), size)
            self.draw.text((x, y), str(text), font=self.fonts[size], fill=color, anchor='ls')


def render(data: dict, png=False) -> Canvas:
    c = Canvas(png)
    c.rect(0, 0, 1560, 1330, '#10272b')
    c.text(52, 65, '绯线巡礼 · 升级进度', 38)
    c.text(52, 105, '2026-10-24 开工快照  /  main 93365331  /  46 个任务包', 22, '#b9c5be')
    metrics = [(data['accepted'], '项最终验收通过'), (data['open'], '项仍待最终验收'),
               ('24 / 21 / 1', '项优先级 P0 / P1 / P2')]
    for i, (value, label) in enumerate(metrics):
        x = 52 + i*492
        c.rect(x, 135, 472, 116, '#1d393d', 12)
        c.text(x+24, 189, value, 40, '#d9b477')
        c.text(x+24, 227, label, 22)
    c.text(52, 295, '最终验收矩阵', 26)
    c.text(320, 295, '金色 = OPEN 待验收    绿色 = 已通过最终验收', 21, '#b9c5be')
    for row, (prefix, label) in enumerate(GROUPS.items()):
        y = 320 + row*61
        c.rect(52, y, 1456, 52, '#193236' if row % 2 == 0 else '#142c30', 6)
        tasks = [t for t in data['tasks'] if t['id'].startswith(prefix)]
        c.text(72, y+34, label, 22)
        c.text(337, y+34, f'{sum(t["accepted"] for t in tasks)}/{len(tasks)}', 22, '#b9c5be')
        for col, task in enumerate(tasks):
            x = 430 + col*174
            color = '#6ec4a3' if task['accepted'] else '#d9b477'
            c.rect(x, y+8, 156, 36, '#244247', 5)
            c.text(x+13, y+34, task['id'] + (' 已验' if task['accepted'] else ' 待验'), 20, color)
    c.text(52, 1040, '已取得的子项与流程证据（不折算整项完成率）', 25)
    c.text(70, 1086, '主顺序：六区前廊钟龛、六证言；最终 Boss 与结局仍待验证。', 23)
    c.text(70, 1126, '第二顺序：C1→C2→C3→C5→C4→C6 下环，117 步、0 死亡。', 23)
    c.text(70, 1166, 'B01：伏击／报警／支援提示已接入；自然可读性与听感仍待验。', 23)
    c.text(52, 1220, '继续推进：多构筑自然流程、人工理解／实听、整合长跑、最终发布包。', 22, '#d9b477')
    c.text(52, 1270, '口径：复选框仅表示最终验收；OPEN 不表示尚未开发。PR #227 未合入本快照。', 20, '#b9c5be')
    c.text(52, 1305, '来源：UPGRADE_COMPLETION_CHECKLIST.md · 详细证据见任务台账与本图说明。', 20, '#b9c5be')
    c.svg.append('</svg>')
    return c


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='fail if SVG/JSON differs from the checklist')
    parser.add_argument('--png', action='store_true', help='also render PNG using Pillow')
    args = parser.parse_args()
    data = snapshot()
    if data['priorities'] != {'P0': 24, 'P1': 21, 'P2': 1}:
        raise ValueError('priority counts changed; update the snapshot caption')
    canvas = render(data, png=args.png)
    files = {OUTPUT.with_suffix('.json'): json.dumps(data, ensure_ascii=False, indent=2)+'\n',
             OUTPUT.with_suffix('.svg'): '\n'.join(canvas.svg)+'\n'}
    for path, content in files.items():
        if args.check:
            if not path.exists() or path.read_text(encoding='utf-8') != content:
                raise ValueError(f'stale progress artifact: {path.relative_to(ROOT)}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding='utf-8')
    if args.png:
        if args.check:
            parser.error('--png writes a preview; use it separately from --check')
        canvas.image.save(OUTPUT.with_suffix('.png'))
    print(f'PROGRESS_PASS total={data["total"]} accepted={data["accepted"]} open={data["open"]}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
