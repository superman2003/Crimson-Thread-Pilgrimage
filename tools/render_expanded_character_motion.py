#!/usr/bin/env python3
"""Offline atlas previews at production scale; these are not GPU captures."""
from pathlib import Path
import argparse
import json
import math
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
GODOT=ROOT/'godot'
OUT=ROOT/'artifacts/expanded_character_motion'

def frame_image(frame,canvas):
    source=Image.open(GODOT/frame['atlas'].removeprefix('res://')).convert('RGBA')
    x,y,w,h=frame['region'];margin=frame.get('margin',[0,0,0,0])
    image=Image.new('RGBA',tuple(canvas));image.alpha_composite(source.crop((x,y,x+w,y+h)),tuple(margin[:2]))
    return image

def canvas_size(data):
    if data.get('canvas') is not None:
        return data['canvas']
    idle=next(a for a in data['animations'] if a['name']=='idle')['frames'][0]
    margin=idle.get('margin',[0,0,0,0])
    return [idle['region'][2]+margin[2],idle['region'][3]+margin[3]]

def visible_baseline(data):
    """Idle silhouette baseline in canvas pixels, independent of actor offset.

    Production offsets preserve the original world anchor, which can be below
    the visible feet for bosses. An offline comparison aligns visible idle feet
    instead; every animation frame keeps its authored position relative to them.
    """
    idle=next(a for a in data['animations'] if a['name']=='idle')['frames'][0]
    return idle.get('margin',[0,0,0,0])[1]+idle['region'][3]

def preview_extents(data,animation,factor):
    canvas=canvas_size(data);baseline=visible_baseline(data)
    scale=data['visual_scale']*factor
    above=below=half_width=0
    for frame in animation['frames']:
        bounds=frame_image(frame,canvas).getchannel('A').getbbox()
        if bounds:
            x,y,ex,ey=bounds
            above=max(above,(baseline-y)*scale)
            below=max(below,(ey-baseline)*scale)
            half_width=max(half_width,abs(x-canvas[0]/2)*scale,abs(ex-canvas[0]/2)*scale)
    return above,below,half_width

def main():
    p=argparse.ArgumentParser();p.add_argument('--partial',action='store_true');args=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    records=[]
    for family in ['original_creatures','original_npcs']:
        for path in sorted((GODOT/'assets/sprites'/family).glob('*/manifest.json')):
            motion=path.with_name('motion_manifest.json')
            if not motion.exists():
                if args.partial:continue
                raise ValueError(str(motion))
            old=json.loads(path.read_text());new=json.loads(motion.read_text())
            anim='talk' if family=='original_npcs' else 'walk'
            if new.get('motion')=='stationary':anim='idle'
            records.append({'id':path.parent.name,'old':old,'new':new,'animation':anim})
    cols=6;cw,ch=300,310
    roster_extents=[]
    for record in records:
        data=record['new'];animation=next(a for a in data['animations'] if a['name']==record['animation'])
        roster_extents.append(preview_extents(data,animation,1.2))
    roster_below=math.ceil(max((e[1] for e in roster_extents),default=0))
    cw=max(cw,math.ceil(max((e[2] for e in roster_extents),default=0)*2)+24)
    ch=max(ch,math.ceil(max((e[0] for e in roster_extents),default=0))+roster_below+50)
    rows=math.ceil(len(records)/cols)
    grid=Image.new('RGB',(cols*cw,rows*ch),(22,27,35));draw=ImageDraw.Draw(grid)
    for i,record in enumerate(records):
        x=(i%cols)*cw;y=(i//cols)*ch;data=record['new']
        animation=next(a for a in data['animations'] if a['name']==record['animation'])
        pose=frame_image(animation['frames'][0],canvas_size(data))
        # Fixed 1.2x production scale, so the roster is a realistic size comparison.
        scale=data['visual_scale']*1.2
        pose=pose.resize((round(pose.width*scale),round(pose.height*scale)),Image.Resampling.LANCZOS)
        grid.paste(pose,(round(x+cw/2-pose.width/2),round(y+ch-35-roster_below-visible_baseline(data)*scale)),pose)
        draw.text((x+6,y+ch-30),record['id'],fill=(225,222,209))
        summary=' / '.join(a['name']+':'+str(len(a['frames'])) for a in data['animations'][:4])
        draw.text((x+6,y+ch-16),summary,fill=(160,177,192))
    grid.save(OUT/'roster.png')
    # Representative before/after loops keep production display scales and
    # align each version's visible idle baseline, using its actual frame list.
    picks=['moss_larva','bell_mote','gear_sentinel','npc_lantern_sister','npc_old_gardener','rust_crown_guardian']
    selected=[r for key in picks for r in records if r['id']==key]
    if not selected:selected=records[:3]
    comparison_extents=[]
    for record in selected:
        for version in ['old','new']:
            data=record[version];animation=next(a for a in data['animations'] if a['name']==record['animation'])
            comparison_extents.append(preview_extents(data,animation,1.4))
    comparison_below=math.ceil(max((e[1] for e in comparison_extents),default=0))
    panel_width=max(500,math.ceil(max((e[2] for e in comparison_extents),default=0)*2)+24)
    width=panel_width*2
    rh=max(320,math.ceil(max((e[0] for e in comparison_extents),default=0))+comparison_below+70)
    pictures=[]
    cache={}
    for tick in range(40):
        image=Image.new('RGB',(width,len(selected)*rh),(22,27,35));d=ImageDraw.Draw(image)
        for i,r in enumerate(selected):
            for j,version in enumerate(['old','new']):
                data=r[version];animation=next(a for a in data['animations'] if a['name']==r['animation'])
                index=int(tick/20*animation['fps'])%len(animation['frames'])
                key=(r['id'],version,index)
                if key not in cache:
                    canvas=canvas_size(data)
                    pose=frame_image(animation['frames'][index],canvas)
                    scale=data['visual_scale']*1.4
                    cache[key]=pose.resize((round(pose.width*scale),round(pose.height*scale)),Image.Resampling.LANCZOS)
                pose=cache[key]
                baseline=i*rh+rh-35-comparison_below
                top=baseline-visible_baseline(data)*data['visual_scale']*1.4
                image.paste(pose,(round(j*panel_width+panel_width/2-pose.width/2),round(top)),pose)
                d.text((j*panel_width+12,i*rh+10),r['id']+' '+version+' '+r['animation'],fill='white')
                d.text((j*panel_width+12,i*rh+26),str(len(animation['frames']))+' cels / '+str(round(animation['fps'],2))+' fps',fill=(160,177,192))
        pictures.append(image)
    pictures[0].save(OUT/'before-after.webp',save_all=True,append_images=pictures[1:],duration=50,loop=0,quality=90,method=5)
    (OUT/'preview.json').write_text(json.dumps({'kind':'offline source-atlas preview, not a GPU capture','characters':len(records),'comparison':[r['id'] for r in selected],'baseline':'visible idle feet aligned per version; authored motion and uniform production scale preserved','roster_factor':1.2,'comparison_factor':1.4,'comparison_row_height':rh},indent=2)+'\n')
    print(f'EXPANDED_MOTION_PREVIEWS characters={len(records)}')
if __name__=='__main__':main()
