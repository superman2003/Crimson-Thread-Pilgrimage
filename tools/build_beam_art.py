#!/usr/bin/env python3
"""Pack four authored segmented beams with registered axes and shared joins."""
from __future__ import annotations
import argparse,hashlib,io,json,math
from pathlib import Path
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT/'art_requests/attack_effects_v1/incoming'
OUTPUT=ROOT/'godot/assets/vfx/beams'
FAMILIES=['erase','gate','steam','thread']
CELL_W,CELL_H,BODY,AXIS=256,128,32,64

def digest(data):return hashlib.sha256(data).hexdigest()

def centerline(cel,region):
    # Sample the straight continuation, away from the large cap burst.
    area=cel.crop((region[0],0,region[1],cel.height));alpha=area.getchannel('A')
    weights=[sum(alpha.crop((0,y,area.width,y+1)).tobytes()) for y in range(area.height)]
    total=sum(weights)
    if total<=0:raise ValueError('empty beam centerline')
    return sum((y+.5)*w for y,w in enumerate(weights))/total

def collar(pieces,widths):
    # Same RGBA profile on every join, both animation frames and both caps.
    joins=[(pieces[0],widths[0]-1),(pieces[1],0),(pieces[1],widths[1]-1),(pieces[2],0),(pieces[2],widths[2]-1),(pieces[3],0)]
    profile=[]
    for y in range(CELL_H):
        values=[im.getpixel((x,y)) for im,x in joins]
        alpha=round(sum(v[3] for v in values)/len(values))
        mass=sum(v[3] for v in values)
        rgb=[round(sum(v[c]*v[3] for v in values)/mass) if mass else 0 for c in range(3)]
        profile.append(tuple(rgb+[alpha]))
    for part,(image,width) in enumerate(zip(pieces,widths)):
        for edge in ([width-1] if part==0 else [0] if part==3 else [0,width-1]):
            for offset in range(8):
                x=offset if edge==0 else width-1-offset
                weight=(1-offset/8)**2
                for y,target in enumerate(profile):
                    old=image.getpixel((x,y));image.putpixel((x,y),tuple(round(a*(1-weight)+b*weight) for a,b in zip(old,target)))
    return profile

def build():
    atlas=Image.new('RGBA',(1024,512));records={}
    for row,family in enumerate(FAMILIES):
        stem=SOURCES/('FX_B_'+family);raw=stem.with_suffix('.png').read_bytes();prompt=stem.with_suffix('.txt').read_bytes();meta=json.loads(stem.with_suffix('.json').read_text())
        if digest(raw)!=meta['image_sha256'] or digest(prompt)!=meta['prompt_sha256']:raise ValueError(f'{family}: source checksum differs')
        image=Image.open(io.BytesIO(raw)).convert('RGBA');frames=meta['frames']
        if len(frames)!=4 or list(image.size)!=meta['image_size']:raise ValueError(f'{family}: dimensions/frame count differs')
        thickness=max(f['bbox_alpha_gt_24_xyxy'][3]-f['bbox_alpha_gt_24_xyxy'][1] for f in frames[1:3]);scale=BODY/thickness
        pieces=[];entries=[];widths=[]
        for part,frame in enumerate(frames):
            rect=frame['rect_xyxy'];cel=image.crop(rect);bounds=frame['bbox_alpha_gt_24_xyxy']
            if part==0:crop=(bounds[0]-rect[0],512);sample=(1024,1536)
            elif part==3:crop=(1024,bounds[2]-rect[0]);sample=(0,512)
            else:crop=(384,1152);sample=(0,1536)
            axis=centerline(cel,sample);width=math.ceil((crop[1]-crop[0])*scale)
            if width> CELL_W or width<16:raise ValueError(f'{family}/{part}: unsafe packed width {width}')
            packed=cel.transform((width,CELL_H),Image.Transform.AFFINE,(1/scale,0,crop[0],0,1/scale,axis-AXIS/scale),resample=Image.Resampling.BICUBIC)
            solid=packed.getchannel('A').point(lambda a:255 if a>128 else 0)
            rim=Image.new('RGBA',packed.size,(15,19,22,0));rim.putalpha(solid.filter(ImageFilter.MaxFilter(3)).point(lambda a:round(a*.9)))
            packed=Image.alpha_composite(rim,packed)
            alpha=packed.getchannel('A')
            if alpha.crop((0,0,width,1)).getextrema()[1] or alpha.crop((0,CELL_H-1,width,CELL_H)).getextrema()[1]:raise ValueError(f'{family}/{part}: vertical clipping')
            pieces.append(packed);widths.append(width)
            entries.append({'delivered_rect':rect,'selected_source_rect':[crop[0]+rect[0],rect[1],crop[1]+rect[0],rect[3]],'source_axis_y':axis+rect[1],'atlas_rect':[part*CELL_W,row*CELL_H,width,CELL_H]})
        join=collar(pieces,widths)
        if max(pixel[3] for pixel in join)<128:raise ValueError(f'{family}: invisible join')
        for part,piece in enumerate(pieces):atlas.paste(piece,(part*CELL_W,row*CELL_H))
        records[family]={'source':str(stem.with_suffix('.png').relative_to(ROOT)),'sha256':digest(raw),'prompt_sha256':digest(prompt),'metadata_sha256':digest(stem.with_suffix('.json').read_bytes()),'shared_scale':scale,'join_rgba_sha256':digest(bytes(c for p in join for c in p)),'frames':entries}
    stream=io.BytesIO();atlas.save(stream,'PNG',optimize=True)
    manifest={'schema':1,'families':FAMILIES,'atlas_size':[1024,512],'axis_y':AXIS,'body_thickness':BODY,'middle_fps':12,'atlas_rgba_sha256':digest(atlas.tobytes()),'registration':'one source scale per family; alpha-weighted straight centerline; central half of middle strips; shared eight-pixel join collar','sources':records}
    return stream.getvalue(),(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n').encode()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();png,manifest=build()
    for path,data in {OUTPUT/'beams.png':png,OUTPUT/'manifest.json':manifest}.items():
        if a.check:
            if not path.exists():raise SystemExit(f'BEAM_ART missing {path}')
            same=Image.open(path).convert('RGBA').tobytes()==Image.open(io.BytesIO(data)).convert('RGBA').tobytes() if path.suffix=='.png' else path.read_bytes()==data
            if not same:raise SystemExit(f'BEAM_ART stale {path}')
        else:OUTPUT.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print(f'BEAM_ART_BUILD families=4 parts=16 atlas={len(png)}B check={a.check}')
if __name__=='__main__':main()
