#!/usr/bin/env python3
"""Check every pre-v6 rendered pose against a frozen local baseline archive."""
import argparse
from functools import lru_cache
import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_boss_motion_v6 import ROOT, KEY


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-dir',type=Path,required=True)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    results=[]

    @lru_cache(maxsize=None)
    def pixels(path): return Image.open(path).convert('RGBA')

    def crop(frame,folder=None):
        path=folder/Path(frame['atlas']).name if folder else ROOT/'godot'/frame['atlas'].removeprefix('res://')
        x,y,w,h=frame['region']
        data=np.array(pixels(path).crop((x,y,x+w,y+h)))
        data[data[:,:,3]==0]=0
        return data

    def origin(manifest,frame):
        return np.array([(frame['margin'][i]-manifest['canvas'][i]/2)*manifest['visual_scale']+manifest['visual_offset'][i] for i in (0,1)])

    for saved in sorted(args.baseline_dir.glob('*/motion_manifest.json')):
        kind=saved.parent.name
        folder=ROOT/'godot/assets/sprites/original_creatures'/kind
        record=json.loads((folder/'motion_generation.json').read_text(encoding='utf-8'))
        if KEY not in record: raise ValueError(f'{kind}: new registration missing')
        batch=record[KEY]
        before=json.loads(saved.read_text(encoding='utf-8'))
        after=json.loads((folder/'motion_manifest.json').read_text(encoding='utf-8'))
        current={a['name']:a for a in after['animations']}
        checked=0
        for animation in before['animations']:
            name=animation['name']; cursor=0
            for index,old_entry in enumerate(batch['baseline_frames'][name]):
                while cursor<len(record['runtime_frames'][name]) and record['runtime_frames'][name][cursor]!=old_entry:cursor+=1
                if cursor==len(record['runtime_frames'][name]):raise ValueError(f'{kind}/{name}/{index}: original source entry missing')
                old_frame=animation['frames'][index];new_frame=current[name]['frames'][cursor]
                if not np.array_equal(crop(old_frame,saved.parent),crop(new_frame)):raise ValueError(f'{kind}/{name}/{index}: original visible pixels changed')
                if np.max(np.abs(origin(before,old_frame)-origin(after,new_frame)))>=1e-5:raise ValueError(f'{kind}/{name}/{index}: original rig origin moved')
                checked+=1;cursor+=1
        results.append(dict(kind=kind,original_poses_preserved=checked))
    if len(results)!=6:raise ValueError('exactly six frozen Boss baselines required')
    report=dict(bosses=6,original_poses_preserved=sum(r['original_poses_preserved'] for r in results),failures=0,coverage=results)
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f'BOSS_MOTION_V6_PRESERVATION bosses=6 frames={report["original_poses_preserved"]} failures=0')


if __name__=='__main__':main()
