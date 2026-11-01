#!/usr/bin/env python3
"""Pack three travelling waves and two eruptions; delivered sources are read-only."""
from __future__ import annotations
import argparse, hashlib, io, json
from pathlib import Path
from PIL import Image, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'art_requests/attack_effects_v1/incoming'
OUTPUT = ROOT / 'godot/assets/vfx/terrain_attacks'
FAMILIES = ['chime', 'quake', 'surge', 'roots', 'spears']

def digest(data): return hashlib.sha256(data).hexdigest()

def build():
    atlas = Image.new('RGBA', (1152, 1024)); records = {}; top = 0
    for family in FAMILIES:
        wave = family in FAMILIES[:3]
        kind, count = ('W', 8) if wave else ('R', 6)
        cell = (128,128) if wave else (192,320)
        anchor = (64,96) if wave else (96,272)
        stem = SOURCES / f'FX_{kind}_{family}'
        raw, prompt = stem.with_suffix('.png').read_bytes(), stem.with_suffix('.txt').read_bytes()
        meta = json.loads(stem.with_suffix('.json').read_text())
        if digest(raw) != meta['image_sha256'] or digest(prompt) != meta['prompt_sha256']:
            raise ValueError(f'{family}: delivered source checksum differs')
        image = Image.open(io.BytesIO(raw)).convert('RGBA'); frames = meta['frames']
        if len(frames) != count or list(image.size) != meta['image_size']:
            raise ValueError(f'{family}: wrong source dimensions/frame count')
        holds = frames[2:6] if wave else frames[2:4]
        width = max(f['bbox_alpha_gt_24_xyxy'][2]-f['bbox_alpha_gt_24_xyxy'][0] for f in holds)
        height = max(f['bbox_alpha_gt_24_xyxy'][3]-f['bbox_alpha_gt_24_xyxy'][1] for f in holds)
        body_width = 64 if wave else 128
        sx = body_width / width
        sy = sx if wave else 224 / height
        entries = []
        for column, f in enumerate(frames):
            rect = f['rect_xyxy']; cel = image.crop(rect)
            bounds = cel.getchannel('A').point(lambda a: 255 if a>24 else 0).getbbox()
            if bounds is None: raise ValueError(f'{family}/{column}: empty cel')
            cx, floor = (bounds[0]+bounds[2])/2, bounds[3]
            packed = cel.transform(cell, Image.Transform.AFFINE,
                (1/sx,0,cx-anchor[0]/sx,0,1/sy,floor-anchor[1]/sy),resample=Image.Resampling.BICUBIC)
            solid = packed.getchannel('A').point(lambda a: 255 if a>128 else 0)
            dark = Image.new('RGBA',cell,(15,19,22,0)); dark.putalpha(solid.filter(ImageFilter.MaxFilter(5)).point(lambda a: round(a*.90)))
            pale = Image.new('RGBA',cell,(206,192,154,0)); pale.putalpha(solid.filter(ImageFilter.MaxFilter(3)).point(lambda a: round(a*.65)))
            packed = Image.alpha_composite(Image.alpha_composite(dark,pale),packed)
            alpha = packed.getchannel('A'); w,h=cell
            edges=[alpha.crop((0,0,w,1)),alpha.crop((0,h-1,w,h)),alpha.crop((0,0,1,h)),alpha.crop((w-1,0,w,h))]
            if any(edge.getextrema()[1]>0 for edge in edges): raise ValueError(f'{family}/{column}: atlas boundary touched')
            atlas.paste(packed,(column*w,top))
            entries.append({'source_rect':rect,'source_floor_anchor':[cx+rect[0],floor+rect[1]],'atlas_rect':[column*w,top,w,h],'packed_alpha_gt_24_bbox':alpha.point(lambda a:255 if a>24 else 0).getbbox()})
        records[family]={'kind':'wave' if wave else 'eruption','cell':cell,'floor_anchor':anchor,'body_width':body_width,'body_height':None if wave else 224,'source':str(stem.with_suffix('.png').relative_to(ROOT)),'sha256':digest(raw),'prompt_sha256':digest(prompt),'metadata_sha256':digest(stem.with_suffix('.json').read_bytes()),'shared_scale_xy':[sx,sy],'frames':entries}
        top += cell[1]
    stream=io.BytesIO();atlas.save(stream,'PNG',optimize=True)
    manifest={'schema':1,'families':FAMILIES,'atlas_size':list(atlas.size),'atlas_rgba_sha256':digest(atlas.tobytes()),'wave_rise_frames':[0,1],'wave_loop_frames':[2,3,4,5],'eruption_emerge_frames':[0,1],'eruption_hold_frames':[2,3],'wave_fade_frames':[6,7],'eruption_retract_frames':[4,5],'animation_fps':12,'eruption_emerge_seconds':.2,'registration':'alpha>24 footprint bottom; waves preserve aspect; eruptions fit fixed width/height axes with one shared transform per family','sources':records}
    return stream.getvalue(),(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n').encode()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    png,manifest=build()
    for path,data in {OUTPUT/'terrain_attacks.png':png,OUTPUT/'manifest.json':manifest}.items():
        if args.check:
            if not path.exists():raise SystemExit(f'TERRAIN_ATTACK_ART missing {path}')
            same=Image.open(path).convert('RGBA').tobytes()==Image.open(io.BytesIO(data)).convert('RGBA').tobytes() if path.suffix=='.png' else path.read_bytes()==data
            if not same:raise SystemExit(f'TERRAIN_ATTACK_ART stale {path}')
        else:OUTPUT.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print(f'TERRAIN_ATTACK_ART_BUILD families=5 frames=36 atlas={len(png)}B check={args.check}')
if __name__=='__main__':main()
