#!/usr/bin/env python3
"""Write one image-generation brief (.md) per regular enemy plus reference strips."""
import json, math, sys
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GODOT = ROOT / 'godot'
sys.path.insert(0, str(HERE))
from design import DESIGN, ELITE

COMBAT = json.loads((GODOT / 'data/original_creature_combat.json').read_text())
DESIGNS = {d['kind']: d for d in json.loads((GODOT / 'data/original_creature_designs.json').read_text())['designs']}
REGIONS = [('demo_ch01_moss_bell_court', '第 1 區 苔鐘庭'), ('demo_ch02_rain_foundry_canal', '第 2 區 鑄雨渠'),
    ('demo_ch03_saltwhite_archive', '第 3 區 鹽白書庫'), ('demo_ch04_broken_string_greenhouse', '第 4 區 斷弦溫室'),
    ('demo_ch05_obsidian_pilgrim_road', '第 5 區 黑曜巡禮路'), ('demo_ch06_silent_crown_core', '第 6 區 靜冠核心')]
TYPE_ZH = {'melee': '近身', 'lunge': '突進', 'dive': '俯衝', 'vault': '弧躍', 'combo': '連擊', 'retreat': '退刺', 'feint': '虛晃',
    'guard': '格擋反擊', 'blink': '瞬移', 'fan': '扇射', 'projectile': '飛彈', 'mortar': '曲射', 'nova': '環射', 'pool': '落圈',
    'rootline': '地刺', 'wave': '地波', 'beam': '直線'}
TRAVEL_TYPES = {'lunge', 'dive', 'vault'}
# Game playback: one-shot wind-up/strike cels, then the loop takes over (enemy_actor.gd POSE_LOOP_LEAD).
CHARGE_FROM = 0.6
TRAVEL_FROM = 0.4

where, elite_spawns, counts = {}, {}, {}
for config, label in REGIONS:
    for spawn in json.loads((GODOT / 'data' / f'{config}.json').read_text()).get('enemy_spawns', []):
        where.setdefault(spawn['kind'], label)
        counts[spawn['kind']] = counts.get(spawn['kind'], 0) + 1
        if spawn.get('elite'):
            elite_spawns[spawn['kind']] = spawn['id']


def attack(kind, attack_id):
    for item in COMBAT[kind]['attacks'] + COMBAT[kind].get('elite', {}).get('attacks', []):
        if item['id'] == attack_id:
            return item
    raise KeyError(attack_id)


def export_reference(kind):
    manifest = json.loads((GODOT / f'assets/sprites/original_creatures/{kind}/motion_manifest.json').read_text())
    anims = {a['name']: a['frames'] for a in manifest['animations']}
    frames = [anims['idle'][0]] + anims['windup'] + anims['attack'] + anims['recover'][:1]
    atlases = {}
    cels = []
    for frame in frames:
        path = GODOT / frame['atlas'].removeprefix('res://')
        atlases.setdefault(path, Image.open(path).convert('RGBA'))
        x, y, w, h = frame['region']
        cels.append(atlases[path].crop((x, y, x + w, y + h)))
    height = max(c.height for c in cels)
    strip = Image.new('RGBA', (sum(c.width for c in cels) + 24 * (len(cels) - 1), height))
    left = 0
    for cel in cels:
        strip.alpha_composite(cel, (left, height - cel.height))
        left += cel.width + 24
    target = HERE / 'refs' / f'{kind}.png'
    target.parent.mkdir(exist_ok=True)
    strip.save(target)
    return target.relative_to(HERE)


def cel_plan(beats, item, strike_count):
    cels = [('前搖', 'wind-up', beats['windup'], 4), ('出招', 'strike', beats['strike'], strike_count), ('收招', 'recovery', beats['recover'], 4)]
    loops = []
    if beats.get('charge') and float(item['windup']) >= CHARGE_FROM:
        loops.append(('蓄力循環', 'charge loop', beats['charge'], 2))
    if beats.get('travel') and item['type'] in TRAVEL_TYPES and float(item['active']) >= TRAVEL_FROM:
        loops.append(('突進循環', 'travel loop', beats['travel'], 2))
    return cels + loops


def sheet_section(kind, title, file_name, item, beats, header):
    strike = 6 if item['type'] == 'combo' else 4
    plan = cel_plan(beats, item, strike)
    total = sum(p[3] for p in plan)
    rows = math.ceil(total / 4)
    lines = [f'### {title}', '', f'- 檔名：`{file_name}`', f'- 招式：{item["name"]}（{TYPE_ZH.get(item["type"], item["type"])}，`{item["id"]}`）',
        f'- 遊戲時長：前搖 {item["windup"]} 秒、出招 {item["active"]} 秒、收招 {item["recover"]} 秒',
        f'- 共 **{total} 格**，4 列 × {rows} 行，從左到右、從上到下依序排列', '', '| 格 | 段落 | 內容 |', '| ---: | --- | --- |']
    index = 1
    order = []
    for zh, en, text, count in plan:
        cells = f'{index}' if count == 1 else f'{index}–{index + count - 1}'
        lines.append(f'| {cells} | {zh} | {text} |')
        order.append(f'Cels {cells} ({en}, {count} cels): {text}.')
        index += count
    prompt = [header, f'Layout: exactly {total} cels on a 4-column x {rows}-row grid (1536 x {rows * 384} px canvas, one 384 px square per cel), '
        'read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.'] + order
    if any(p[1].endswith('loop') for p in plan):
        prompt.append('Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.')
    lines += ['', '提示詞：', '', '```text', '\n'.join(prompt), '```', '']
    return lines, total


def loops_section(kind, item, beats):
    plan = []
    if beats.get('keep_charge') and float(item['windup']) >= CHARGE_FROM:
        plan.append(('蓄力循環', 'charge loop', beats['keep_charge'], 'the LAST wind-up pose in the reference strip (6th sprite)'))
    if beats.get('keep_travel') and item['type'] in TRAVEL_TYPES and float(item['active']) >= TRAVEL_FROM:
        plan.append(('突進循環', 'travel loop', beats['keep_travel'], 'the SECOND strike pose in the reference strip (8th sprite)'))
    return plan


def build():
    index_rows, totals = [], {'new': 0, 'elite': 0, 'loops': 0}
    for kind in sorted(DESIGN):
        beats = DESIGN[kind]
        concept = DESIGNS[kind]['concept']
        keep, new = attack(kind, beats['keep']), attack(kind, beats['new'])
        ref = export_reference(kind)
        header = ('Use case: identity-preserve. Reference image is the existing animation strip of this exact creature '
            f'({ref.as_posix()}): {concept}. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted '
            'dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling '
            'game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical '
            'scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own '
            'cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. '
            'Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. '
            'Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all '
            'attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.')
        lines = [f'# {kind}', '', f'- 外觀：{concept}', f'- 出現：{where.get(kind, "—")}，共 {counts.get(kind, 0)} 隻',
            f'- 參考圖：`{ref.as_posix()}`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）', '',
            '## 招式安排', '', '| 招式 | 類型 | 動畫 |', '| --- | --- | --- |',
            f'| {keep["name"]} | {TYPE_ZH.get(keep["type"], keep["type"])} | 沿用現有前搖/出招/收招（參考圖那套） |',
            f'| {new["name"]} | {TYPE_ZH.get(new["type"], new["type"])} | **新畫專屬動作**：{beats["zh"]} |']
        elite = ELITE.get(kind)
        if elite:
            elite_item = attack(kind, elite['id'])
            profile = COMBAT[kind]['elite']
            lines.append(f'| {elite_item["name"]}（精英專屬） | {TYPE_ZH.get(elite_item["type"], elite_item["type"])} | **新畫專屬動作**：{elite["zh"]} |')
            lines += ['', f'**精英怪**：`{elite_spawns.get(kind, "—")}` 這一隻是精英，血量 ×{profile["hp_mult"]}（無條件進位）、所有招式傷害 +{profile["damage_bonus"]}、'
                f'體型 ×{profile["visual_scale_mult"]}，並多一招「{elite_item["name"]}」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。']
        lines += ['', '## 要生成的圖', '']
        section, count = sheet_section(kind, f'1. {new["name"]}', f'{new["id"]}.png', new, beats, header)
        lines += section
        totals['new'] += count
        sheet_no = 2
        if elite:
            section, count = sheet_section(kind, f'{sheet_no}. {elite_item["name"]}（精英）', f'{elite["id"]}.png', elite_item, elite, header)
            lines += section
            totals['elite'] += count
            sheet_no += 1
        loops = loops_section(kind, keep, beats)
        loop_count = 2 * len(loops)
        if loops:
            names = '、'.join(p[0] for p in loops)
            lines += [f'### {sheet_no}. {keep["name"]}的{names}（現有動作補循環）', '', f'- 檔名：`{keep["id"]}_loops.png`',
                f'- 共 **{loop_count} 格**，{loop_count} 列 × 1 行', '', '| 格 | 段落 | 接在哪一格後面 | 內容 |', '| ---: | --- | --- | --- |']
            order = []
            for number, (zh, en, text, after) in enumerate(loops):
                lines.append(f'| {2 * number + 1}–{2 * number + 2} | {zh} | {after} | {text} |')
                order.append(f'Cels {2 * number + 1}-{2 * number + 2} ({en}): continue seamlessly from {after}; {text}; the two cels form a seamless cycle.')
            prompt = [header, f'Layout: exactly {loop_count} cels in one row ({loop_count * 384} x 384 px canvas, one 384 px square per cel).'] + order
            lines += ['', '提示詞：', '', '```text', '\n'.join(prompt), '```', '']
            totals['loops'] += loop_count
        lines += ['## 交付', '', '- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。',
            '- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。', '']
        (HERE / f'{kind}.md').write_text('\n'.join(lines))
        index_rows.append((kind, where.get(kind, '—'), keep['name'], new['name'], elite_item['name'] if elite else '', count_cels(kind)))
    return index_rows, totals


def count_cels(kind):
    beats = DESIGN[kind]
    new = attack(kind, beats['new'])
    total = sum(p[3] for p in cel_plan(beats, new, 6 if new['type'] == 'combo' else 4))
    if kind in ELITE:
        item = attack(kind, ELITE[kind]['id'])
        total += sum(p[3] for p in cel_plan(ELITE[kind], item, 6 if item['type'] == 'combo' else 4))
    total += 2 * len(loops_section(kind, attack(kind, beats['keep']), beats))
    return total


if __name__ == '__main__':
    rows, totals = build()
    out = ['# 小怪專屬攻擊動作出圖清單（v1）', '', '每種小怪一份 md，裡面有招式安排、逐格內容和可以直接貼的提示詞。參考圖在 `refs/`。', '',
        '| 小怪 | 地區 | 沿用現有動作 | 新畫專屬動作 | 精英專屬 | 格數 |', '| --- | --- | --- | --- | --- | ---: |']
    for kind, region, keep, new, elite, cels in rows:
        out.append(f'| [{kind}]({kind}.md) | {region} | {keep} | {new} | {elite} | {cels} |')
    out += ['', f'合計：普通招式新動作 {totals["new"]} 格、精英專屬 {totals["elite"]} 格、現有動作補循環 {totals["loops"]} 格，共 {sum(totals.values())} 格。', '']
    (HERE / 'README_list.md').write_text('\n'.join(out))
    print(totals, sum(totals.values()))
