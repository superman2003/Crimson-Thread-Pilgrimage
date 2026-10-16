#!/usr/bin/env python3
"""Losslessly isolate four existing attack poses; never draw/interpolate source art.

Only Pillow and NumPy are required. All source RGBA bytes are copied verbatim.
The two original atlases are immutable. Selection uses manually reviewed source
ownership domains and alpha>0 seeded 8-neighbour connectivity, NOT an alpha128
largest-component crop. A hand-reviewed polygon removes page_duelist's alpha=1
cross-row background bridge. Disconnected residuals are reported, not silently
classified as new artwork. Regenerate with:
    python tools/repack_enemy_attack_frames.py --evidence-dir /tmp/enemy-integrity
Verify without rewriting with --check. No Git history or executable is needed;
source manifests are checked-in byte-exact snapshots protected by fixed SHA-256.
No Godot/import/cache is invoked.
"""
from __future__ import annotations
import argparse
from collections import deque
from copy import deepcopy
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

BASE = '5df88208de2e44cad6fe9f5f6ead0dd13e6152d5'
ASSETS = Path('godot/assets/sprites/original_creatures')
PAD = (192, 16)
CONFIG = {
    'gear_sentinel': {
        'manifest_sha256': '86a08e7570b7028cf60c2070f31affba5a9fa2ff8a0610ba7eda55f342093e3e',
        'sha256': 'e4444a601c78d76d4758e9f7f403a2b44d841b4e479646728ade68a723047734',
        'domains': [[(15,695),(515,695),(515,1000),(15,1000)],
                    [(435,705),(842,705),(842,1002),(435,1002)]],
        'seeds': [(250,800),(650,850)],
        'weapons': [(320,775,505,825),(730,835,839,871)],
        'moves': [('gear_spear',480,240,500),('gear_guard',700,250,700)],
    },
    'page_duelist': {
        'manifest_sha256': '6f197dbb8b58289767ccca1671628bca169a3eab7bfe7a9e2d6f758c41d04e86',
        'sha256': '3d7c6492a74755425617edf2c71059dd42fcd9c97a49c36adfcb365e70b77475',
        'domains': [[(0,700),(225,700),(245,708),(265,723),(285,744),
                     (320,776),(560,776),(560,990),(0,990)],
                    [(450,695),(870,695),(870,990),(450,990)]],
        'seeds': [(250,800),(650,850)],
        'weapons': [(360,785,552,823),(720,796,869,861)],
        'moves': [('page_feint',480,260,380),('page_combo',620,550,700)],
    },
}

def digest(data):
    return sha256(data).hexdigest()

def baseline(root, kind):
    # Exact base-manifest bytes are shipped locally for depth=1/no-history CI.
    # BASE records provenance only; regeneration never invokes Git.
    raw = (root / ASSETS / kind / 'attack_source_manifest.json').read_bytes()
    if digest(raw) != CONFIG[kind]['manifest_sha256']:
        raise ValueError(f'{kind}: source manifest hash changed; manual review required')
    return json.loads(raw), digest(raw)

def domain_mask(shape, points):
    im = Image.new('1', (shape[1], shape[0]))
    ImageDraw.Draw(im).polygon(points, fill=1)
    return np.asarray(im, dtype=bool)

def seed_component(alpha, domain, seed):
    """Keep every nonzero-alpha neighbour, including alpha=1, from explicit seed."""
    sx, sy = seed
    permitted = (alpha > 0) & domain
    if not permitted[sy, sx]:
        raise ValueError('Ownership seed must hit an original nonzero-alpha pixel')
    selected = np.zeros(alpha.shape, dtype=bool)
    selected[sy, sx] = True
    queue = deque([(sx, sy)])
    h, w = alpha.shape
    while queue:
        x, y = queue.popleft()
        for ny in range(max(0,y-1), min(h,y+2)):
            for nx in range(max(0,x-1), min(w,x+2)):
                if permitted[ny,nx] and not selected[ny,nx]:
                    selected[ny,nx] = True
                    queue.append((nx,ny))
    return selected

def bbox(mask):
    ys, xs = np.nonzero(mask)
    return [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)] if len(xs) else None

def rle(mask):
    rows = []
    for y in np.flatnonzero(mask.any(axis=1)):
        edges = np.flatnonzero(np.diff(np.pad(mask[y].astype(np.int8),(1,1))))
        rows.extend([int(y),int(a),int(b)] for a,b in zip(edges[::2],edges[1::2]))
    return rows

def unroll(rows, shape=(1024,1536)):
    mask = np.zeros(shape,dtype=bool)
    for y,x0,x1 in rows:
        mask[y,x0:x1] = True
    return mask

def rect_mask(shape, rect):
    x,y,w,h = rect
    result = np.zeros(shape,dtype=bool)
    result[y:y+h,x:x+w] = True
    return result

def registered_copy(source, mask, old_frame, old_canvas):
    rx,ry,_,_ = old_frame['region']
    mx,my,_,_ = old_frame['margin']
    dx,dy = mx-rx+PAD[0], my-ry+PAD[1]
    w,h = old_canvas[0]+2*PAD[0], old_canvas[1]+2*PAD[1]
    ys,xs = np.nonzero(mask)
    if not (np.all(xs+dx>=0) and np.all(xs+dx<w) and np.all(ys+dy>=0) and np.all(ys+dy<h)):
        raise ValueError('Selected pixels exceed registration canvas')
    out = np.zeros((h,w,4), dtype=np.uint8)
    out[ys+dy,xs+dx] = source[ys,xs]
    return out, [dx,dy]

def png_bytes(rgba):
    buffer = BytesIO()
    Image.fromarray(rgba).save(buffer,format='PNG',compress_level=9)
    return buffer.getvalue()

def json_bytes(value):
    return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()

def build(root, kind):
    cfg = CONFIG[kind]
    path = root / ASSETS / kind
    raw = (path/'atlas.png').read_bytes()
    if digest(raw) != cfg['sha256']:
        raise ValueError(f'{kind}: source atlas hash changed; manual ownership review required')
    source = np.array(Image.open(BytesIO(raw)).convert('RGBA'))
    if source.shape != (1024,1536,4):
        raise ValueError('Unexpected source dimensions')
    old, old_hash = baseline(root,kind)
    old_attack = next(a for a in old['animations'] if a['name']=='attack')['frames']
    masks = [seed_component(source[:,:,3],domain_mask(source.shape,cfg['domains'][i]),cfg['seeds'][i]) for i in range(2)]
    if np.any(masks[0]&masks[1]):
        raise ValueError('Two poses claim the same source pixel')
    new = deepcopy(old)
    new['canvas'] = [old['canvas'][0]+2*PAD[0],old['canvas'][1]+2*PAD[1]]
    new['attack_integrity'] = f'res://assets/sprites/original_creatures/{kind}/attack_integrity.json'
    outputs = {}
    records = []
    for animation in new['animations']:
        for i,frame in enumerate(animation['frames']):
            if animation['name'] != 'attack':
                x,y,w,h = frame['margin']
                frame['margin'] = [x+PAD[0],y+PAD[1],w+2*PAD[0],h+2*PAD[1]]
                continue
            mask = masks[i]
            other = masks[1-i]
            packed, shift = registered_copy(source,mask,old_attack[i],old['canvas'])
            name = f'attack_{i}_isolated.png'
            data = png_bytes(packed)
            outputs[name] = data
            frame['atlas'] = f'res://assets/sprites/original_creatures/{kind}/{name}'
            frame['region'] = [0,0,*new['canvas']]
            frame['margin'] = [0,0,0,0]
            original_rect = rect_mask(mask.shape,old_attack[i]['region'])
            bx0,by0,bx1,by1 = bbox(mask)
            expanded_rect = rect_mask(mask.shape,[bx0,by0,bx1-bx0,by1-by0])
            weapon_rect = cfg['weapons'][i]
            wx0,wy0,wx1,wy1 = weapon_rect
            weapon = mask & rect_mask(mask.shape,[wx0,wy0,wx1-wx0,wy1-wy0])
            hist = np.bincount(source[:,:,3][mask],minlength=256)
            core = seed_component((source[:,:,3]>128).astype(np.uint8),mask,cfg['seeds'][i])
            records.append({
                'frame':i, 'output':name, 'output_sha256':digest(data),
                'output_rgba_sha256':digest(packed.tobytes()),
                'source_seed_xy':list(cfg['seeds'][i]),
                'ownership_domain_polygon_xy':[list(p) for p in cfg['domains'][i]],
                'source_bbox_xyxy':bbox(mask),'source_mask_sha256':digest(mask.tobytes()),
                'source_mask_rle_y_x0_x1':rle(mask),'selected_pixels':int(mask.sum()),
                'selected_alpha_histogram':hist.tolist(),
                'selected_alpha_1_2':int(hist[1:3].sum()),
                'selected_alpha_1_128':int(hist[1:129].sum()),
                'alpha_gt128_pixels_outside_seeded_core_preserved':int((mask&~core&(source[:,:,3]>128)).sum()),
                'recovered_pixels_outside_old_region':int((mask&~original_rect).sum()),
                'other_pose_pixels_excluded_from_old_region':int((other&original_rect).sum()),
                'other_pose_pixels_excluded_from_expanded_bbox':int((other&expanded_rect).sum()),
                'weapon_source_inspection_box_xyxy':list(weapon_rect),
                'weapon_selected_pixels':int(weapon.sum()),
                'weapon_pixels_recovered_outside_old_region':int((weapon&~original_rect).sum()),
                'source_to_output_translation_xy':shift,
                'old_frame':old_attack[i],
            })
    bottom = rect_mask(masks[0].shape,[0,700,880,305])
    residual = bottom&(source[:,:,3]>0)&~(masks[0]|masks[1])
    provenance = {
        'schema':1,'kind':kind,'base_commit':BASE,
        'scope':'Only existing attack[0] and attack[1]; no generated or interpolated artwork.',
        'source':'atlas.png','source_sha256':cfg['sha256'],'source_size':[1536,1024],
        'source_manifest':'attack_source_manifest.json',
        'source_manifest_sha256':old_hash,'old_canvas':old['canvas'],'canvas':new['canvas'],
        'symmetric_padding_xy':list(PAD),
        'registration':'output = source - old_region.position + old_margin.position + padding; output - new_canvas/2 = source - old_region.position + old_margin.position - old_canvas/2. Flip-X negates the same local X on both sides.',
        'method':'Manually reviewed ownership polygons, explicit pose seeds, nonzero-alpha 8-neighbour flood; all selected RGBA copied byte-for-byte. No alpha thresholding, color editing, scaling, drawing, or interpolation in assets.',
        'manual_review':{
            'gear_sentinel':'Both complete spear/handle outlines are distinct nonzero-alpha components. Disconnected residuals outside selected poses in their inspected boxes are source background speckles; no independently drawn body/weapon part was identified.',
            'page_duelist':'attack[0] polygon severs only an alpha=1 background bridge toward the preceding row. Within the bottom-row seeded component this removes 1,522 alpha=1 pixels and zero alpha>=2 pixels. Antennae, sword-tip subparts, pale cape edges, and both feet remain. A separate alpha<=2 patch at [401,878,478,976) is background residue, not a drawn limb.',
        }[kind],
        'transparent_background':'Unselected output RGBA is [0,0,0,0]. Faint alpha=1/2 pixels attached to owned art are retained; the original artwork is not recolored.',
        'non_attack_contract':'All 10 other frame regions/source atlases/RGBA unchanged; only margin.position += padding, margin.size += 2*padding. fps, loops, frame counts, display_height, visual_scale and visual_offset unchanged.',
        'remaining_open':['Other existing pose clipping/foreign-pose risks were not repaired.','No missing animation frames were drawn.','Runtime gameplay/GL validation is owned by the integration task; offline previews do not include runtime pose tweens or effects.'],
        'bottom_roi_unselected_nonzero_pixels':int(residual.sum()),
        'frames':records,
    }
    outputs['manifest.json'] = json_bytes(new)
    outputs['attack_integrity.json'] = json_bytes(provenance)
    return source,old,new,masks,outputs,provenance

def composite(rgba, color=(35,43,51,255)):
    im = Image.new('RGBA',(rgba.shape[1],rgba.shape[0]),color)
    im.alpha_composite(Image.fromarray(rgba))
    return im.convert('RGB')

def display_frame(root, kind, frame, canvas, padded=True):
    texture = np.array(Image.open(root/'godot'/frame['atlas'].removeprefix('res://')).convert('RGBA'))
    x,y,w,h = frame['region'];mx,my,_,_ = frame['margin']
    result = np.zeros((canvas[1],canvas[0],4),np.uint8)
    result[my:my+h,mx:mx+w] = texture[y:y+h,x:x+w]
    if padded:
        result = np.pad(result,((PAD[1],PAD[1]),(PAD[0],PAD[0]),(0,0)))
    return result

def evidence(root, outdir, kind, source, old, new, masks, provenance):
    outdir.mkdir(parents=True,exist_ok=True)
    frames = next(a for a in old['animations'] if a['name']=='attack')['frames']
    old_images = [display_frame(root,kind,f,old['canvas']) for f in frames]
    new_images = [np.array(Image.open(root/ASSETS/kind/f'attack_{i}_isolated.png')) for i in range(2)]
    width,height = new['canvas'];label=30
    sheet=Image.new('RGB',(width*2,(height+label)*2),(21,27,33));d=ImageDraw.Draw(sheet)
    for i in range(2):
        for j,rgba in enumerate((old_images[i],new_images[i])):
            sheet.paste(composite(rgba),(j*width,i*(height+label)+label))
            d.text((j*width+12,i*(height+label)+8),f'{kind} attack[{i}] / {"OLD crop" if j==0 else "NEW isolated source pixels"} / source 1:1',fill='white')
    sheet.save(outdir/f'{kind}-old-new-1x.png')
    sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(outdir/f'{kind}-old-new-2x.png')
    crop=(0,680,880,1005)
    overlay=np.zeros_like(source);overlay[:,:,:3]=(25,30,35);overlay[:,:,3]=255
    unselected=(source[:,:,3]>0)&~(masks[0]|masks[1])
    overlay[unselected]=(146,48,113,255);overlay[masks[0]]=(40,210,95,255);overlay[masks[1]]=(30,180,240,255)
    panel=Image.fromarray(overlay).crop(crop).convert('RGB').resize((1760,650),Image.Resampling.NEAREST)
    d=ImageDraw.Draw(panel);d.text((12,12),'GREEN: attack0  CYAN: attack1  MAGENTA: excluded source alpha>0 (including background/other poses)',fill='white')
    panel.save(outdir/f'{kind}-ownership-mask-2x.png')
    for i,mask in enumerate(masks):
        Image.fromarray((mask*255).astype('uint8')).save(outdir/f'{kind}-source-mask-{i}.png')
    # Source-coordinate overlay: semitransparent colors retain the visible ink.
    visible=composite(source).convert('RGBA'); tint=np.zeros_like(source)
    tint[unselected]=(230,40,170,85);tint[masks[0]]=(30,220,70,65);tint[masks[1]]=(20,180,250,65)
    visible.alpha_composite(Image.fromarray(tint))
    visible.crop(crop).resize((1760,650),Image.Resampling.NEAREST).save(outdir/f'{kind}-ownership-overlay-2x.png')
    # Same frames/timing on each side. Runtime command durations rescale only U/A;
    # recovery uses idle's original 3 fps and is clipped at command recovery end.
    animations={a['name']:a for a in old['animations']}
    anim_old={name:[display_frame(root,kind,f,old['canvas']) for f in animations[name]['frames']] for name in ('windup','attack','idle')}
    anim_new={**anim_old,'attack':new_images}
    variants=[('manifest-fps',None,None,None)]+CONFIG[kind]['moves']
    for move,u,a,r in variants:
        sequence=[]
        for name,total in [('windup',u),('attack',a),('idle',r)]:
            per=1000/animations[name]['fps'] if total is None or name=='idle' else total/2
            remain=2*per if total is None else total
            index=0
            while remain>0.01:
                duration=min(per,remain);sequence.append((name,index%2,duration));remain-=duration;index+=1
        pictures=[];durations=[]; elapsed=0.0; timeline=[]
        for name,i,duration in sequence:
            frame=Image.new('RGB',(width*2,height+55),(21,27,33));draw=ImageDraw.Draw(frame)
            for j,collection in enumerate((anim_old,anim_new)):
                frame.paste(composite(collection[name][i]),(j*width,55))
                draw.text((j*width+12,9),f'{kind} {move}: {"OLD" if j==0 else "REPAIRED"} {name}[{i}]',fill='white')
                draw.text((j*width+12,28),'Existing poses only; same timing / no tween, effects or new drawings',fill=(190,200,210))
            pictures.append(frame); elapsed+=duration
            encoded_duration=round(elapsed)-sum(durations)
            durations.append(encoded_duration)
            timeline.append({'animation':name,'frame':i,'nominal_duration_ms':duration,'encoded_duration_ms':encoded_duration})
        (outdir/f'{kind}-{move}-timeline.json').write_bytes(json_bytes({'kind':kind,'move':move,'base_fps':{'windup':6,'attack':10,'idle':3},'both_sides_identical_timing':True,'runtime_tweens_or_effects':False,'timeline':timeline}))
        pictures[0].save(outdir/f'{kind}-{move}-comparison.webp',save_all=True,append_images=pictures[1:],duration=durations,loop=0,lossless=True,method=3)
    # At original visual_scale, both facings have the same center registration.
    scale=old['visual_scale'];runtime=Image.new('RGB',(600,360),(21,27,33));d=ImageDraw.Draw(runtime)
    for i in range(2):
        for j,rgba in enumerate((old_images[i],new_images[i])):
            im=composite(rgba).resize((round(width*scale),round(height*scale)),Image.Resampling.LANCZOS)
            runtime.paste(im,(j*300,i*180+35));d.text((j*300+8,i*180+8),f'attack[{i}] {"OLD" if j==0 else "REPAIRED"} visual_scale={scale:.6f}',fill='white')
    runtime.save(outdir/f'{kind}-runtime-scale.png')
    (outdir/f'{kind}-summary.json').write_bytes(json_bytes({k:v for k,v in provenance.items() if k!='frames'}|{'frames':[{k:v for k,v in f.items() if k!='source_mask_rle_y_x0_x1'} for f in provenance['frames']]}))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--evidence-dir',type=Path)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    for kind in CONFIG:
        source,old,new,masks,outputs,record=build(args.root,kind)
        for name,data in outputs.items():
            path=args.root/ASSETS/kind/name
            if args.check:
                if not path.exists() or path.read_bytes()!=data:
                    raise SystemExit(f'MISMATCH: {path}')
            else:
                path.write_bytes(data)
        if args.evidence_dir:
            evidence(args.root,args.evidence_dir,kind,source,old,new,masks,record)
        print(kind, 'VERIFIED' if args.check else 'WROTE',json.dumps([{k:f[k] for k in ('frame','selected_pixels','selected_alpha_1_2','recovered_pixels_outside_old_region','other_pose_pixels_excluded_from_old_region')} for f in record['frames']]))

if __name__=='__main__':
    main()
