#!/usr/bin/env python3
"""Additional structural checks for generated world upgrades, not a playthrough."""
import json
from collections import Counter, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate():
    routes = json.loads((ROOT / 'godot/data/world_routes.json').read_text())
    chapters = routes['chapters']
    bases = {r: json.loads((ROOT / f'godot/data/{r}.json').read_text()) for r in chapters}
    errors, checks = [], 0

    def check(value, label):
        nonlocal checks
        checks += 1
        if not value:
            errors.append(label)

    counts = Counter(v['ability_id'] for v in routes['ability_backtracks'] if v.get('role') == 'backtrack')
    check(len(counts) == 8 and all(v >= 2 for v in counts.values()), 'eight abilities need two real return targets')
    ch06 = 'demo_ch06_silent_crown_core'
    check(len(bases[ch06]['map_rooms']) == 15, 'sixth region retains its 15 authored main rooms')
    check(all(len(room.get('camera_bounds', [])) == 4 for room in bases[ch06]['map_rooms']), 'all 15 sixth-region main rooms have independent camera bounds')
    check(len({tuple(room.get('camera_bounds', [])) for room in bases[ch06]['map_rooms']}) == 15, 'sixth-region main-room camera bounds are individually authored')
    workshops = [room for region in chapters.values() for room in region.get('map_rooms', [])]
    check(len(workshops) == 20, 'world upgrade authors 20 action workshop rooms')
    check(all(len(room.get('camera_bounds', [])) == 4 for room in workshops), 'all workshops have independent camera bounds')
    check(len({tuple(room.get('camera_bounds', [])) for room in workshops}) == 20, 'workshop camera bounds are individually authored')
    check(all(len(room.get('movement_combo', [])) >= 2 and len(room.get('entry_point', [])) == 2
              and len(room.get('action_point', [])) == 2 and len(room.get('reward_landing', [])) == 2
              for room in workshops), 'all workshops declare action-specific movement and production landmarks')
    gate_offsets = {}
    for target in routes['ability_backtracks']:
        if target.get('role') != 'backtrack':
            continue
        gate = next((g for g in chapters[target['region_id']]['locked_gates'] if g['id'] == target['gate_id']), {})
        room = next((r for r in chapters[target['region_id']]['map_rooms'] if r['id'] == target['room_id']), {})
        origin_x = room.get('layout_rect', [0])[0]
        gate_offsets.setdefault(target['ability_id'], set()).add(gate.get('rect', [0])[0] - origin_x)
    check(len({min(v) for v in gate_offsets.values() if v}) == 8, 'eight ability gate offsets differ')
    combo_by_action = {}
    for target in routes['ability_backtracks']:
        room = next((r for r in chapters[target['region_id']]['map_rooms'] if r['id'] == target['room_id']), {})
        combo_by_action.setdefault(target['ability_id'], set()).add(tuple(room.get('movement_combo', [])))
    check(len(combo_by_action) == 8 and all(len(combos) == 1 for combos in combo_by_action.values())
          and len({next(iter(combos)) for combos in combo_by_action.values() if combos}) == 8,
          'each ability uses its own consistent movement combo')
    for reg, overlay in chapters.items():
        all_ids = [v['id'] for key in ['collectibles', 'platforms', 'locked_gates', 'map_rooms', 'portals'] for v in overlay.get(key, [])]
        check(len(all_ids) == len(set(all_ids)), reg + ': overlay IDs must be unique')
        bounds = dict(bases[reg]['world'], **overlay.get('world_overrides', {}))
        for room in overlay.get('map_rooms', []):
            x, y, w, h = room['layout_rect']
            check(x >= 0 and y >= 0 and x + w <= bounds['width'] and y + h <= bounds['height'], room['id'] + ': workshop camera bounds')
            if room.get('id', '').startswith('upgrade_'):
                cx, cy, cw, ch = room.get('camera_bounds', [0, 0, 0, 0])
                check(cx >= 0 and cy >= 0 and cw > 0 and ch > 0 and cx + cw <= bounds['width'] and cy + ch <= bounds['height'], room['id'] + ': camera bounds fit world')
        for portal in overlay['portals']:
            if not portal['id'].startswith('upgrade_'):
                continue
            x, y = portal['position']
            for sx, sy, sw, sh in bases[reg].get('cave_world', {}).get('solid_rects', []):
                check(not (x + 17 > sx and x - 17 < sx + sw and y > sy and y - 84 < sy + sh), portal['id'] + ': entrance intersects cave mass')
            for hazard in bases[reg].get('hazards', []):
                if 'rect' in hazard:
                    hx, hy, hw, hh = hazard['rect']
                    check(not (x + 28 > hx and x - 28 < hx + hw and y > hy and y - 84 < hy + hh), portal['id'] + ': entrance intersects hazard')
    for target in routes['ability_backtracks']:
        overlay = chapters[target['region_id']]
        gate = next(v for v in overlay['locked_gates'] if v['id'] == target['gate_id'])
        check(gate['requires_action'] == target['ability_id'], gate['id'] + ': action must match ability')
        check(gate['permanent_action_unlock_id'] == gate['id'], gate['id'] + ': save unlock ID')
        rewards = [v for v in overlay['collectibles'] if v['id'] in target['reward_ids']]
        check(len(rewards) == 2 and {v['kind'] for v in rewards} == {'item', 'currency'}, gate['id'] + ': real evidence and currency rewards')
        platforms = {v['id']: v['rect'] for v in overlay['platforms']}
        room_id = target['room_id']
        roof = platforms[room_id + '_roof']
        foundation = platforms[room_id + '_foundation']
        wall = platforms[room_id + '_backwall']
        gx, gy, gw, gh = gate['rect']
        check(wall[1] <= roof[1] + roof[3] and wall[1] + wall[3] >= foundation[1] + foundation[3], gate['id'] + ': no exterior back opening')
        if gate['requires_action'] == 'thorn_downstrike':
            approach = platforms[room_id + '_approach']
            left_wall = platforms[room_id + '_well_wall']
            check(gx <= approach[0] + approach[2] and gx + gw >= wall[0] and gy + gh >= approach[1], gate['id'] + ': floor seal covers well mouth')
            check(left_wall[1] <= gy + gh and left_wall[1] + left_wall[3] >= foundation[1], gate['id'] + ': no side opening below floor seal')
            peers = [p for p in overlay['portals'] if p['id'].startswith(room_id + '_well_lift')]
            check(len(peers) == 2 and sum(bool(p.get('requires_shortcut')) for p in peers) == 1, gate['id'] + ': floor seal safe far-side return lift')
        else:
            check(gy <= roof[1] + roof[3] and gy + gh >= foundation[1] + foundation[3] - 10, gate['id'] + ': sealed against jumps, wall climb and downward bypass')

    # Search the region progression graph with ability pickup/shortcut state. This
    # proves no abstract acquisition cycle, not every physical room's reachability.
    start = next(r for r in chapters if 'ch01' in r)
    acquired_at = {r: set() for r in chapters}
    for r, base in bases.items():
        collected = list(base.get('collectibles', [])) + chapters[r].get('collectibles', [])
        for item in collected:
            if item.get('item_id') in counts:
                acquired_at[r].add(item['item_id'])
    queue = deque([(start, frozenset(), frozenset(), (start,))])
    visited, completion_orders = set(), set()
    while queue:
        region, abilities, shortcuts, order = queue.popleft()
        abilities = frozenset(set(abilities) | acquired_at[region])
        key = (region, abilities, shortcuts, frozenset(order))
        if key in visited:
            continue
        visited.add(key)
        if len(set(order)) == 6:
            completion_orders.add(tuple(dict.fromkeys(order)))
        for p in chapters[region]['portals']:
            if p['target_config_id'] == region:
                continue
            if p.get('requires_shortcut') and p['requires_shortcut'] not in shortcuts:
                continue
            if p.get('required_ability') and p['required_ability'] not in abilities:
                continue
            unlocked = shortcuts | {p['unlock_shortcut_id']} if p.get('unlock_shortcut_id') else shortcuts
            queue.append((p['target_config_id'], abilities, frozenset(unlocked), order + (p['target_config_id'],)))
    check(bool(completion_orders), 'all six regions reachable without abstract acquisition cycle')
    check(any(v.index(next(r for r in chapters if 'ch04' in r)) < v.index(next(r for r in chapters if 'ch05' in r)) for v in completion_orders), 'greenhouse-first order')
    check(any(v.index(next(r for r in chapters if 'ch05' in r)) < v.index(next(r for r in chapters if 'ch04' in r)) for v in completion_orders), 'obsidian-first order')
    print(json.dumps(dict(checks=checks, errors=errors, ability_return_counts=counts,
        valid_first_visit_orders=[list(v) for v in sorted(completion_orders)],
        limitation='Static overlay structure, paired landing geometry, cave/hazard clearance and abstract progression graph. Physical route controls/combat require Godot suites.'), ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(validate())
