#!/usr/bin/env python3
"""Check room identities, navigation references and repeated room silhouettes."""
from __future__ import annotations
import argparse
from collections import defaultdict
import json
from pathlib import Path
from audit_platform_geometry import ROOT, effective_config, finite_vector, selected_configs

def audit(config):
    errors, warnings, checks = [], [], 0
    def check(condition, label):
        nonlocal checks
        checks += 1
        if not condition:
            errors.append(f"{config.get('id', '?')}: {label}")
    rooms = config.get('map_rooms', [])
    ids = [v.get('id') for v in rooms]
    names = [v.get('name') for v in rooms]
    check(bool(rooms), 'no map rooms')
    check(all(ids) and len(ids) == len(set(ids)), 'missing or duplicate room IDs')
    check(all(names) and len(names) == len(set(names)), 'missing or duplicate room names')
    silhouettes = defaultdict(list)
    for room in rooms:
        r = room.get('layout_rect')
        valid = finite_vector(r, 4) and r[2] > 0 and r[3] > 0
        check(valid, f"{room.get('id')}: invalid 2D room outline")
        if not valid:
            continue
        x, y, w, h = r
        platforms = [p for p in config.get('platforms', []) if finite_vector(p.get('rect'), 4) and x <= p['rect'][0] + p['rect'][2] / 2 <= x + w and y <= p['rect'][1] <= y + h]
        check(bool(platforms), f"{room['id']}: room outline contains no landing platform")
        # Relative geometry ignores art and identifiers. Repeated templates are
        # reported separately: a shared silhouette alone is not a softlock.
        fingerprint = tuple(sorted(tuple(round(v / 8) for v in (p['rect'][0] - x, p['rect'][1] - y, p['rect'][2], p['rect'][3])) for p in platforms))
        if fingerprint:
            silhouettes[fingerprint].append(room['id'])
    for group in silhouettes.values():
        if len(group) >= 3:
            warnings.append({'repeated_collision_silhouette': group})
    for link in config.get('connections', []):
        check(link.get('from') in ids and link.get('to') in ids, f"connection references missing room: {link.get('id')}")
        check(link.get('from') != link.get('to') or (link.get('type') == 'ability_gate' and bool(link.get('required_ability'))), f"unqualified self connection: {link.get('id')}")
    return checks, errors, warnings

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=('active', 'generated', 'all'), default='active')
    parser.add_argument('--data-root', type=Path, default=ROOT / 'godot/data')
    parser.add_argument('--strict', action='store_true')
    args = parser.parse_args()
    paths = selected_configs(args.data_root, args.scope)
    errors, warnings, checks = [], [], 0
    expected = 12 if args.scope == 'all' else 6
    if not paths or (args.strict and len(paths) != expected):
        errors.append(f'{args.scope}: expected {expected} maps, found {len(paths)}')
    for path in paths:
        try:
            count, problems, repeats = audit(effective_config(path, args.data_root))
            checks += count
            errors.extend(problems)
            warnings += [{'file': path.name, **v} for v in repeats]
        except (ValueError, KeyError, TypeError) as exc:
            errors.append(f'{path.name}: malformed map data: {exc}')
    print(json.dumps({'suite': 'map_uniqueness', 'scope': args.scope, 'files': len(paths), 'checks': checks, 'errors': errors, 'warnings': warnings, 'limitation': 'Unique IDs/outlines do not establish visual identity; repeated collision shapes require design review.'}, ensure_ascii=False, indent=2))
    return 1 if errors else 0

if __name__ == '__main__':
    raise SystemExit(main())
