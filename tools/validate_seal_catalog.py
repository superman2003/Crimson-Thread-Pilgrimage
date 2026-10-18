#!/usr/bin/env python3
"""Validate the first seal batch's data contract without loading gameplay."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    'crests': {'crimson': ('缝名契印', 4), 'bell': ('司铸契印', 5), 'salt': ('校录契印', 3)},
    'skills': {'cleave': ('绯线穿刺', 25), 'needle': ('回声针', 20), 'shockwave': ('钟鸣震波', 35), 'ward': ('守钟架势', 20), 'snare': ('盐印缚线', 30), 'crosscut': ('断弦回斩', 30)},
    'tools': {'shard': ('铜铃投罐', 3), 'mine': ('绊线钉', 2), 'fog': ('盐雾瓶', 2), 'lure': ('回响诱铃', 2)},
    'passives': {'reflux': ('工匠线轴', 2), 'spur': ('盐页书签', 2), 'shell': ('铜背扣', 2), 'stride': ('巡礼鞋结', 1), 'mender': ('静钟碎片', 1), 'needlecase': ('余声针匣', 2), 'compass': ('钟骨罗盘', 1)},
}

def validate(data: dict) -> list[str]:
    errors = []
    def check(ok, label):
        if not ok: errors.append(label)
    check(data.get('version') == 2, 'catalog version must be 2')
    events = data.get('events', {})
    for section, expected in EXPECTED.items():
        rows = data.get(section, {})
        check(set(rows) == set(expected), f'{section}: exact first-batch membership')
        for key, (name, number) in expected.items():
            row = rows.get(key, {})
            check(row.get('name') == name, f'{section}/{key}: display name')
            field = {'crests': 'slots', 'skills': 'energy_cost', 'tools': 'capacity', 'passives': 'cost'}[section]
            check(row.get(field) == number, f'{section}/{key}: initial {field}')
            check(bool(row.get('description')), f'{section}/{key}: readable description')
            check(bool(row.get('unlock_flag')), f'{section}/{key}: explicit event unlock')
            if section != 'crests':
                check(bool(row.get('unlock_item')), f'{section}/{key}: relic source')
                icon = row.get('icon', '')
                check(icon.startswith('res://') and (ROOT / 'godot' / icon.removeprefix('res://')).is_file(), f'{section}/{key}: icon exists')
                check(any(key in event.get(section, []) for event in events.values()), f'{section}/{key}: reachable event registry')
    for key, row in data.get('skills', {}).items():
        check(all(isinstance(row.get(field), (int, float)) and row[field] > 0 for field in ('windup', 'active', 'recovery', 'cooldown')), f'{key}: three timed stages and cooldown')
        check(0 <= row.get('boss_control_mult', -1) <= 1, f'{key}: explicit boss control resistance')
        check(bool(row.get('cancel_rules')) and bool(row.get('synergy')), f'{key}: cancellation and synergy documented')
        check(row.get('refund_on_interrupt') == 0, f'{key}: no free interruption refund')
    check(data.get('skills', {}).get('shockwave', {}).get('ground_only') is True, 'shockwave must require ground')
    check(data.get('skills', {}).get('needle', {}).get('pierce') == 1, 'echo needle remains single target')
    for key, row in data.get('tools', {}).items():
        check(row.get('boss_immune_control') is True, f'{key}: boss crowd-control immunity is explicit')
        check('免费' in row.get('refill_rule', ''), f'{key}: free shrine refill is readable')
    for key, row in data.get('passives', {}).items():
        forbidden = {'jump_height', 'jump_velocity', 'dash_unlocked', 'double_jump_unlocked', 'thread_grapple_unlocked'}
        check(not (set(row.get('modifiers', {})) & forbidden), f'{key}: does not alter permanent exploration gates')
    for key, row in data.get('recipes', {}).items():
        check(row.get('kind') != 'refill', f'{key}: tool supplies are not sold as recipes')
        check(row.get('target') in data.get('skills', {}), f'{key}: recipe target exists')
    return errors

def main() -> int:
    data = json.loads((ROOT / 'godot/data/build_catalog.json').read_text())
    errors = validate(data)
    for error in errors: print('FAIL: ' + error)
    print(f'SEAL_CATALOG {"FAIL" if errors else "PASS"}: 3 seals, 6 skills, 4 tools, 7 adornments; errors={len(errors)}')
    return bool(errors)

if __name__ == '__main__':
    raise SystemExit(main())
