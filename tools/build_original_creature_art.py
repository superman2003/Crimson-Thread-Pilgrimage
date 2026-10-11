#!/usr/bin/env python3
"""Index untouched generated creature atlases and install runtime animation data."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / 'godot'

def bounds(image, rect):
    x,y,w,h = rect
    alpha = np.asarray(image)[y:y+h,x:x+w,3] > 24
    labels,n = ndimage.label(alpha)
    if not n:
        raise ValueError(f'Empty atlas cell: {rect}')
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    useful = np.isin(labels, np.where(sizes > max(18, sizes.max() * .005))[0])
    ys,xs = np.nonzero(useful)
    return [x+int(xs.min()),y+int(ys.min()),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)]

def atlas_frames(path, cols, rows):
    im = Image.open(path).convert('RGBA')
    frames=[]
    for i in range(cols*rows):
        col,row=i%cols,i//cols
        x,y=round(col*im.width/cols),round(row*im.height/rows)
        x2,y2=round((col+1)*im.width/cols),round((row+1)*im.height/rows)
        frames.append(bounds(im,[x,y,x2-x,y2-y]))
    return frames,[im.width,im.height]

def build_creature(design):
    kind=design['kind']; directory=GODOT/'assets/sprites/original_creatures'/kind
    if not (directory/'atlas.png').exists():
        return False
    raw,dimensions=atlas_frames(directory/'atlas.png',4,3)
    extra=directory/'attacks.png'
    extra_frames,extra_size=atlas_frames(extra,4,3) if extra.exists() else ([],[0,0])
    cw=dimensions[0]/4; canvas=[int(np.ceil(max(cw,extra_size[0]/4))),max(f[3] for f in raw+extra_frames)+4]
    scale=design['display_height']/raw[0][3]
    all_frames=[]
    for i,(x,y,w,h) in enumerate(raw):
        cx=round((i%4)*cw)
        all_frames.append({'atlas':f'res://assets/sprites/original_creatures/{kind}/atlas.png','region':[x,y,w,h],
            'margin':[x-cx,canvas[1]-h-2,canvas[0]-w,canvas[1]-h]})
    animations=[]
    indexes={'idle':[0,1],'walk':[2,3,4,5],'windup':[6,7],'attack':[8,9],'hurt':[10],'death':[11]}
    for name,indices in indexes.items():
        animations.append({'name':name,'fps':{'idle':3,'walk':9,'windup':6,'attack':10,'hurt':8,'death':4}[name],
            'loop':name in ['idle','walk'],'frames':[all_frames[i] for i in indices]})
    manifest={'source':'Original hand-drawn production atlas / built-in image_gen','kind':kind,'canvas':canvas,
        'display_height':design['display_height'],'visual_scale':scale,
        'visual_offset':[0,(70 if design['boss'] else 58)-canvas[1]*scale/2],
        'motion':design.get('motion','ground'),'animations':animations,'atlas_size':dimensions}
    if extra.exists():
        frames,sz=extra_frames,extra_size
        for j,name in enumerate(design.get('special_animations',['heavy','cast','phase'])):
            poses=[]
            for i in range(j*4,j*4+4):
                x,y,w,h=frames[i]
                poses.append({'atlas':f'res://assets/sprites/original_creatures/{kind}/attacks.png','region':[x,y,w,h],
                    'margin':[x-round((i%4)*sz[0]/4),canvas[1]-h-2,canvas[0]-w,canvas[1]-h]})
            animations.append({'name':name+'_windup','fps':6,'loop':False,'frames':poses[:2]})
            animations.append({'name':name,'fps':9,'loop':False,'frames':poses[2:]})
    (directory/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    for p in sorted((GODOT/'data').rglob('demo*.json')):
        data=json.loads(p.read_text()); changed=False
        for actor in data.get('enemy_spawns',[])+([data['boss']] if isinstance(data.get('boss'),dict) else []):
            if actor.get('kind')!=kind: continue
            actor['sprite']=f'res://assets/sprites/original_creatures/{kind}/manifest.json'
            actor['visual_scale']=scale;actor['visual_offset']=manifest['visual_offset'];actor['locomotion']=manifest['motion']
            actor['visual_source']='original_hand_drawn';actor['visual_modulate']='ffffff';actor['sprite_faces_left']=False
            actor['spawn_half_width']=24 if not design['boss'] else 49
            actor['spawn_visual_height']=max(20,design['display_height']-40)
            actor['source_sprite']=f'res://assets/sprites/original_creatures/{kind}/atlas.png'
            actor.pop('source_sprite_region',None)
            actor.pop('sprite_parts',None);actor.pop('sprite_region',None);actor.pop('sprite_regions',None)
            changed=True
        if changed: p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    return True

def main():
    designs=json.loads((GODOT/'data/original_creature_designs.json').read_text())['designs']
    done=sum(build_creature(d) for d in designs)
    print(f'Creature animation atlases installed: {done}/{len(designs)}')

if __name__=='__main__': main()
