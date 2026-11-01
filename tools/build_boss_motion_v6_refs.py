#!/usr/bin/env python3
"""Prepare exact production pose pairs for new, individually authored inbetweens."""
import ast
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'art_requests/boss_motion_v6'
BOSSES = ('rust_crown_guardian', 'sunken_hammer_smith', 'saltwhite_contract_judge',
          'broken_string_gardener', 'silent_pilgrim_commander', 'silent_crown_core')


def main():
    (OUT/'refs').mkdir(parents=True, exist_ok=True)
    (OUT/'incoming').mkdir(exist_ok=True)
    (OUT/'prompts').mkdir(exist_ok=True)
    tree = ast.parse((ROOT/'art_requests/character_motion_v5/build_list.py').read_text(encoding='utf-8'))
    identities = ast.literal_eval(next(node.value for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'BOSSES' for t in node.targets)))
    jobs = []
    for kind in BOSSES:
        folder = ROOT/'godot/assets/sprites/original_creatures'/kind
        if 'boss_motion_v6' in json.loads((folder/'motion_generation.json').read_text(encoding='utf-8')):
            raise ValueError('References are frozen to the pre-v6 rig; do not regenerate after registration')
        manifest = json.loads((folder/'motion_manifest.json').read_text(encoding='utf-8'))
        animations = {a['name']: a for a in manifest['animations']}
        cache = {}

        def frame(animation, index):
            value = animations[animation]['frames'][index]
            path = ROOT/'godot'/value['atlas'].removeprefix('res://')
            if path not in cache: cache[path] = Image.open(path).convert('RGBA')
            x, y, w, h = value['region']
            return cache[path].crop((x, y, x+w, y+h))

        # All source cels in this reference use the same physical-world scale.
        def reference(rows, label):
            image = Image.new('RGBA', (1680, 300*len(rows)))
            draw = ImageDraw.Draw(image)
            for row_index, (name, poses) in enumerate(rows):
                draw.text((8, row_index*300+2), name, fill=(190,190,190,255))
                for col, (animation, index) in enumerate(poses):
                    cel = frame(animation, index)
                    scale = manifest['visual_scale'] * .9
                    cel = cel.resize((max(1, round(cel.width*scale)), max(1, round(cel.height*scale))), Image.Resampling.LANCZOS)
                    image.alpha_composite(cel, (col*420+(420-cel.width)//2, row_index*300+285-cel.height))
            path = OUT/'refs'/f'{kind}_{label}.png'
            image.save(path)
            return path.relative_to(ROOT).as_posix()

        rows, slots = [], []
        for attack in ('attack', 'heavy', 'cast', 'phase'):
            for animation in ('windup' if attack == 'attack' else attack+'_windup', attack):
                rows.append((animation, [(animation, i) for i in range(4)]))
                slots += [dict(animation=animation, after=i, fraction=.5) for i in range(3)]
        refs = [reference(rows, 'combat')]
        prompt = f'''Use case: identity-preserve. Asset: production hand-drawn sprite animation IN-BETWEEN POSES for Crimson Thread Pilgrimage.
Reference image 1 is the CURRENT in-game {identities[kind][0]}: {identities[kind][1]}. Preserve this exact character, costume, weapon length, head size, materials, fine dark ink and painted palette. No redesign.
The reference has EIGHT ROWS, each with FOUR source key poses. Labels are reference metadata only. Row order: normal windup, normal strike, heavy windup, heavy strike, cast windup, cast strike, phase windup, phase strike.
Draw exactly TWENTY-FOUR NEW hand-drawn intermediate poses, in THREE COLUMNS x EIGHT ROWS, on a 1536x3072 transparent canvas. Each output row matches the SAME reference row: output column 1 is halfway anatomically between reference columns 1 and 2; output column 2 halfway between reference columns 2 and 3; output column 3 halfway between reference columns 3 and 4. Never copy either endpoint: articulate the shoulder, elbows, knees, hands, weapon and trailing cloth into a physically coherent NEW halfway silhouette. Follow the reference movement direction and the exact grip through each interval. These are inserted between existing poses to remove popping, NOT a new sequence or alternative attack.
Every figure faces RIGHT, orthographic side view, same character body scale throughout; every full character AND full weapon inside its own cell, with generous empty alpha gutters at least 10% on every side. Fixed ground baseline at 88% cell height for grounded poses. Preserve airborne intent where shown. Body and weapon must never touch adjacent rows/cells. Keep cloak and antenna motion following body momentum.
Genuine RGBA transparency, no background, checkerboard, shadows, floor, labels, letters, numbers, grid, duplicates, cross-fades, ghosted limbs, motion trails, particles, magic, glows or special effects. Output exactly 24 isolated complete character drawings, read left-to-right then top-to-bottom.'''
        jobs.append(dict(kind=kind, role='combat', refs=refs, columns=3, rows=8, slots=slots, prompt=prompt))

        count = len(animations['recover']['frames'])
        intervals = list(range(count-1))
        while len(intervals) < 6: intervals.append(count-2 if len(intervals)%2 else 0)
        intervals.sort()
        rows, slots = [], []
        # A reference row is an endpoint pair; two output columns below are
        # only used for the dedicated recovery/locomotion jobs.
        for index in intervals:
            duplicate_index = sum(s['after'] == index for s in slots)
            total = intervals.count(index)
            slots.append(dict(animation='recover', after=index, fraction=(duplicate_index+1)/(total+1)))
            rows.append((f'recover {index} -> {index+1}', [('recover',index),('recover',index+1)]))
        for attack in ('heavy','cast','phase'):
            for index in (0,1):
                slots.append(dict(animation=attack+'_recover', after=index, fraction=.5))
                rows.append((f'{attack}_recover {index} -> {index+1}', [(attack+'_recover',index),(attack+'_recover',index+1)]))
        refs = [reference(rows, 'recovery')]
        prompt = f'''Use case: identity-preserve. Production game sprite IN-BETWEENS of the EXACT character in reference 1, {identities[kind][0]}: {identities[kind][1]}. Preserve head and body size, exact clothes, weapon length, fine ink and painted materials.
Reference image 1 has TWELVE ROWS, each row is a chronological PAIR of existing source poses (left endpoint then right endpoint), with reference-only labels. Draw exactly TWELVE NEW distinct halfway poses, one anatomically intermediate drawing for EACH reference pair, in that SAME top-to-bottom order. If a pair is repeated, the first occurrence is one-third along the motion, the second two-thirds; do not duplicate the halfway drawing.
Output layout is THREE COLUMNS x FOUR ROWS, 1536x2048 genuine transparent RGBA canvas, read left-to-right then top-to-bottom. Output cel 1 corresponds to reference pair row 1, cel 2 to row 2, ... cel 12 to row 12. These are genuine newly articulated return-to-guard poses, not copies, rotations, blends, ghost images or alternate character designs. Follow each pair's exact limb and weapon path. Fixed body scale, consistent foot baseline at 88% cell height, complete figure and FULL weapon inside each cel with 10% clear alpha gutters, facing RIGHT, side view.
No floor, background, checkerboard, cast shadows, labels, text, numbers, grid lines, effects, glows, afterimages, magic or particles. Exactly 12 complete new characters.'''
        jobs.append(dict(kind=kind, role='recovery', refs=refs, columns=3, rows=4, slots=slots, prompt=prompt))

        rows, slots = [], []
        for animation, count in [('idle',4),('walk',8)]:
            for index in range(count):
                rows.append((f'{animation} {index} -> {(index+1)%count}', [(animation,index),(animation,(index+1)%count)]))
                slots.append(dict(animation=animation,after=index,fraction=.5))
        refs = [reference(rows,'locomotion')]
        prompt = f'''Use case: identity-preserve. Production game sprite animation IN-BETWEENS of the EXACT boss in reference 1, {identities[kind][0]}: {identities[kind][1]}. Preserve character identity, head/body proportions, costume, colors, fine ink and painterly textures, exact weapon length.
The reference contains TWELVE ROWS of endpoint PAIRS: first 4 rows are breathing idle cycle intervals including loop seam; last 8 rows are walking cycle intervals including loop seam. Draw one NEW anatomically halfway pose between the two figures in EACH row. Especially maintain planted foot contact while the other leg passes, hips on the same horizontal origin, weight transfer through knee and ankle, cloth trailing rather than jumping. For idle use subtle chest/cape/antenna articulation with fixed supporting feet. No whole-body bob or repositioning. Do not copy endpoints or crossfade.
Output EXACTLY 12 isolated complete figures, THREE COLUMNS x FOUR ROWS, 1536x2048 true RGBA transparent canvas. Read left-to-right then top-to-bottom: output cel 1 matches reference pair row 1, ... cel 12 matches pair row 12. Fixed size throughout, whole figure and whole weapon must fit within own cel with 10% alpha gutters, grounded baseline 88%, facing RIGHT, pure side view.
No background/checkerboard/floor/shadows/text/labels/grid/effects/trails/particles. Hand-draw actual new limb/cloth poses, no duplicates or ghost limbs.'''
        jobs.append(dict(kind=kind, role='locomotion', refs=refs, columns=3, rows=4, slots=slots, prompt=prompt))
    # Six-pose jobs keep each endpoint pair readable to the image model;
    # long 24/12-pose sheets lose row semantics near their lower edge.
    split_jobs = []
    loaded_atlases = {}
    for job in jobs:
        kind = job['kind']
        folder = ROOT/'godot/assets/sprites/original_creatures'/kind
        manifest = json.loads((folder/'motion_manifest.json').read_text(encoding='utf-8'))
        animations = {a['name']: a for a in manifest['animations']}
        for offset in range(0, len(job['slots']), 6):
            slots = job['slots'][offset:offset+6]
            image = Image.new('RGBA', (1800, 1050))
            draw = ImageDraw.Draw(image)
            for index, slot in enumerate(slots):
                col, row = index%2, index//2
                label = f'PAIR {index+1}: {slot["animation"]} / {slot["after"]} -> next / fraction {slot["fraction"]:.2f}'
                draw.text((col*900+8,row*350+2),label,fill=(220,220,220,255))
                name = slot['animation']
                count = len(animations[name]['frames'])
                for endpoint, frame_index in enumerate((slot['after'], (slot['after']+1)%count)):
                    value = animations[name]['frames'][frame_index]
                    path = ROOT/'godot'/value['atlas'].removeprefix('res://')
                    if path not in loaded_atlases: loaded_atlases[path] = Image.open(path).convert('RGBA')
                    x,y,w,h = value['region']; cel=loaded_atlases[path].crop((x,y,x+w,y+h))
                    scale=manifest['visual_scale']*.9
                    cel=cel.resize((max(1,round(cel.width*scale)),max(1,round(cel.height*scale))),Image.Resampling.LANCZOS)
                    image.alpha_composite(cel,(col*900+endpoint*450+(450-cel.width)//2,row*350+330-cel.height))
            role=job['role']+f'_{offset//6+1:02d}'
            ref=OUT/'refs'/f'{kind}_{role}.png';image.save(ref)
            fractions=', '.join(f'{i+1}: {s["fraction"]:.2f}' for i,s in enumerate(slots))
            prompt=f'''Use case: identity-preserve. Production hand-drawn game sprite animation in-between poses for Crimson Thread Pilgrimage. Reference 1 is the exact boss {identities[kind][0]}, {identities[kind][1]}. Lock its design, proportions, palette, materials, ink linework and weapon length.
The reference image contains SIX PAIRS in TWO COLUMNS x THREE ROWS, each pair is TWO chronological endpoint figures, LEFT then RIGHT. Read the PAIRS left-to-right then top-to-bottom, pair 1 through 6. Pair captions are metadata only.
Draw EXACTLY SIX NEW intermediate character drawings: one between the LEFT and RIGHT endpoints of each pair, respecting their exact limb, weapon, head and cloak movement. Most are halfway; exact progress fractions by pair: {fractions}. A genuinely new articulated pose at that position, not either endpoint copied, not a blended double/ghost, not an alternate attack. If the two endpoints differ sharply, bridge them with believable joints and momentum. For airborne frames preserve airborne intent; for grounded walking keep the supporting foot planted and body origin fixed. For idle support feet stay fixed while chest/cape/antennae articulate.
OUTPUT LAYOUT: THREE COLUMNS x TWO ROWS, SIX total cels, 1536x1024 transparent RGBA canvas. Cel 1 matches pair 1, cel 2 pair 2, ... cel 6 pair 6. Only one COMPLETE full-body boss with its COMPLETE weapon per cell, all facing RIGHT, fixed side-view, same body scale, feet at 88% cell height when grounded, clear transparent 10% gutters all sides. Never touch canvas/cell edge.
No text, labels, digits, grid, floor, shadows, checkerboard, background, particles, magic, glows, speed trails or effects. Keep the exact hand-painted existing style and sharp details. Six NEW coherent anatomical key poses, not duplicates.'''
            split_jobs.append(dict(kind=kind,role=role,refs=[ref.relative_to(ROOT).as_posix()],columns=3,rows=2,slots=slots,prompt=prompt))
    jobs=split_jobs
    for job in jobs:
        (OUT/'prompts'/f'{job["kind"]}_{job["role"]}.txt').write_text(job['prompt']+'\n',encoding='utf-8')
    (OUT/'specification.json').write_text(json.dumps(dict(bosses=6, sheets=len(jobs), new_frames=288, jobs=jobs),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'BOSS_MOTION_V6_REFS bosses=6 sheets={len(jobs)} new_frames=288')


if __name__ == '__main__': main()
