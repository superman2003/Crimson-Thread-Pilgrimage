"""Author A01's in-world hook lines and sleeping-bell return routes.

Called by build_ability_places.py after its shelves have been placed. Endpoints
use existing floors; the only new colliders hang above walking head height.
"""
import math

CH01 = 'demo_ch01_moss_bell_court'
CH03 = 'demo_ch03_saltwhite_archive'
CH04 = 'demo_ch04_broken_string_greenhouse'
CH05 = 'demo_ch05_obsidian_pilgrim_road'
# id, region, opening side, return side, ability, title, optional journal record
ROUTES = [
    ('a01_archive_hook_line', CH03, 'sealed_stacks', 'white_spine_hall', 'echo_hook', '运书铜环索道', ''),
    ('a01_greenhouse_hook_line', CH04, 'canopy_east', 'west_gate', 'echo_hook', '藤架铜环索道', ''),
    ('a01_court_sleeping_bell', CH01, 'root_vault', 'moss_descent', 'crown_resonance', '根须沉睡钟',
     '旧钟铭记：这里曾替归家的织工报时。王冠收走了钟声，留下没有夜晚的工时。'),
    ('a01_archive_sleeping_bell', CH03, 'salt_dock', 'crest_bridge', 'crown_resonance', '盐白沉睡钟',
     '旧钟铭记：书船卸货时，钟声会替无名抄书人留下一次签到。后来名册比人活得更久。'),
    ('a01_obsidian_sleeping_bell', CH05, 'silent_gate', 'pilgrim_camp', 'crown_resonance', '黑曜沉睡钟',
     '旧钟铭记：军中的归途钟只为回营者鸣响。最后一道军令，却要求它永远保持沉默。'),
]


def inside(rect, x, y):
    return rect[0] <= x <= rect[0] + rect[2] and rect[1] <= y <= rect[1] + rect[3]


def landing(base, overlay, room_id, overhead=250):
    room = next(r for r in base['map_rooms'] if r['id'] == room_id)
    platforms = base['platforms'] + overlay.get('platforms', [])
    things = [p['position'] for key in ('interactives', 'collectibles', 'save_points', 'npcs', 'enemy_spawns')
              for p in base.get(key, []) if 'position' in p]
    things += [p['position'] for key in ('portals', 'collectibles') for p in overlay.get(key, [])]
    candidates = []
    for floor in base['platforms']:
        if floor.get('collision_role') in ('wall', 'ceiling', 'decorative', 'no_collision'):
            continue
        px, py, pw, _ = floor['rect']
        for x in range(int(px + 40), int(px + pw - 39), 20):
            y = py - 40
            flat = floor.get('terrain_flat_span', [px, px + pw])
            if not flat[0] + 18 <= x <= flat[1] - 18:
                continue
            if not inside(room.get('play_rect', room['layout_rect']), x, y):
                continue
            # Full standing body plus the overhead mechanism and hook approach.
            clear = [x - 45, py - overhead, 90, overhead - 1]
            if any(p['id'] != floor['id'] and overlap(clear, p['rect']) for p in platforms):
                continue
            if any('rect' in h and overlap(clear, h['rect']) for h in base.get('hazards', [])):
                continue
            if any(overlap(clear, r) for r in base.get('cave_world', {}).get('solid_rects', [])):
                continue
            if any(overlap(clear, g['rect']) for g in base.get('locked_gates', []) + overlay.get('locked_gates', [])):
                continue
            distance = min((math.dist((x, y), t) for t in things), default=500)
            if distance < (115 if overhead > 125 else 105):
                continue
            candidates.append((min(distance, 500), -abs(x - (px + pw / 2)), [x, y], floor['id']))
    if not candidates:
        raise ValueError(f'no clear supported landing in {room_id}')
    _, _, point, floor_id = max(candidates)
    return point, floor_id


def overlap(a, b):
    return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]


def apply(routes, bases):
    entries = []
    for rid, region, far_room, home_room, ability, title, record in ROUTES:
        overlay, base = routes['chapters'][region], bases[region]
        far, far_floor = landing(base, overlay, far_room)
        # Reserve the opening side before finding the second endpoint.
        overlay['portals'].append(dict(id=rid + '_far', kind='world_portal', position=far))
        home, home_floor = landing(base, overlay, home_room, overhead=125)
        overlay['portals'].pop()
        gate_id = rid + '_seal'
        record_id = rid + '_record' if record else ''
        name = '回声钩索' if ability == 'echo_hook' else '王冠共鸣'
        action_hint = '瞄准上方铜环施展钩索，牵开索道闩。' if ability == 'echo_hook' else '旧钟在等某种回声；在钟下施展王冠共鸣。'
        gate = dict(id=gate_id, rect=[far[0] - 18, far[1] - 120, 36, 36], color='b58a48',
                    material='bronze_bridge', required_ability=ability, required_ability_name=name,
                    requires_action=ability, permanent_action_unlock_id=gate_id, action_range=150,
                    unlock_shortcut_id=rid, from_room=far_room, to_room=far_room,
                    map_marker='ability_gate', gate_kind='action_gate', action_hint=action_hint,
                    open_message=title + '已经苏醒，回程通路永久接通。')
        if record:
            gate['unlock_item_id'] = record_id
            overlay.setdefault('inventory_catalog', {})[record_id] = dict(name=title + '旧事', category='Relics', description=record)
        overlay['locked_gates'].append(gate)
        if ability == 'echo_hook':
            # The ring is below the seal; its ray and pull never cross a solid.
            overlay['grapple_anchors'].append(dict(id=rid + '_ring', position=[far[0], far[1] - 65],
                room_id=far_room, label=title + '牵引环', required_ability=ability, test_from=far))
        for point, peer, room, suffix, target_suffix in ((far, home, far_room, '_far', '_home'), (home, far, home_room, '_home', '_far')):
            overlay['portals'].append(dict(id=rid + suffix, kind='world_portal', position=point,
                interaction_size=[90, 100], target_config_id=region, target_portal_id=rid + target_suffix,
                target_spawn=peer, room_id=room, label=title + (' · 回程' if suffix == '_far' else ' · 返访'),
                required_ability=ability, required_ability_name=name, requires_shortcut=rid,
                hint=action_hint if suffix == '_far' else '须先在另一端唤醒旧机关。', requires_demo_complete=False))
        override = next((o for o in overlay['map_room_overrides'] if o['id'] == far_room), None)
        if override is None:
            source = next(r for r in base['map_rooms'] if r['id'] == far_room)
            override = dict(id=far_room, guide=source.get('guide', ''), generated_by='ability_places')
            overlay['map_room_overrides'].append(override)
        hint = ' 可选旧路：「' + title + '」。' + action_hint
        if hint not in override.get('guide', ''):
            override['guide'] = override.get('guide', '') + hint
        entries.append(dict(id=rid, region_id=region, room_id=far_room, return_room_id=home_room,
            required_ability=ability, gate_id=gate_id, entry_portal_id=rid + '_far', return_portal_id=rid + '_home',
            base_platform_id=far_floor, return_platform_id=home_floor, record_id=record_id))
    routes['ability_routes'] = entries
