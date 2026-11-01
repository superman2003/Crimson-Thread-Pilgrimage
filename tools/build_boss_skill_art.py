#!/usr/bin/env python3
"""Mechanically crop/register delivered PNG cels into six bounded runtime atlases.

No drawn content is synthesized or recoloured. Source PNGs remain unchanged.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, io, json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
V2 = ROOT/'art_requests/combat_presentation_v2'
V3 = ROOT/'art_requests/boss_execution_v3'
OUT = ROOT/'godot/assets/vfx/boss_skills'
CELL = 192

def digest(data):return hashlib.sha256(data).hexdigest()

def inspect_new_sources():
    spec=importlib.util.spec_from_file_location('source_inspector',V2/'inspect_sources.py')
    inspector=importlib.util.module_from_spec(spec);spec.loader.exec_module(inspector)
    inspector.HERE=V3
    for request in json.loads((V3/'requests.json').read_text(encoding='utf-8'))['requests']:
        result=inspector.inspect(request)
        if result is None:raise ValueError('Missing execution source: '+request['file'])
        result['schema']='boss-execution-source-v3'
        result['source_brief']='art_requests/boss_execution_v3/README.md'
        result.pop('source_brief_pr',None)
        result['actual_runtime_anchor']='See godot/assets/vfx/boss_skills/manifest.json for measured per-cel registration and scale.'
        result['usage']='Source QA only. Original PNG bytes retained. Actual runtime atlas registration and visual/regression evidence are recorded separately in art_requests/boss_execution_v3/README.md.'
        (V3/'incoming'/Path(request['file']).with_suffix('.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        if result['measured_issues']:raise ValueError(str(result['measured_issues']))

def build():
    v2=json.loads((V2/'requests.json').read_text(encoding='utf-8'))
    v3=json.loads((V3/'requests.json').read_text(encoding='utf-8'))
    requests=[(V2,r) for r in v2['requests'] if r['group'].startswith('boss')]+[(V3,r) for r in v3['requests']]
    output={};bosses={};commands={};charges={}
    for boss in v2['bosses']:
        kind=boss['kind'];rows=[(base,r) for base,r in requests if r['boss_kind']==kind]
        atlas=Image.new('RGBA',(CELL*6,CELL*len(rows)))
        for row,(base,r) in enumerate(rows):
            stem=base/'incoming'/Path(r['file']).stem
            raw=stem.with_suffix('.png').read_bytes();prompt=stem.with_suffix('.txt').read_bytes()
            meta=json.loads(stem.with_suffix('.json').read_text(encoding='utf-8'))
            if digest(raw)!=meta['image_sha256'] or digest(prompt)!=meta['prompt_sha256']:raise ValueError('Source hash differs: '+r['file'])
            if meta['measured_issues'] or meta.get('visual_review',{}).get('status')!='source_reviewed':raise ValueError('Unreviewed source: '+r['file'])
            image=Image.open(io.BytesIO(raw)).convert('RGBA')
            if len(meta['frames'])!=6 or list(image.size)!=meta['image_size']:raise ValueError('Wrong cels/dimensions: '+r['file'])
            frames=[]
            # All warning frames use exactly the same registered footprint.
            # Execution cels share one scale so onset/fade are not enlarged.
            bboxes=[]
            for f in meta['frames']:
                rect=f['rect_xyxy'];b=f['bbox_alpha_gt_24_xyxy']
                bboxes.append((b[0]-rect[0],b[1]-rect[1],b[2]-rect[0],b[3]-rect[1]))
            maxw=max(b[2]-b[0] for b in bboxes);maxh=max(b[3]-b[1] for b in bboxes)
            warning=r['group']=='boss_warning'
            for i,(f,b) in enumerate(zip(meta['frames'],bboxes)):
                rect=f['rect_xyxy'];cel=image.crop(rect)
                w,h=b[2]-b[0],b[3]-b[1]
                sx=160/(w if warning else maxw);sy=160/(h if warning else maxh)
                # Centre registration; ground/beam offsets are specified at draw time.
                cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2
                packed=cel.transform((CELL,CELL),Image.Transform.AFFINE,(1/sx,0,cx-CELL*.5/sx,0,1/sy,cy-CELL*.5/sy),resample=Image.Resampling.BICUBIC)
                atlas.paste(packed,(i*CELL,row*CELL))
                frames.append(dict(source_rect=rect,source_anchor=[cx+rect[0],cy+rect[1]],atlas_rect=[i*CELL,row*CELL,CELL,CELL],scale_xy=[sx,sy]))
            entry=dict(boss=kind,topology=r['topology'],source=str(stem.with_suffix('.png').relative_to(ROOT)).replace('\\','/'),sha256=digest(raw),prompt_sha256=digest(prompt),frames=frames)
            if r['group']=='boss_charge':charges[kind]=entry
            else:
                cid=r['command']['id'];commands.setdefault(cid,dict(boss=kind,type=r['command']['type']))
                commands[cid]['warning' if warning else 'execution']=entry
        buf=io.BytesIO();atlas.save(buf,'PNG',optimize=True)
        output[OUT/(kind+'.png')]=buf.getvalue()
        bosses[kind]=dict(texture='res://assets/vfx/boss_skills/'+kind+'.png',size=list(atlas.size),rgba_sha256=digest(atlas.tobytes()))
    manifest=dict(schema=1,scope='six enabled chapter bosses, 24 commands',cell=CELL,material_footprint=160,commands=commands,charges=charges,bosses=bosses)
    output[OUT/'manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    return output

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');p.add_argument('--inspect-sources',action='store_true');args=p.parse_args()
    if args.inspect_sources:inspect_new_sources();return
    for path,data in build().items():
        if args.check:
            if not path.is_file():raise ValueError('Missing '+str(path))
            same=Image.open(path).convert('RGBA').tobytes()==Image.open(io.BytesIO(data)).convert('RGBA').tobytes() if path.suffix=='.png' else path.read_bytes()==data
            if not same:raise ValueError('Stale '+str(path))
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print('BOSS_SKILL_ART atlases=6 warnings=24 executions=12 charges=6 check='+str(args.check))

if __name__=='__main__':main()
