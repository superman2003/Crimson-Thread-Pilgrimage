"""Semantic contracts for both groups of authored workshop routes."""
from collections import Counter
import math

GROUP = 'movement_group_one'
ABILITIES = {'thread_dash','silk_wall_grip','echo_hook','double_thread_jump','bell_guard'}
ACTIONS = {'walk','jump','wall_jump','double_jump','hook'}

def contracts(routes, group=GROUP):
    checks = []
    def check(ok,label):checks.append((bool(ok),label))
    layouts=[l for l in routes.get('workshop_layouts',[]) if l.get('layout_group')==group]
    expected = 10 if group==GROUP else 9
    check(len(layouts)==expected,group+': expected authored room count')
    keys=[(l['region_id'],l['room_id']) for l in layouts]
    check(len(set(keys))==len(keys),group+': room recipes are unique')
    targets={(t['region_id'],t['room_id']):t for t in routes['ability_backtracks']}
    counts=Counter(targets[k]['ability_id'] for k in keys if k in targets)
    check(counts == (Counter({a:2 for a in ABILITIES}) if group==GROUP else Counter(bell_guard=1,thorn_downstrike=3,lantern_phase=2,crown_resonance=3)),'group has its exact ability coverage')
    check(len({l.get('variant') for l in layouts})==len(layouts),group+': workshop route archetypes differ')
    shapes=set()
    for layout in layouts:
        label=layout['room_id']; key=(layout['region_id'],label)
        chapter=routes['chapters'][layout['region_id']]
        room=next((r for r in chapter['map_rooms'] if r['id']==label),{})
        target=targets.get(key,{})
        check(target.get('role') in (['backtrack'] if group==GROUP else ['backtrack','practice']),label+': expected workshop role')
        check(room.get('layout_group')==group and room.get('route_archetype')==layout.get('variant'),label+': production room retains authored route identity')
        pieces=[tuple(v['offset']+v['size']) for v in layout['platforms']]
        shapes.add(tuple(pieces))
        platforms=[p for p in chapter['platforms'] if p['id'].startswith(label+'_')]
        floor=next(p for p in platforms if p['id']==label+'_foundation')['rect']
        roof=next(p for p in platforms if p['id']==label+'_roof')['rect']
        x,y,w,h=room['layout_rect']
        steps=room.get('route_steps',[])
        check(len(steps)>=2,label+': route has actual intermediate movement goals')
        for step in steps:
            point=step.get('position',[])
            valid=len(point)==2 and all(isinstance(n,(int,float)) and not isinstance(n,bool) and math.isfinite(n) for n in point)
            check(valid and step.get('action') in ACTIONS,label+': finite route goal and supported control action')
            if not valid:continue
            px,py=point
            check(x+17<=px<=x+w-17 and roof[1]+roof[3]+84<=py<=floor[1],label+': route goal fits standing player inside shell')
            supported=any(p['rect'][0]+4<=px<=p['rect'][0]+p['rect'][2]-4 and abs(p['rect'][1]-py)<0.01 for p in platforms if p.get('collision_role') not in ('wall','ceiling','decorative'))
            # A climb face is also a safe solid top after a wall jump.
            supported=supported or any(p['rect'][0]+4<=px<=p['rect'][0]+p['rect'][2]-4 and abs(p['rect'][1]-py)<0.01 for p in platforms if p.get('collision_role')=='wall')
            check(supported,label+': route goal has a real landing surface')
        rewards=[p for p in chapter['collectibles'] if p['id'] in target.get('reward_ids',[])]
        check(len(rewards)==2 and all(p.get('platform_id')==layout.get('reward_platform') for p in rewards),label+': both original rewards use the authored upper landing')
        gallery=next(p for p in platforms if p['id']==layout['reward_platform'])['rect']
        check(all(gallery[0]+18<=p['position'][0]<=gallery[0]+gallery[2]-18 and abs(gallery[1]-p['position'][1]-40)<0.01 for p in rewards),label+': item positions have standing clearance and full support')
        if target.get('ability_id')=='double_thread_jump':
            check(floor[1]-gallery[1]>=175,label+': reward level is above a full ordinary jump')
            check(any(s['action']=='double_jump' for s in steps),label+': route explicitly requires the air jump')
        if target.get('ability_id')=='echo_hook':check(len(layout.get('extra_anchors',[]))==1,label+': a second authored ring serves the reward route')
    check(len(shapes)==len(layouts),'physical platform arrangements differ')
    return checks
