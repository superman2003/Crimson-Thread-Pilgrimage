"""Semantic contracts for both groups of authored workshop routes."""
from collections import Counter
import math

GROUP = 'movement_group_one'
ABILITIES = {'thread_dash','silk_wall_grip','echo_hook','double_thread_jump','bell_guard'}
ACTIONS = {'walk','jump','wall_jump','double_jump','hook'}

def _finite_vector(value, length):
    return (isinstance(value, (list, tuple)) and len(value) == length
            and all(isinstance(n, (int, float)) and not isinstance(n, bool)
                    and math.isfinite(n) for n in value))

def _has_platform_collision(platform):
    # Main/WorldPrefetch skip a platform whenever this key exists, even if the
    # value is empty. Terrain collision is owned by a separate geometry source.
    return (bool(platform) and 'terrain_id' not in platform
            and str(platform.get('collision_role', '')).lower()
            not in ('decorative', 'no_collision'))

def _one_way(platform):
    # Keep the same legacy name fallback as world_platform_body.gd.
    return (str(platform.get('collision_role', '')).lower() == 'one_way'
            or str(platform.get('id', '')).lower().startswith(('bridge_', 'step_', 'shaft_bridge_')))

def _overlaps(a, b):
    return (a[0] < b[0]+b[2] and a[0]+a[2] > b[0]
            and a[1] < b[1]+b[3] and a[1]+a[3] > b[1])

def _standing_clear(point, platforms):
    """Match the existing 34 x 84 standing footprint, after opening the gate.

    One-way ledges can overlap the upper body without blocking it; only their
    tops support the feet. Closed action gates are checked by the runtime suite.
    """
    px, py = point
    for platform in platforms:
        if not _has_platform_collision(platform) or _one_way(platform):
            continue
        x, y, w, h = platform['rect']
        if px + 17 > x and px - 17 < x + w and py > y and py - 84 < y + h:
            return False
    return True

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
        if not room:
            continue
        pieces=[tuple(v['offset']+v['size']) for v in layout['platforms']]
        shapes.add(tuple(pieces))
        platforms=[p for p in chapter['platforms'] if p['id'].startswith(label+'_')]
        platform_by_id = {p['id']: p for p in platforms}
        floor=platform_by_id.get(label+'_foundation', {}).get('rect')
        roof=platform_by_id.get(label+'_roof', {}).get('rect')
        valid_shell = (_finite_vector(room.get('layout_rect'), 4)
                       and _finite_vector(floor, 4) and _finite_vector(roof, 4))
        check(valid_shell,label+': production room and shell geometry exist')
        if not valid_shell:
            continue
        # Collision ownership follows runtime geometry, not generator naming.
        # A foreign-ID collider can obstruct this room even without room_id.
        nearby_platforms = [p for p in chapter['platforms']
                            if p.get('room_id') == label
                            or (_finite_vector(p.get('rect'),4)
                                and _overlaps(p['rect'],room['layout_rect']))]
        collision_platforms = [p for p in nearby_platforms if _has_platform_collision(p)]
        valid_platforms = all(_finite_vector(p.get('rect'), 4)
                              and p['rect'][2] > 0 and p['rect'][3] > 0
                              for p in platforms+collision_platforms)
        check(valid_platforms,label+': production platform geometry is finite and positive')
        if not valid_platforms:
            continue
        x,y,w,h=room['layout_rect']
        # Room framing includes 20 pixels above the physical shell. Recipes
        # are relative to that shell origin, exactly as in the generator.
        origin_x, origin_y = floor[0], roof[1]
        shell_suffixes = ['foundation','roof','backwall']
        if target.get('ability_id') == 'thorn_downstrike':
            shell_suffixes += ['approach','well_wall']
        for suffix in shell_suffixes:
            check(_has_platform_collision(platform_by_id.get(label+'_'+suffix,{})),
                  label+': authored shell retains standalone runtime collision '+suffix)
        for piece in layout['platforms']:
            expected_id = label+'_'+piece['id_suffix']
            actual = platform_by_id.get(expected_id, {})
            expected_rect = [origin_x+piece['offset'][0], origin_y+piece['offset'][1], *piece['size']]
            check(sum(p['id']==expected_id for p in platforms)==1
                  and actual.get('rect')==expected_rect
                  and actual.get('collision_role')==piece.get('collision_role','floor'),
                  label+': production platform matches its authored recipe '+expected_id)
            check(_has_platform_collision(actual),
                  label+': authored platform retains standalone runtime collision '+expected_id)
        steps=room.get('route_steps',[])
        check(len(steps)>=2,label+': route has actual intermediate movement goals')
        expected_steps = [dict(action=step['action'], position=[origin_x+step['offset'][0], origin_y+step['offset'][1]])
                          for step in layout.get('route_steps', [])]
        check(steps==expected_steps,label+': production route steps match the authored recipe')
        for step in steps:
            point=step.get('position',[])
            valid=_finite_vector(point,2)
            check(valid and step.get('action') in ACTIONS,label+': finite route goal and supported control action')
            if not valid:continue
            px,py=point
            check(x+17<=px<=x+w-17 and roof[1]+roof[3]+84<=py<=floor[1],label+': route goal fits standing player inside shell')
            # All live rectangular colliders have a supporting top, including
            # climb faces and one-way ledges; visual-only records do not.
            supported=any(p['rect'][0]+4<=px<=p['rect'][0]+p['rect'][2]-4 and abs(p['rect'][1]-py)<0.01 for p in collision_platforms)
            check(supported,label+': route goal has a real landing surface')
            check(_standing_clear(point,collision_platforms),label+': route goal has unobstructed standing clearance')
        rewards=[p for p in chapter['collectibles'] if p['id'] in target.get('reward_ids',[])]
        check(len(rewards)==2 and all(p.get('platform_id')==layout.get('reward_platform') for p in rewards),label+': both original rewards use the authored upper landing')
        gallery=platform_by_id.get(layout.get('reward_platform'), {}).get('rect')
        check(_finite_vector(gallery,4),label+': authored reward platform exists in production')
        if gallery is None:
            continue
        check(_has_platform_collision(platform_by_id.get(layout.get('reward_platform'),{}))
              and all(gallery[0]+18<=p['position'][0]<=gallery[0]+gallery[2]-18 and abs(gallery[1]-p['position'][1]-40)<0.01 for p in rewards),label+': item positions have standing clearance and full support')
        check(all(_standing_clear([p['position'][0],p['position'][1]+40],collision_platforms) for p in rewards),
              label+': reward pickup has unobstructed standing clearance')
        expected_landing = [origin_x+layout['reward_offset'][0], origin_y+layout['reward_offset'][1]]
        check(room.get('reward_landing')==expected_landing and target.get('reward_landing')==expected_landing,
              label+': room and backtrack retain the authored reward landing')
        for anchor in layout.get('extra_anchors', []):
            anchor_id = label+'_'+anchor['id_suffix']
            actual_anchors = [a for a in chapter.get('grapple_anchors', []) if a['id']==anchor_id]
            expected_position = [origin_x+anchor['offset'][0],origin_y+anchor['offset'][1]]
            expected_approach = [origin_x+anchor['test_from_offset'][0],origin_y+anchor['test_from_offset'][1]]
            check(len(actual_anchors)==1 and actual_anchors[0].get('position')==expected_position
                  and actual_anchors[0].get('test_from')==expected_approach
                  and actual_anchors[0].get('room_id')==label
                  and actual_anchors[0].get('required_ability')=='echo_hook',
                  label+': production grapple anchor matches its authored recipe')
        if target.get('ability_id')=='double_thread_jump':
            check(floor[1]-gallery[1]>=175,label+': reward level is above a full ordinary jump')
            check(any(s['action']=='double_jump' for s in steps),label+': route explicitly requires the air jump')
        if target.get('ability_id')=='echo_hook':check(len(layout.get('extra_anchors',[]))==1,label+': a second authored ring serves the reward route')
    check(len(shapes)==len(layouts),'physical platform arrangements differ')
    return checks
