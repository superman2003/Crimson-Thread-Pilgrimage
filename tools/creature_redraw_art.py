"""Pack image_gen redraw sheets without synthesizing poses or changing clocks.

One uniform registration scale matches the replaced median solid body area for an entire sheet. Transparent cropping
uses either planted feet or the authored cell coordinates for hovering actors.
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


BODY_AREA_TOLERANCE = 0.04      # redrawn median body area vs the replaced clip
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

WALK_STRIDE_MIN = LEG_CHANGE_FLOOR

# Painting style of the new drawings against the clip they replace. The
# silhouette checks above cannot see a smeared outline or lost markings.
SOFT_EDGE_LIMIT = 2.5           # semi-transparent pixels per solid pixel, new / replaced
ACCENT_FLOOR = 0.55             # share of saturated solid pixels, new / replaced
ACCENT_MIN_SHARE = 0.05         # creatures with fewer accent pixels are not judged on them
# Deliveries merged before this check that already lost accent colour. Each is
# pinned to its source sheet: a new drawing pass for the clip is judged again.
LEGACY_ACCENT_SOURCES = {
    ('bronze_moth', 'moth_dust'): 'b056b313d65d7461c97effad9aef231a00daa80f3cd0a71fed226a89387d3499',
    ('bronze_moth', 'moth_dust_recover'): '686aa4ce38da02cf2fa82b5c2cb2cd0a7df85287cf831b2e53a34b8c0638325e',
    ('bronze_moth', 'moth_dust_windup'): 'c888232b2eb93cdb09a8d62eddfebdbeca048c1d492515d79258a16c7e235e9d',
    ('bronze_moth', 'windup'): 'ef60efaa989a03632119a73ff4f8f26c94e9b6ae3b927320624b36e0173c15fa',
    ('corridor_heavy', 'heavy_stamp'): 'e41032cefbc54756428d8475effdef666b58a1db90e9cef6b3934069cf9a35e3',
    ('index_scribe', 'attack'): '797afc62e4ed7d043c3eaf6136754585edb594db8028d955eada18dae65d6516',
    ('saltwhite_contract_judge', 'windup'): '5efa67075624690cffedc7a2a6000764838488a163e9e997cbb0b28764a214a3',
}

# Merged minutes before this check landed (#636) and fails both parts of it.
# Kept only so the contract stays green until the clip is redrawn: delete this
# entry with that redraw. Pinned to the sheet, so a new pass is judged in full.
PENDING_STYLE_REDRAW = {
    ('summoned_page', 'windup'): '7cabfa1e7070d40b9b87888dd98cdb8c6c1645177263d414560cb739d30df3d7',
}


def surface_style(drawings):
    """(soft-edge share, accent share) over the solid pixels of the drawings."""
    soft = solid = accent = 0
    for art, _ in drawings:
        pixels = np.asarray(art.convert('RGBA')).astype(np.int16)
        alpha = pixels[:, :, 3]
        mask = alpha > 128
        colour = pixels[mask][:, :3]
        high, low = colour.max(axis=1), colour.min(axis=1)
        soft += int(((alpha > 8) & ~mask).sum())
        solid += int(mask.sum())
        accent += int(((high > 90) & ((high-low)*2 > high)).sum())
    return soft/solid, accent/solid


def style_defects(replaced, redrawn, accent_waived=False):
    """Reasons the new drawings no longer look like the clip they replace."""
    old_soft, old_accent = surface_style(replaced)
    new_soft, new_accent = surface_style(redrawn)
    found = []
    if new_soft > old_soft*SOFT_EDGE_LIMIT:
        found.append(f'blurred outline: soft edge {new_soft:.3f} vs {old_soft:.3f} in the replaced clip')
    if old_accent >= ACCENT_MIN_SHARE and new_accent < old_accent*ACCENT_FLOOR and not accent_waived:
        found.append(f'lost markings: accent colour {new_accent:.3f} vs {old_accent:.3f} in the replaced clip')
    return found


def body_area(clip, canvas):
    """Median solid area of the clip being replaced, on the rig canvas."""
    pages = fit.Atlases()
    return float(statistics.median(int(audit.placed(pages.alpha(f), f, canvas).sum()) for f in clip['frames']))


def index_list(values, limit, label):
    if not values or any(type(i) is not int or i < 0 or i >= limit for i in values):
        raise ValueError('Invalid '+label)
    if len(set(values)) != len(values):
        raise ValueError('Duplicate '+label)
    return list(values)


def reviewed_checklist():
    source = REQUEST/'checklist.json'
    if sha256(source.read_bytes()).hexdigest() != '53b857ca603458a6d47dedab2b8a0b72b6183290c10d951f54b76f3af3dcc778':
        raise ValueError('The reviewed pinned checklist changed')
    return read(source)['clips']


def required_frames(kind, clip):
    rows = [r for r in reviewed_checklist() if r['kind'] == kind and r['clip'] == clip]
    if len(rows) != 1:
        raise ValueError('Missing or ambiguous checklist entry')
    row = rows[0]
    if row['boil']:
        raise ValueError('Outline boil requires a complete clip redraw')
    return ({r['frame'] for r in row['size']} |
            {r[key] for r in row['jumps'] for key in ('after', 'before')})


def target_indices(kind, job, clip):
    count = len(clip['frames'])
    if 'target_frames' not in job:
        if job['count'] != count:
            raise ValueError('Redrawing may not change the frozen frame count')
        return list(range(count))
    if job.get('original_frame_count') != count:
        raise ValueError('Partial redraw changed the frozen frame count')
    targets = index_list(job['target_frames'], count, 'target frame indices')
    if len(targets) != job['count']:
        raise ValueError('Partial redraw count does not match its target frames')
    missing = required_frames(kind, job['clip']) - set(targets)
    if missing:
        raise ValueError('Partial redraw misses listed frames: '+str(sorted(missing)))
    return targets


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
    selected = index_list(job.get('cells', list(range(job['count']))), columns*rows, 'source cells')
    if len(selected) != job['count']:
        raise ValueError('Source cell count does not match the drawings')
    scale_cells = index_list(job.get('scale_cells', selected), columns*rows, 'scale cells')
    if not set(selected).issubset(scale_cells):
        raise ValueError('Every selected cell must participate in the shared sheet scale')
    cells, boxes, areas = {}, {}, {}
    for i in scale_cells:
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
        cells[i] = cell; boxes[i] = box; areas[i] = len(xs)
    scale = ((target_area/statistics.median(areas[i] for i in scale_cells))**.5 if target_area
             else job['reference_height']/statistics.median(boxes[i][3]-boxes[i][1] for i in scale_cells))
    # This single affine scale is never adjusted to make individual frames fit.
    drawings = []
    for i in selected:
        cell, box = cells[i], boxes[i]
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


def source_drawing(frame, cache):
    atlas = frame['atlas']
    if atlas not in cache:
        with Image.open(ROOT/'godot'/atlas.removeprefix('res://')) as image:
            cache[atlas] = image.convert('RGBA')
    x, y, w, h = frame['region']
    return cache[atlas].crop((x,y,x+w,y+h)), tuple(frame['margin'][:2])


def replace_frames(base, packed):
    manifest = deepcopy(base)
    for clip in manifest['animations']:
        clip['frames'] = [packed.get((clip['name'], i), old)
                          for i, old in enumerate(clip['frames'])]
    return manifest


def unrepaired_sizes(row, fit_rows):
    return [(item['frame'], fit_rows[item['frame']][0]) for item in row['size']
            if abs(fit_rows[item['frame']][0]-1) > .080001]


def verify_repairs():
    """Confirm listed size defects disappeared after measuring the actual delivery."""
    rows = {(r['kind'],r['clip']):r for r in reviewed_checklist()}
    checked_clips = checked_frames = 0
    for spec_path in sorted((REQUEST/'jobs').glob('*.json')):
        spec = read(spec_path); kind = spec['kind']
        partial = [j for j in spec['jobs'] if 'target_frames' in j]
        if not partial: continue
        folder = fit.CREATURES/kind
        path = fit.active_manifest(folder); manifest = read(path)
        table = read(folder/'frame_fit.json')
        if (table['manifest_sha256'] != sha256(path.read_bytes()).hexdigest() or
                table['atlas_sha256'] != fit.atlas_digests(manifest)):
            raise ValueError('Stale repair measurements: '+kind)
        for job in partial:
            row = rows[(kind,job['clip'])]
            fits = table['frames'].get(job['clip'], [[1,0,0]]*row['frames'])
            remaining = unrepaired_sizes(row, fits)
            if remaining:
                raise ValueError(f'Listed size defect remains: {kind}/{job["clip"]} {remaining}')
            checked_clips += 1; checked_frames += len(row['size'])
    print(f'REPAIR_VERIFY clips={checked_clips} size_frames={checked_frames} remaining=0')


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

def mask_leg_change(masks, loop):
    rows = np.nonzero(np.any(masks, axis=0).any(axis=1))[0]
    cut = int(rows.min()+(rows.max()-rows.min())*(1-LEG_BAND))
    legs = [m[cut:] for m in masks]
    pairs = zip(legs, legs[1:]+(legs[:1] if loop else []))
    return float(np.mean([audit.change(a, b) for a, b in pairs]))


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
                leg_change_raw=mask_leg_change(masks, loop))


def leg_change(drawings, canvas):
    """Mean cyclic IoU change in the common lower 35% of the rig silhouette.

    Keep one crop for the complete clip so moving the crop cannot masquerade
    as leg motion. This measures a gait already registered on its rig canvas.
    """
    masks = []
    for art, (x, y) in drawings:
        mask = np.zeros((canvas[1], canvas[0]), bool)
        mask[y:y+art.height, x:x+art.width] = np.asarray(art.getchannel('A')) > 128
        masks.append(mask)
    low = min(int(np.nonzero(mask)[0].min()) for mask in masks)
    high = max(int(np.nonzero(mask)[0].max()) for mask in masks)+1
    start = round(high-(high-low)*.35)
    legs = [mask[start:] for mask in masks]
    return round(float(statistics.mean(audit.change(a, b) for a, b in zip(legs, legs[1:]+legs[:1]))), 4)


def build(kind, check=False):
    spec_path = REQUEST/'jobs'/(kind+'.json')
    spec = read(spec_path)
    path, base = baseline(kind)
    if sha256(path.read_bytes()).hexdigest() != spec['baseline_sha256']:
        raise ValueError('Baseline changed; review drawings against the new layer')
    clips = {c['name']: c for c in fit.animations_of(base)}
    drawings, summary, atlas_cache, strides = {}, {}, {}, {}
    for job in spec['jobs']:
        name = job['clip']; clip = clips[name]
        if name in summary:
            raise ValueError('Duplicate registered clip: '+name)
        prompt = (ROOT/job['source']).with_suffix('.prompt.txt').read_text(encoding='utf-8').rstrip('\n')
        if sha256(prompt.encode()).hexdigest() != job['prompt_sha256']:
            raise ValueError('Recorded generation prompt changed')
        if 'guide' in job and sha256((ROOT/job['guide']).read_bytes()).hexdigest() != job['guide_sha256']:
            raise ValueError('Recorded pose reference recipe changed')
        for guide in job.get('reference', {}).get('supporting_guides', []):
            if sha256((ROOT/guide['path']).read_bytes()).hexdigest() != guide['sha256']:
                raise ValueError('Recorded handoff reference recipe changed')
        targets = target_indices(kind, job, clip)
        replaced = body_area(clip, base['canvas'])
        target_area = replaced
        if 'target_frames' in job:
            if 'guide' not in job:
                raise ValueError('Partial redraw requires its frozen pose guide')
            guide = read(ROOT/job['guide'])
            entries = guide['entries']
            if guide['kind'] != kind or guide['canvas'] != base['canvas'] or guide['baseline_sha256'] != spec['baseline_sha256']:
                raise ValueError('Partial redraw guide belongs to a different baseline')
            if job.get('grid') != guide['grid'] or job.get('scale_cells') != list(range(len(entries))):
                raise ValueError('Shared sheet scale must cover every frozen guide cell')
            for cell, target in zip(job['cells'], targets):
                entry = entries[cell]
                if (entry['clip'], entry['frame'], entry['source_frame']) != (name, target, clip['frames'][target]):
                    raise ValueError('Source cell does not match the frozen target pose')
            target_area = body_area({'frames':[entry['source_frame'] for entry in entries]}, base['canvas'])
        cels, scale = extract(job, base['canvas'], target_area)
        replacements = dict(zip(targets, cels))
        complete = ([replacements[i] if i in replacements else source_drawing(frame, atlas_cache)
                     for i, frame in enumerate(clip['frames'])]
                    if 'target_frames' in job else cels)
        measured = metrics(complete, base['canvas'], bool(clip['loop']))
        measured['body_area_ratio'] = round(measured.pop('body_area')/replaced, 3)
        if abs(measured['body_area_ratio']-1) > BODY_AREA_TOLERANCE:
            raise ValueError(f'Redrawn body size differs from the replaced clip: {name} {measured}')
        defects = style_defects([source_drawing(frame, atlas_cache) for frame in clip['frames']], cels,
                                LEGACY_ACCENT_SOURCES.get((kind, name)) == job['sha256'])
        if defects and PENDING_STYLE_REDRAW.get((kind, name)) == job['sha256']:
            print(f'STYLE_REDRAW_PENDING {kind}/{name}: '+'; '.join(defects))
            defects = []
        if defects:
            raise ValueError(f'Redraw drifts from the established painting: {kind}/{name}: '+'; '.join(defects))
        unique = len({sha256(a.tobytes()).hexdigest() for a, _ in cels})
        measured['unique'] = unique
        if measured['unique'] != job['count'] or measured['max_change'] > .5:
            raise ValueError(f'Duplicated drawings or silhouette jump: {name} {measured}')
        if name in ('idle', 'walk') and (measured['boil_ratio'] >= 3 or measured['area_ratio'] > 1.15):
            raise ValueError(f'Outline boil or body mass drift: {name} {measured}')
        if name in ('idle', 'walk') and clip['loop'] and measured['loop_seam'] > .25:
            raise ValueError(f'Loop seam needs another drawing pass: {name} {measured}')
        # Apply the shared ground-walk floor before rounding diagnostic values.
        legs = measured.pop('leg_change_raw')
        strides[name] = round(legs, 3)
        if (name == 'walk' and fit.is_grounded(base) and job.get('registration', 'ground') == 'ground'
                and legs < LEG_CHANGE_FLOOR and not stride_waived(kind, job)):
            raise ValueError(f'Walk cycle legs barely move ({legs} < {LEG_CHANGE_FLOOR}); redraw with real stride poses: {kind}')
        if job.get('stride_reviewed') is not None:
            if job['stride_reviewed'] is not True or name != 'walk' or 'target_frames' in job:
                raise ValueError('Stride review requires a complete walking cycle')
            measured['leg_change'] = leg_change(complete, base['canvas'])
            if measured['leg_change'] < WALK_STRIDE_MIN:
                raise ValueError(f'Walking feet need another drawing pass: {name} {measured}')
        summary[name] = dict(measured, registration_scale=round(scale, 9), frames=job['count'])
        if 'target_frames' in job:
            summary[name].update(target_frames=targets, original_frames=len(clip['frames']),
                                 measurement='complete_clip_with_unchanged_neighbours')
        drawings.update({(name, i): drawing for i, drawing in replacements.items()})
    pages, packed = onion.pack(kind, drawings, base['canvas'])
    for key, frame in packed.items():
        page = pages[int(frame['atlas'].rsplit('_', 1)[1].removesuffix('.png'))]
        x, y, w, h = frame['region']
        if x < 0 or y < 0 or x+w > page.width or y+h > page.height:
            raise ValueError('Packed drawing leaves its atlas: '+str(key))
        actual = np.asarray(page.crop((x,y,x+w,y+h)))
        expected = np.asarray(drawings[key][0])
        if (not np.array_equal(actual[:,:,3], expected[:,:,3]) or
                not np.array_equal(actual[expected[:,:,3]>0], expected[expected[:,:,3]>0])):
            raise ValueError('Packed drawing differs from its source: '+str(key))
    for frame in packed.values():
        frame['atlas'] = frame['atlas'].replace('motion_onion_', 'motion_redraw_')
    manifest = replace_frames(base, packed)
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
    selection.add_argument('--verify-repairs', action='store_true', help='Check listed size defects against fresh runtime measurements')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    if args.verify_repairs:
        verify_repairs()
        return 0
    kinds = [p.stem for p in sorted((REQUEST/'jobs').glob('*.json'))] if args.all else [args.kind]
    if not kinds:
        parser.error('No registered deliveries found; hydrate the redraw request directory')
    for kind in kinds:
        build(kind, args.check)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
