#!/usr/bin/env python3
"""Write README.md: image requests for enemy attack effects and player tool/skill effects.

Every ranged or area enemy move in original_creature_combat.json must belong to exactly one
family below; the script fails otherwise, so the list cannot silently drift from the game data.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GODOT = ROOT / 'godot'
COMBAT = json.loads((GODOT / 'data/original_creature_combat.json').read_text())

RANGED = {'projectile', 'fan', 'nova', 'mortar', 'wave', 'beam', 'pool', 'rootline', 'blink'}
DEFAULT_RADIUS = 11  # enemy_actor.gd _effect(): command.get("radius", 11)
REGION = {1: '苔鐘庭', 2: '鑄雨渠', 3: '鹽白書庫', 4: '斷弦溫室', 5: '黑曜巡禮路', 6: '靜冠核心'}
BOSS_REGION = {'rust_crown_guardian': 1, 'sunken_hammer_smith': 2, 'saltwhite_contract_judge': 3,
               'broken_string_gardener': 4, 'silent_pilgrim_commander': 5, 'silent_crown_core': 6}
BOSS_ZH = {'rust_crown_guardian': '苔鐘守母', 'sunken_hammer_smith': '緋線執剪者', 'broken_string_gardener': '銅根主教',
           'silent_pilgrim_commander': '靜音巡禮統帥', 'silent_crown_core': '無聲王冠'}
BOSS_REF = {k: f'attack_effects_v1/refs/{k}.png' for k in BOSS_ZH}
HERO_REF = 'attack_effects_v1/refs/hero_style.png'


def region_of(kind):
    if kind in BOSS_REGION:
        return BOSS_REGION[kind]
    for i, name in enumerate(['ch01_moss_bell_court', 'ch02_rain_foundry_canal', 'ch03_saltwhite_archive',
                              'ch04_broken_string_greenhouse', 'ch05_obsidian_pilgrim_road', 'ch06_silent_crown_core'], 1):
        spawns = json.loads((GODOT / f'data/demo_{name}.json').read_text())['enemy_spawns']
        if any(s['kind'] == kind for s in spawns):
            return i
    raise SystemExit(f'no region for {kind}')


def ref_of(kind):
    return BOSS_REF.get(kind, f'creature_attacks_v1/refs/{kind}.png')


MOVES = {}
for kind, profile in COMBAT.items():
    attacks = list(profile.get('attacks', [])) + [dict(a, elite=True) for a in (profile.get('elite') or {}).get('attacks', [])]
    for a in attacks:
        if a.get('type') in RANGED:
            MOVES[a['id']] = dict(a, kind=kind, region=region_of(kind))

# ---------------------------------------------------------------- families
# (file stem, 中文名, category, move ids, look, notes)
# category decides layout, cel plan and size rules.
P = 'projectile'
FAMILIES = [
    ('P_thorn', '荊針', P, ['thorn_ring', 'echo_thorn_double', 'bloom_needle'],
     'a short sharp curved plant thorn, glossy dark green-brown with a pale bone tip, pointing right', ''),
    ('P_bolt', '弩矢', P, ['crossbow_burst', 'crossbow_low'],
     'a short heavy crossbow bolt with a dark iron head, a black shaft and small grey fletching, pointing right', ''),
    ('P_stinger', '蠟針', P, ['bee_stingers'],
     'a slim amber wax stinger needle with a bead of molten wax at its base, pointing right', ''),
    ('P_net', '根網', P, ['cage_net'],
     'a small tumbling bundle of brown roots and crimson thread that is unfolding into a net', '命中會讓主角減速，命中消散幀可畫成網張開罩住。'),
    ('P_blade', '影刃', P, ['censor_blink', 'censor_fan', 'shadow_blink', 'boss_bride_mirror'],
     'a thin pale silver crescent blade with a sharp leading edge pointing right and a slightly darker steel spine', '三個怪物共用；畫成淡銀白，遊戲按怪物各自上色。'),
    ('P_spore', '孢子', P, ['bell_spores', 'boss_moss_spores'],
     'a round moss-green spore pod with a pale yellow glowing centre and tiny soft hairs', ''),
    ('P_pollen', '花粉團', P, ['moth_dust', 'pollen_arcs'],
     'a soft clump of golden pollen with a few loose grains drifting behind it', 'pollen_arcs 命中會讓主角減速。'),
    ('P_seed', '藤種', P, ['boss_bishop_seeds'],
     'an orange seed pod like the ones hanging from the bishop\'s crozier, with a short curling green vine tail', '命中會讓主角減速。'),
    ('P_incense', '香灰滴', P, ['censer_rain'],
     'a falling teardrop of grey-violet incense ash with a faint ember-orange core', '受重力下落；命中會讓主角減速。'),
    ('P_light', '光珠', P, ['mote_seek', 'lumen_orbits'],
     'a small glowing pale gold orb with a bright white core and a thin dark rim', 'mote_seek 會緩慢追蹤主角。'),
    ('P_page', '書頁', P, ['index_pages', 'page_orbit', 'echo_scribe_pages'],
     'a single torn parchment page, slightly curled, with faint ink lines but no readable letters, spinning edge-on', ''),
    ('P_slug', '管彈', P, ['pipe_mortar'],
     'a short rusty iron pipe canister tumbling end over end, a little steam leaking from one end', '拋物線曲射；落地後變成「鐵渣灘」，見 A_slag。'),
    ('P_chime', '鐘聲彈', P, ['bugle_volley', 'clapper_wave'],
     'a small brass-coloured sound pulse shaped like a thick crescent ring segment, convex side to the right, with two thinner echo arcs behind it', ''),
    ('P_wheel', '水輪刃', P, ['wheel_return', 'echo_wheel_elite'],
     'a small spinning bronze waterwheel blade with six paddles, green patina and a few water droplets flung off its rim', '飛出後會折返回到主人身邊。'),
    ('P_key', '鑰刃', P, ['boss_key_return'],
     'an ornate golden key with a wheel-shaped bow, spinning end over end', '飛出後會折返。'),
    ('A_seal', '印陣', 'pool', ['index_seal', 'echo_scribe_seals'],
     'a flat circular seal of black ink stamped on the ground, ringed with dark red sealing wax, glyph-like marks but no readable letters, faint ink wisps rising', 'index_seal 會讓主角減速。'),
    ('A_fungus', '菌圈', 'pool', ['bell_fungus', 'echo_larva_mark'],
     'a ring of moss and small pale bell-shaped mushrooms pushing out of the ground, puffing a faint green spore haze', ''),
    ('A_haze', '煙圈', 'pool', ['censer_cloud', 'pollen_spots'],
     'a low hovering cloud of pale warm-grey smoke with drifting golden specks, hugging the ground', '兩個怪物共用；畫成偏淡的中性色，遊戲按怪物各自上色。'),
    ('A_snare', '根籠', 'pool', ['cage_elite_snare', 'boss_bishop_cage', 'boss_shears_knots'],
     'a low cage of brown roots and taut crimson threads snapping up out of the ground and knotting together', 'cage_elite_snare 會讓主角減速。'),
    ('A_caltrops', '灰釘陣', 'pool', ['chariot_caltrops'],
     'a scatter of black iron caltrops lying on the ground, a dull ash-grey glint on their points', ''),
    ('A_shadow', '影池', 'pool', ['shadow_echo', 'boss_bride_pools'],
     'a dark navy mirror-like puddle on the ground with a pale silver rim, a faint blurred silhouette rising out of it', ''),
    ('A_focus', '聚光', 'pool', ['lumen_focus'],
     'a short column of pale gold light focused down onto a bright disc on the ground', ''),
    ('A_slag', '鐵渣灘', 'pool', ['pipe_mortar'],
     'a splash of glowing orange molten slag and rusty iron scraps on the ground, hissing steam', '管彈落地後的地面危險（半徑固定 32）。'),
    ('W_quake', '震地裂波', 'wave', ['heavy_stamp', 'heavy_elite_quake', 'boss_moss_stamp'],
     'a low crescent of cracked earth and rock shards heaving up out of the ground and rolling to the right', ''),
    ('W_chime', '鐘聲地波', 'wave', ['root_bell_wave', 'bugle_pulse', 'bellwheel_waves', 'echo_wheel_wave', 'boss_key_rings'],
     'a standing half-ring of brass sound ripples rolling along the ground to the right, two or three nested arcs', '五招共用；畫成偏淡的黃銅色，遊戲按怪物各自上色。'),
    ('W_surge', '渠水湧浪', 'wave', ['diver_splash'],
     'a low surge of dark green canal water curling forward along the ground to the right, with a foamy crest', ''),
    ('R_roots', '根刺', 'eruption', ['vine_roots', 'thorn_wall', 'bloom_seeds', 'echo_thorn_roots', 'boss_moss_roots', 'boss_bishop_roots'],
     'a tight cluster of sharp brown roots and green thorns bursting straight up out of the ground', '六招共用。'),
    ('R_spears', '槍陣', 'eruption', ['minor_banner', 'minor_elite_rally'],
     'a cluster of ghostly black spears with tattered grey pennants thrusting straight up out of the ground', ''),
    ('B_steam', '蒸汽', 'beam', ['pipe_backblast', 'valve_vent'],
     'a straight jet of scalding white steam with a hot pale core', ''),
    ('B_erase', '擦除線', 'beam', ['bailiff_erase'],
     'a straight band of erasing ink: rough black ink edges around a pale paper-white core, like a stroke being wiped out of a page', ''),
    ('B_thread', '緋線', 'beam', ['boss_shears_thread'],
     'a single taut glowing crimson thread with a few loose silk fibres', ''),
    ('B_gate', '冠門封線', 'beam', ['boss_key_gate'],
     'a straight bar of gold light with key-tooth notches along both edges', ''),
]

# Player effects: (stem, 中文名, category, look, game facts)
PLAYER = [
    ('H_needle', '回聲針（技能）', 'projectile', 'a thin crimson thread needle with a short trailing loop of red thread, pointing right',
     '直線飛行 620 px/秒，射程 420；判定很小（敵人受擊框外擴 8 px），命中一個敵人或碰牆即消失。'),
    ('H_shockwave', '鐘鳴震波（技能）', 'wave', 'a forward-rolling ground wave of bronze bell resonance: nested brass arcs with a few kicked-up stone chips',
     '地面向前 620 px/秒，射程 160，持續 0.8 秒；沿途命中所有敵人並使其踉蹌。'),
    ('H_snare', '鹽印縛線（技能）', 'pool', 'a ring of pale salt-white threads snapping taut across the ground in a seal pattern, with a faint crimson core thread',
     '落在主角前方 90 px，判定半徑 36，持續約 1.4 秒；困住敵人。'),
    ('H_shard', '銅鈴投罐（戰具）', 'bomb', 'a small bronze bell-shaped clay jar sealed with red thread',
     '拋物線投出；落地後 0.35 秒亮橙色預警再爆裂，爆裂半徑 75。'),
    ('H_mine', '絆線釘（戰具）', 'trap', 'a small iron stake driven into the ground with a taut crimson tripwire',
     '放在地面，判定半徑 36，最多 2 個、持續 6 秒；被觸發時絆倒敵人後消失。'),
    ('H_fog', '鹽霧瓶（戰具）', 'cloud', 'a cloud of pale salt-white mist with glittering salt crystals',
     '在主角前方原地展開，半徑 130，持續 4 秒；干擾敵人索敵，不造成傷害。'),
    ('H_lure', '回響誘鈴（戰具）', 'chime', 'a small brass hand bell lying on the ground, ringing',
     '放下即響，吸引 320 範圍內的小怪來查看；遊戲裡只存在一瞬間，畫成短促的響鈴動畫。'),
]

COMMON = ('Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, '
          'a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; '
          'not neon, not pixel art, not a 3D render. {REFS} Every cel shows ONLY the effect, at the same scale in every cel. '
          'The game shrinks it to about {SIZE}, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim '
          'around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent '
          'glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, '
          'no grid lines, no characters. {GUTTER}')
GUTTER = 'Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.'
REF_ENEMY = 'The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature.'
REF_HERO = 'The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character\'s kit, but do NOT draw the character.'


def cels(lines):
    return '\n'.join(f'Cel {i}: {t}' for i, t in enumerate(lines, 1))


def grid(n, cols, rows, w, h, extra=''):
    order = 'read left-to-right' + (' then top-to-bottom' if rows > 1 else '')
    return f'Layout: exactly {n} cels on a {cols}-column x {rows}-row grid ({w}x{h} px canvas, one {w // cols}x{h // rows} px cel each), {order}.{extra}'


PLAN = {
    'projectile': (grid(8, 4, 2, 1024, 512, ' The effect is centred in each cel and fills about 55% of the cel width.'), [
        'flight loop frame 1, travelling to the right.', 'flight loop frame 2 (small rotation, flicker or flutter change).',
        'flight loop frame 3.', 'flight loop frame 4, leading back seamlessly into cel 1.',
        'impact: the effect hits something on its right side and starts to break apart.', 'impact: breaking apart into a few large fragments.',
        'impact: fragments scattering and thinning.', 'impact: last faint fragments, almost gone.']),
    'pool': (grid(8, 4, 2, 1536, 768, ' The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.'), [
        'appear: the hazard just starting to form on the ground.', 'appear: half formed.',
        'active loop frame 1, fully formed.', 'active loop frame 2.', 'active loop frame 3.', 'active loop frame 4, leading back seamlessly into cel 3.',
        'fade: breaking up and thinning.', 'fade: last faint traces.']),
    'wave': (grid(8, 4, 2, 1536, 768, ' The wave stands on an invisible ground line at 80% of the cel height, centred horizontally, about 60% of the cel width wide, and travels to the RIGHT.'), [
        'rise: the wave just lifting off the ground.', 'rise: reaching full height.',
        'travel loop frame 1.', 'travel loop frame 2.', 'travel loop frame 3.', 'travel loop frame 4, leading back seamlessly into cel 3.',
        'fade: collapsing back toward the ground.', 'fade: last faint traces.']),
    'eruption': (grid(6, 3, 2, 1536, 1024, ' The burst grows straight up from an invisible ground line at 90% of the cel height, centred horizontally, about 40% of the cel width wide and up to 85% of the cel height tall.'), [
        'emerge: tips just breaking the ground.', 'emerge: shooting up to about two thirds height.',
        'full height, hold frame 1.', 'full height, hold frame 2 (slight sway), loops with cel 3.',
        'retract: cracking and sinking back down.', 'retract: almost gone, a few fragments at ground level.']),
    'beam': ('Layout: exactly 4 cels stacked as 4 horizontal strips on a 1536x1024 px canvas (each strip 1536x256 px), top to bottom. '
             'The beam runs horizontally through the vertical centre of each strip and is about 25% of the strip height thick.', [
        'origin burst: where the beam leaves the attacker, a short flare on the LEFT third of the strip, the beam starting to its right.',
        'middle segment frame A: the beam body running the FULL width of the strip, touching the left and right canvas edges, with no start or end, so it can be repeated side by side.',
        'middle segment frame B: same as frame A with a slightly different shimmer, also touching both side edges.',
        'end cap: the far end of the beam on the RIGHT third of the strip, the beam arriving from the left edge and ending in a small splash.']),
}
PLAN['trap'] = (PLAN['pool'][0], [
    'placed: being driven into the ground.', 'armed idle frame 1.', 'armed idle frame 2 (small glint), loops with cel 2.',
    'triggered: the wire snapping.', 'triggered: the stake jerking and the wire whipping up.', 'triggered: spent, the wire slack.',
    'fade: breaking up.', 'fade: last faint traces.'])
PLAN['bomb'] = (grid(8, 4, 2, 1536, 768, ' The jar is small and centred in cels 1-4; the burst in cels 5-8 fills about 80% of the cel.'), [
    'thrown jar flight frame 1, tumbling.', 'flight frame 2.', 'landed: the jar glowing hot orange, warning.', 'landed: cracks of orange light spreading, about to burst.',
    'burst: a round blast of bronze shards and crimson thread.', 'burst at full size.', 'burst breaking up.', 'last faint fragments.'])
PLAN['cloud'] = (grid(8, 4, 2, 1536, 768, ' The cloud is centred and up to 85% of the cel width wide.'), [
    'the bottle shattering, mist bursting out.', 'mist spreading quickly.', 'cloud loop frame 1, full size.', 'cloud loop frame 2.',
    'cloud loop frame 3.', 'cloud loop frame 4, leading back seamlessly into cel 3.', 'thinning.', 'last faint wisps.'])
PLAN['chime'] = (grid(4, 4, 1, 1536, 384, ' The bell sits on an invisible ground line at 80% of the cel height.'), [
    'the bell set down, still.', 'the bell swinging, small sound arcs spreading from it.', 'the bell swinging the other way, sound arcs wider.', 'settling, last faint arcs.'])


def size_text(cat, radii, beams=None):
    lo, hi = min(radii), max(radii)
    span = (lambda a, b: f'{a}' if a == b else f'{a}–{b}')
    if cat == 'projectile':
        return f'a {span(lo * 2, hi * 2)} px wide sprite', f'子彈主體直徑約 {span(lo * 2, hi * 2)} px（判定以中心為準，半徑 {span(lo, hi)}）'
    if cat == 'pool':
        return f'a {span(lo * 2, hi * 2)} px wide ground patch', f'地面範圍寬約 {span(lo * 2, hi * 2)} px（判定圓半徑 {span(lo, hi)}，中心在地面上方 5 px）'
    if cat == 'wave':
        return f'a {span(lo * 2, hi * 2)} px wide wave', f'沿地面移動，主體寬高約 {span(lo * 2, hi * 2)} px（判定圓半徑 {span(lo, hi)}，中心在地面上方 18 px）'
    if cat == 'eruption':
        return f'a {span(lo * 2, hi * 2)} px wide, 100 px tall burst', f'寬 {span(lo * 2, hi * 2)} px、高 100 px 的地刺（判定矩形從地面往上 92 px）'
    if cat == 'beam':
        return f'a {span(lo * 2, hi * 2)} px thick beam', f'光束粗 {span(lo * 2, hi * 2)} px、長 {span(min(beams), max(beams))} px（中段重複拼接到所需長度）'


def block(stem, title, frames, refs, game, notes, prompt):
    out = [f'### {title} · `FX_{stem}.png`', '', f'- 幀數：{frames}', f'- 附參考圖：{refs}', f'- 遊戲內：{game}']
    if notes:
        out.append(f'- 備註：{notes}')
    return '\n'.join(out + ['', '```text', prompt, '```', '', ''])


assigned = {}
for stem, *_rest in FAMILIES:
    for m in _rest[2]:
        assigned.setdefault(m, []).append(stem)
missing = sorted(set(MOVES) - set(assigned))
unknown = sorted(set(assigned) - set(MOVES))
# pipe_mortar is listed twice on purpose: its flight (P_slug) and its landing pool (A_slag).
dupes = {m: s for m, s in assigned.items() if len(s) > 1 and m != 'pipe_mortar'}
if missing or unknown or dupes:
    raise SystemExit(f'family table out of date: missing={missing} unknown={unknown} dupes={dupes}')

CAT_ZH = {'projectile': '子彈', 'pool': '地面危險', 'wave': '地波', 'eruption': '地刺', 'beam': '光束'}
ORDER = [('projectile', 'P', '子彈（P）'), ('pool', 'A', '落點地面危險（A）'), ('wave', 'W', '地波（W）'), ('eruption', 'R', '地刺（R）'), ('beam', 'B', '光束（B）')]

md = ['''# 攻擊特效出圖清單（v1）

依 main `58a06c18` 審計。敵人的子彈、法術、地面危險和主角的技能、戰具效果，**目前全部由代碼即時畫幾何圖形**（圓、三角、線條），沒有任何圖片素材：

- 敵人：37 種怪物（含 5 個 Boss）共 63 招遠程或範圍攻擊，都由 `godot/scripts/enemy_attack_effect.gd` 繪製。子彈只有 4 種形狀（三角、圓球、四邊形、鑰匙），金屬彈和水輪沒有自己的畫法而退回三角；除 4 招精英招外，所有招式都是同一個土黃色。
- 主角：回聲針、鐘鳴震波、鹽印縛線三個技能和四件戰具，在 `godot/scripts/player_tool_effect.gd` 裡都是一個 16×10 的純色方塊。

本清單按「看起來是同一種東西」分家族出圖，不逐招各畫一套：**32 個敵人特效家族 + 7 個主角效果，共 39 張**。逐招對照表在最後。

## 先說清楚的規則

- **預警留給代碼畫**。落點圈、地刺、光束出手前的閃爍預警圈／預警通道，仍由遊戲按真實判定畫，不出圖。這部分已專門調過可讀性（見 `docs/ENEMY_ATTACK_WARNING_READABILITY.md`、`docs/ENEMY_BEAM_HITBOX_READABILITY.md`），圖片只負責「生效時長什麼樣」。
- **看到的大小要等於打到的大小**。每個家族都寫了遊戲內尺寸；接入時我按判定半徑縮放，讓圖的實心部分剛好覆蓋判定範圍，外圍柔光要淡，不能讓人誤以為範圍更大。
- **遊戲裡很小**。子彈只有二三十像素，所以要求輪廓簡單、核心對比強、實心部分帶細黑邊。細節畫得再多，縮小後也看不到。
- **共用家族會在遊戲裡上色**。備註寫「遊戲按怪物各自上色」的，請畫成偏淡的中性色；其他的直接畫成最終顏色。精英招一律由遊戲疊紅色，不另外出圖。
- 方向：子彈和地波一律朝右畫，遊戲會旋轉或翻轉。

## 通用要求

- 每張附上寫明的參考圖（路徑相對於 `art_requests/`）。參考圖只用來對配色和材質，**不要把怪物畫進去**。
- 真透明 PNG，柔和的半透明光暈邊緣可以；不要黑底、白底、棋盤格、地面、投影、文字、格線。
- 格數、排法照提示詞；生成器不支持該尺寸就用最接近的比例，格子數和順序不能變。
- 只上傳選定的那一張，放進 `art_requests/attack_effects_v1/incoming/`，檔名照清單；當次實際用的提示詞存成同名 `.txt`。
- 退回標準：格數不對、畫了角色或背景、循環接不上、大小比例和其他格不一致、縮到遊戲尺寸後看不清。

## 清單

| 順序 | 檔名 | 名稱 | 類型 | 幀數 | 用到的招數 |
| ---: | --- | --- | --- | ---: | ---: |
''']

rows = []
for cat, prefix, _ in ORDER:
    for stem, zh, c, moves, look, notes in FAMILIES:
        if c == cat:
            rows.append((stem, zh, CAT_ZH[cat], len(PLAN[cat][1]), len(moves)))
for stem, zh, cat, look, facts in PLAYER:
    rows.append((stem, zh, '主角', len(PLAN[cat][1]), '—'))
for i, (stem, zh, cat, n, uses) in enumerate(rows, 1):
    md.append(f'| {i} | `FX_{stem}.png` | {zh} | {cat} | {n} | {uses} |\n')
total = sum(r[3] for r in rows)
md.append(f'\n共 **{len(rows)} 張、{total} 幀**。優先順序：敵人子彈 → 地面危險、地波、地刺、光束 → 主角效果；同一類內照表格順序。\n\n')

for cat, prefix, heading in ORDER:
    md.append(f'## {heading}\n\n')
    for stem, zh, c, moves, look, notes in FAMILIES:
        if c != cat:
            continue
        ms = [MOVES[m] for m in moves]
        radii = [int(m.get('radius') or DEFAULT_RADIUS) for m in ms]
        if stem == 'A_slag':
            radii = [32]  # enemy_attack_effect.gd: impact_pool converts to a radius-32 pool
        beams = [int(m.get('beam_length', 360)) for m in ms]
        size_en, size_zh = size_text(cat, radii, beams)
        kinds = list(dict.fromkeys(m['kind'] for m in ms))
        refs = '、'.join(f'`{ref_of(k)}`' for k in kinds)
        users = '、'.join(f"{BOSS_ZH.get(m['kind'], m['kind'])}「{m['name']}」" for m in ms)
        regions = '、'.join(dict.fromkeys(REGION[m['region']] for m in ms))
        layout, plan = PLAN[cat]
        prompt = (COMMON.format(REFS=REF_ENEMY, SIZE=size_en, GUTTER='' if cat == 'beam' else GUTTER).rstrip()
                  + f'\nThe effect: {look}.\n' + layout + '\n' + cels(plan))
        md.append(block(stem, zh, len(plan), refs, f'{size_zh}；{regions}', f'用於 {users}。' + notes, prompt))

md.append('## 主角技能與戰具（H）\n\n')
for stem, zh, cat, look, facts in PLAYER:
    layout, plan = PLAN[cat]
    size_en = {'projectile': 'a 24 px wide sprite', 'wave': 'a 60 px wide wave', 'pool': 'a 72 px wide ground patch',
               'bomb': 'a 20 px jar and a 150 px wide burst', 'trap': 'a 72 px wide ground patch', 'cloud': 'a 260 px wide cloud',
               'chime': 'a 40 px wide bell'}[cat]
    prompt = (COMMON.format(REFS=REF_HERO, SIZE=size_en, GUTTER=GUTTER) + f'\nThe effect: {look}.\n' + layout + '\n' + cels(plan))
    md.append(block(stem, zh, len(plan), f'`{HERO_REF}`', facts, '', prompt))

md.append('## 逐招對照表\n\n| 怪物 | 地區 | 招式 | 類型 | 半徑 | 家族 |\n| --- | --- | --- | --- | ---: | --- |\n')
for mid, m in sorted(MOVES.items(), key=lambda kv: (kv[1]['region'], kv[1]['kind'], kv[0])):
    fam = ' + '.join(f'`FX_{s}`' for s in assigned[mid])
    elite = '（精英）' if m.get('elite') else ''
    md.append(f"| {BOSS_ZH.get(m['kind'], m['kind'])} | {REGION[m['region']]} | {m['name']}{elite} `{mid}` | {m['type']} | "
              f"{m.get('radius') or DEFAULT_RADIUS} | {fam} |\n")

md.append('''
## 不在清單內

- **預警圈和預警通道**：由代碼按真實判定繪製，理由見上。
- **主角近戰刀光、契印與能力光環**：已由遊戲繪製並按判定調好，這次不動。
- **被彈反的子彈**：遊戲把原子彈改成淡金色並反向飛行，不另外出圖。

## 收到後

逐張檢查 → 切幀、統一錨點（子彈以中心、地面類以地面線、光束以起點）→ 按判定半徑縮放 → `enemy_attack_effect.gd` 和 `player_tool_effect.gd` 改為按家族播放序列幀（保留代碼預警、判定與上色）→ 跑敵人特效生命週期、判定可讀性和相關真實渲染回歸，附前後對比截圖開 PR。

本檔由 `build_list.py` 生成，改內容請改腳本後重跑；腳本會檢查遊戲裡每一招遠程或範圍攻擊都恰好歸入一個家族。
''')

(HERE / 'README.md').write_text(''.join(md), encoding='utf-8')
print('sheets', len(rows), 'frames', total, 'moves', len(MOVES))
