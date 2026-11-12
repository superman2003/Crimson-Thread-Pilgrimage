"""Pack image_gen redraw sheets without synthesizing poses or changing clocks.

One uniform registration scale is used for an entire sheet. Transparent cropping
uses either planted feet or the authored cell coordinates for hovering actors.

The sheet scale makes the median drawn body cover the same area as the clip it
replaces. Height is not used: a redrawn pose with wider wings, cloak or weapon at
the same height would otherwise come out bigger than every clip left untouched,
and the actor would visibly grow and shrink when it changes action.
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


# A walk cycle whose legs do not move is a still picture sliding along the floor.
# Leg change = mean neighbour-frame outline change in the lowest 35% of the
# clip's height. Deliveries listed in stride_pending.json were accepted before
# this floor existed and wait for a redraw (docs/research/20261112_redraw_walk_stride_request.md).
# Immutable pre-guard source identities: only these historical sheets may wait.
LEGACY_STRIDE_SOURCES = {
    ('corridor_heavy', 'walk'): 'd93dbb520a5dcc9612859455e98f8508ad2aef91ea0d5e512673c6594012fbc6',
    ('drain_leech', 'walk'): '040e35bfeb97a865948628d95510495b0a8facd1b085dac1b0a0c48b7c411658',
    ('echo_moss_larva', 'walk'): 'dc69307bc6bf5704c643bc757fdae13ac89fc3adee8391761a508d4d2c5648c8',
    ('erasure_bailiff', 'walk'): '194e8c8a1c6979c62ba46a8eac754a7f94557b4cfd4bd73d425b77f880afbeeb',
    ('moss_larva', 'walk'): 'f8f2807e361d9cc3a44da24a478fb0f033694003e4a684e181dc39ec41098b40',
    ('pilgrim_chariot', 'walk'): 'd7038e1d0a8e4bc0637400ee0502998acba7d2369b34c35d54bb05fec4e83c32',
    ('rust_crown_guardian', 'walk'): '8322b4dc1d578d4159148fc0bd39af1eb0e4817ec4c06e44606d683ba89babf2',
    ('rust_diver', 'walk'): 'b9189c17149746d221e31278607bb14da579c439b1fb7d95a366ef11d1b320f5',
    ('saltwhite_contract_judge', 'walk'): '978f1df0f1081d58f11c0b532e485257f6cccf38dd0eb8b60c0cd6a8be7e558c',
    ('silent_crown_core', 'walk'): '18d7c7c81fc58dccc37a096874191603692a14d71dbdd37c595e6a0071e3f569',
    ('vine_crawler', 'walk'): 'dc302920c71e42dce4663fbcf0ef270eee9dc8704d67117e30e46d5f35f05740',
}
LEG_CHANGE_FLOOR = 0.15
LEG_BAND = 0.35
BODY_AREA_TOLERANCE = 0.04      # redrawn median body area vs the replaced clip


def body_area(clip, canvas):
    """Median solid area of the clip being replaced, on the rig canvas."""
    pages = fit.Atlases()
    return float(statistics.median(int(audit.placed(pages.alpha(f), f, canvas).sum()) for f in clip['frames']))


def extract(job, canvas, target_area=None):
    registration = job.get('registration', 'ground')
    if registration not in ('ground', 'cell_center'):
        raise ValueError('Unknown drawing registration: '+registration)
    source = ROOT/job['source']
    if sha256(source.read_bytes()).hexdigest() != job['sha256']:
        raise ValueError('Raw image_gen output changed: '+str(source))
    with Image.open(source) as image:
        sheet = image.convert('RGBA')
    columns, rows = job['grid']
    cells, boxes, heights, areas = [], [], [], []
    for i in range(job['count']):
        x, y = i % columns, i // columns
        cell = sheet.crop((round(x*sheet.width/columns), round(y*sheet.height/rows),
                           round((x+1)*sheet.width/columns), round((y+1)*sheet.height/rows)))
        alpha = np.asarray(cell.getchannel('A'))
        gutter = np.concatenate((alpha[:5].ravel(), alpha[-5:].ravel(),
                                 alpha[:, :5].ravel(), alpha[:, -5:].ravel()))
        if float(np.mean(gutter > 8)) > .01:
            raise ValueError(f'Nontransparent cell gutter in drawing {i}; redraw the background')
        solid = alpha > 128
        ys, xs = np.nonzero(solid)
        if len(xs) < 500:
            raise ValueError('Empty drawing')
        box = (int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1)
        if min(box[0], box[1], cell.width-box[2], cell.height-box[3]) < 5:
            raise ValueError(f'Drawing {i} touches its cell boundary')
        cells.append(cell); boxes.append(box); heights.append(box[3]-box[1]); areas.append(len(xs))
    if target_area:
        scale = (target_area/statistics.median(areas))**.5
    else:
        scale = job['reference_height']/statistics.median(heights)
    # This single affine scale is never adjusted to make individual frames fit.
    drawings = []
    for cell, box in zip(cells, boxes):
        art = cell.crop(box)
        art = art.resize((round(art.width*scale), round(art.height*scale)), Image.Resampling.LANCZOS)
        x = round(job['center_x']+(box[0]-cell.width/2)*scale)
        if registration == 'cell_center':
            # Keep the vertical motion that was actually drawn, including wing
            # height changes; do not move a hovering body to align its lowest pixel.
            y = round(job['center_y']+(box[1]-cell.height/2)*scale)
        else:
            y = job['ground_y']-art.height
        if x < 0 or y < 0 or x+art.width > canvas[0] or y+art.height > canvas[1]:
            raise ValueError('Drawing leaves the frozen rig canvas')
        drawings.append((art, (x, y)))
    return drawings, scale


def stride_pending():
    path = REQUEST/'stride_pending.json'
    if not path.exists():
        return set()
    pending = read(path)
    if pending.get('schema') != 1 or pending.get('floor') != LEG_CHANGE_FLOOR:
        raise ValueError('Invalid historical stride exception policy')
    keys = []
    for row in pending['clips']:
        key = (row['kind'], row['clip'])
        if key not in LEGACY_STRIDE_SOURCES or row.get('source_sha256') != LEGACY_STRIDE_SOURCES[key]:
            raise ValueError('Stride exceptions may only retain pinned historical sources')
        keys.append(key)
    if len(keys) != len(set(keys)):
        raise ValueError('Duplicate historical stride exception')
    return set(keys)


def stride_waived(kind, job):
    key = (kind, job['clip'])
    return key in stride_pending() and job['sha256'] == LEGACY_STRIDE_SOURCES[key]


def leg_change(masks, loop):
    rows = np.nonzero(np.any(masks, axis=0).any(axis=1))[0]
    cut = int(rows.min()+(rows.max()-rows.min())*(1-LEG_BAND))
    legs = [m[cut:] for m in masks]
    pairs = zip(legs, legs[1:]+(legs[:1] if loop else []))
    return round(float(np.mean([audit.change(a, b) for a, b in pairs])), 3)


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
                area_ratio=round(max(int(m.sum()) for m in masks)/min(int(m.sum()) for m in masks), 3),
                body_area=float(statistics.median(int(m.sum()) for m in masks)),
                leg_change=leg_change(masks, loop))


def build(kind, check=False):
    spec_path = REQUEST/'jobs'/(kind+'.json')
    spec = read(spec_path)
    path, base = baseline(kind)
    if sha256(path.read_bytes()).hexdigest() != spec['baseline_sha256']:
        raise ValueError('Baseline changed; review drawings against the new layer')
    clips = {c['name']: c for c in fit.animations_of(base)}
    drawings, summary, strides = {}, {}, {}
    for job in spec['jobs']:
        name = job['clip']; clip = clips[name]
        if name in summary:
            raise ValueError('Duplicate registered clip: '+name)
        prompt = (ROOT/job['source']).with_suffix('.prompt.txt').read_text(encoding='utf-8').rstrip('\n')
        if sha256(prompt.encode()).hexdigest() != job['prompt_sha256']:
            raise ValueError('Recorded generation prompt changed')
        if job['count'] != len(clip['frames']):
            raise ValueError('Redrawing may not change the frozen frame count')
        replaced = body_area(clip, base['canvas'])
        cels, scale = extract(job, base['canvas'], replaced)
        measured = metrics(cels, base['canvas'], bool(clip['loop']))
        measured['body_area_ratio'] = round(measured.pop('body_area')/replaced, 3)
        if abs(measured['body_area_ratio']-1) > BODY_AREA_TOLERANCE:
            raise ValueError(f'Redrawn body size differs from the replaced clip: {name} {measured}')
        if measured['unique'] != job['count'] or measured['max_change'] > .5:
            raise ValueError(f'Duplicated drawings or silhouette jump: {name} {measured}')
        if name in ('idle', 'walk') and (measured['boil_ratio'] >= 3 or measured['area_ratio'] > 1.15):
            raise ValueError(f'Outline boil or body mass drift: {name} {measured}')
        if name in ('idle', 'walk') and clip['loop'] and measured['loop_seam'] > .25:
            raise ValueError(f'Loop seam needs another drawing pass: {name} {measured}')
        # Measured for the gate and the build log only; the stored record keeps its shape.
        legs = measured.pop('leg_change')
        strides[name] = legs
        if (name == 'walk' and fit.is_grounded(base) and job.get('registration', 'ground') == 'ground'
                and legs < LEG_CHANGE_FLOOR and not stride_waived(kind, job)):
            raise ValueError(f'Walk cycle legs barely move ({legs} < {LEG_CHANGE_FLOOR}); redraw with real stride poses: {kind}')
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
    print(json.dumps(dict(kind=kind, check=check, clips=summary, leg_change=strides)))
    return manifest


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--kind')
    selection.add_argument('--all', action='store_true', help='Validate or rebuild every registered delivery')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    kinds = [p.stem for p in sorted((REQUEST/'jobs').glob('*.json'))] if args.all else [args.kind]
    if not kinds:
        parser.error('No registered deliveries found; hydrate the redraw request directory')
    for kind in kinds:
        build(kind, args.check)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
