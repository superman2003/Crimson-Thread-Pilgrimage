#!/usr/bin/env python3
"""Package the actual hero ability states, preserving their existing clocks."""
from __future__ import annotations
import argparse
from hashlib import sha256
from io import BytesIO
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from build_hero_motion_v7 import register, encoded

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT/'art_requests/hero_motion_v8'
OUT = ROOT/'godot/assets/sprites/player/generated_hero_motion_v8'
MANIFEST = ROOT/'godot/assets/sprites/player/generated_hero_v3/manifest.json'
RES = 'res://assets/sprites/player/generated_hero_motion_v8/frames/'
COUNTS = {'guard':6,'heal':6,'hook_throw':4,'wall_slide':4,'phase':4,
          'resonance':6,'skill_projectile':6,'skill_control':6,'skill_defense':4}


def face_area(image, expected_box):
    rgba = np.asarray(image.convert('RGBA'))
    rgb = rgba[:,:,:3].astype(int)
    skin = (rgba[:,:,3]>128)&(rgb[:,:,0]>100)&(rgb[:,:,1]>60)&(rgb[:,:,0]>rgb[:,:,2]*1.2)&(rgb[:,:,1]>rgb[:,:,2]*1.05)&(rgb.mean(-1)>100)
    labels,n = ndimage.label(skin)
    for index in range(1,n+1):
        ys,xs = np.nonzero(labels==index)
        box = [int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
        if box == expected_box:
            return len(xs)
    raise ValueError('The reviewed face component changed; recalibrate this source')


def wall_registration(canvas, cell, entry):
    rgba = np.asarray(cell)
    rgb = rgba[:,:,:3].astype(int)
    solid = rgba[:,:,3]>96
    labels,n = ndimage.label(solid,structure=np.ones((3,3)))
    areas = ndimage.sum(solid,labels,range(1,n+1))
    body = labels==int(np.argmax(areas))+1
    ys,_ = np.nonzero(body)
    lower = np.indices(body.shape)[0] > (int(ys.min())+int(ys.max()))/2
    boots = body&lower&(rgb[:,:,0]>45)&(rgb[:,:,0]<190)&(rgb[:,:,0]>rgb[:,:,1]*1.15)&(rgb[:,:,1]>rgb[:,:,2]*1.08)
    _,xs = np.nonzero(boots)
    if not xs.size:
        raise ValueError('No leading boot contact in wall pose')
    toe = float(xs.max())+2.0  # include the boot's dark painted rim
    box = entry['source_bounds']
    ratio = entry['output_size'][0]/float(box[2]-box[0])
    before = entry['output_origin'][0]+(toe-box[0])*ratio
    shift = round(218.0-before)  # 17px right of the physical root at scale .66
    moved = Image.new('RGBA',(384,384))
    moved.alpha_composite(canvas,(shift,0))
    bounds = moved.getbbox()
    if bounds is None or min(bounds[:2])<=0 or max(bounds[2:])>=384:
        raise ValueError('Wall registration would clip the character')
    entry['output_origin'][0] += shift
    entry['target_anchor'][0] += shift
    entry['wall_toe'] = {'source_x':toe,'output_x':before+shift,'target_x':218.0}
    entry['visible_sha256'] = sha256(moved.tobytes()).hexdigest()
    return moved,entry


def build(check=False):
    slices = json.loads((REQUEST/'source_slices.json').read_text(encoding='utf-8'))
    previous = json.loads((REQUEST/'previous_animations.json').read_text(encoding='utf-8'))
    calibration = json.loads((REQUEST/'calibration.json').read_text(encoding='utf-8'))
    if slices['missing'] or set(slices['sheets']) != set(COUNTS):
        raise ValueError('Source delivery is incomplete')
    reference = ROOT/calibration['reference']['path']
    if sha256(reference.read_bytes()).hexdigest()!=calibration['reference']['sha256']:
        raise ValueError('The reviewed run reference changed')
    reference_area = face_area(Image.open(reference),calibration['reference']['face_box'])
    if reference_area != calibration['reference']['face_area']:
        raise ValueError('The reference face measurement changed')
    outputs = {}
    registration = {'schema':'hero-motion-v8-registration','new_drawings':46,
                    'frame_size':[384,384],'ground_row':280,'animations':{}}
    unique = set()
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    by_name = {a['name']:a for a in manifest['animations']}
    for name,count in COUNTS.items():
        spec = slices['sheets'][name]
        source = REQUEST/spec['source']
        if sha256(source.read_bytes()).hexdigest()!=spec['source_sha256'] or sha256(source.with_suffix('.txt').read_bytes()).hexdigest()!=spec['prompt_sha256']:
            raise ValueError(f'{name}: source or actual prompt changed')
        measurement = calibration['sheets'][name]
        if measurement['source_sha256']!=spec['source_sha256']:
            raise ValueError(f'{name}: selected source needs reviewed calibration')
        sheet = Image.open(source).convert('RGBA')
        x,y,w,h = spec['regions'][0]
        area = face_area(sheet.crop((x,y,x+w,y+h)),measurement['face_box'])
        if area != measurement['face_area']:
            raise ValueError(f'{name}: face measurement changed')
        scale = round(math.sqrt(reference_area/area),9)
        entries = []
        if len(spec['regions']) != count:
            raise ValueError(f'{name}: wrong cel count')
        for index,(x,y,w,h) in enumerate(spec['regions']):
            cell = sheet.crop((x,y,x+w,y+h))
            canvas,entry = register(cell,scale,name=='wall_slide')
            if name=='wall_slide': canvas,entry = wall_registration(canvas,cell,entry)
            if entry['visible_sha256'] in unique:
                raise ValueError(f'{name}/{index}: duplicated drawing')
            unique.add(entry['visible_sha256'])
            entry['source_region'] = [x,y,w,h]
            entries.append(entry)
            outputs[OUT/'frames'/f'{name}_{index:02d}.png'] = encoded(canvas)
        registration['animations'][name] = {'source':spec['source'],'source_sha256':spec['source_sha256'],
                                             'shared_scale':scale,'face_area':area,'frames':entries}
        original = previous[name]
        frames = [RES+f'{name}_{index:02d}.png' for index in range(count)]
        duration = len(original['frames'])/original['fps']
        fps = count/duration
        current = by_name[name]
        if check:
            if current['frames']!=frames or current['fps']!=fps or current['loop']!=original['loop']:
                raise ValueError(f'{name}: production binding or clock differs')
        else:
            if current['frames'] not in [original['frames'],frames]:
                raise ValueError(f'{name}: refusing to overwrite unrelated artwork')
            current.update(frames=frames,fps=fps,loop=original['loop'])
    outputs[OUT/'registration.json'] = (json.dumps(registration,ensure_ascii=False,indent=2)+'\n').encode()
    if not check: outputs[MANIFEST] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    for path,content in outputs.items():
        if check:
            if not path.exists(): raise ValueError(f'{path}: missing output')
            if path.suffix=='.png':
                if not np.array_equal(np.asarray(Image.open(path)),np.asarray(Image.open(BytesIO(content)))):
                    raise ValueError(f'{path}: stale pixels')
            elif path.read_bytes()!=content: raise ValueError(f'{path}: stale registration')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(content)
    print('HERO_MOTION_V8 actions=9 drawings=%d clocks=preserved check=%s' % (len(unique),check))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    build(parser.parse_args().check)
