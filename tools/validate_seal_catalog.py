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

LEGACY_TRAVEL_PASSIVES = {'quiet_sole': '静靴', 'damp_knot': '防潮线结'}

CRAFTED_PASSIVES = {'tide_reel': 'craft_tide_reel', 'wax_stitch': 'craft_wax_stitch', 'ash_ring': 'craft_ash_ring', 'crown_pendant': 'craft_crown_pendant'}

def validate(data: dict) -> list[str]:
    errors = []
    def check(ok, label):
        if not ok: errors.append(label)
    check(data.get('version') == 2, 'catalog version must be 2')
    events = data.get('events', {})
    for section, expected in EXPECTED.items():
        rows = data.get(section, {})
        check(set(rows) == set(expected) | ((set(CRAFTED_PASSIVES) | set(LEGACY_TRAVEL_PASSIVES)) if section == 'passives' else set()), f'{section}: exact original, crafted and legacy reward membership')
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
    # Legacy chapter rewards unlock from the real inventory item, not a fabricated event.
    for key, name in LEGACY_TRAVEL_PASSIVES.items():
        row = data.get('passives', {}).get(key, {})
        check(row.get('name') == name and row.get('unlock_item') == key, f'{key}: original name and inventory unlock identity')
        check(row.get('family') == 'travel_accessory' and row.get('cost') == 1, f'{key}: one-capacity independent travel accessory')
        check(row.get('modifiers') == {'hazard_trigger_mult': -0.2}, f'{key}: only the promised trap trigger reduction')
        check(row.get('group') == 'trap_trigger_reduction', f'{key}: same-effect rewards cannot stack')
        check(all(row.get(field) for field in ('source', 'unlock_hint', 'risk', 'synergy')), f'{key}: readable source and equipment tradeoff')
        other_name = LEGACY_TRAVEL_PASSIVES['damp_knot' if key == 'quiet_sole' else 'quiet_sole']
        check(other_name in row.get('risk', '') and '互斥' in row.get('risk', ''), f'{key}: mutual exclusion names the other original reward')
        icon = row.get('icon', '')
        check(icon.startswith('res://') and (ROOT / 'godot' / icon.removeprefix('res://')).is_file(), f'{key}: original-style vector icon exists')
        for crest, crest_row in data.get('crests', {}).items():
            check(all(key in slot.get('compatible', []) for slot in crest_row.get('slot_layout', {}).get('travel_accessory', [])), f'{key}: compatible with {crest} travel slots')
    for key, recipe_id in CRAFTED_PASSIVES.items():
        item = data.get('passives', {}).get(key, {})
        recipe = data.get('recipes', {}).get(recipe_id, {})
        check(item.get('craft_recipe') == recipe_id and recipe.get('target') == key and recipe.get('kind') == 'passive', f'{key}: one explicit artisan crafting source')
        check(bool(recipe.get('requires_items')) and bool(recipe.get('artisan')), f'{key}: requires a proof and named artisan')
        check(item.get('cost') in (1, 2) and item.get('family') in ('combat_accessory', 'travel_accessory'), f'{key}: typed and bounded accessory cost')
        check(bool(item.get('source')) and bool(item.get('unlock_hint')) and bool(item.get('risk')), f'{key}: discoverable source and tradeoff')
        icon = item.get('icon', '')
        check(icon.startswith('res://') and (ROOT / 'godot' / icon.removeprefix('res://')).is_file(), f'{key}: native vector icon exists')
    for key, row in data.get('skills', {}).items():
        check(all(isinstance(row.get(field), (int, float)) and row[field] > 0 for field in ('windup', 'active', 'recovery', 'cooldown')), f'{key}: three timed stages and cooldown')
        check(0 <= row.get('boss_control_mult', -1) <= 1, f'{key}: explicit boss control resistance')
        check(bool(row.get('cancel_rules')) and bool(row.get('synergy')), f'{key}: cancellation and synergy documented')
        check(row.get('refund_on_interrupt') == 0, f'{key}: no free interruption refund')
    check(data.get('skills', {}).get('shockwave', {}).get('ground_only') is True, 'shockwave must require ground')
    check(data.get('skills', {}).get('needle', {}).get('pierce') == 1, 'echo needle remains single target')
    for key, row in data.get('tools', {}).items():
        check(row.get('boss_immune_control') is True, f'{key}: boss crowd-control immunity is explicit')
        # Supplies are paid at the shrine (E02); the rule text and the actual cost must agree.
        resupply = row.get('resupply', {})
        check(int(resupply.get('currency', 0)) > 0 and bool(resupply.get('materials')), f'{key}: shrine resupply costs currency and a material')
        check('免费' not in row.get('refill_rule', '') and str(resupply.get('currency')) in row.get('refill_rule', ''), f'{key}: refill text states the actual paid cost')
    # Healing is part of each seal's identity (C02/E01): no two seals heal the same way,
    # every heal is affordable from a full meter, and only a light seal heals airborne.
    crests = data.get('crests', {})
    styles = {(row.get('heal_cost'), row.get('heal_amount'), row.get('heal_duration'), bool(row.get('heal_airborne'))) for row in crests.values()}
    check(len(styles) == len(crests), 'each seal has its own heal cost/amount/duration/air rule')
    for key, row in crests.items():
        check(0 < row.get('heal_cost', 0) <= row.get('max_energy', 0), f'{key}: one heal fits in a full meter')
        check(1 <= row.get('heal_amount', 0) <= 2 and 0.3 <= row.get('heal_duration', 0) <= 1.5, f'{key}: heal amount and channel time stay in a readable range')
        check(0.0 <= row.get('heal_interrupt_loss_ratio', -1) <= 1.0, f'{key}: interrupted heal loss is a ratio')
        check(row.get('heal_cost', 0) / row.get('heal_amount', 1) >= 40, f'{key}: healing never costs under 40 thread per mask')
        check(str(row.get('heal_cost')) in row.get('heal_effect', '') and str(row.get('heal_amount')) in row.get('heal_effect', ''), f'{key}: heal text names the real cost and amount')
        if row.get('heal_airborne'):
            check(row.get('heal_duration', 9) <= 0.6 and row.get('heal_amount') == 1, f'{key}: airborne healing is reserved for a short one-mask stitch')
    for key, row in data.get('passives', {}).items():
        forbidden = {'jump_height', 'jump_velocity', 'dash_unlocked', 'double_jump_unlocked', 'thread_grapple_unlocked'}
        check(not (set(row.get('modifiers', {})) & forbidden), f'{key}: does not alter permanent exploration gates')
    for key, row in data.get('recipes', {}).items():
        check(row.get('kind') != 'refill', f'{key}: tool supplies are not sold as recipes')
        targets = {'skill_branch': data.get('skills', {}), 'tool_capacity': data.get('tools', {}), 'slot_part': {'travel_accessory': True}, 'passive': data.get('passives', {})}
        check(row.get('kind') in targets, f'{key}: recipe kind is 校习 or an artisan craft')
        check(row.get('target') in targets.get(row.get('kind'), {}), f'{key}: recipe target exists')
        if row.get('kind') == 'tool_capacity':
            check(row.get('amount') == 1, f'{key}: a capacity upgrade adds exactly one charge')
    return errors

def main() -> int:
    data = json.loads((ROOT / 'godot/data/build_catalog.json').read_text(encoding='utf-8'))
    errors = validate(data)
    for error in errors: print('FAIL: ' + error)
    print(f'SEAL_CATALOG {"FAIL" if errors else "PASS"}: 3 seals, 6 skills, 4 tools, {len(data.get("passives", {}))} adornments; errors={len(errors)}')
    return bool(errors)

if __name__ == '__main__':
    raise SystemExit(main())
