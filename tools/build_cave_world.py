#!/usr/bin/env python3
"""Author solid cave envelopes and walkable links without replacing chapter content.

Requires Shapely. Runtime consumes only JSON and has no Python dependency.
"""
import json
import math
from pathlib import Path
from shapely.geometry import box, LineString, Polygon
from shapely.ops import unary_union
from shapely.prepared import prep

ROOT = Path(__file__).resolve().parents[1]
LIFTS = [
    ('ba01', 'ba12', 4040),
    ('gtc_floor', 'rs_floor', 1780),
    ('atrium_mezz_west', 'atrium_f3_landing', 3000),
    ('bw_floor', 'trellis_a', 5620),
    ('ash_floor', 'shaft_bridge_fgang', 3800),
    ('moss_bell_perch', 'ante_floor', 2440),
]
# The upper greenhouse gallery crosses the free vine exit. Its hanging dock
# follows the trellis surface so climbing from below remains possible.
HANGING_DOCKS = {(4, 1)}


def rectangle(values):
    x, y, w, h = values
    return box(x, y, x + w, y + h)


def build(path, number):
    d = json.loads(path.read_text())
    d['terrain'] = [t for t in d['terrain'] if not t['id'].startswith('cave_link_')]
    d['platforms'] = [p for p in d['platforms'] if not p['id'].startswith('cave_dock_')]
    plats = {p['id']: p for p in d['platforms']}
    protected = []
    for p in plats.values():
        x, y, w, _ = p['rect']
        protected.append(box(x - 38, y - 260, x + w + 38, y + 3) if p.get('collision_role')!='ceiling' else box(x,y,x+w,y+1))
    for key in ['enemy_spawns', 'npcs', 'save_points', 'collectibles', 'interactives']:
        for obj in d.get(key, []):
            if 'position' not in obj: continue
            x, y = obj['position']
            protected.append(box(x - 100, y - 240, x + 100, y + 25))
    for obj in [d['boss'], {'position': d['player_start']}, {'position': d.get('boss_checkpoint', d['player_start'])}]:
        if not isinstance(obj['position'], list): continue
        x, y = obj['position']; protected.append(box(x-180, y-320, x+180, y+45))
    gates = unary_union([rectangle(g['rect']).buffer(10) for g in d.get('locked_gates', [])])
    ordered = sorted([p for p in plats.values() if p.get('route_order') is not None], key=lambda p:p['route_order'])
    links = []
    for a, b in zip(ordered, ordered[1:]):
        if a['rect'][0] > b['rect'][0]: a, b = b, a
        ax, ay, aw, _ = a['rect']; bx, by, _, _ = b['rect']
        gap = bx - ax - aw
        if gap < 35 or gap > 440 or abs(by-ay) > gap * math.tan(math.radians(30)): continue
        if any(t['surface'][0][0] <= ax+aw and t['surface'][-1][0] >= bx and
               abs(t['surface'][0][1]-ay) < 120 for t in d['terrain']): continue
        surface=[(ax+aw-36,ay),(ax+aw,ay),(bx,by),(bx+36,by)]
        polygon = Polygon(surface+[(x,y+100) for x,y in reversed(surface)])
        if polygon.intersects(gates): continue
        other_air = unary_union([r for p,r in zip(plats.values(), protected[:len(plats)]) if p['id'] not in [a['id'],b['id']]])
        if polygon.intersects(other_air): continue
        corridor_air=Polygon([(x,y-240) for x,y in surface]+[(x,y-1) for x,y in reversed(surface)])
        blocked=False
        for previous in links:
            ps=previous['surface']
            previous_body=Polygon(ps+[(x,y+100) for x,y in reversed(ps)])
            previous_air=Polygon([(x,y-240) for x,y in ps]+[(x,y-1) for x,y in reversed(ps)])
            if previous_body.intersects(corridor_air) or polygon.intersects(previous_air):blocked=True;break
        if blocked:continue
        link = {'id':f'cave_link_{len(links):02d}', 'kind':'cave_road',
                'surface':surface, 'depth':100,
                'texture_variants':[0,3,1,2], 'platform_ids':[], 'cave_walk_link':True}
        links.append(link)
    d['terrain'].extend(links)
    # Open hubs and arenas are chambers; ordinary passages follow the route,
    # rather than excavating an entire large rectangular room behind ledges.
    boss_x,boss_y=d['boss']['position']
    air=[]
    for room in d['map_rooms']:
        if 'layout_rect' not in room:continue
        x,y,w,h=room['layout_rect']
        if (w>=900 and h>=700) or (x<=boss_x<=x+w and y<=boss_y<=y+h):
            air.append(rectangle(room['layout_rect']).buffer(45))
    air.extend(protected)
    walkable=[p for p in plats.values() if p.get('collision_role')!='ceiling']
    for i,a in enumerate(walkable):
        ax,ay,aw,_=a['rect']
        for b in walkable[i+1:]:
            bx,by,bw,_=b['rect']
            if abs(ay-by)>170 or abs(ax+aw/2-bx-bw/2)>620:continue
            air.append(LineString([(ax+aw/2,ay-140),(bx+bw/2,by-140)]).buffer(155))
    for a,b in zip(ordered,ordered[1:]):
        ax,ay,aw,_=a['rect']; bx,by,bw,_=b['rect']
        air.append(LineString([(ax+aw/2,ay-140),(bx+bw/2,by-140)]).buffer(175))
    for segment in d.get('parkour_segments', []):
        steps = [plats[k] for k in segment.get('platforms', []) if k in plats]
        for a,b in zip(steps,steps[1:]):
            ax,ay,aw,_=a['rect'];bx,by,bw,_=b['rect']
            air.append(LineString([(ax+aw/2,ay-140),(bx+bw/2,by-140)]).buffer(175))
    # A dedicated, clear lift shaft and two landing galleries. No teleportation.
    low, high, sx = LIFTS[number-1]
    lower, upper = plats[low]['rect'], plats[high]['rect']
    y0, y1 = lower[1], upper[1]
    low_x = lower[0]+lower[2]/2; high_x = upper[0]+upper[2]/2
    # Find a clear vertical pocket rather than cutting through another room's floor.
    blockers=[rectangle(p['rect']) for p in plats.values() if p['id'] not in [low,high]]
    blockers.extend(rectangle(g['rect']) for g in d.get('locked_gates',[]))
    for t in d['terrain']:
        owners=[plats[k] for k in t.get('platform_ids',[]) if k in plats]
        if owners and all(p.get('collision_role')=='one_way' for p in owners):continue
        s=t['surface']; blockers.append(Polygon(s+[[x,y+t['depth']] for x,y in reversed(s)]))
    candidates=sorted(range(140,d['world']['width']-140,32),key=lambda x:abs(x-sx)+abs(x-low_x)*.3+abs(x-high_x)*.3)
    sx=next((x for x in candidates if not any(b.intersects(box(x-75,min(y0,y1)+90,x+75,max(y0,y1)-100)) for b in blockers)),None)
    if sx is None:raise ValueError(f'{path.name}: no clear lift shaft')
    shaft_clear = box(sx-95,min(y0,y1)-280,sx+95,max(y0,y1)+100)
    air.append(shaft_clear)
    for i,(x,y) in enumerate([(low_x,y0),(high_x,y1)]):
        air.append(box(min(x,sx)-60,y-300,max(x,sx)+60,y+110))
        # Leave the central shaft open; the basket completes the landing gap.
        left,right=sorted([x,sx-70 if x<sx else sx+70])
        if right-left > 10:
            hanging = (number, i) in HANGING_DOCKS
            anchor = plats[low if i == 0 else high]
            d['platforms'].append({'id':f'cave_dock_{i}','rect':[left,y,right-left,28],
                'color':next(iter(plats.values())).get('color','253c3a'),
                'material':anchor['material'] if hanging else next(iter(plats.values())).get('material','moss_stone'),
                'collision_role':'one_way' if hanging else 'floor','route_role':'branch'})
    d['cave_lifts']=[{'id':f'ch{number:02d}_cave_lift','x':sx,'bottom_y':max(y0,y1),
                     'top_y':min(y0,y1),'speed':300,'label':'巡礼升降笼：F 呼叫 / 乘坐'}]
    # Each room is excavated from a solid mass, not hung against an open background.
    world=box(-256,-256,d['world']['width']+256,d['world']['height']+256)
    free=unary_union(air)
    bulk=[]
    for t in d['terrain']:
        owners=[plats[k] for k in t.get('platform_ids',[]) if k in plats]
        if owners and all(p.get('collision_role')=='one_way' for p in owners):continue
        s=t['surface']; depth=t['depth']
        top=[(x,y+depth-1) for x,y in s];bottom=[(x,y+470) for x,y in reversed(s)]
        bulk.append(Polygon(top+bottom).difference(unary_union(protected)))
    for p in plats.values():
        if p.get('collision_role')!='ceiling':continue
        x,y,w,h=p['rect']
        # Attach low tunnel ceilings to overhead rock, retaining any upper path.
        upper_air=[r for other,r in zip(plats.values(),protected[:len(plats)])
                   if other.get('collision_role')!='ceiling' and other['rect'][1]<y]
        bulk.append(box(x,y-250,x+w,y).difference(unary_union(upper_air)))
    solid=world.difference(free).union(unary_union(bulk).difference(shaft_clear))
    # Conservative rasterisation: only fully solid cells receive a collider.
    cell=32; prepared=prep(solid); rows=[]
    for y in range(-256,d['world']['height']+256,cell):
        start=None
        for x in range(-256,d['world']['width']+256,cell):
            occupied=prepared.covers(box(x,y,x+cell,y+cell))
            if occupied and start is None:start=x
            if not occupied and start is not None:rows.append([start,y,x-start,cell]);start=None
        if start is not None:rows.append([start,y,x+cell-start,cell])
    merged=[];active={}
    for y in sorted({r[1] for r in rows}):
        next_active={}
        for r in [r for r in rows if r[1]==y]:
            k=(r[0],r[2]); previous=active.get(k)
            if previous is not None and previous[1]+previous[3]==y:
                previous[3]+=cell;next_active[k]=previous
            else:merged.append(r);next_active[k]=r
        active=next_active
    outlines=[]
    shapes=unary_union([rectangle(r) for r in merged])
    for polygon in getattr(shapes,'geoms',[shapes]):
        for ring in [polygon.exterior,*polygon.interiors]:
            outlines.append([[round(x,1),round(y,1)] for x,y in ring.simplify(12).coords])
    d['cave_world']={'version':1,'solid_rects':merged,'outlines':outlines,'cell_size':cell,
        'visibility':d.get('cave_world',{}).get('visibility','normal'),
        'vision_radius':540,'dark_vision_radius':360,'ray_count':96,
        'walk_links':len(links),'design':'Excavated rooms and shafts inside opaque solid rock; normal room visibility; authored dark rooms use local line-of-sight lighting.'}
    d['terrain_design']['cave_envelope']=True
    d['boss_route_via_exploration']=True
    d['exploration_hint']='洞内沿地面与缓坡前进；竖井升降笼按 F 呼叫和乘坐。寻找并接通捷径即可开启 Boss 通路，无需清空全图小怪。'
    for npc in d.get('npcs',[])[:1]:
        topics=npc.setdefault('dialogue_topics',{})
        route=topics.get('route','')
        if isinstance(route,str) and d['exploration_hint'] not in route:
            topics['route']=route+' '+d['exploration_hint']
    path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    print(path.name,'rock bodies',len(merged),'new walk links',len(links),'lift',sx,flush=True)


if __name__=='__main__':
    paths=sorted(p for p in (ROOT/'godot/data').glob('demo_ch0*.json') if 'boss_trial' not in p.name)
    for i,p in enumerate(paths,1):build(p,i)
