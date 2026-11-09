#!/usr/bin/env python3
"""Plan, register and pack new authored in-betweens on an isolated animation layer.

Original atlases/manifests remain byte-exact. This tool only extracts complete
drawings, calibrates their scale/anchor/palette and packs pixels; never morphs or
interpolates source artwork. New phase seams are authored drawings too.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
from functools import lru_cache
from hashlib import sha256
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage
from build_expanded_character_motion import ROOT,build,apply_grade

REQUEST=ROOT/'art_requests/combat_motion_v7'
BASE=ROOT/'godot/assets/sprites/original_creatures'
RECORD='combat_motion_v7.json'
MANIFEST='combat_motion_v7_manifest.json'
ATLAS='combat_motion_v7.png'
DETACHED_MARGIN=16  # px beyond a body's bounds that still count as part of the figure
CAPTION_HEIGHT,CAPTION_AREA=9,150  # glyph-sized marks entirely above or below a body
CHAPTERS=['moss_bell_court','rain_foundry_canal','saltwhite_archive','broken_string_greenhouse','obsidian_pilgrim_road','silent_crown_core']
PROMPT='''Use case: identity-preserve. Production 2D game animation IN-BETWEEN drawings, not concept art.
The reference is a strict SIX-COLUMN by FOUR-ROW sheet. Each adjacent horizontal pair (left endpoint, right endpoint) is ONE numbered transition. There are three PAIRS per row, twelve pairs total, read left-to-right then top-to-bottom.
Replace EACH of those twelve pairs with TWO genuinely NEW full-body drawings: LEFT is one-third through that exact transition, RIGHT is two-thirds through it. KEEP THE IDENTICAL SIX-COLUMN / FOUR-ROW LAYOUT AND PAIR POSITIONS. Do not rearrange rows or poses. Preserve the exact character identity, anatomy, face, materials, costume, weapon length and detailed painted-ink rendering. Smoothly articulate the head, torso, arms/legs, weapon and cloth through the endpoints; no pose resets or unrelated gestures. Constant body mass and camera, right-facing fixed side view. For grounded poses keep the support foot stable; for airborne poses keep their air/wing intent. No added limbs or floating props.
Output exactly 24 isolated sprites on a wide 1536x1024 or larger 3:2 canvas with genuine transparent alpha. Each figure fully contained in its own equal cell with 12 percent clear gutters. Complete weapons and antennae. No cropped figures, no overlapping cells. No text, captions, digits, labels, grid, background, floor, shadows, particles, glow, motion lines or UI. Never copy an endpoint, stretch a stamp, blend/double/ghost two poses, or draw a checkerboard. These are new anatomical in-between drawings for the existing game, not a redesign.
Character and attack: {kind} / {move}.'''

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')

@lru_cache(maxsize=4)
def source_image(path):return Image.open(path).convert('RGBA')

def packed_baseline(folder):
    data=read(folder/'motion_manifest.json');half=data['canvas'][0]/2
    result={}
    for animation in data['animations']:
        result[animation['name']]=[dict(sheet=Path(frame['atlas']).name,region=frame['region'],anchor_x=half-frame['margin'][0],packed_runtime=True) for frame in animation['frames']]
    legacy=read(folder/'motion_generation.json')
    batch=legacy.get('boss_motion_v6')
    if batch:
        # Align the previously authored loop in-betweens too. Their alternating
        # scale was visible even while no attack was playing. The original
        # endpoint drawings and the old production layer remain untouched.
        for name in ['idle','walk']:
            originals=[legacy['runtime_frames'][name].index(entry) for entry in batch['baseline_frames'][name]]
            entries=result[name]
            for index,left in enumerate(originals):
                right=originals[(index+1)%len(originals)]
                slots=[];cursor=(left+1)%len(entries)
                while cursor!=right:slots.append(cursor);cursor=(cursor+1)%len(entries)
                first,a=pose(folder,entries[left]);last,b=pose(folder,entries[right])
                for rank,slot in enumerate(slots):
                    t=(rank+1)/(len(slots)+1);entry=entries[slot]
                    current,c=pose(folder,entry)
                    scale=(a['height']*(1-t)+b['height']*t)/current.height
                    median=c['median_offset']+entry['anchor_x']
                    offset=a['median_offset']*(1-t)+b['median_offset']*t
                    entry['scale']=round(scale,6);entry['anchor_x']=round(median-offset/scale,6)
                    entry['_v7_loop_alignment']={'from':left,'to':right,'progress':t}
    return result

def pose(folder,entry):
    path=ROOT/entry['source'] if 'source' in entry else folder/entry.get('sheet','motion_expanded.png')
    image=source_image(str(path));x,y,w,h=map(int,entry['region'])
    crop=np.asarray(image.crop((x,y,x+w,y+h))).copy()
    if entry.get('component_seeds'):
        raw=np.asarray(image)
        labels,_=ndimage.label(raw[:,:,3]>24,structure=np.ones((3,3)))
        ids=[int(labels[int(sy),int(sx)]) for sx,sy in entry['component_seeds']]
        distance,nearest=ndimage.distance_transform_edt(labels==0,return_indices=True)
        keep=np.isin(labels,ids)|((raw[:,:,3]>0)&(raw[:,:,3]<=24)&(distance<=3)&np.isin(labels[tuple(nearest)],ids))
        crop[~keep[y:y+h,x:x+w]]=0
    cell=Image.fromarray(crop);box=cell.getchannel('A').getbbox()
    if box is None:raise ValueError('empty reference pose')
    bx,by,ex,ey=box;cell=cell.crop(box)
    if entry.get('grade'):
        grade=entry['grade'];cell=apply_grade(cell,float(grade['saturation']),grade['rgb'])
    scale=float(entry.get('scale',1))
    if scale!=1:cell=cell.resize((max(1,round(cell.width*scale)),max(1,round(cell.height*scale))),Image.Resampling.LANCZOS)
    weights=np.asarray(cell)[:,:,3].sum(axis=0);median=float(np.searchsorted(np.cumsum(weights),weights.sum()*.5))
    left=(bx-float(entry.get('anchor_x',w/2)))*scale
    return cell,dict(height=cell.height,median_offset=left+median)

def sample(entries):return [deepcopy(entries[round(i*(len(entries)-1)/3)]) for i in range(4)]

def prepare() -> dict:
    profiles={};bosses=set()
    selections=read(REQUEST/'selections.json') if (REQUEST/'selections.json').is_file() else {}
    for n,slug in enumerate(CHAPTERS,1):
        data=read(ROOT/f'godot/data/demo_ch{n:02}_{slug}.json');bosses.add(data['boss']['kind'])
        for spawn in data['enemy_spawns']:profiles[spawn['kind']]=data['ai_profiles'][spawn['kind']]
        profiles[data['boss']['kind']]=data['ai_profiles'][data['boss']['kind']]
    jobs=[]
    for kind,profile in profiles.items():
        folder=BASE/kind;record=read(folder/'motion_generation.json');runtime=packed_baseline(folder)
        clean=runtime
        if 'boss_motion_v6' in record:
            clean={}
            for name,entries in record['boss_motion_v6']['baseline_frames'].items():
                clean[name]=[runtime[name][record['runtime_frames'][name].index(entry)] for entry in entries]
        moves={'attack'}
        for command in profile['attacks']:
            own=command['id'];moves.add(own if own in clean or own+'_windup' in clean else command.get('animation','attack'))
        # Elite signatures live in the authored rig even when the chapter's
        # ordinary spawn profile does not list that extra command.
        moves.update(name.removesuffix('_windup') for name in clean if name.endswith('_windup') and name.removesuffix('_windup') in clean)
        if kind in bosses:moves.update(['heavy','cast','phase'])
        for move in sorted(moves):
            windup=move+'_windup' if move+'_windup' in clean else 'windup'
            release=move if move in clean else 'attack'
            recovery=move+'_recover' if move+'_recover' in clean else 'recover'
            phases=[sample(clean[name]) for name in [windup,release,recovery]]
            pairs=[]
            for phase,entries in enumerate(phases):
                for i in range(3):pairs.append(dict(phase=phase,after=i,left=entries[i],right=entries[i+1]))
                pairs.append(dict(phase=phase,after=3,left=entries[-1],right=phases[phase+1][0] if phase<2 else clean['idle'][0]))
            job=dict(id=kind+'__'+move,kind=kind,move=move,boss=kind in bosses,animations=[windup,release,recovery],phases=phases,pairs=pairs,
                     reference=f'art_requests/combat_motion_v7/refs/{kind}__{move}.png',
                     source=f'art_requests/combat_motion_v7/incoming/{kind}__{move}.png',prompt=PROMPT.format(kind=kind,move=move))
            job['source']=selections.get(job['id'],job['source'])
            sheet=Image.new('RGBA',(1800,1200));draw=ImageDraw.Draw(sheet)
            for i,pair in enumerate(pairs):
                x=i%3*600;y=i//3*300;draw.text((x+10,y+5),f'PAIR {i+1} / phase {pair["phase"]} / gap {pair["after"]}',fill='white')
                for j,entry in enumerate([pair['left'],pair['right']]):
                    cel,_=pose(folder,entry);cel=cel.copy();cel.thumbnail((260,250))
                    sheet.alpha_composite(cel,(x+j*300+(300-cel.width)//2,y+285-cel.height))
            destination=ROOT/job['reference'];destination.parent.mkdir(parents=True,exist_ok=True);sheet.save(destination)
            jobs.append(job)
    result=dict(schema=1,characters=len(profiles),jobs=jobs,planned_new_drawings=24*len(jobs),policy='New authored drawings; isolated versioned runtime layer; source art immutable.')
    write(REQUEST/'specification.json',result)
    return result

def extract(path):
    image=Image.open(path).convert('RGBA');rgba=np.asarray(image)
    labels,count=ndimage.label(rgba[:,:,3]>24,structure=np.ones((3,3)));sizes=np.bincount(labels.ravel())
    if count<24:raise ValueError(f'{path.name}: fewer than 24 disconnected figures')
    main=list(np.argsort(sizes[1:])[-24:]+1)
    moments=ndimage.center_of_mass(np.ones(labels.shape,dtype=np.uint8),labels,list(range(1,count+1)))
    centers={int(i):moments[int(i)-1] for i in main}
    objects=ndimage.find_objects(labels)
    vertical=sorted(main,key=lambda i:centers[int(i)][0]);main=[]
    for row in range(4):main.extend(sorted(vertical[row*6:row*6+6],key=lambda i:centers[int(i)][1]))
    if min(sizes[i] for i in main)<500:raise ValueError(f'{path.name}: incomplete body component')
    groups={int(i):[int(i)] for i in main}
    for i in range(1,count+1):
        if i in groups or sizes[i]<4:continue
        y,x=moments[i-1]
        nearest=min(main,key=lambda j:(x-centers[int(j)][1])**2+(y-centers[int(j)][0])**2)
        # Detached pieces of a figure sit beside its body. Marks well outside it
        # are not part of the drawing (generated sheets sometimes copy the
        # reference's "PAIR n / phase / gap" captions); keeping them inflated
        # the measured height, so calibration shrank the whole pose.
        body,piece=objects[int(nearest)-1],objects[i-1]
        if piece[0].start>body[0].stop+DETACHED_MARGIN or piece[0].stop<body[0].start-DETACHED_MARGIN or \
                piece[1].start>body[1].stop+DETACHED_MARGIN or piece[1].stop<body[1].start-DETACHED_MARGIN:continue
        # A caption glyph close below or above the figure: short and small,
        # lying entirely outside the body's height.
        if (piece[0].start>=body[0].stop or piece[0].stop<=body[0].start) and piece[0].stop-piece[0].start<=CAPTION_HEIGHT and sizes[i]<=CAPTION_AREA:continue
        groups[int(nearest)].append(i)
    result=[]
    for body in main:
        ids=groups[int(body)]
        bounds=[objects[label-1] for label in ids]
        left=min(box[1].start for box in bounds);right=max(box[1].stop for box in bounds)
        top=min(box[0].start for box in bounds);bottom=max(box[0].stop for box in bounds)
        if left==0 or top==0 or right==image.width or bottom==image.height:raise ValueError(f'{path.name}: figure is clipped')
        x,y=max(0,left-4),max(0,top-4);w=min(image.width,right+4)-x;h=min(image.height,bottom+4)-y
        seeds=[]
        for label in ids:
            box=objects[label-1];sy,sx=np.argwhere(labels[box]==label)[sizes[label]//2]
            seeds.append([int(sx+box[1].start),int(sy+box[0].start)])
        mask=np.isin(labels[y:y+h,x:x+w],ids)
        cell=rgba[y:y+h,x:x+w].copy();cell[~mask]=0
        alpha=cell[:,:,3];weights=alpha.sum(axis=0);median=float(np.searchsorted(np.cumsum(weights),weights.sum()*.5))
        visible_h=bottom-top
        result.append(dict(region=[x,y,w,h],component_seeds=seeds,median_x=median,height=visible_h,pixels=cell))
    return result

def palette(image):
    rgba=np.asarray(image);mask=rgba[:,:,3]>128
    if not mask.any():mask=rgba[:,:,3]>24
    hsv=np.asarray(image.convert('RGB').convert('HSV'))
    return rgba[:,:,:3][mask].mean(axis=0),float(hsv[:,:,1][mask].mean())

def source_grade(folder,job,frames):
    targets=[pose(folder,pair[side])[0] for pair in job['pairs'] for side in ['left','right']]
    target_rgb=np.mean([palette(image)[0] for image in targets],axis=0)
    target_sat=np.mean([palette(image)[1] for image in targets])
    images=[Image.fromarray(cel['pixels']) for cel in frames]
    source_sat=np.mean([palette(image)[1] for image in images])
    saturation=round(float(np.clip(target_sat/max(1,source_sat),.85,1.15)),4)
    graded=[apply_grade(image,saturation,[1,1,1]) for image in images]
    source_rgb=np.mean([palette(image)[0] for image in graded],axis=0)
    return dict(saturation=saturation,rgb=[round(float(x),4) for x in np.clip(target_rgb/np.maximum(source_rgb,1),.85,1.15)])

def register(jobs,check=False):
    groups={}
    for job in jobs:groups.setdefault(job['kind'],[]).append(job)
    results=[]
    for kind,items in groups.items():
        folder=BASE/kind;record=deepcopy(read(folder/'motion_generation.json'));runtime=packed_baseline(folder);record['runtime_frames']=runtime;sources=[]
        for job in items:
            path=ROOT/job['source'];frames=extract(path);new=[[],[],[]];grade=source_grade(folder,job,frames)
            for i,pair in enumerate(job['pairs']):
                _,a=pose(folder,pair['left']);_,b=pose(folder,pair['right'])
                phase=pair['phase'];after=pair['after'];new[phase].append(deepcopy(job['phases'][phase][after]))
                for step,t in enumerate([1/3,2/3]):
                    cel=frames[i*2+step];height=a['height']*(1-t)+b['height']*t
                    scale=height/cel['height'];offset=a['median_offset']*(1-t)+b['median_offset']*t
                    if not .15<=scale<=3.5:raise ValueError(job['id']+': unexpected drawing scale')
                    entry=dict(source=job['source'],region=cel['region'],component_seeds=cel['component_seeds'],scale=round(scale,6),anchor_x=round(cel['median_x']-offset/scale,6),grade=grade)
                    new[phase].append(entry)
            names=[job['animations'][0],job['animations'][1],job['animations'][2]]
            if job['move']!='attack':names[2]=job['move']+'_recover'
            for name,entries in zip(names,new):runtime[name]=entries
            sources.append(dict(id=job['id'],source=job['source'],sha256=sha256(path.read_bytes()).hexdigest(),new_drawings=24,animations=names,reference=job['reference']))
        source_paths={item['source'] for item in sources}
        used={(entry['source'],tuple(entry['region'])) for entries in runtime.values() for entry in entries if entry.get('source') in source_paths}
        record['combat_motion_v7']=dict(tool='tools/build_combat_motion_v7.py',sources=sources,new_drawings=24*len(items),runtime_drawings=len(used),calibration='Continuous endpoint height and rig median; uniform sheet palette match; source pixels never morphed or interpolated.')
        if not check:write(folder/RECORD,record)
        elif read(folder/RECORD)!=record:raise ValueError(kind+': registration differs')
        result=build(folder,check,RECORD,MANIFEST,ATLAS);result['new_drawings']=24*len(items);results.append(result)
    return results

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--check',action='store_true');parser.add_argument('--only',action='append');parser.add_argument('--available',action='store_true');parser.add_argument('--audit-sources',action='store_true');args=parser.parse_args()
    if args.prepare:
        spec=prepare();print('COMBAT_MOTION_V7_PLAN characters=%d jobs=%d new_drawings=%d' % (spec['characters'],len(spec['jobs']),spec['planned_new_drawings']));return
    jobs=read(REQUEST/'specification.json')['jobs']
    if args.only:jobs=[job for job in jobs if job['id'] in args.only or job['kind'] in args.only]
    if args.available:jobs=[job for job in jobs if (ROOT/job['source']).is_file() and (ROOT/(job['source']+'.receipt.json')).is_file()]
    if args.audit_sources:
        errors=[]
        for job in jobs:
            try:extract(ROOT/job['source'])
            except (ValueError,OSError) as error:errors.append({'id':job['id'],'source':job['source'],'error':str(error)})
        write(ROOT/'output/combat_animation_v7/source-audit.json',{'jobs':len(jobs),'valid':len(jobs)-len(errors),'errors':errors})
        print(json.dumps({'jobs':len(jobs),'valid':len(jobs)-len(errors),'errors':errors},ensure_ascii=False,indent=2))
        raise SystemExit(1 if errors else 0)
    results=register(jobs,args.check);write(REQUEST/'runtime_report.json',dict(characters=len(results),coverage=results))
    print('COMBAT_MOTION_V7 characters=%d new_drawings=%d frames=%d check=%s' % (len(results),sum(r['new_drawings'] for r in results),sum(r['frames'] for r in results),args.check))

if __name__=='__main__':main()
