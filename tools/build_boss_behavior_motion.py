#!/usr/bin/env python3
"""Pack 144 authored defensive poses, preserving original combat art and timing."""
import argparse
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import numpy as np
from PIL import Image
from build_combat_motion_v7 import extract

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / 'art_requests/boss_behavior_v1'
BASE = ROOT / 'godot/assets/sprites/original_creatures'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    report = []
    for job in read(REQUEST / 'jobs.json'):
        kind = job['kind']
        folder = BASE / kind
        original_path = folder / 'combat_motion_v7_manifest.json'
        manifest = read(original_path)
        source = ROOT / job['source']
        cels = extract(source)  # Connected bodies, full weapons, true alpha.
        idle = next(a for a in manifest['animations'] if a['name'] == 'idle')['frames'][0]
        x, y, w, h = idle['region']
        im = Image.open(ROOT / 'godot' / idle['atlas'].removeprefix('res://')).convert('RGBA').crop((x,y,x+w,y+h))
        weights = np.asarray(im)[:,:,3].sum(axis=0)
        center = idle['margin'][0] + int(np.searchsorted(np.cumsum(weights), weights.sum() * .5))
        baseline = idle['margin'][1] + h
        # One scale for the entire sheet preserves posture/weight changes.
        scale = h / cels[-1]['height']
        images = [Image.fromarray(c['pixels']).resize((round(c['region'][2]*scale), round(c['region'][3]*scale)),Image.Resampling.LANCZOS) for c in cels]
        canvas_w, canvas_h = manifest['canvas']
        max_w = max(im.width for im in images)
        max_h = max(im.height for im in images)
        if max_w + 16 > canvas_w or max_h > baseline:
            raise ValueError(f'{kind}: new poses exceed the existing fixed rig canvas')
        cell_w, cell_h = max_w+4, max_h+4
        atlas = Image.new('RGBA', (cell_w*6,cell_h*4))
        frames = []
        for index, im in enumerate(images):
            px, py = index%6*cell_w, index//6*cell_h
            atlas.alpha_composite(im,(px,py))
            weights = np.asarray(im)[:,:,3].sum(axis=0)
            anchor = int(np.searchsorted(np.cumsum(weights),weights.sum()*.5))
            frames.append(dict(atlas=f'res://assets/sprites/original_creatures/{kind}/boss_behavior_v1.png',region=[px,py,im.width,im.height],margin=[center-anchor,baseline-im.height,canvas_w-im.width,canvas_h-im.height]))
        for name, start, end, fps, loop in [('backstep',0,12,18,True),('ready_guard',12,18,18,False),('ready_settle',18,24,18,False)]:
            manifest['animations'].append(dict(name=name,fps=fps,loop=loop,frames=frames[start:end]))
        manifest['behavior_generation_record'] = 'boss_behavior_v1.json'
        record = dict(schema=1,kind=kind,source=job['source'],source_sha256=sha256(source.read_bytes()).hexdigest(),reference=f'art_requests/boss_behavior_v1/refs/{kind}.png',
            generator='built-in image_gen',prompt=job['prompt'],new_drawings=24,source_regions=[c['region'] for c in cels],scale=scale,
            baseline_manifest_sha256=sha256(original_path.read_bytes()).hexdigest(),animations=['backstep','ready_guard','ready_settle'])
        for path, data in [(folder/'boss_behavior_manifest.json',manifest),(folder/'boss_behavior_v1.json',record)]:
            content=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
            if args.check:
                if path.read_text(encoding='utf-8') != content:raise ValueError(f'{path}: stale build')
            else:path.write_text(content,encoding='utf-8',newline='\n')
        dest=folder/'boss_behavior_v1.png'
        if args.check:
            with Image.open(dest) as current:
                if current.size!=atlas.size or current.tobytes()!=atlas.tobytes():raise ValueError(f'{dest}: stale pixels')
        else:atlas.save(dest)
        report.append(dict(kind=kind,drawings=24,clips=3,canvas=manifest['canvas']))
    print(json.dumps(dict(bosses=len(report),new_drawings=sum(r['drawings'] for r in report),clips=len(report)*3),indent=2))

if __name__ == '__main__':main()
