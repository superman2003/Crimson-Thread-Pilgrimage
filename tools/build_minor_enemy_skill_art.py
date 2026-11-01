#!/usr/bin/env python3
"""Measure immutable generated enemy sheets and mechanically register their cels."""
from __future__ import annotations
import argparse,hashlib,importlib.util,io,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
HERE=ROOT/'art_requests/minor_enemy_skills_v4'
OUT=ROOT/'godot/assets/vfx/minor_enemy_skills'
CELL=192

def digest(data):return hashlib.sha256(data).hexdigest()
def jobs():return json.loads((HERE/'requests.json').read_text(encoding='utf-8'))['jobs']
def separator_api():
 spec=importlib.util.spec_from_file_location('source_measure',ROOT/'art_requests/combat_presentation_v2/inspect_sources.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module.separators

def measure(job):
 path=HERE/'incoming'/job['file']
 if not path.is_file():return None
 prompt=path.with_suffix('.txt')
 if not prompt.is_file():raise ValueError('No actual prompt '+job['file'])
 raw=path.read_bytes();old=json.loads(path.with_suffix('.json').read_text(encoding='utf-8')) if path.with_suffix('.json').is_file() else {}
 with Image.open(io.BytesIO(raw)) as image:
  if image.mode!='RGBA' or image.format!='PNG':raise ValueError('Expected original RGBA PNG '+path.name)
  alpha=image.getchannel('A');bounds=alpha.getextrema()
  if bounds[0]!=0 or bounds[1]<128:raise ValueError('Missing true transparency/visible pixels '+path.name)
  cuts=separator_api();ycuts=cuts(alpha,job['rows'],True);frames=[];issues=[]
  for row,animation in enumerate(job['animations']):
   band=alpha.crop((0,ycuts[row],image.width,ycuts[row+1]));tile=animation['topology']=='beam'
   xcuts=[round(i*image.width/3) for i in range(4)] if tile else cuts(band,3,False)
   distinct=set()
   for col in range(3):
    rect=[xcuts[col],ycuts[row],xcuts[col+1],ycuts[row+1]];cel=alpha.crop(rect)
    bbox=cel.point(lambda a:255 if a>24 else 0).getbbox()
    if bbox is None:issues.append(f'row {row+1} cel {col+1}: empty material')
    else:
     margins=[bbox[0],bbox[1],cel.width-bbox[2],cel.height-bbox[3]]
     if margins[1]==0 or margins[3]==0 or (not tile and min(margins)==0):issues.append(f'row {row+1} cel {col+1}: material crosses frame edge')
    distinct.add(digest(image.crop(rect).tobytes()))
    frames.append(dict(row=row,column=col,animation=animation['key'],rect_xyxy=rect,bbox_alpha_gt_24_xyxy=[bbox[0]+rect[0],bbox[1]+rect[1],bbox[2]+rect[0],bbox[3]+rect[1]] if bbox else None))
   if len(distinct)!=3:issues.append(f'row {row+1}: duplicate cels')
  record=dict(schema='minor-enemy-skill-source-v4',file=path.name,kind=job['kind'],image_sha256=digest(raw),prompt_sha256=digest(prompt.read_bytes()),image_size=list(image.size),frame_count=len(frames),layout=[3,job['rows']],reference=job['reference'],reference_sha256=digest((ROOT/job['reference']).read_bytes()),generator='built-in image_gen.imagegen',frames=frames,measured_issues=issues,usage='Original PNG bytes retained. Source QA is separate from runtime geometry, timing and visual acceptance.')
  if old.get('image_sha256')==record['image_sha256'] and old.get('visual_review'):record['visual_review']=old['visual_review']
  return record

def inspect(check=False):
 records=[r for j in jobs() if (r:=measure(j))]
 summary=dict(expected_sheets=40,saved_sheets=len(records),expected_cels=sum(j['frame_count'] for j in jobs()),saved_cels=sum(r['frame_count'] for r in records),pending=[j['file'] for j in jobs() if not (HERE/'incoming'/j['file']).is_file()],measured_issues={r['file']:r['measured_issues'] for r in records if r['measured_issues']},visual_review_pending=[r['file'] for r in records if r.get('visual_review',{}).get('status')!='source_reviewed'])
 for r in records+[summary]:
  path=HERE/'incoming'/(Path(r['file']).stem+'.json' if 'file' in r else 'delivery_status.json');text=json.dumps(r,ensure_ascii=False,indent=2)+'\n'
  if check:
   if not path.is_file() or path.read_text(encoding='utf-8')!=text:raise ValueError('Stale measurement '+str(path))
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print(json.dumps(summary,ensure_ascii=False))
 return 1 if summary['measured_issues'] else 0

def build():
 commands={};creatures={};extras={};output={}
 for job in jobs():
  stem=HERE/'incoming'/Path(job['file']).stem;raw=stem.with_suffix('.png').read_bytes();meta=json.loads(stem.with_suffix('.json').read_text(encoding='utf-8'))
  if meta['image_sha256']!=digest(raw) or meta['prompt_sha256']!=digest(stem.with_suffix('.txt').read_bytes()):raise ValueError('Changed source '+job['file'])
  if meta['measured_issues'] or meta.get('visual_review',{}).get('status')!='source_reviewed':raise ValueError('Unreviewed source '+job['file'])
  image=Image.open(io.BytesIO(raw)).convert('RGBA');atlas=Image.new('RGBA',(CELL*3,CELL*job['rows']))
  for row,animation in enumerate(job['animations']):
   measured=meta['frames'][row*3:row*3+3];sizes=[(f['bbox_alpha_gt_24_xyxy'][2]-f['bbox_alpha_gt_24_xyxy'][0],f['bbox_alpha_gt_24_xyxy'][3]-f['bbox_alpha_gt_24_xyxy'][1]) for f in measured]
   maxw=max(s[0] for s in sizes);maxh=max(s[1] for s in sizes);frames=[];fixed=animation['mode'] in ['warning','channel','link']
   for col,f in enumerate(measured):
    r=f['rect_xyxy'];b=f['bbox_alpha_gt_24_xyxy'];w,h=sizes[col];sx=160/(w if fixed else maxw);sy=160/(h if fixed else maxh);cx=(b[0]+b[2])/2-r[0];cy=(b[1]+b[3])/2-r[1]
    cel=image.crop(r);packed=cel.transform((CELL,CELL),Image.Transform.AFFINE,(1/sx,0,cx-96/sx,0,1/sy,cy-96/sy),resample=Image.Resampling.BICUBIC)
    atlas.paste(packed,(col*CELL,row*CELL));frames.append(dict(source_rect=r,source_anchor=[cx+r[0],cy+r[1]],scale_xy=[sx,sy],atlas_rect=[col*CELL,row*CELL,CELL,CELL]))
   entry=dict(topology=animation['topology'],source=stem.with_suffix('.png').relative_to(ROOT).as_posix(),source_sha256=digest(raw),frames=frames)
   if 'command_id' in animation:
    cid=animation['command_id'];command=commands.setdefault(cid,dict(kind=job['kind'],type=animation['type']))
    command[animation['mode']]=entry
   else:extras.setdefault(animation['extra'],{})[animation['mode']]=entry
  stream=io.BytesIO();atlas.save(stream,'PNG',optimize=True);output[OUT/(job['kind']+'.png')]=stream.getvalue()
  creatures[job['kind']]=dict(texture='res://assets/vfx/minor_enemy_skills/'+job['kind']+'.png',size=list(atlas.size),rgba_sha256=digest(atlas.tobytes()))
 for cid,extra in [('wax_charge','wax_trail'),('pipe_mortar','pipe_impact')]:commands[cid]['hazard_warning']=extras[extra]['warning']
 manifest=dict(schema=1,cell=CELL,material_footprint=160,creatures=creatures,commands=commands,extras=extras)
 output[OUT/'manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
 return output

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--inspect',action='store_true');p.add_argument('--check',action='store_true');a=p.parse_args()
 if a.inspect:raise SystemExit(inspect(a.check))
 for path,data in build().items():
  if a.check:
   if not path.is_file():raise ValueError('Missing '+str(path))
   same=Image.open(path).convert('RGBA').tobytes()==Image.open(io.BytesIO(data)).convert('RGBA').tobytes() if path.suffix=='.png' else path.read_bytes()==data
   if not same:raise ValueError('Stale '+str(path))
  else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 print('MINOR_ENEMY_SKILL_ART_BUILD creatures=40 commands=90 executions=42 extras=6 check='+str(a.check))
if __name__=='__main__':main()
