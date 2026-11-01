#!/usr/bin/env python3
"""Pack three player skills from read-only delivered sources."""
from __future__ import annotations
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT/'art_requests/attack_effects_v1/incoming'
OUTPUT=ROOT/'godot/assets/vfx/player_skills'
FAMILIES=['needle','shockwave','snare'];CELL=192

def digest(data):return hashlib.sha256(data).hexdigest()

def build():
 atlas=Image.new('RGBA',(CELL*8,CELL*3));records={}
 for row,family in enumerate(FAMILIES):
  stem=SOURCES/('FX_H_'+family);raw=stem.with_suffix('.png').read_bytes();prompt=stem.with_suffix('.txt').read_bytes();meta=json.loads(stem.with_suffix('.json').read_text())
  if digest(raw)!=meta['image_sha256'] or digest(prompt)!=meta['prompt_sha256']:raise ValueError(f'{family}: delivered source hash differs')
  image=Image.open(io.BytesIO(raw)).convert('RGBA');frames=meta['frames']
  if len(frames)!=8 or list(image.size)!=meta['image_size']:raise ValueError(f'{family}: source dimensions/frame count differ')
  body=64 if family=='needle' else 96;holds=frames[:4] if family=='needle' else frames[2:6]
  scale=body/max(f['bbox_alpha_gt_24_xyxy'][2]-f['bbox_alpha_gt_24_xyxy'][0] for f in holds)
  anchor=(96,96) if family=='needle' else (96,144);entries=[]
  for column,frame in enumerate(frames):
   rect=frame['rect_xyxy'];cel=image.crop(rect);bounds=cel.getchannel('A').point(lambda a:255 if a>24 else 0).getbbox()
   if not bounds:raise ValueError(f'{family}/{column}: empty cel')
   cx=(bounds[0]+bounds[2])/2;cy=(bounds[1]+bounds[3])/2 if family=='needle' else bounds[3]
   packed=cel.transform((CELL,CELL),Image.Transform.AFFINE,(1/scale,0,cx-anchor[0]/scale,0,1/scale,cy-anchor[1]/scale),resample=Image.Resampling.BICUBIC)
   solid=packed.getchannel('A').point(lambda a:255 if a>128 else 0)
   dark=Image.new('RGBA',packed.size,(15,19,22,0));dark.putalpha(solid.filter(ImageFilter.MaxFilter(5)).point(lambda a:round(a*.9)))
   pale=Image.new('RGBA',packed.size,(220,208,178,0));pale.putalpha(solid.filter(ImageFilter.MaxFilter(3)).point(lambda a:round(a*.6)))
   packed=Image.alpha_composite(Image.alpha_composite(dark,pale),packed);alpha=packed.getchannel('A')
   edges=[alpha.crop((0,0,CELL,1)),alpha.crop((0,CELL-1,CELL,CELL)),alpha.crop((0,0,1,CELL)),alpha.crop((CELL-1,0,CELL,CELL))]
   if any(edge.getextrema()[1] for edge in edges):raise ValueError(f'{family}/{column}: atlas boundary touched')
   atlas.paste(packed,(column*CELL,row*CELL));entries.append({'source_rect':rect,'source_anchor':[cx+rect[0],cy+rect[1]],'atlas_rect':[column*CELL,row*CELL,CELL,CELL],'packed_alpha_gt_24_bbox':alpha.point(lambda a:255 if a>24 else 0).getbbox()})
  records[family]={'source':str(stem.with_suffix('.png').relative_to(ROOT)),'sha256':digest(raw),'prompt_sha256':digest(prompt),'metadata_sha256':digest(stem.with_suffix('.json').read_bytes()),'body_width':body,'packed_anchor':anchor,'shared_scale':scale,'frames':entries}
 stream=io.BytesIO();atlas.save(stream,'PNG',optimize=True)
 manifest={'schema':1,'families':FAMILIES,'cell':CELL,'atlas_size':[1536,576],'atlas_rgba_sha256':digest(atlas.tobytes()),'native_widths':{'needle':24,'shockwave':60,'snare':72},'registration':'needle centers; wave/field visible bottom; one shared scale per family; dark radius2/pale radius1 ink rim','sources':records}
 return stream.getvalue(),(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n').encode()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();png,manifest=build()
 for path,data in {OUTPUT/'player_skills.png':png,OUTPUT/'manifest.json':manifest}.items():
  if a.check:
   if not path.exists():raise SystemExit(f'PLAYER_SKILL_ART missing {path}')
   same=Image.open(path).convert('RGBA').tobytes()==Image.open(io.BytesIO(data)).convert('RGBA').tobytes() if path.suffix=='.png' else path.read_bytes()==data
   if not same:raise SystemExit(f'PLAYER_SKILL_ART stale {path}')
  else:OUTPUT.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 print(f'PLAYER_SKILL_ART_BUILD families=3 frames=24 atlas={len(png)}B check={a.check}')
if __name__=='__main__':main()
