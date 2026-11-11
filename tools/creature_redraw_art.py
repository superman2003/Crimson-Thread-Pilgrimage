"""Pack image_gen redraw sheets without synthesizing poses or changing clocks.

One uniform registration scale is used for an entire sheet. Only transparent
cropping and fixed ground registration are performed on individual drawings.
"""
from copy import deepcopy
from hashlib import sha256
import argparse
import json
from pathlib import Path
import statistics
import numpy as np
from PIL import Image
import motion_onion as onion
import build_creature_frame_fit as fit
import build_creature_redraw_list as audit

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / 'art_requests/creature_redraw_v1'
LAYER = 'motion_redraw_manifest.json'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')


def baseline(kind):
    folder = fit.CREATURES/kind
    path = next(folder/name for name in fit.ACTIVE_LAYERS if name != LAYER and (folder/name).exists())
    return path, read(path)


def extract(job, canvas):
    source = ROOT/job['source']
    if sha256(source.read_bytes()).hexdigest() != job['sha256']:
        raise ValueError('Raw image_gen output changed: '+str(source))
    with Image.open(source) as image:
        sheet = image.convert('RGBA')
    columns, rows = job['grid']
    cells, boxes, heights = [], [], []
    for i in range(job['count']):
        x, y = i % columns, i // columns
        cell = sheet.crop((round(x*sheet.width/columns), round(y*sheet.height/rows),
                           round((x+1)*sheet.width/columns), round((y+1)*sheet.height/rows)))
        solid = np.asarray(cell.getchannel('A')) > 128
        ys, xs = np.nonzero(solid)
        if len(xs) < 500:
            raise ValueError('Empty drawing')
        box = (int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1)
        if min(box[0], box[1], cell.width-box[2], cell.height-box[3]) < 5:
            raise ValueError(f'Drawing {i} touches its cell boundary')
        cells.append(cell); boxes.append(box); heights.append(box[3]-box[1])
    scale = job['reference_height']/statistics.median(heights)
    # This single affine scale is never adjusted to make individual frames fit.
    drawings = []
    for cell, box in zip(cells, boxes):
        art = cell.crop(box)
        art = art.resize((round(art.width*scale), round(art.height*scale)), Image.Resampling.LANCZOS)
        x = round(job['center_x']+(box[0]-cell.width/2)*scale)
        y = job['ground_y']-art.height
        if x < 0 or y < 0 or x+art.width > canvas[0] or y+art.height > canvas[1]:
            raise ValueError('Drawing leaves the frozen rig canvas')
        drawings.append((art, (x, y)))
    return drawings, scale


def metrics(drawings, canvas, loop):
    masks = []
    for art, (x, y) in drawings:
        mask = np.zeros((canvas[1], canvas[0]), bool)
        mask[y:y+art.height, x:x+art.width] = np.asarray(art.getchannel('A')) > 128
        masks.append(mask)
    pairs = list(zip(masks, masks[1:]+(masks[:1] if loop else [])))
    changes = [audit.change(a, b) for a, b in pairs]
    slide = float(np.mean([audit.change(m[:, 2:], m[:, :-2]) for m in masks]))
    return dict(mean_change=round(float(np.mean(changes)), 4),
                max_change=round(max(changes), 4),
                loop_seam=round(audit.change(masks[-1], masks[0]), 4) if loop else None,
                boil_ratio=round(float(np.mean(changes))/max(.02, slide), 3),
                unique=len({sha256(a.tobytes()).hexdigest() for a, _ in drawings}),
                area_ratio=round(max(int(m.sum()) for m in masks)/min(int(m.sum()) for m in masks), 3))


def build(kind, check=False):
    spec_path = REQUEST/'jobs'/(kind+'.json')
    spec = read(spec_path)
    path, base = baseline(kind)
    if sha256(path.read_bytes()).hexdigest() != spec['baseline_sha256']:
        raise ValueError('Baseline changed; review drawings against the new layer')
    clips = {c['name']: c for c in fit.animations_of(base)}
    drawings, summary = {}, {}
    for job in spec['jobs']:
        name = job['clip']; clip = clips[name]
        prompt = (ROOT/job['source']).with_suffix('.prompt.txt').read_text(encoding='utf-8').rstrip('\n')
        if sha256(prompt.encode()).hexdigest() != job['prompt_sha256']:
            raise ValueError('Recorded generation prompt changed')
        if job['count'] != len(clip['frames']):
            raise ValueError('Redrawing may not change the frozen frame count')
        cels, scale = extract(job, base['canvas'])
        measured = metrics(cels, base['canvas'], bool(clip['loop']))
        if measured['unique'] != job['count'] or measured['max_change'] > .5:
            raise ValueError(f'Duplicated drawings or silhouette jump: {name} {measured}')
        if name in ('idle', 'walk') and (measured['boil_ratio'] >= 3 or measured['area_ratio'] > 1.15):
            raise ValueError(f'Outline boil or body mass drift: {name} {measured}')
        summary[name] = dict(measured, registration_scale=round(scale, 9), frames=job['count'])
        drawings.update({(name, i): drawing for i, drawing in enumerate(cels)})
    pages, packed = onion.pack(kind, drawings, base['canvas'])
    for frame in packed.values():
        frame['atlas'] = frame['atlas'].replace('motion_onion_', 'motion_redraw_')
    manifest = deepcopy(base)
    for clip in manifest['animations']:
        name = clip['name']
        if name in summary:
            clip['frames'] = [packed[(name, i)] for i in range(len(clip['frames']))]
    manifest['redraw_record'] = dict(schema=1, baseline=path.name, baseline_sha256=spec['baseline_sha256'],
                                    spec=spec_path.relative_to(ROOT).as_posix(), clips=summary)
    outputs = [(fit.CREATURES/kind/LAYER, manifest)]
    outputs += [(fit.CREATURES/kind/f'motion_redraw_{i:02}.png', page) for i, page in enumerate(pages)]
    for target, value in outputs:
        if check:
            if isinstance(value, dict):
                if read(target) != value: raise ValueError('Stale manifest')
            else:
                with Image.open(target) as current:
                    if current.convert('RGBA').tobytes() != value.tobytes(): raise ValueError('Stale atlas')
        elif isinstance(value, dict): write(target, value)
        else: value.save(target)
    print(json.dumps(dict(kind=kind, check=check, clips=summary)))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--kind')
    selection.add_argument('--all', action='store_true', help='Validate or rebuild every registered delivery')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    kinds = [p.stem for p in sorted((REQUEST/'jobs').glob('*.json'))] if args.all else [args.kind]
    for kind in kinds:
        build(kind, args.check)
