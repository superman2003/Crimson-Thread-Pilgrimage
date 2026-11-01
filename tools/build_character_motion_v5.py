#!/usr/bin/env python3
"""Register all 67 delivered v5 cels, then use the existing production packer.

Sources remain immutable. Boss recoveries concatenate two new transition cels
with the original generic recovery, inside the existing gameplay time window.
Stored pre-integration frames/metrics make rebuilding independent of new atlases.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from hashlib import sha256
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image

from build_expanded_character_motion import build

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / 'art_requests/character_motion_v5'
sys.path.insert(0, str(REQUEST))
from validate_incoming import validate  # noqa: E402

KEY = 'character_motion_v5'
BOSSES = ('broken_string_gardener', 'rust_crown_guardian',
          'saltwhite_contract_judge', 'sunken_hammer_smith',
          'silent_crown_core', 'silent_pilgrim_commander')


def operations():
    result = []
    for kind in BOSSES[:4]:
        result.append((kind, f'E_phase_{kind}.png', 'phase', 'replace', None, 'idle', 0))
    for kind in BOSSES:
        for attack in ('heavy', 'cast', 'phase'):
            result.append((kind, f'F_recover_{kind}_{attack}.png', attack+'_recover', 'prepend', None, 'recover', 0))
    result += [
        ('ash_banner_imp', 'G_ash_banner_imp_attack0.png', 'attack', 'frame', 0, 'attack', 1),
        ('ash_banner_imp', 'G_ash_banner_imp_windup.png', 'windup', 'replace', None, 'idle', 0),
        ('ash_banner_imp', 'G_ash_banner_imp_recover.png', 'recover', 'prepend', None, 'recover', 0),
        ('echo_contract_scribe', 'G_echo_contract_scribe_attack3.png', 'attack', 'frame', 3, 'attack', 2),
        ('wax_lancer', 'G_wax_lancer_recover.png', 'recover', 'prepend', None, 'recover', 0),
        ('broken_string_gardener', 'H_broken_string_gardener_death3.png', 'death', 'frame', 3, 'death', 2),
        ('delayed_shadow', 'H_delayed_shadow_recover0.png', 'recover', 'frame', 0, 'recover', 1),
        ('pipe_thrower', 'H_pipe_thrower_hurt2.png', 'hurt', 'frame', 2, 'hurt', 1),
        ('npc_blind_bell_knight', 'H_npc_blind_bell_knight_talk3.png', 'talk', 'frame', 3, 'talk', 2),
        ('npc_deserter_flagbearer', 'H_npc_deserter_flagbearer_talk6.png', 'talk', 'frame', 6, 'talk', 5),
    ]
    return result


def metrics(image):
    alpha = np.asarray(image)[:, :, 3] > 24
    ys, xs = np.nonzero(alpha)
    if not len(xs):
        raise ValueError('empty calibration pose')
    median = float(np.searchsorted(alpha.sum(axis=0).cumsum(), alpha.sum()/2)) + .5
    return {'area': int(alpha.sum()), 'median_x': median}


def reference(manifest, animation, index):
    frame = next(a for a in manifest['animations'] if a['name'] == animation)['frames'][index]
    path = ROOT / 'godot' / frame['atlas'].removeprefix('res://')
    with Image.open(path) as atlas:
        x, y, w, h = frame['region']
        stats = metrics(atlas.crop((x, y, x+w, y+h)))
    stats['anchor_offset'] = stats.pop('median_x') - (manifest['canvas'][0]/2-frame['margin'][0])
    return stats


def entries_for(asset, ref, mode):
    path = REQUEST / 'incoming' / asset['name']
    count = asset['frames']
    cols, rows = (2, 2) if count == 4 else (2, 1) if count == 2 else (1, 1)
    with Image.open(path) as image:
        w, h = image.width//cols, image.height//rows
        cells = [image.crop((i%cols*w, i//cols*h, (i%cols+1)*w, (i//cols+1)*h)) for i in range(count)]
        measured = [metrics(cell) for cell in cells]
    # Transition cel 2 approaches the generic recovery; a whole strip shares
    # that calibration. Wind-up/phase strips match their first standing pose.
    match = count-1 if mode == 'prepend' else 0
    scale = round(math.sqrt(ref['area']/measured[match]['area']), 6)
    if not .1 <= scale <= 4:
        raise ValueError(f'{path.name}: packaging scale out of range: {scale}')
    return [dict(source=path.relative_to(ROOT).as_posix(),
                 region=[i%cols*w, i//cols*h, w, h], scale=scale,
                 anchor_x=round(stats['median_x']-ref['anchor_offset']/scale, 3))
            for i, stats in enumerate(measured)]


def register(kind, specs, assets, check, registration_only=False):
    family = 'original_npcs' if kind.startswith('npc_') else 'original_creatures'
    folder = ROOT / 'godot/assets/sprites' / family / kind
    path = folder / 'motion_generation.json'
    record = json.loads(path.read_text(encoding='utf-8'))
    previous = record.get(KEY)
    if previous:
        baseline = previous['baseline_frames']
        refs = previous['references']
        rig_half_parity = previous['rig_half_parity']
    else:
        baseline = deepcopy(record['runtime_frames'])
        manifest = json.loads((folder/'motion_manifest.json').read_text(encoding='utf-8'))
        rig_half_parity = manifest['canvas'][0]//2 % 2
        refs = {name: reference(manifest, ref_anim, ref_index)
                for _, name, _, _, _, ref_anim, ref_index in specs}
    runtime = deepcopy(baseline)
    sheets = []
    for _, name, animation, mode, index, _, _ in specs:
        entries = entries_for(assets[name], refs[name], mode)
        if mode == 'replace':
            runtime[animation] = entries
        elif mode == 'frame':
            runtime[animation][index] = entries[0]
        else:
            runtime[animation] = entries + deepcopy(baseline['recover'])
        sheets.append(dict(image=name, sha256=assets[name]['sha256'], animation=animation,
                           mode=mode, index=index, frames=len(entries), scale=entries[0]['scale']))
    # Save only the overridden sequences. Other batches can rebuild their own
    # attack registrations without this batch claiming unrelated sequences.
    touched = {spec[2] for spec in specs}
    base_names = touched | {spec[5] for spec in specs} | {'recover'}
    saved_baseline = {name: baseline[name] for name in baseline if name in base_names}
    for name in touched:
        downstream = record.get('boss_motion_v6')
        if downstream:
            if downstream['baseline_frames'][name] != runtime[name]:
                raise ValueError(f'{kind}/{name}: v6 baseline does not preserve v5 registration')
        else:
            record['runtime_frames'][name] = runtime[name]
    record[KEY] = dict(tool='tools/build_character_motion_v5.py',
                       brief='art_requests/character_motion_v5/README.md',
                       baseline_frames=saved_baseline, references=refs, sheets=sheets,
                       rig_half_parity=rig_half_parity)
    encoded = json.dumps(record, ensure_ascii=False, indent=2)+'\n'
    if check:
        if path.read_text(encoding='utf-8') != encoded:
            raise ValueError(f'{kind}: v5 registration differs; rebuild')
    else:
        path.write_text(encoded, encoding='utf-8')
    result = None if registration_only else build(folder, check)
    return dict(kind=kind, sheets=sheets, runtime=result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--registration-only', action='store_true', help='Skip atlas verification when the caller runs the full production packer afterwards')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    assets = {item['name']: item for item in validate()}
    specs = operations()
    if len(specs) != 32 or {spec[1] for spec in specs} != set(assets):
        raise ValueError('registration must consume exactly the delivered 32 sheets')
    results = [register(kind, [s for s in specs if s[0] == kind], assets, args.check, args.registration_only)
               for kind in dict.fromkeys(s[0] for s in specs)]
    report = dict(characters=len(results), sheets=len(specs), frames=sum(a['frames'] for a in assets.values()), coverage=results)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'CHARACTER_MOTION_V5 characters={len(results)} sheets={len(specs)} frames={report["frames"]} check={args.check}')


if __name__ == '__main__':
    main()
