#!/usr/bin/env python3
"""Audit collision data without confusing 2D rooms with legacy X ranges.

This checks stored rectangles and recovery markers, not jump feasibility or a
human playthrough. Strict mode also requires six campaign files in each scope.
"""
from __future__ import annotations
import argparse
import copy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER_WIDTH, PLAYER_HEIGHT = 34, 84

def finite_vector(value, length):
    return isinstance(value, list) and len(value) == length and all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in value)

def selected_configs(data_root, scope):
    paths = []
    if scope in ('active', 'all'):
        paths += sorted(p for p in data_root.glob('demo_ch*.json') if 'boss_trial' not in p.name)
    if scope in ('generated', 'all'):
        paths += sorted((data_root / 'generated').glob('*.generated.json'))
    return paths

def effective_config(path, data_root):
    config = json.loads(path.read_text(encoding='utf-8-sig'))
    overlay_path = data_root / 'world_routes.json'
    if path.parent == data_root and overlay_path.exists():
        overlay = json.loads(overlay_path.read_text(encoding='utf-8-sig')).get('chapters', {}).get(config['id'], {})
        config.get('world', {}).update(copy.deepcopy(overlay.get('world_overrides', {})))
        for key in ('platforms', 'terrain', 'locked_gates', 'collectibles', 'map_rooms', 'save_points'):
            items = config.setdefault(key, [])
            by_id = {v['id']: v for v in items}
            override_key = 'terrain_overrides' if key == 'terrain' else key[:-1] + '_overrides'
            for override in overlay.get(override_key, []):
                if override['id'] not in by_id:
                    raise ValueError(f"{config['id']}: override targets missing {key}: {override['id']}")
                by_id[override['id']].update(copy.deepcopy(override))
            items.extend(copy.deepcopy(overlay.get(key, [])))
    return config

def audit(config):
    errors, checks = [], 0
    def check(condition, label):
        nonlocal checks
        checks += 1
        if not condition:
            errors.append(f"{config.get('id', '?')}: {label}")
    platforms = config.get('platforms', [])
    check(bool(platforms), 'no collision platforms')
    ids = [p.get('id') for p in platforms]
    check(all(ids) and len(ids) == len(set(ids)), 'missing or duplicate platform IDs')
    valid = []
    for p in platforms:
        r = p.get('rect')
        okay = finite_vector(r, 4) and r[2] > 0 and r[3] > 0
        check(okay, f"{p.get('id')}: invalid collision rectangle")
        if okay:
            valid.append(p)
            if p.get('safe_landing'):
                check(r[2] >= PLAYER_WIDTH, f"{p['id']}: safe landing narrower than player")
                check(p.get('gameplay_clearance', PLAYER_HEIGHT) >= PLAYER_HEIGHT, f"{p['id']}: stated headroom smaller than player")
    for field in ('player_start', 'boss_checkpoint'):
        check(finite_vector(config.get(field), 2), f'{field}: missing or non-finite recovery point')
    markers = [(field, config.get(field)) for field in ('player_start', 'boss_checkpoint')]
    markers += [(p.get('id', 'save_point'), p.get('position')) for p in config.get('save_points', [])]
    for label, point in markers:
        if not finite_vector(point, 2):
            check(False, f'{label}: invalid recovery point')
            continue
        x, y = point
        floors = [p for p in valid if p.get('collision_role') != 'ceiling']
        check(any(px + 17 <= x <= px + w - 17 and 0 <= py - y <= 180 for px, py, w, h in (p['rect'] for p in floors)), f'{label}: no landing within 180px below recovery point')
        blockers = [p['id'] for p in valid if x + 17 > p['rect'][0] and x - 17 < p['rect'][0] + p['rect'][2] and y > p['rect'][1] + .1 and y - PLAYER_HEIGHT < p['rect'][1] + p['rect'][3]]
        check(not blockers, f'{label}: player collider overlaps {blockers}')
    return checks, errors

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=('active', 'generated', 'all'), default='active')
    parser.add_argument('--data-root', type=Path, default=ROOT / 'godot/data')
    parser.add_argument('--strict', action='store_true')
    args = parser.parse_args()
    paths = selected_configs(args.data_root, args.scope)
    errors, checks = [], 0
    expected = 12 if args.scope == 'all' else 6
    if not paths or (args.strict and len(paths) != expected):
        errors.append(f'{args.scope}: expected {expected} campaign maps, found {len(paths)}')
    for path in paths:
        try:
            count, problems = audit(effective_config(path, args.data_root))
            checks += count
            errors.extend(problems)
        except (ValueError, KeyError, TypeError) as exc:
            errors.append(f'{path.name}: malformed map data: {exc}')
    print(json.dumps({'suite': 'platform_geometry', 'scope': args.scope, 'files': len(paths), 'checks': checks, 'errors': errors, 'limitation': 'Collision/recovery data audit; does not certify physical traversal or player experience.'}, ensure_ascii=False, indent=2))
    return 1 if errors else 0

if __name__ == '__main__':
    raise SystemExit(main())
