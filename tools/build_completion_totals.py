#!/usr/bin/env python3
"""Author godot/data/completion_totals.json: the rooms and pickups a journey can find.

Save-slot completion divides by these lists. They come from the six region
files plus the generated world_routes overlay, so run this after either changes
(`--check` fails when the file is stale; it is part of test:campaign).
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot/data'
PATH = DATA / 'completion_totals.json'


def build(data=DATA):
    routes = json.loads((data / 'world_routes.json').read_text(encoding='utf-8'))
    regions = {}
    for region, overlay in routes['chapters'].items():
        base = json.loads((data / f'{region}.json').read_text(encoding='utf-8'))
        rooms = [r['id'] for key in (base, overlay) for r in key.get('map_rooms', [])]
        pickups = [c['id'] for key in (base, overlay) for c in key.get('collectibles', [])]
        if len(set(rooms)) != len(rooms) or len(set(pickups)) != len(pickups):
            raise ValueError(f'duplicate room or pickup id in {region}')
        regions[region] = dict(rooms=sorted(rooms), pickups=sorted(pickups))
    return dict(schema=1, regions=regions)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    text = json.dumps(build(), ensure_ascii=False, indent=1) + '\n'
    if args.check:
        if not PATH.exists() or PATH.read_text(encoding='utf-8') != text:
            print('COMPLETION_TOTALS stale: run tools/build_completion_totals.py')
            return 1
    else:
        PATH.write_text(text, encoding='utf-8', newline='\n')
    totals = json.loads(text)['regions']
    print('COMPLETION_TOTALS OK regions=%d rooms=%d pickups=%d' % (
        len(totals), sum(len(r['rooms']) for r in totals.values()), sum(len(r['pickups']) for r in totals.values())))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
