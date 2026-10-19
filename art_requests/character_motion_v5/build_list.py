#!/usr/bin/env python3
"""Write README.md: the outstanding v5 image requests with fully expanded prompts."""
from pathlib import Path

HERE = Path(__file__).resolve().parent

BOSSES = {
    'broken_string_gardener': ('銅根主教', 'a hunched root-bishop: a tall pale wooden mitre-shaped head with two small black eyes, a crown of orange coral-like root hair, a layered dark green leafy feather cloak, long cream lace stoles hanging from the shoulders, gnarled root-claw feet, and a twisted wooden crozier staff whose spiral head carries small hanging orange seed pods'),
    'rust_crown_guardian': ('苔鐘守母', 'a tall moss mantis matriarch: a pale bone skull-mask head with long curling antennae that end in two small brass bells, a huge drooping cloak of mossy green fern fronds dotted with tiny white flowers, a dark bronze bell-shaped armoured torso, slender brown wooden limbs and root feet, and two long bone-white scythe forearms'),
    'saltwhite_contract_judge': ('灰冠螳將', 'a spiky mantis general: a charcoal-black insect body on thin long legs, a jagged brown spiked crown head with glowing amber eyes, bone-white serrated blade plates covering the shoulders and back, a long tattered crimson cloak and red ribbons, a small gold clasp at the waist, and two very long bone-white curved scythe blades for forearms'),
    'sunken_hammer_smith': ('緋線執剪者', 'a crimson bird-like shear wielder: a hooked beak, a tall comb crest of bronze quills, long thin red whip antennae sweeping back, a deep crimson ragged feather cloak, a pale cream segmented belly, thin dark clawed legs, and enormous ornate bronze shears with ring handles held in front of the body'),
    'silent_crown_core': ('無聲王冠', 'an armoured key king: a dark insect body in black plate armour, a pale bone crescent-horned crown head hung with small chains and keys, a tall golden organ-pipe crown of keys rising behind the head, a white ermine fur collar, a long red royal cloak with gold embroidery, and a giant ornate golden key with a wheel-shaped bow carried like a polearm'),
    'silent_pilgrim_commander': ('靜音巡禮統帥', 'a tall slender veiled commander: a white oval mask face, a crown of pale spikes hung with small crystal pendants, a long translucent lavender veil, a layered cream petal gown set with large oval silver mirror panels, thin dark legs on heeled feet, and a long thin silver lance'),
}
CREATURES = {
    'ash_banner_imp': 'a small nimble ash grey beetle imp: a pale bone skull face with black eye holes, two curved white horns, a round grey shell on its back, thin dark limbs, red silk ribbons tied around its neck, and a tall spear that carries a ragged black banner edged with red silk',
    'echo_contract_scribe': 'a slender paper scribe insect: a pale bone mask face with black eyes and two curved antennae, a tattered cream parchment cloak, a crimson scarf and a long red sash with small gold seal ornaments, thin black limbs, and a long golden quill-spear',
    'wax_lancer': 'an amber wax wasp knight: glossy golden-orange wax armour plates, a black head with dark eyes and two antennae, translucent amber wings, a deep crimson cape, dark segmented limbs, and a long melting wax lance dripping with amber wax',
    'delayed_shadow': 'a dark navy feathered shadow insect: a white oval mask face, two long dark plume antennae, a red scarf streaming back, a tattered navy feather cloak with small pale eye spots, thin dark limbs, and a long thin silver needle rapier',
    'pipe_thrower': 'a hunched worker beetle: a rust-orange shell, a white oval mask face with long antennae, a tattered blue work coat, a brown belt with pouches, thin dark limbs, and a short heavy iron pipe',
    'npc_blind_bell_knight': 'a stout armoured beetle knight: two dark curved horns, a white bandage blindfold over the face, dark plate armour, a tattered red cape and white sash, a large round brass shield, small brass bells hanging at the waist, and a tall spear with a bell and red tassel below its blade',
    'npc_deserter_flagbearer': 'a tall thin insect flagbearer: a long pale bone-white head with an amber eye and long thin antennae, a tattered red-and-black cloak, a cream tabard with brass medallions, thin jointed legs, and a tall wooden pole carrying a ragged red pennant',
}

STYLE = ('Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. '
    'Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body '
    'and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, '
    'feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% '
    'of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. '
    'Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. '
    'Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack '
    'effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.')


def head(ref, look):
    return f'Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character ({ref}): {look}. {STYLE}'


def layout(n, cols, rows, w, h):
    if n == 1:
        return f'Layout: exactly ONE cel, the figure centred on a {w}x{h} px canvas.'
    order = 'read left-to-right' + (' then top-to-bottom' if rows > 1 else '')
    return f'Layout: exactly {n} cels on a {cols}-column x {rows}-row grid ({w}x{h} px canvas, one {w // cols}x{h // rows} px cel each), {order}.'


def cels(lines):
    return '\n'.join(f'Cel {i}: {t}' for i, t in enumerate(lines, 1))


def block(title, fname, frames, refs, prompt, note=''):
    out = [f'#### {title} · `{fname}`', '', f'- 幀數：{frames}', f'- 附參考圖：{refs}']
    if note:
        out.append(f'- {note}')
    out += ['', '```text', prompt, '```', '']
    return '\n'.join(out)


# ---------- E: boss phase strikes ----------
E_STRIKE = {
    'broken_string_gardener': ['steps forward out of the tall wind-up and swings the crozier up overhead with both hands, root-hair crown flaring, leafy cloak lifting.',
        'brings the crozier down in a huge overhead arc in front of the body, lace stoles and leaf cloak whipping forward.',
        'deep forward lunge, the crozier head slammed onto the ground line well in front of the feet, root claws gripping, leafy mantle splayed wide.',
        'holds the impact low and heavy, hunched over the crozier still planted on the ground ahead.'],
    'rust_crown_guardian': ['launches from the raised wind-up into a long low lunge, both scythes thrust far ahead, fern cloak streaming back, bells swinging.',
        'twists the torso and sweeps both scythes wide outward at full reach, one high and one low.',
        'continues the turn, both scythes swung around overhead in a big crossing arc, cloak flung open.',
        'plants low and wide with both scythes crossed and driven down at the ground line in front.'],
    'saltwhite_contract_judge': ['rising diagonal sweep with the front scythe blade from low behind to high in front, body uncoiling from the wind-up.',
        'reverse diagonal sweep with the rear blade from high to low, torso twisting the other way, crimson cloak whipping.',
        'deep lunge with both blades thrust straight forward and crossed in an X at full extension.',
        'exhausted low stance, both blades lowered and crossed near the ground, shoulders dropped, cloak settling.'],
    'sunken_hammer_smith': ['leaps up and forward out of the wind-up with the enormous shears held wide open overhead, feet off the ground.',
        'airborne, body curled in a tight forward spin, the open shears hugged close, crimson feather cloak wrapping around.',
        'still airborne, uncurls and snaps the shears shut in a horizontal sweep at full arm extension in front of the chest.',
        'lands in a deep low crouch, the closed shears pointing forward along the ground line. Same body size as every other cel; do not shrink.'],
}

# ---------- G: regular enemy fixes ----------
G = [
    ('G_ash_banner_imp_attack0.png', 'ash_banner_imp', '出招第 1 幀（旗色錯）', 1, '`refs/60_ash_banner_imp_full_attack.png`',
     'Reference figure order: idle 1, wind-up 4, strike 4, recovery 2. Redraw ONLY strike figure 1 (the 6th figure): the same low forward lunge with the banner spear thrust forward at hip height. The banner and its red silk must look like they do in strike figures 2-4 (the 7th to 9th figures), so the four strike cels share one consistent banner color.',
     (1, 1, 1, 1024, 1024), '先做這張；前搖第 4 幀要接上它。'),
    ('G_ash_banner_imp_windup.png', 'ash_banner_imp', '前搖 4 幀（現在和待機幾乎一樣）', 4, '`refs/60_ash_banner_imp_full_attack.png`＋你選定的 `G_ash_banner_imp_attack0.png`',
     'Reference image 2 is the new strike figure 1. Draw a NEW four-cel wind-up that clearly reads as preparing a lunge: it starts from the upright idle stance (first figure of reference 1) and ends one step before the low lunge of reference image 2.\n'
     + cels(['weight shifts back, the upright banner spear starts to tilt forward.',
             'spear brought down to shoulder height and drawn back, body coiling, banner swinging behind.',
             'deep crouch, spear held level and pulled far back at the hip, horns lowered.',
             'front foot sliding forward, body low and stretched, spear tip aimed forward low, about to lunge into reference image 2.']),
     (4, 2, 2, 1536, 1024), ''),
    ('G_ash_banner_imp_recover.png', 'ash_banner_imp', '收招過渡 2 幀', 2, '`refs/60_ash_banner_imp_full_attack.png`',
     'Draw exactly two in-between poses that bridge from strike figure 4 (the 9th figure, low forward thrust) to recovery figure 1 (the 10th figure, standing upright holding the banner high).\n'
     + cels(['pulls the spear back and rises halfway, spear angled up at about 45 degrees, banner starting to lift.',
             'almost upright, spear nearly vertical, banner falling into place, one short step from the 10th figure.']),
     (2, 2, 1, 1536, 1024), ''),
    ('G_echo_contract_scribe_attack3.png', 'echo_contract_scribe', '出招第 4 幀（縮成一團）', 1, '`refs/62_echo_contract_scribe_attack3.png`',
     'Reference figure order: strike 1-4, then recovery 1. Strike figure 4 (the 4th figure) is wrong: the body curls up like a hurt pose. Redraw it as the follow-through of the thrust: still in the low wide stance of the 3rd figure, the golden quill-spear tip lowered toward the ground ahead and beginning to draw back, head up and facing right, body not curled. It must flow from the 3rd figure into the 5th figure.',
     (1, 1, 1, 1024, 1024), ''),
    ('G_wax_lancer_recover.png', 'wax_lancer', '收招過渡 2 幀', 2, '`refs/63_wax_lancer_attack_to_recover.png`',
     'Reference figure order: strike 1-4, recovery 1-4. Draw exactly two in-between poses that bridge from strike figure 4 (the 4th figure, low horizontal lance thrust) to recovery figure 1 (the 5th figure, standing with the lance upright).\n'
     + cels(['pulls the lance back toward the chest and rises halfway, lance tilted up at about 45 degrees.',
             'almost upright, lance nearly vertical beside the body, cape settling, one short step from the 5th figure.']),
     (2, 2, 1, 1536, 1024), ''),
]

# ---------- H: cropped single frames ----------
H = [
    ('H_broken_string_gardener_death3.png', 'broken_string_gardener', '銅根主教 死亡第 4 幀', '第 2 個', 'right edge'),
    ('H_delayed_shadow_recover0.png', 'delayed_shadow', 'delayed_shadow 收招第 1 幀', '第 1 個', 'top edge'),
    ('H_pipe_thrower_hurt2.png', 'pipe_thrower', 'pipe_thrower 受擊第 3 幀', '第 2 個', 'right edge'),
    ('H_npc_blind_bell_knight_talk3.png', 'npc_blind_bell_knight', '盲鐘騎士 交談第 4 幀', '第 2 個', 'top edge (the spear tip)'),
    ('H_npc_deserter_flagbearer_talk6.png', 'npc_deserter_flagbearer', '逃旗手 交談第 7 幀', '第 2 個', 'left edge'),
]
ORD = {'第 1 個': 'first', '第 2 個': 'second'}


def look(kind):
    return BOSSES[kind][1] if kind in BOSSES else CREATURES[kind]


md = []
md.append('''# 角色動作素材出圖清單（v5，仍需出圖）

2026-10-19 依 main `cae227c1` 重新核對。主角（原 A–D 組與上劈/下劈弧線重畫）已在 #102 及之後的提交接入，不再列出；下面每一項都用目前遊戲實際讀到的幀確認過問題仍在。

## 清單

| 順序 | 組 | 檔名 | 幀數 | 依賴 |
| ---: | --- | --- | ---: | --- |
''')
rows = []
n = 0
for k in ['broken_string_gardener', 'rust_crown_guardian', 'saltwhite_contract_judge', 'sunken_hammer_smith']:
    rows.append(('E', f'E_phase_{k}.png', 4, ''))
for g in G:
    rows.append(('G', g[0], g[3], '先做 `G_ash_banner_imp_attack0.png`' if g[0] == 'G_ash_banner_imp_windup.png' else ''))
for b in BOSSES:
    for mv in ['heavy', 'cast', 'phase']:
        dep = f'先做 `E_phase_{b}.png`' if mv == 'phase' and b in E_STRIKE else ''
        rows.append(('F', f'F_recover_{b}_{mv}.png', 2, dep))
for h in H:
    rows.append(('H', h[0], 1, ''))
for i, (grp, f, c, dep) in enumerate(rows, 1):
    md.append(f'| {i} | {grp} | `{f}` | {c} | {dep} |\n')
total = sum(r[2] for r in rows)
md.append(f'\n共 **{len(rows)} 張、{total} 幀**：E 16、G 10、F 36、H 5。順序就是建議的出圖順序（優先 1 的 E、G 在前）。\n')
md.append('''
## 通用要求

- 每張附上下面寫明的參考圖（在 `refs/`），提示詞整段複製，不要刪減。
- 一律面朝右、真透明 PNG、不要地面陰影和文字；畫面上只有角色和武器，**不要任何特效**（刀光、殘影、光波、塵土都由遊戲繪製）。
- 尺寸照提示詞裡的畫布；生成器不支持就用最接近的比例，格子數和順序不能變。
- 角色大小要和參考圖裡同一角色一致，同一張內每格一樣大。導入時我會統一縮放和腳底對齊，但不會修姿勢。
- 只上傳選定的那一張，放進 `incoming/`，檔名照清單；當次實際用的提示詞存成同名 `.txt`。
- 退回標準：格數不對、角色走樣、帶特效或背景、被裁邊、接不上前後幀。

''')

md.append('## E. Boss 二階段攻擊專屬出招（4 張 × 4 幀，優先 1）\n\n')
md.append('這 4 個 Boss 的二階段出招 4 幀和普通攻擊的像素完全相同（10-19 逐幀比對 4/4 相同）。參考圖依序是：待機 1、二階段前搖 4、目前被複製的普通攻擊 4。新出招要從第 5 個（前搖最後一幀）接下去，而且**不能**畫得像最後 4 個。\n\n')
for k, strike in E_STRIKE.items():
    zh, lk = BOSSES[k]
    ref = f'refs/50_boss_phase_{k}.png'
    p = (head(ref, lk) + '\n'
         'Reference figure order: idle 1, second-phase wind-up 4, current normal attack 4. Draw a NEW four-cel second-phase signature strike that continues '
         'directly from the LAST wind-up figure (the 5th figure). It must be a larger, more violent and clearly different attack from the normal attack '
         '(the last four figures); do not reuse those poses.\n'
         + layout(4, 2, 2, 1536, 1024) + '\n' + cels(strike))
    md.append(block(f'{zh}（{k}）', f'E_phase_{k}.png', 4, f'`{ref}`', p,
                    '緋線執剪者普通攻擊第 4 幀縮小的問題我會用調比例修，不用另外畫。' if k == 'sunken_hammer_smith' else ''))

md.append('## G. 普通怪銜接和畫面錯誤（5 張共 10 幀，優先 1）\n\n')
for f, kind, what, nf, refs, body, lay, note in G:
    ref1 = refs.split('＋')[0].strip('`')
    p = head(ref1, look(kind)) + '\n' + body + '\n' + layout(nf, *lay[1:])
    md.append(block(f'{kind}：{what}', f, nf, refs, p, note))

md.append('## F. Boss 招式收招過渡（18 張 × 2 幀，優先 2）\n\n')
md.append('6 個 Boss 的重擊（heavy）、施法（cast）、二階段攻擊（phase）結束後都直接跳到同一套通用收招。參考圖 `51_boss_recover_<Boss>_<招式>.png` 依序是：該招最後一幀、通用收招第 1 幀、待機第 1 幀。要畫的是第 1 個和第 2 個之間的 2 幀。\n\n')
md.append('**例外**：銅根主教、苔鐘守母、灰冠螳將、緋線執剪者的 `phase` 要等 E 組定稿後再做，起點改成你選定的 E 圖第 4 格（參考圖 2），終點仍是 `51_…_phase.png` 的第 2 個。\n\n')
for b, (zh, lk) in BOSSES.items():
    md.append(f'### {zh}（{b}）\n\n')
    for mv, mvzh in [('heavy', '重擊'), ('cast', '施法'), ('phase', '二階段攻擊')]:
        ref = f'refs/51_boss_recover_{b}_{mv}.png'
        if mv == 'phase' and b in E_STRIKE:
            refs = f'`{ref}`＋你選定的 `E_phase_{b}.png`'
            src = ('Reference image 2 is the new second-phase strike sheet. Draw exactly two in-between poses that bridge from the LAST cel of reference image 2 '
                   '(end of the strike) to the SECOND figure of reference image 1 (first pose of the shared recovery); ignore the first figure of reference image 1.')
        else:
            refs = f'`{ref}`'
            src = ('Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from '
                   'the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).')
        p = (head(ref, lk) + '\n' + src + '\n'
             'Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, '
             'with no new gesture that appears in neither end pose.\n' + layout(2, 2, 1, 1536, 1024))
        md.append(block(f'{zh} {mvzh}', f'F_recover_{b}_{mv}.png', 2, refs, p))

md.append('## H. 被裁到邊的單幀（5 張 × 1 幀，優先 3）\n\n')
md.append('原圖在生成時就被裁到，邊緣是一條直線。畫同一個姿勢，只是完整不被裁。\n\n')
for f, kind, zh, which, edge in H:
    ref = f'refs/70_crop_{kind}_{f.rsplit("_", 1)[1][:-4]}.png'
    p = (head(ref, look(kind)) + '\n'
         f'Redraw ONLY the {ORD[which]} figure of the reference, in exactly the same pose, so that it is complete: in the reference its {edge} is cut off '
         'by a straight line. Show the whole figure, cloak and weapon with clear transparent space on every side.\n' + layout(1, 1, 1, 1024, 1024))
    md.append(block(zh, f, 1, f'`{ref}`（要重畫的是{which}）', p))

md.append('''## 不在清單內

- **主角待機披風過渡（原 A 組）**：10-17 交過一版，A1、A2 稍有改善，A3 沒有改善。用不用要看對比動圖決定，決定之前不重畫。
- **delayed_shadow 前搖與出招順序、銅根主教重擊與二階段前搖、corridor_heavy 前搖**：像是幀順序問題，我先調順序，不行再補出圖。
- **緋線執剪者普通攻擊第 4 幀縮小**：先用比例修正。
- **生成地圖的 36 個佔位 NPC**：只在 `GeneratedMain.tscn` 試玩場景出現，主遊戲不用，不建議做（36 × 16 = 576 幀）。

## 上傳方式

本機直接放進 `art_requests/character_motion_v5/incoming/`，不用自己 commit。在別的電腦就上傳到新分支（例如 `art/character-motion-v5`）的同一資料夾，不要直接傳 main。

## 收到後

逐張檢查（透明、裁切、身份、動作語義、前後銜接）→ 統一比例和腳底 → 寫入 manifest 與生成記錄 → 接入遊戲（Boss 二階段換圖；收招新增「招式專屬過渡 → 通用收招」；普通怪換對應幀）→ 跑 `test:character-motion`、`test:boss-assets` 和相關真實渲染回歸，附前後對比截圖開 PR。

本檔由 `build_list.py` 生成，改內容請改腳本後重跑。
''')

(HERE / 'README.md').write_text(''.join(md), encoding='utf-8')
print('rows', len(rows), 'frames', total)
