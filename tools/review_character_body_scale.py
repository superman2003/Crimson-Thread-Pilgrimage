from pathlib import Path
from functools import lru_cache
import json,math,argparse,sys,subprocess
from io import BytesIO
from copy import deepcopy
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'godot/assets/sprites/original_creatures'
parser=argparse.ArgumentParser(description='Review actual runtime body scale and canvas bounds without resizing individual comparison poses.')
parser.add_argument('--output',type=Path,default=ROOT/'artifacts/character_motion_v8/body_size_review_20261110')
parser.add_argument('--review-cases',type=Path,default=ROOT/'art_requests/character_motion_v8/review_regressions.json')
parser.add_argument('--verify-previous',action='store_true',help='Verify the review comment against its actual prior Git commit; needs local history')
args=parser.parse_args();OUT=args.output.resolve();OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'tools'))
from build_character_motion_v8 import body_measure,endpoint_opaque_area,read,SPEC
@lru_cache(maxsize=8)
def atlas(path):return Image.open(ROOT/('godot/'+path.removeprefix('res://'))).convert('RGBA')
def pose(frame):
 x,y,w,h=frame['region'];return atlas(frame['atlas']).crop((x,y,x+w,y+h))
rows=[];overflow=[];errors=[];totals=0;pages=0;area_checks=[];manifests={}
edges={(j['kind'],e['animation'],e['after']):e for j in read(SPEC)['jobs'] for e in j['edges']}
def opaque_area(image):return int((np.asarray(image)[:,:,3]>128).sum())
for folder in sorted(BASE.iterdir()):
 p=folder/'motion_v8_manifest.json'
 if not p.exists():continue
 m=json.loads(p.read_text(encoding='utf-8'));record=json.loads((folder/'motion_v8_generation.json').read_text(encoding='utf-8'));cw,ch=m['canvas'];animations={a['name']:a for a in m['animations']};drawings=record['registrations'];totals+=len(drawings)
 manifests[folder.name]=(m,animations,record)
 for a in m['animations']:
  for i,f in enumerate(a['frames']):
   px,py=f['margin'][:2];w,h=f['region'][2:]
   if px<0 or py<0 or px+w>cw or py+h>ch:overflow.append(dict(kind=folder.name,clip=a['name'],frame=i,margin=[px,py],size=[w,h],canvas=[cw,ch]))
 for d in drawings:
  b=dict(d['body_registration']);f=animations[d['animation']]['frames'][d['after']*2+1];b['registered']=body_measure(pose(f),folder.name)[1];errors.append(dict(kind=folder.name,clip=d['animation'],after=d['after'],error=abs(b['registered']/b['target']-1),metric=b['metric'],target=b['target'],registered=b['registered']))
  edge=edges[(folder.name,d['animation'],d['after'])]
  left,right=[endpoint_opaque_area(edge[side]['atlas'],tuple(edge[side]['region'])) for side in ['left','right']]
  middle=opaque_area(pose(f))
  area_checks.append(dict(kind=folder.name,animation=d['animation'],frame=d['after']*2+1,areas=[left,middle,right],ratio=middle/math.sqrt(left*right)))
 picks=[]
 for name,mode in [('idle','first'),('idle','last'),('walk','mid'),('attack','mid'),('hurt','mid'),('death','last')]:
  a=animations[name];n=len(a['frames'])//2;i=0 if mode=='first' else n-1 if mode=='last' else n//2
  picks.append((name,2*i))
 # One common rig transform across all thumbnails in this character row.
 extent=[0,0,cw,ch]
 for name,i in picks:
  for f in animations[name]['frames'][i:i+2]:
   x,y=f['margin'][:2];w,h=f['region'][2:];extent=[min(extent[0],x),min(extent[1],y),max(extent[2],x+w),max(extent[3],y+h)]
 scale=min(144/(extent[2]-extent[0]),142/(extent[3]-extent[1]))
 row=Image.new('RGB',(2040,184),(39,43,47));draw=ImageDraw.Draw(row);draw.text((4,8),folder.name,fill='white');draw.text((4,28),'same rig scale',fill=(180,185,190))
 for col,(name,i) in enumerate(picks):
  for side,index in enumerate([i,i+1]):
   f=animations[name]['frames'][index];im=pose(f);im=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.LANCZOS)
   x=240+(col*2+side)*150;y=30;px,py=f['margin'][:2];row.paste(im,(x+round((px-extent[0])*scale),y+round((py-extent[1])*scale)),im)
   draw.text((x+2,6),name+' '+('old' if side==0 else 'new'),fill='white')
 rows.append(row)
for i in range(0,len(rows),6):
 board=Image.new('RGB',(2040,184*len(rows[i:i+6])),(39,43,47))
 for j,row in enumerate(rows[i:i+6]):board.paste(row,(0,j*184))
 board.save(OUT/f'roster_{i//6+1:02}.jpg',quality=93);pages+=1
area_outliers=[r for r in area_checks if not .67<=r['ratio']<=1.5]
report={'characters':len(rows),'new_drawings':totals,'contact_pages':pages,'rig_overflows':overflow,'body_metric_max_relative_error':max(d['error'] for d in errors),'worst_metrics':sorted(errors,key=lambda d:d['error'],reverse=True)[:30],
        'opaque_area_bounds':[.67,1.5],'opaque_area_ratio_range':[min(r['ratio'] for r in area_checks),max(r['ratio'] for r in area_checks)],'opaque_area_outliers':area_outliers,
        'endpoint_policy':'Frozen authored left/right endpoints; looping last poses wrap to first; nonlooping tails use the documented next-clip endpoint, or the final death pose.'}
if args.review_cases.exists():
 review=read(args.review_cases);lookup={(r['kind'],r['animation'],r['frame']):r for r in area_checks};reviewed=[];cards=[]
 @lru_cache(maxsize=16)
 def previous_manifest(kind):return json.loads(subprocess.check_output(['git','show',review['source_commit']+f':godot/assets/sprites/original_creatures/{kind}/motion_v8_manifest.json'],cwd=ROOT))
 @lru_cache(maxsize=8)
 def previous_atlas(path):return Image.open(BytesIO(subprocess.check_output(['git','show',review['source_commit']+':godot/'+path.removeprefix('res://')],cwd=ROOT))).convert('RGBA')
 for case in review['cases']:
  key=(case['kind'],case['animation'],case['frame']);current=lookup[key]
  item=dict(case,current_areas=current['areas'],current_ratio=current['ratio'])
  if args.verify_previous:
   old=next(a for a in previous_manifest(case['kind'])['animations'] if a['name']==case['animation']);index=case['frame'];frame=old['frames'][index];x,y,w,h=frame['region']
   left=opaque_area(pose(old['frames'][index-1]));right=opaque_area(pose(old['frames'][index+1 if index+1<len(old['frames']) else 0 if old.get('loop') else index-1]))
   actual=[left,opaque_area(previous_atlas(frame['atlas']).crop((x,y,x+w,y+h))),right]
   item['previous_areas_verified']=actual==case['previous_areas'];item['previous_actual_areas']=actual
  reviewed.append(item)
  m,animations,record=manifests[case['kind']];index=case['frame'];animation=animations[case['animation']]
  left,new=animation['frames'][index-1:index+1];right=deepcopy(edges[(case['kind'],case['animation'],(index-1)//2)]['right']);pad=record['symmetric_padding'];right['margin'][0]+=pad[0];right['margin'][1]+=pad[1]
  frames=[left,new,right];min_x=min(f['margin'][0] for f in frames);min_y=min(f['margin'][1] for f in frames);max_x=max(f['margin'][0]+f['region'][2] for f in frames);max_y=max(f['margin'][1]+f['region'][3] for f in frames)
  scale=min(188/(max_x-min_x),180/(max_y-min_y));card=Image.new('RGB',(600,240),(39,43,47));draw=ImageDraw.Draw(card)
  draw.text((5,4),f"{case['kind']} / {case['animation']} #{index}",fill='white');draw.text((5,19),f"area ratio {case['previous_ratio']:.3f} -> {current['ratio']:.3f}; same scale for all three",fill=(190,195,200))
  for col,frame in enumerate(frames):
   image=pose(frame);image=image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))),Image.Resampling.LANCZOS)
   card.paste(image,(col*200+5+round((frame['margin'][0]-min_x)*scale),42+round((frame['margin'][1]-min_y)*scale)),image)
  cards.append(card)
 for offset in range(0,len(cards),12):
  page=Image.new('RGB',(1800,240*math.ceil(len(cards[offset:offset+12])/3)),(39,43,47))
  for i,card in enumerate(cards[offset:offset+12]):page.paste(card,((i%3)*600,(i//3)*240))
  page.save(OUT/f'review_cases_{offset//12+1:02}.jpg',quality=94)
 report['review_source']=review['source_comment'];report['reviewed_case_count']=len(reviewed);report['review_case_outliers']=[r for r in reviewed if not .67<=r['current_ratio']<=1.5]
 report['previous_verification_mismatches']=[r for r in reviewed if r.get('previous_areas_verified') is False]
 (OUT/'reviewed_regressions.json').write_text(json.dumps(reviewed,indent=2)+'\n',encoding='utf-8')
(OUT/'body_review.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['worst_metrics','previous_verification_mismatches']},indent=2),flush=True)

if len(rows)!=46 or totals!=5439 or overflow or area_outliers or report.get('review_case_outliers') or report.get('previous_verification_mismatches') or report['body_metric_max_relative_error']>.02:raise SystemExit(1)
