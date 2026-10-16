#!/usr/bin/env python3
"""Check registered physical links, endpoints and walkable slopes; not playthrough evidence."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def validate(data, routes, layout):
    errors = []
    ids, mouths = set(), set()
    graph = {region: set() for region in layout['regions']}
    for link in data.get('passages', []):
        name = link.get('id', '')
        if not name or name in ids: errors.append('missing or duplicate passage id')
        ids.add(name)
        points = []
        for side in ('a', 'b'):
            end = link.get(side, {})
            region, portal_id = end.get('region'), end.get('portal')
            key = (region, portal_id)
            if key in mouths: errors.append(f'{name}: duplicate physical mouth')
            mouths.add(key)
            chapter = routes.get('chapters', {}).get(region, {})
            portal = next((p for p in chapter.get('portals', []) if p['id'] == portal_id), None)
            other = link.get('b' if side == 'a' else 'a', {})
            if portal is None or region not in graph:
                errors.append(f'{name}: missing endpoint'); continue
            if portal.get('target_config_id') != other.get('region') or portal.get('target_portal_id') != other.get('portal'):
                errors.append(f'{name}: physical link differs from authored portal pair')
            point = portal.get('position', [])
            if len(point) != 2 or any(not isinstance(n, (int, float)) or isinstance(n, bool) or not math.isfinite(n) for n in point):
                errors.append(f'{name}: invalid endpoint position'); continue
            origin = layout['regions'][region]['origin']
            points.append([a+b for a,b in zip(origin, point)])
            if other.get('region') in graph: graph[region].add(other['region'])
        if len(points) == 2:
            dx, dy = (points[1][i]-points[0][i] for i in (0,1))
            if abs(dx) < 100 or abs(dy) >= abs(dx): errors.append(f'{name}: slope exceeds player walkable floor angle')
    visited, pending = set(), [next(iter(graph))]
    while pending:
        region = pending.pop()
        if region in visited: continue
        visited.add(region); pending.extend(graph[region]-visited)
    if len(visited) != 6: errors.append('physical network does not connect all six regions')
    return errors

if __name__ == '__main__':
    errors = validate(*(json.loads((ROOT / 'godot/data' / file).read_text()) for file in ('world_passages.json', 'world_routes.json', 'world_layout.json')))
    for error in errors: print('FAIL:', error)
    print(f'WORLD_PASSAGE_CONTRACT failures={len(errors)}')
    raise SystemExit(bool(errors))
