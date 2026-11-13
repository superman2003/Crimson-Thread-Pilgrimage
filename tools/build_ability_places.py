#!/usr/bin/env python3
"""A01: author the optional ability places outside the workshops.

Writes `ability_ledges` and the platforms, bell plates, hook rings, rewards and
room hints they need into godot/data/world_routes.json. Re-running replaces
only objects with the `a01_` prefix (and the hints this script appended), so
it is safe after tools/build_world_upgrade.py. Geometry is proven by
tools/audit_ability_ledges.py; real input by the Godot suite ability_ledges.
"""
import json
from pathlib import Path

import audit_ability_ledges as A

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'godot/data/world_routes.json'
PREFIX = 'a01_'
NAMES = {'double_thread_jump': '双线跃', 'echo_hook': '回声钩索', 'crown_resonance': '王冠共鸣'}
CH01, CH02, CH03 = 'demo_ch01_moss_bell_court', 'demo_ch02_rain_foundry_canal', 'demo_ch03_saltwhite_archive'

# (id, kind, ability, region, room, base floor, shelf rect, material, amount, label, room hint)
PLACES = [
    ('a01_atrium_high_shelf', 'ledge', 'double_thread_jump', CH03, 'atrium_shaft', 'f2_gap_ledge',
     [2455, 1594, 100, 22], 'salt_crystal_shard', 5, '高架盐晶',
     '西侧二层上方还有一层孤架，单跳够不着。'),
    ('a01_court_jump_niche', 'niche', 'double_thread_jump', CH01, 'court_hub', 'hub_floor_e',
     [3310, 3707, 120, 22], 'moss_chitin', 5, '钟庭壁龛苔壳',
     '东岸地面上方嵌着一口壁龛，一跳差半身。'),
    ('a01_pump_hook_niche', 'niche', 'echo_hook', CH02, 'pump_atrium', 'hub_floor_e',
     [3420, 2990, 120, 22], 'wet_chitin', 6, '泵房吊龛湿壳',
     '东岸高处的吊龛里垂着一枚铜环，跳不上去。'),
    ('a01_undercanal_bell_niche', 'niche', 'crown_resonance', CH02, 'undercanal', 'uc_end',
     [1760, 4646, 120, 16], 'wet_chitin', 6, '暗渠钟板后的湿壳',
     '走道尽头头顶封着一块旧钟板，敲不响，像在等某种回声。'),
    ('a01_atrium_bell_niche', 'niche', 'crown_resonance', CH03, 'atrium_shaft', 'atrium_base_floor',
     [2520, 2486, 120, 16], 'salt_crystal_shard', 6, '书塔钟板后的盐晶',
     '塔底头顶封着一块旧钟板，敲不响，像在等某种回声。'),
]
COLORS = {'double_thread_jump': '4c4b3e', 'echo_hook': '4c4b3e', 'crown_resonance': '385357'}


def build():
    routes = json.loads(PATH.read_text(encoding='utf-8'))
    chapters = routes['chapters']
    hints = {p[10] for p in PLACES}
    for overlay in chapters.values():
        for key in ('platforms', 'collectibles', 'locked_gates', 'grapple_anchors'):
            overlay[key] = [v for v in overlay.get(key, []) if not v.get('id', '').startswith(PREFIX)]
        kept = []
        for override in overlay.get('map_room_overrides', []):
            if override.get('generated_by') == 'ability_places':
                continue
            for hint in hints:
                override['guide'] = override.get('guide', '').replace(' ' + hint, '')
            kept.append(override)
        overlay['map_room_overrides'] = kept
    entries = []
    for pid, kind, ability, region, room, base, rect, material, amount, label, hint in PLACES:
        overlay = chapters[region]
        base_config = json.loads((A.DATA / f'{region}.json').read_text(encoding='utf-8'))
        base_rect = next(p['rect'] for p in base_config['platforms'] if p['id'] == base)
        role = 'one_way'
        overlay['platforms'].append(dict(id=pid, rect=rect, collision_role=role, color=COLORS[ability],
                                         material='bronze_bridge', route_role='branch'))
        reward_id = 'a01_col_atrium_high_shelf' if pid == 'a01_atrium_high_shelf' else pid + '_reward'
        entry = dict(id=pid, kind=kind, region_id=region, room_id=room, required_ability=ability,
                     base_platform_id=base, platform_id=pid, reward_id=reward_id)
        if kind == 'niche':
            shell, gate = A.niche_shell(rect, ability)
            for part, part_rect in shell.items():
                overlay['platforms'].append(dict(id=f'{pid}_{part}', rect=part_rect,
                    collision_role='ceiling' if part == 'roof' else 'wall', color=COLORS[ability],
                    material='bronze_bridge', route_role='branch'))
            if gate:
                gate_id = pid + '_bell'
                overlay['locked_gates'].append(dict(id=gate_id, rect=gate, color='b58a48', material='bronze_bridge',
                    required_ability=ability, required_ability_name=NAMES[ability], requires_action=ability,
                    permanent_action_unlock_id=gate_id, action_range=150, from_room=room, to_room=room,
                    map_marker='ability_gate', gate_kind='action_gate',
                    action_hint='站在钟板正下方按 R，共鸣震开封板。',
                    open_message='旧钟板应和共鸣松开了，上面的壁龛永久敞开。'))
                entry['gate_id'] = gate_id
            if ability == 'echo_hook':
                position = A.ring_for(rect)
                overlay['grapple_anchors'].append(dict(id=pid + '_ring', position=position, room_id=room,
                    label='吊龛铜环', required_ability='echo_hook',
                    test_from=[position[0], base_rect[1] - 40]))
                entry['ring_id'] = pid + '_ring'
        overlay['collectibles'].append(dict(id=reward_id, kind='item', item_id=material, amount=amount,
            position=[rect[0] + rect[2] / 2, rect[1] - 70], room_id=room, platform_id=pid,
            reward_role='optional_exploration', label=label,
            note=f'{NAMES[ability]}才能取到的可选探索奖励。'))
        override = next((o for o in overlay['map_room_overrides'] if o['id'] == room), None)
        if override is None:
            source = next(r for r in base_config['map_rooms'] if r['id'] == room)
            override = dict(id=room, guide=source.get('guide', ''), generated_by='ability_places')
            overlay['map_room_overrides'].append(override)
        if hint not in override['guide']:
            override['guide'] = override.get('guide', '') + ' ' + hint
        entries.append(entry)
    routes['ability_ledges'] = entries
    PATH.write_text(json.dumps(routes, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    counts = {a: sum(e['required_ability'] == a for e in entries) for a in NAMES}
    print('ABILITY_PLACES authored', len(entries), counts)


if __name__ == '__main__':
    build()
