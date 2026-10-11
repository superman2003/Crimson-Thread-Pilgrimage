#!/usr/bin/env python3
"""Index original NPC animations and inventory icons without repainting the PNGs."""
import json
from pathlib import Path
from build_original_creature_art import atlas_frames

ROOT=Path(__file__).resolve().parents[1];GODOT=ROOT/'godot'

def main():
    data=json.loads((GODOT/'data/original_world_art_designs.json').read_text());count=0
    for npc in data['npcs']:
        folder=GODOT/'assets/sprites/original_npcs'/npc['id'];path=folder/'atlas.png'
        if not path.exists():continue
        raw,size=atlas_frames(path,3,2);canvas=[round(size[0]/3),max(f[3] for f in raw)+4];scale=npc['display_height']/raw[0][3]
        frames=[]
        atlas='res://assets/sprites/original_npcs/'+npc['id']+'/atlas.png'
        for i,(x,y,w,h) in enumerate(raw):
            frames.append({'atlas':atlas,'region':[x,y,w,h],'margin':[x-round((i%3)*size[0]/3),canvas[1]-h-2,canvas[0]-w,canvas[1]-h]})
        x,y,w,h=raw[0]
        manifest={'npc_id':npc['id'],'visual_scale':scale,'visual_offset':[0,40-canvas[1]*scale/2],
            'portrait':{'atlas':atlas,'region':[x,y,w,max(1,round(h*.65))]},
            'animations':[{'name':'idle','fps':2.5,'loop':True,'frames':frames[:2]},
                          {'name':'talk','fps':4,'loop':True,'frames':frames[2:4]},
                          {'name':'greet','fps':4,'loop':False,'frames':[frames[4]]},
                          {'name':'rest','fps':3,'loop':False,'frames':[frames[5]]}]}
        (folder/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');count+=1
    icons={}
    for group in data['item_atlases']:
        path=GODOT/'assets/sprites/original_items'/(group['id']+'.png')
        if not path.exists():continue
        raw,size=atlas_frames(path,4,2)
        for item,region in zip(group['items'],raw):
            icons[item[0]]={'atlas':'res://assets/sprites/original_items/'+group['id']+'.png','region':region}
    folder=GODOT/'assets/sprites/original_items';folder.mkdir(parents=True,exist_ok=True)
    (folder/'manifest.json').write_text(json.dumps(icons,ensure_ascii=False,indent=2)+'\n')
    print('NPC animations:',count,'item icons:',len(icons))
    props=GODOT/'assets/sprites/original_interactables'
    if (props/'atlas.png').exists():
        raw,_=atlas_frames(props/'atlas.png',4,2)
        names=['rest_bell','rest_root','lever_closed','lever_open','gate_closed','gate_open','chest_closed','chest_open']
        (props/'manifest.json').write_text(json.dumps({k:{'atlas':'res://assets/sprites/original_interactables/atlas.png','region':r} for k,r in zip(names,raw)},indent=2)+'\n')

if __name__=='__main__':main()
