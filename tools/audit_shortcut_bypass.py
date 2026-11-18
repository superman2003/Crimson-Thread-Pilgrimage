"""W05: shortcuts never open a place the owned abilities cannot already reach.

Builds one room graph for the whole world: each region's authored room
connections (passages, one-way drops, ability gates, lever shortcuts), the
world portals between regions and inside upgrade rooms (ability, directional
latch, latch-opening side), and each ability backtrack's gated reward. For every
subset of the movement abilities it compares the rooms reachable from the new
game start with every shortcut closed against the rooms reachable when a
shortcut opens as soon as its opening side is reached. Any extra room is a
shortcut bypassing an ability gate.

Also reports, per shortcut, how many room steps it saves between its two ends
for a player who owns nothing beyond what reaching it needs.

This checks the authored graph, not physics: that each room edge is physically
walkable is covered by the route-walk suites."""
import argparse, itertools, json, sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot' / 'data'


def inside(rect, point):
    return rect[0] <= point[0] <= rect[0] + rect[2] and rect[1] <= point[1] <= rect[1] + rect[3]


def room_at(rooms, point):
    hits = [r for r in rooms if inside(r.get('play_rect') or r['layout_rect'], point)]
    return min(hits, key=lambda r: (r.get('play_rect') or r['layout_rect'])[2] * (r.get('play_rect') or r['layout_rect'])[3])['id'] if hits else None


def load_world(routes_path=DATA / 'world_routes.json', data_root=DATA):
    routes = json.loads(Path(routes_path).read_text(encoding='utf-8'))
    # edge: (src, dst, ability or '', latch needed or '', latch opened or '')
    edges, nodes, levers, errors = [], set(), {}, []
    start = None
    for region, extra in routes['chapters'].items():
        demo = json.loads((Path(data_root) / f'{region}.json').read_text(encoding='utf-8'))
        rooms = demo['map_rooms'] + extra.get('map_rooms', [])
        known = {r['id'] for r in rooms}
        nodes |= {(region, r) for r in known}
        if region == 'demo_ch01_moss_bell_court':
            start = (region, room_at(demo['map_rooms'], demo['player_start']))
        for lever in demo.get('interactives', []):
            if lever.get('shortcut_id'):
                room = room_at(demo['map_rooms'], lever['position'])
                if room is None:
                    errors.append(f"{region}:{lever['id']} lever lies in no room")
                levers[lever['shortcut_id']] = (region, room)
        for e in demo.get('connections', []):
            a, b = (region, e['from']), (region, e['to'])
            if e['from'] not in known or e['to'] not in known:
                errors.append(f"{region}: connection {e['from']}->{e['to']} names an unknown room")
                continue
            ability = e.get('required_ability', '') if e['edge_kind'] == 'ability_gate' else ''
            latch = e.get('shortcut_id', '') if e['edge_kind'] == 'unlock_shortcut' else ''
            edges.append((a, b, ability, latch, ''))
            if e.get('bidirectional'):
                edges.append((b, a, ability, latch, ''))
    for region, extra in routes['chapters'].items():
        # Action-operated return lines open at the far side only after the
        # permanent ability has been acquired. Virtual action nodes model both
        # conditions without pretending that merely owning the ability opens it.
        for gate in extra.get('locked_gates', []):
            latch = gate.get('unlock_shortcut_id', '')
            if not latch:
                continue
            room = (region, gate['from_room'])
            action = (region, gate['id'] + '#action')
            nodes.add(action)
            edges.extend([(room, action, gate['requires_action'], '', ''), (action, room, '', '', '')])
            levers[latch] = action
        for p in extra['portals']:
            target = routes['chapters'][p['target_config_id']]
            q = next(x for x in target['portals'] if x['id'] == p['target_portal_id'])
            a, b = (region, p['room_id']), (p['target_config_id'], q['room_id'])
            for node, owner in ((a, p['id']), (b, q['id'])):
                if node not in nodes:
                    errors.append(f"{owner}: portal room {node[1]} is not a map room")
            opens = p.get('unlock_shortcut_id', '') if not p.get('requires_shortcut') else ''
            edges.append((a, b, p.get('required_ability', ''), p.get('requires_shortcut', ''), opens))
    for track in routes['ability_backtracks']:
        room = (track['region_id'], track['room_id'])
        reward = (track['region_id'], track['room_id'] + '#reward')
        nodes.add(reward)
        edges.append((room, reward, track['ability_id'], '', ''))
        edges.append((reward, room, '', '', ''))
    abilities = sorted({e[2] for e in edges if e[2]})
    return {'nodes': nodes, 'edges': edges, 'levers': levers, 'start': start,
            'abilities': abilities, 'errors': errors}


def reach(world, owned, shortcuts, source=None):
    """Rooms reachable owning `owned`. With shortcuts, a latch opens once its
    lever room is reached or its opening portal is used."""
    source = source or world['start']
    opened = set()
    seen = {source}
    while True:
        queue, grew = deque(seen), False
        while queue:
            node = queue.popleft()
            for a, b, ability, latch, opens in world['edges']:
                if a != node or (ability and ability not in owned):
                    continue
                if latch and latch not in opened:
                    continue
                if shortcuts and opens and opens not in opened:
                    opened.add(opens)
                    grew = True
                if b not in seen:
                    seen.add(b)
                    queue.append(b)
        if shortcuts:
            for latch, room in world['levers'].items():
                if room in seen and latch not in opened:
                    opened.add(latch)
                    grew = True
        if not grew:
            return seen, opened


def steps(world, owned, opened, a, b):
    dist = {a: 0}
    queue = deque([a])
    while queue:
        node = queue.popleft()
        if node == b:
            return dist[node]
        for x, y, ability, latch, _ in world['edges']:
            if x == node and y not in dist and (not ability or ability in owned) and (not latch or latch in opened):
                dist[y] = dist[node] + 1
                queue.append(y)
    return None


def subsets(world):
    for size in range(len(world['abilities']) + 1):
        for owned in itertools.combinations(world['abilities'], size):
            yield set(owned)


def audit(world):
    bypasses, first_open = [], {}
    for owned in subsets(world):
        closed, _ = reach(world, owned, False)
        open_rooms, opened = reach(world, owned, True)
        for node in sorted(open_rooms - closed):
            bypasses.append({'owned': sorted(owned), 'room': f'{node[0]}:{node[1]}'})
        for latch in opened:
            first_open.setdefault(latch, (owned, opened))
    everything, _ = reach(world, set(world['abilities']), True)
    unreachable = sorted(f'{n[0]}:{n[1]}' for n in world['nodes'] - everything)
    ends = {}
    for a, b, _, latch, opens in world['edges']:
        if latch and not opens:
            ends.setdefault(latch, (a, b))
    savings = []
    for latch, (a, b) in sorted(ends.items()):
        # The least the player owns when this shortcut first opens.
        owned, opened = first_open.get(latch, (set(), set()))
        savings.append({'shortcut': latch, 'from': f'{a[0]}:{a[1]}', 'to': f'{b[0]}:{b[1]}',
                        'owned': sorted(owned), 'opened': latch in first_open,
                        'steps_closed': steps(world, owned, opened - {latch}, a, b),
                        'steps_open': steps(world, owned, opened, a, b)})
    return {'abilities': world['abilities'], 'subsets': 2 ** len(world['abilities']),
            'bypasses': bypasses, 'unreachable': unreachable,
            'savings': savings, 'errors': world['errors']}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    result = audit(load_world())
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"abilities={len(result['abilities'])} subsets={result['subsets']} "
              f"bypasses={len(result['bypasses'])} unreachable={len(result['unreachable'])} "
              f"errors={len(result['errors'])}")
        for row in result['savings']:
            print(f"  {row['shortcut']}: {row['steps_closed']} -> {row['steps_open']} room steps ({row['from']} -> {row['to']}, owning {row['owned'] or 'nothing'})")
        for line in result['errors'] + [f"bypass {b['room']} with {b['owned']}" for b in result['bypasses'][:20]] + [f'unreachable {u}' for u in result['unreachable']]:
            print('  ' + line)
    ok = not result['bypasses'] and not result['errors'] and not result['unreachable'] and all(r['opened'] for r in result['savings'])
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
