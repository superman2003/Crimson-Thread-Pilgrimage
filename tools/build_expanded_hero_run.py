#!/usr/bin/env python3
"""Package eight authored run cels with one fixed scale and the existing rig.

Only crop/resize/pad generated source pixels; no interpolated or painted poses.
The original four run PNGs remain available for provenance and comparison.
"""
from pathlib import Path
from hashlib import sha256
import json
from io import BytesIO
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'godot/assets/sprites/player/generated_hero_motion_v4'

def build(check=False):
    record=json.loads((FOLDER/'run_generation.json').read_text())
    sheet=Image.open(FOLDER/record['sheet']).convert('RGBA')
    reference=Image.open(FOLDER/record['reference']).convert('RGBA')
    target_height=reference.getchannel('A').getbbox()[3]-reference.getchannel('A').getbbox()[1]
    scale=None; hashes=set()
    outdir=FOLDER/'runtime_run';outdir.mkdir(exist_ok=True)
    for index,(x,y,w,h) in enumerate(record['regions']):
        cell=sheet.crop((x,y,x+w,y+h));alpha=np.asarray(cell)[:,:,3]
        if any((edge>24).any() for edge in (alpha[0],alpha[-1],alpha[:,0],alpha[:,-1])):
            raise ValueError(f'clipped run pose {index}')
        ys,xs=np.nonzero(alpha>24)
        box=(max(0,int(xs.min())-2),max(0,int(ys.min())-2),min(w,int(xs.max())+3),min(h,int(ys.max())+3))
        if scale is None:scale=target_height/(box[3]-box[1])
        pose=cell.crop(box)
        pose=pose.resize((round(pose.width*scale),round(pose.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(384,384))
        # Shared cell rig origin; a small flight lift follows the authored stride.
        left=round(192+(box[0]-w/2)*scale)
        bottom=289-[0,0,3,5,0,0,3,5][index]
        canvas.alpha_composite(pose,(left,bottom-pose.height))
        hashes.add(sha256(canvas.tobytes()).hexdigest())
        buffer=BytesIO();canvas.save(buffer,format='PNG');data=buffer.getvalue()
        path=outdir/f'run_{index:02d}.png'
        if check:
            if not path.exists() or Image.open(path).mode != 'RGBA' or not np.array_equal(np.asarray(Image.open(path)),np.asarray(canvas)):raise ValueError(f'{path}: rebuild')
        else:path.write_bytes(data)
    if len(hashes)!=8:raise ValueError('duplicate run poses')
    manifest_path=ROOT/'godot/assets/sprites/player/generated_hero_v3/manifest.json'
    manifest=json.loads(manifest_path.read_text())
    animation=next(a for a in manifest['animations'] if a['name']=='run')
    frames=['res://assets/sprites/player/generated_hero_motion_v4/runtime_run/run_%02d.png'%i for i in range(8)]
    if check:
        if animation['frames']!=frames:raise ValueError('run manifest not connected')
    else:
        animation['frames']=frames
        # Ground motion is distance-driven; fps is only the standalone preview rate.
        animation['fps']=16
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('HERO_EXPANDED_RUN poses=8 canvas=384x384 shared_scale=%.9f'%scale)

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');build(p.parse_args().check)
