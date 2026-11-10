"""Double production clips with new imagegen drawings; preserve every old cel.

--prepare freezes the baseline and makes ordered endpoint reference boards.
--build extracts independently drawn source figures and packs a new runtime layer.
No temporal pixel interpolation, copied cels, new gameplay windows, or AI changes.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
from functools import lru_cache
from hashlib import sha256
from io import BytesIO
import json
import math
from pathlib import Path
import shutil
import subprocess
import numpy as np
from PIL import Image, ImageDraw
from build_combat_motion_v7 import extract

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / 'art_requests/character_motion_v8'
BASE = ROOT / 'godot/assets/sprites/original_creatures'
REF = 'ff8ab652b224523afbf8789a7b5ad98a676eb389'
SPEC = REQUEST / 'specification.json'
REFERENCE_SPEC = REQUEST / 'reference_specification.json'
POSE_REPAIRS = REQUEST / 'pose_repairs.json'
PROMPT = '''Use case: identity-preserve. Asset type: production 2D game animation IN-BETWEEN drawings for Crimson Thread Pilgrimage.
Input image 1 is a REFERENCE BOARD with SIX columns and FOUR rows: TWENTY-FOUR numbered transition cells. Within EACH cell the EARLIER endpoint is ABOVE and the LATER endpoint is BELOW. Order is row-major 1 through 24.
Draw ONE genuinely NEW anatomical MIDPOINT pose halfway between the two endpoints in EACH corresponding cell. Output exactly TWENTY-FOUR separate full-body sprites, SIX columns by FOUR rows, 1536x1024 or larger 3:2 landscape. Output ONLY new midpoint drawings, never the endpoint drawings. If endpoints look nearly identical, articulate the tiny intermediate cloth/limb/antenna settling movement; do not invent a different action.
Preserve this exact character's identity, anatomy, costume, colors, materials, detailed painted ink linework, body mass, weapon length, fixed RIGHT-facing orthographic side-view and constant character scale. Keep the grounded support foot stable; respect airborne intent. Interpolate the intended ANATOMICAL gesture by drawing a new pose, never blending/stretching pixels or ghosting/copying stamps.
Genuine transparent alpha background. Each full figure and every weapon, antenna, cape and detached accessory stays inside its OWN cell with 12 percent clear transparent gutters. No clipping or overlaps, no text, labels, digits, grid, background, floor, shadows, particles, glow, VFX, afterimages, duplicated silhouettes or added limbs. One identical character per cell.
Character ID: {kind}. Preserve the reference's existing design exactly; this is animation completion, not character redesign.'''


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')


def blob(path, ref=None):
    ref=ref or REF
    try:
        return subprocess.check_output(['git', 'show', ref+':'+path], cwd=ROOT,stderr=subprocess.PIPE)
    except subprocess.CalledProcessError:
        # CI shallow checkouts retain these original production assets. Their
        # frozen hashes are mandatory before using them without commit history.
        spec=read(REFERENCE_SPEC if ref!=REF and REFERENCE_SPEC.exists() else SPEC)
        expected=spec.get('baseline_assets',{}).get(path)
        if expected is None:
            expected=next((c['baseline_sha256'] for c in spec['characters'] if c['manifest']==path),None)
        candidate=ROOT/path
        if expected is None or not candidate.is_file():raise
        data=candidate.read_bytes()
        if sha256(data).hexdigest()!=expected:raise ValueError('Frozen baseline changed: '+path)
        return data


@lru_cache(maxsize=6)
def atlas(path, ref=None):
    return Image.open(BytesIO(blob('godot/'+path.removeprefix('res://'),ref))).convert('RGBA')


def cel(frame, ref=None):
    x,y,w,h=frame['region']
    return atlas(frame['atlas'],ref).crop((x,y,x+w,y+h))


def body_measure(image, kind):
    pixels=np.asarray(image)
    solid=pixels[:,:,3]>128
    if kind=='wax_bee':
        # The golden abdomen is a stable body reference while its pale wings
        # fold, rotate and overlap. Measure that material rather than wing span.
        r,g,b=(pixels[:,:,i].astype(np.float32) for i in range(3))
        body=solid&(r>b*1.8)&(g>b*1.3)&(r>g*1.1)&(r>80)
        value=math.sqrt(float(body.sum()))
        metric='golden_body_area_sqrt'
    else:
        # Opaque painted mass stays stable when a pose rotates or spreads its
        # limbs. Unlike full silhouette height it does not enlarge crouches or
        # folded wings to the height of a standing / fully spread endpoint.
        value=math.sqrt(float(solid.sum()))
        metric='opaque_area_sqrt'
    if not math.isfinite(value) or value<3:raise ValueError(kind+': no reliable body scale reference')
    return metric,value


@lru_cache(maxsize=16384)
def endpoint_body_measure(kind, resource, region):
    return body_measure(cel(dict(atlas=resource,region=region)),kind)[1]


@lru_cache(maxsize=16384)
def endpoint_opaque_area(resource, region):
    return int((np.asarray(cel(dict(atlas=resource,region=region)))[:,:,3]>128).sum())


@lru_cache(maxsize=1)
def pose_repairs():
    result={}
    jobs={j['id']:j for j in read(SPEC)['jobs']}
    for repair in read(POSE_REPAIRS) if POSE_REPAIRS.exists() else []:
        source=ROOT/repair['source'];receipt=read(Path(str(source)+'.receipt.json'))
        if receipt.get('generator')!='built-in image_gen' or sha256(source.read_bytes()).hexdigest()!=repair['sha256'] or receipt['sha256']!=repair['sha256']:
            raise ValueError(repair['id']+': unverified repair source')
        figures=extract(source)
        if len(figures)!=24:raise ValueError(repair['id']+': repair must contain 24 complete figures')
        used=[]
        for slot in repair['slots']:
            key=(slot['job'],slot['source_index'])
            edge=jobs[slot['job']]['edges'][slot['source_index']]
            if key in result or (edge['animation'],edge['after'])!=(slot['animation'],slot['after']) or jobs[slot['job']]['kind']!=slot['kind']:
                raise ValueError(repair['id']+': invalid or duplicate repair slot')
            drawing=figures[slot['repair_index']]
            used.append(sha256(drawing['pixels'].tobytes()).hexdigest())
            result[key]=(repair,slot['repair_index'],drawing)
        if len(used)!=len(set(used)):raise ValueError(repair['id']+': duplicate repair cels')
    return result


def endpoint(animations, animation, index):
    name=animation['name'];frames=animation['frames']
    if index+1<len(frames):return frames[index+1]
    if animation.get('loop'):return frames[0]
    if name=='death':return frames[-1]  # final cloth/body settling, not revival
    if name=='windup':target='attack'
    elif name.endswith('_windup'):target=name.removesuffix('_windup')
    elif name.endswith('_bridge'):target='recover'
    elif name=='ready_guard':target='ready_settle'
    elif name=='attack':target='recover'
    elif name+'_recover' in animations:target=name+'_recover'
    else:target='idle'
    return animations.get(target,animations['idle'])['frames'][0]


def alpha_references():
    reference_spec=read(REFERENCE_SPEC if REFERENCE_SPEC.exists() else SPEC)
    for job in reference_spec['jobs']:
        board=Image.new('RGBA',(1800,1680),(0,0,0,0));draw=ImageDraw.Draw(board)
        edges=job['edges']+[job['edges'][-1]]*(24-len(job['edges']))
        for index,edge in enumerate(edges):
            x=index%6*300;y=index//6*420
            draw.text((x+8,y+3),f'{index+1:02}: {edge["animation"]} {edge["after"]}',fill=(190,190,190,255))
            for side,key in enumerate(['left','right']):
                im=cel(edge[key],reference_spec['baseline_commit']);im.thumbnail((270,174))
                board.alpha_composite(im,(x+(300-im.width)//2,y+25+side*195+174-im.height))
        path=REQUEST/'refs_alpha'/f'{job["id"]}.png';path.parent.mkdir(parents=True,exist_ok=True);board.save(path)
    print('ALPHA_REFERENCES_READY')


def prepare():
    if any((REQUEST/'incoming').glob('*.png')):raise ValueError('Delivered source references are frozen; do not replace the specification with --prepare')
    plans=[];characters=[];baseline_assets={}
    for folder in sorted(BASE.iterdir()):
        if not folder.is_dir():continue
        path=next((folder/n for n in ['boss_behavior_manifest.json','combat_motion_v7_manifest.json'] if (folder/n).exists()),None)
        if path is None:continue
        relative=path.relative_to(ROOT).as_posix();raw=blob(relative);manifest=json.loads(raw)
        animations={a['name']:a for a in manifest['animations']};edges=[]
        for animation in manifest['animations']:
            for frame in animation['frames']:
                resource='godot/'+frame['atlas'].removeprefix('res://')
                if resource not in baseline_assets:baseline_assets[resource]=sha256(blob(resource)).hexdigest()
        order=list(animations)
        if folder.name=='broken_string_gardener':
            order=['heavy_recover','cast_recover']+[n for n in order if n not in ['heavy_recover','cast_recover']]
        for name in order:
            animation=animations[name]
            for i,frame in enumerate(animation['frames']):
                edges.append(dict(animation=name,after=i,left=frame,right=endpoint(animations,animation,i)))
        baseline=REQUEST/'baselines'/f'{folder.name}.json';write(baseline,manifest)
        for offset in range(0,len(edges),24):
            chunk=edges[offset:offset+24];used=len(chunk)
            padded=chunk+[chunk[-1]]*(24-used)
            job_id=f'{folder.name}__{offset//24+1:02}'
            reference=f'art_requests/character_motion_v8/refs/{job_id}.png'
            board=Image.new('RGB',(1800,1680),(40,43,46));draw=ImageDraw.Draw(board)
            for index,edge in enumerate(padded):
                x=index%6*300;y=index//6*420
                draw.text((x+8,y+3),f'{index+1:02}: {edge["animation"]} {edge["after"]}',fill='white')
                for side,key in enumerate(['left','right']):
                    im=cel(edge[key],REF);im.thumbnail((270,174))
                    board.paste(im,(x+(300-im.width)//2,y+25+side*195+174-im.height),im)
            (ROOT/reference).parent.mkdir(parents=True,exist_ok=True);board.save(ROOT/reference)
            plans.append(dict(id=job_id,kind=folder.name,reference=reference,
                source=f'art_requests/character_motion_v8/incoming/{job_id}.png',
                used_drawings=used,edges=chunk,prompt=PROMPT.format(kind=folder.name)))
        characters.append(dict(kind=folder.name,manifest=relative,baseline_sha256=sha256(raw).hexdigest(),
            frame_refs=sum(len(a['frames']) for a in manifest['animations']),
            baseline=baseline.relative_to(ROOT).as_posix()))
    spec=dict(schema=1,baseline_commit=REF,baseline_assets=baseline_assets,characters=characters,jobs=plans,
              new_runtime_drawings=sum(c['frame_refs'] for c in characters),
              policy='One newly authored midpoint after each retained original pose; original frame objects unchanged; fps doubled to preserve duration.')
    write(SPEC,spec)
    print(json.dumps(dict(characters=len(characters),jobs=len(plans),new_runtime_drawings=spec['new_runtime_drawings'])))


def register_job(job):
    source=ROOT/job['source'];receipt=read(Path(str(source)+'.receipt.json'))
    if receipt.get('generator')!='built-in image_gen':raise ValueError(job['id']+': unknown generator')
    raw=source.read_bytes()
    if receipt['sha256']!=sha256(raw).hexdigest():raise ValueError(job['id']+': changed source')
    figures=extract(source)
    if len(figures)!=24:raise ValueError(job['id']+': source must contain 24 complete sprites')
    used_hashes=[sha256(f['pixels'].tobytes()).hexdigest() for f in figures[:job['used_drawings']]]
    if len(set(used_hashes))!=len(used_hashes):raise ValueError(job['id']+': duplicated source cels cannot count as new drawings')
    def mean_rgb(image):
        pixels=np.asarray(image);mask=pixels[:,:,3]>128
        if not mask.any():raise ValueError(job['id']+': no solid character ink')
        return pixels[:,:,:3][mask].mean(axis=0)
    targets=[cel(edge[side]) for edge in job['edges'] for side in ['left','right']]
    gain=np.clip(np.mean([mean_rgb(im) for im in targets],axis=0)/np.maximum(1,np.mean([mean_rgb(Image.fromarray(f['pixels'])) for f in figures[:len(job['edges'])]],axis=0)),.85,1.15)
    result=[]
    for index,edge in enumerate(job['edges']):
        replacement=pose_repairs().get((job['id'],index))
        drawing=replacement[2] if replacement else figures[index]
        pixels=drawing['pixels'].copy()
        frame_gain=gain
        if replacement:
            target_rgb=np.mean([mean_rgb(cel(edge[side])) for side in ['left','right']],axis=0)
            frame_gain=np.clip(target_rgb/np.maximum(1,mean_rgb(Image.fromarray(pixels))),.85,1.15)
        pixels[:,:,:3]=np.clip(np.round(pixels[:,:,:3].astype(np.float32)*frame_gain),0,255).astype(np.uint8)
        im=Image.fromarray(pixels)
        # Registration only: new silhouettes are independently authored pixels.
        left,right=edge['left'],edge['right']
        lb,rb=cel(left).getchannel('A').getbbox(),cel(right).getchannel('A').getbbox()
        if lb is None or rb is None:raise ValueError(job['id']+': empty baseline endpoint')
        metric,source_body=body_measure(im,job['kind'])
        target_body=math.sqrt(math.prod(endpoint_body_measure(job['kind'],frame['atlas'],tuple(frame['region'])) for frame in [left,right]))
        scale=target_body/source_body
        im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
        if not .15<=scale<=4:raise ValueError(job['id']+': unexpected drawing scale')
        reference_area=math.sqrt(endpoint_opaque_area(left['atlas'],tuple(left['region']))*endpoint_opaque_area(right['atlas'],tuple(right['region'])))
        opaque_area=int((np.asarray(im)[:,:,3]>128).sum())
        area_ratio=opaque_area/reference_area
        if not .67<=area_ratio<=1.5:
            raise ValueError(f"{job['id']}/{edge['animation']} after {edge['after']}: opaque area ratio {area_ratio:.3f} outside [0.67, 1.5]")
        baseline=(left['margin'][1]+lb[3]+right['margin'][1]+rb[3])*.5
        anchors=[]
        for frame in [left,right]:
            image=cel(frame);weights=np.asarray(image)[:,:,3].sum(axis=0)
            anchors.append(frame['margin'][0]+int(np.searchsorted(np.cumsum(weights),weights.sum()*.5)))
        weights=np.asarray(im)[:,:,3].sum(axis=0);center=int(np.searchsorted(np.cumsum(weights),weights.sum()*.5))
        visible=im.getchannel('A').getbbox()
        result.append(dict(edge=edge,image=im,margin_xy=[round(sum(anchors)*.5-center),round(baseline-visible[3])],
                            source=replacement[0]['source'] if replacement else job['source'],source_region=drawing['region'],source_index=replacement[1] if replacement else index,scale=scale,rgb_gain=[round(float(v),6) for v in frame_gain]))
        if replacement:result[-1]['replaces']=dict(source=job['source'],source_index=index,repair_id=replacement[0]['id'])
        result[-1]['body_registration']=dict(metric=metric,source=source_body,target=target_body,registered=body_measure(im,job['kind'])[1])
    return result


def deliver(job_id, image, actual_prompt=None, actual_reference=None):
    job=next(j for j in read(SPEC)['jobs'] if j['id']==job_id)
    source=ROOT/job['source'];source.parent.mkdir(parents=True,exist_ok=True)
    tool_reference=actual_reference or job['reference']
    if source.exists() and source.read_bytes()!=image.read_bytes():
        rejected=REQUEST/'rejected'/f'{job_id}__{sha256(source.read_bytes()).hexdigest()[:12]}.png'
        rejected.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,rejected)
        if actual_reference==job['source']:actual_reference=rejected.relative_to(ROOT).as_posix()
        old_receipt=Path(str(source)+'.receipt.json')
        if old_receipt.exists():shutil.copyfile(old_receipt,Path(str(rejected)+'.receipt.json'))
    shutil.copyfile(image,source)
    receipt=dict(id=job_id,generator='built-in image_gen',prompt=actual_prompt or job['prompt'],
                 reference=actual_reference or job['reference'],generated_path=str(image),
                 tool_reference=tool_reference,
                 sha256=sha256(source.read_bytes()).hexdigest(),used_drawings=job['used_drawings'])
    write(Path(str(source)+'.receipt.json'),receipt)
    try:register_job(job)
    except Exception as error:
        receipt['validation_passed']=False;receipt['validation_error']=str(error)
        write(Path(str(source)+'.receipt.json'),receipt)
        raise
    receipt['validation_passed']=True
    write(Path(str(source)+'.receipt.json'),receipt)
    print('DELIVERY_VALID '+job_id)


def build(only=None,check=False):
    spec=read(SPEC);reports=[]
    for character in spec['characters']:
        kind=character['kind']
        if only and kind not in only:continue
        jobs=[j for j in spec['jobs'] if j['kind']==kind]
        if sha256((ROOT/character['manifest']).read_bytes()).hexdigest()!=character['baseline_sha256']:
            raise ValueError(kind+': retained production manifest changed')
        drawings=[]
        for job in jobs:drawings.extend(register_job(job))
        if len(drawings)!=character['frame_refs']:raise ValueError(kind+': one new drawing per old frame is required')
        manifest=read(ROOT/character['baseline']);canvas=manifest['canvas'];frames={};pages=[]
        for resource in {f['atlas'] for a in manifest['animations'] for f in a['frames']}:
            path='godot/'+resource.removeprefix('res://')
            if sha256((ROOT/path).read_bytes()).hexdigest()!=spec['baseline_assets'][path]:
                raise ValueError(kind+': retained atlas pixels changed: '+path)
        page=Image.new('RGBA',(2048,2048));x=y=row_h=0
        folder=BASE/kind
        def finish():
            if not page.getbbox():return
            pages.append(page.crop((0,0,2048,min(2048,y+row_h))))
        for drawing in drawings:
            im=drawing['image'];w,h=im.size
            if w+4>2048 or h+4>2048:raise ValueError(kind+': sprite exceeds texture budget')
            if x+w+4>2048:x=0;y+=row_h+4;row_h=0
            if y+h+4>2048:finish();page=Image.new('RGBA',(2048,2048));x=y=row_h=0
            page.alpha_composite(im,(x+2,y+2))
            edge=drawing['edge'];key=(edge['animation'],edge['after']);px,py=drawing['margin_xy']
            frames[key]=dict(atlas=f'res://assets/sprites/original_creatures/{kind}/motion_v8_{len(pages):02}.png',
                             region=[x+2,y+2,w,h],margin=[px,py,canvas[0]-w,canvas[1]-h])
            x+=w+4;row_h=max(row_h,h+4)
        finish()
        if len(frames)!=character['frame_refs']:raise ValueError(kind+': duplicate or missing transition slots')
        # A common symmetric canvas keeps every old pixel at its original
        # world position in both facings, while fully containing extended art.
        padding=[max(0,max(max(-f['margin'][axis],f['margin'][axis]+f['region'][axis+2]-canvas[axis]) for f in frames.values())) for axis in [0,1]]
        for animation in manifest['animations']:
            original=animation['frames'];animation['frames']=[f for i,old in enumerate(original) for f in [old,frames[(animation['name'],i)]]]
            animation['fps']*=2
            for frame in animation['frames']:
                frame['margin']=[frame['margin'][0]+padding[0],frame['margin'][1]+padding[1],frame['margin'][2]+padding[0]*2,frame['margin'][3]+padding[1]*2]
        manifest['canvas']=[canvas[0]+padding[0]*2,canvas[1]+padding[1]*2]
        manifest['version']=8;manifest['generation_record']='motion_v8_generation.json'
        manifest['source']='Built-in image_gen authored midpoints; body-scale registration; retained original pixels and world placement; symmetric canvas padding; no temporal pixel interpolation.'
        sources={}
        for drawing in drawings:
            source=drawing['source']
            if source not in sources:sources[source]=dict(id=Path(source).stem,source=source,sha256=sha256((ROOT/source).read_bytes()).hexdigest(),used_drawings=0)
            sources[source]['used_drawings']+=1
        record=dict(schema=1,baseline_commit=REF,reference_baseline_commit=spec.get('reference_baseline_commit',REF),baseline_manifest=character['manifest'],baseline_sha256=character['baseline_sha256'],
                    baseline_canvas=canvas,symmetric_padding=padding,
                    new_drawings=len(drawings),old_frame_refs=character['frame_refs'],
                    sources=list(sources.values()),
                    registrations=[{k:v for k,v in d.items() if k not in ['image','edge']}|dict(animation=d['edge']['animation'],after=d['edge']['after']) for d in drawings])
        for name,data in [('motion_v8_manifest.json',manifest),('motion_v8_generation.json',record)]:
            path=folder/name
            if check:
                if read(path)!=data:raise ValueError(kind+': stale '+name)
            else:write(path,data)
        for i,image in enumerate(pages):
            path=folder/f'motion_v8_{i:02}.png'
            if check:
                with Image.open(path) as current:
                    if current.size!=image.size or current.convert('RGBA').tobytes()!=image.tobytes():raise ValueError(kind+': stale atlas pixels')
            else:image.save(path)
        expected_pages={folder/f'motion_v8_{i:02}.png' for i in range(len(pages))}
        for stale in folder.glob('motion_v8_[0-9][0-9].png'):
            if stale not in expected_pages:
                if check:raise ValueError(kind+': unreferenced motion v8 page '+stale.name)
                stale.unlink()
        reports.append(dict(kind=kind,old_frames=character['frame_refs'],new_frames=character['frame_refs']*2,pages=len(pages)))
    if not check:write(REQUEST/'runtime_report.json',reports)
    print(json.dumps(dict(characters=len(reports),new_frames=sum(r['new_frames'] for r in reports),check=check)))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--alpha-refs',action='store_true');p.add_argument('--build',action='store_true');p.add_argument('--check',action='store_true');p.add_argument('--only',action='append');p.add_argument('--deliver');p.add_argument('--image',type=Path);p.add_argument('--actual-prompt');p.add_argument('--actual-reference');args=p.parse_args()
    if args.prepare:prepare()
    elif args.alpha_refs:alpha_references()
    elif args.deliver:deliver(args.deliver,args.image,args.actual_prompt,args.actual_reference)
    elif args.build or args.check:build(args.only,args.check)
    else:p.error('choose --prepare, --build, or --check')
