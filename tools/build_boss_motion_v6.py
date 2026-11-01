#!/usr/bin/env python3
"""Interleave imagegen-authored poses into the six production Boss rigs.

Never interpolate pixels. Segmentation only isolates complete authored figures;
all new body/limb/cloth articulation comes from the recorded source images.
"""
import argparse
from copy import deepcopy
from functools import lru_cache
from hashlib import sha256
import json
import math

import numpy as np
from PIL import Image
from scipy import ndimage

from build_expanded_character_motion import ROOT, build
from build_character_motion_v5 import measure as measure_pose, graded_mean

REQUEST = ROOT/'art_requests/boss_motion_v6'
KEY = 'boss_motion_v6'


@lru_cache(maxsize=None)
def atlas(path):
    return Image.open(path).convert('RGBA')


def measure(image):
    stats = measure_pose(np.asarray(image))
    stats['rgb'] = stats['rgb'].tolist()
    return stats


def metrics(manifest):
    result = {}
    for animation in manifest['animations']:
        result[animation['name']] = []
        for frame in animation['frames']:
            path = ROOT/'godot'/frame['atlas'].removeprefix('res://')
            x,y,w,h = frame['region']
            stats = measure(atlas(path).crop((x,y,x+w,y+h)))
            stats['anchor_offset'] = stats.pop('median_x')-(manifest['canvas'][0]/2-frame['margin'][0])
            result[animation['name']].append(stats)
    return result


def isolate(path):
    """Find six whole, separated figures; allow interlocking bounding boxes."""
    image = atlas(path)
    rgba = np.asarray(image)
    labels, count = ndimage.label(rgba[:, :, 3]>24, structure=np.ones((3,3)))
    sizes = np.bincount(labels.ravel())
    if count < 6:
        raise ValueError(f'{path.name}: fewer than six separated silhouettes')
    main = list(np.argsort(sizes[1:])[-6:]+1)
    centers = {int(i): ndimage.center_of_mass(labels==i) for i in main}
    # Sort by rows using the largest vertical gap between six body centroids.
    vertical = sorted(main, key=lambda i: centers[int(i)][0])
    main = sorted(vertical[:3],key=lambda i:centers[int(i)][1])+sorted(vertical[3:],key=lambda i:centers[int(i)][1])
    if min(sizes[i] for i in main) < 2000:
        raise ValueError(f'{path.name}: incomplete or merged figures')
    if sum(sizes[1:])-sum(sizes[i] for i in main) > sum(sizes[i] for i in main)*.15:
        raise ValueError(f'{path.name}: large unassigned props need review')
    groups = {int(i):[int(i)] for i in main}
    for i in range(1,count+1):
        if i in groups or sizes[i] < 4: continue
        y,x = ndimage.center_of_mass(labels==i)
        nearest = min(main, key=lambda k:(x-centers[int(k)][1])**2+(y-centers[int(k)][0])**2)
        groups[int(nearest)].append(i)
    frames = []
    for i in main:
        ids = groups[int(i)]
        mask = np.isin(labels,ids)
        ys,xs = np.nonzero(mask)
        if xs.min()==0 or ys.min()==0 or xs.max()==image.width-1 or ys.max()==image.height-1:
            raise ValueError(f'{path.name}: figure touches source canvas edge')
        left,top = max(0,int(xs.min())-4),max(0,int(ys.min())-4)
        right,bottom = min(image.width,int(xs.max())+5),min(image.height,int(ys.max())+5)
        seeds = []
        for group in ids:
            sy,sx = np.argwhere(labels==group)[sizes[group]//2]
            seeds.append([int(sx),int(sy)])
        cel = rgba[top:bottom,left:right].copy()
        cel[~mask[top:bottom,left:right]] = 0
        frames.append(dict(region=[left,top,right-left,bottom-top], component_seeds=seeds,
                           stats=measure(Image.fromarray(cel)), pixels=cel))
    return frames


def resolve_slot(slot, baseline, references):
    """Map the original review pairs onto main's timed bridge/settle model."""
    name, after = slot['animation'], slot['after']
    if name.endswith('_recover'):
        move = name.removesuffix('_recover')
        settle = move+'_settle' in baseline
        name = move+('_settle' if settle else '_bridge')
        if settle and after == 1:
            # This old pair headed from upright into the crouched recovery.
            # Main intentionally skips that transition; retain its cel as
            # source-only art rather than reintroducing the visual hitch.
            return None
        first = references[name][after]
        last = references[name][1] if after == 0 else references['recover'][0]
    else:
        refs = references[name]
        first, last = refs[after], refs[(after+1) % len(refs)]
    return name, after, first, last


def colour_grade(frames, targets):
    """Match each new sheet to the graded main poses beside its new cels."""
    saturation = round(float(np.clip(
        np.mean([p['saturation'] for p in targets]) /
        np.mean([f['stats']['saturation'] for f in frames]), .6, 1.15)), 3)
    source = np.mean([graded_mean(f['pixels'], saturation) for f in frames], axis=0)
    target = np.mean([p['rgb'] for p in targets], axis=0)
    return dict(saturation=saturation,
                rgb=[round(float(np.clip(t/g, .8, 1.2)), 3) for t,g in zip(target, source)])


def register(kind,jobs,check=False,registration_only=False):
    if len(jobs)!=8 or any(len(job['slots'])!=6 for job in jobs):
        raise ValueError(f'{kind}: exactly eight reviewed six-pose jobs required')
    folder = ROOT/'godot/assets/sprites/original_creatures'/kind
    path = folder/'motion_generation.json'
    record = json.loads(path.read_text(encoding='utf-8'))
    previous = record.get(KEY)
    if previous:
        baseline, references = previous['baseline_frames'], previous['references']
        if previous.get('runtime_model') != 'main-bridge-settle':
            raise ValueError(f'{kind}: restore the main rig before migrating the old v6 registration')
        rig_half_parity = previous['rig_half_parity']
    else:
        baseline = deepcopy(record['runtime_frames'])
        manifest = json.loads((folder/'motion_manifest.json').read_text(encoding='utf-8'))
        references = metrics(manifest)
        rig_half_parity = manifest['canvas'][0]//2 % 2
    inserts = {}
    sources = []
    source_only = []
    for job in jobs:
        stem = kind+'_'+job['role']
        source = REQUEST/'incoming'/(stem+'.png')
        if not source.exists(): raise ValueError(f'missing source {source}')
        if not source.with_suffix('.txt').exists(): raise ValueError(f'missing generation prompt {stem}')
        frames = isolate(source)
        mapped = [resolve_slot(slot, baseline, references) for slot in job['slots']]
        targets = [p for value in mapped if value for p in value[2:]]
        grade = colour_grade(frames, targets)
        for index,(slot,cel,value) in enumerate(zip(job['slots'],frames,mapped,strict=True)):
            if value is None:
                source_only.append(dict(image=source.name,cel=index,
                                        reason='upstream upright settle skips crouched recovery'))
                continue
            name,after,first,last = value
            t = slot['fraction']
            area = math.exp((1-t)*math.log(first['area'])+t*math.log(last['area']))
            scale = round(math.sqrt(area/cel['stats']['area']),6)
            offset = (1-t)*first['anchor_offset']+t*last['anchor_offset']
            if not .1<=scale<=4: raise ValueError(f'{stem}: invalid normalization scale {scale}')
            entry = dict(source=source.relative_to(ROOT).as_posix(), region=cel['region'],
                         component_seeds=cel['component_seeds'],scale=scale,
                         anchor_x=round(cel['stats']['median_x']-offset/scale,3),grade=grade)
            inserts.setdefault(name,{}).setdefault(after,[]).append((t,entry))
        sources.append(dict(image=source.name,sha256=sha256(source.read_bytes()).hexdigest(),
                            prompt_sha256=sha256(source.with_suffix('.txt').read_bytes()).hexdigest(),
                            role=job['role'],frames=6,runtime_frames=sum(v is not None for v in mapped),grade=grade))
    for name, additions in inserts.items():
        sequence = []
        for index,entry in enumerate(baseline[name]):
            sequence.append(deepcopy(entry))
            sequence.extend(deepcopy(item) for _,item in sorted(additions.get(index,[]),key=lambda p:p[0]))
        record['runtime_frames'][name] = sequence
    record[KEY] = dict(tool='tools/build_boss_motion_v6.py',baseline_frames=baseline,
                       references=references,sources=sources,new_drawings=48,
                       runtime_drawings=48-len(source_only),source_only=source_only,
                       runtime_model='main-bridge-settle',rig_half_parity=rig_half_parity)
    encoded = json.dumps(record,ensure_ascii=False,indent=2)+'\n'
    if check:
        if path.read_text(encoding='utf-8')!=encoded: raise ValueError(f'{kind}: registration differs; rebuild')
    else: path.write_text(encoded,encoding='utf-8')
    result = None if registration_only else build(folder,check)
    return dict(kind=kind,new_drawings=48,runtime_drawings=48-len(source_only),
                source_only=source_only,sources=sources,runtime=result)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind',action='append')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--registration-only',action='store_true')
    parser.add_argument('--report')
    args=parser.parse_args()
    jobs=json.loads((REQUEST/'specification.json').read_text(encoding='utf-8'))['jobs']
    kinds=list(dict.fromkeys(j['kind'] for j in jobs))
    if args.kind: kinds=[k for k in kinds if k in args.kind]
    results=[register(kind,[j for j in jobs if j['kind']==kind],args.check,args.registration_only) for kind in kinds]
    report=dict(bosses=len(results),new_drawings=sum(r['new_drawings'] for r in results),coverage=results)
    if args.report:
        from pathlib import Path
        output=Path(args.report);output.parent.mkdir(parents=True,exist_ok=True)
        output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'BOSS_MOTION_V6 bosses={len(results)} new_drawings={report["new_drawings"]} check={args.check}')


if __name__=='__main__':main()
