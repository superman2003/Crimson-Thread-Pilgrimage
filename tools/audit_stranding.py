"""W04: no reachable room strands the player away from every shrine.

Uses the world room graph of audit_shortcut_bypass (region connections, one-way
drops, ability gates, lever shortcuts, world portals and workshop rewards).
A player who owns exactly the abilities T can only be where a route from the
new game start reaches without passing the pickup room of any ability outside
T (walking through it would have picked that ability up). For every such T
that can actually be collected in some order, and every room R reachable that
way, the player must be able to get back to a shrine (save point) from R,
picking up abilities found on the way out. A room that fails is a soft lock:
death would be the only way out, and only if something there can kill.

This checks the authored graph, not physics; where the graph is stricter than
the terrain (an unrecorded way out) the graph should be corrected."""
import argparse, itertools, json, sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_shortcut_bypass as GRAPH

DATA = GRAPH.DATA


def landmarks(world, routes_path=DATA / 'world_routes.json', data_root=DATA):
    """Pickup room of each movement ability and every shrine room."""
    routes = json.loads(Path(routes_path).read_text(encoding='utf-8'))
    pickups, shrines, errors = {}, set(), []
    for region, extra in routes['chapters'].items():
        demo = json.loads((Path(data_root) / f'{region}.json').read_text(encoding='utf-8'))
        rooms = demo['map_rooms'] + extra.get('map_rooms', [])
        for item in demo.get('collectibles', []) + extra.get('collectibles', []):
            ability = item.get('item_id') or item.get('item')
            if ability in world['abilities'] and ability not in pickups:
                pickups[ability] = (region, GRAPH.room_at(rooms, item['position']))
        for point in demo.get('save_points', []) + extra.get('save_points', []):
            room = GRAPH.room_at(rooms, point['position'])
            if room is None:
                errors.append(f"{region}:{point.get('id')} shrine lies in no room")
            shrines.add((region, room))
    for ability in world['abilities']:
        if ability not in pickups:
            errors.append(f'{ability} has no pickup in any region')
    return pickups, shrines, errors


def outgoing(world):
    index = world.get('_out')
    if index is None:
        index = {}
        for edge in world['edges']:
            index.setdefault(edge[0], []).append(edge)
        world['_out'] = index
    return index


def spread(world, source, owned, opened, blocked=frozenset()):
    """Rooms reachable from source owning `owned`; latches open as their lever
    room is reached or their opening portal is used. `blocked` rooms are never
    entered."""
    out = outgoing(world)
    opened = set(opened)
    seen = {source}
    while True:
        queue, grew = deque(seen), False
        while queue:
            node = queue.popleft()
            for a, b, ability, latch, opens in out.get(node, ()):
                if b in blocked or (ability and ability not in owned) or (latch and latch not in opened):
                    continue
                if opens and opens not in opened:
                    opened.add(opens)
                    grew = True
                if b not in seen:
                    seen.add(b)
                    queue.append(b)
        for latch, room in world['levers'].items():
            if room in seen and latch not in opened:
                opened.add(latch)
                grew = True
        if not grew:
            return seen, opened


def holding(world, pickups, target):
    """Rooms where a player owning exactly `target` can stand, or None if
    `target` cannot be collected without also passing another pickup."""
    blocked = frozenset(room for ability, room in pickups.items() if ability not in target)
    owned, opened = set(), set()
    while True:
        seen, opened = spread(world, world['start'], owned, opened, blocked)
        found = {a for a in target if a not in owned and pickups[a] in seen}
        if not found:
            return (seen, opened) if owned == target else None
        owned |= found


def escapes(world, pickups, shrines, room, owned, opened):
    cache = world.setdefault('_escapes', {})
    key = (room, frozenset(owned), frozenset(opened))
    if key not in cache:
        cache[key] = _escapes(world, pickups, shrines, room, owned, opened)
    return cache[key]


def _escapes(world, pickups, shrines, room, owned, opened):
    owned = set(owned)
    while True:
        seen, opened = spread(world, room, owned, opened)
        if seen & shrines:
            return True
        found = {a for a, where in pickups.items() if a not in owned and where in seen}
        if not found:
            return False
        owned |= found


def audit(world, pickups, shrines):
    stranded, collectable = [], 0
    for size in range(len(world['abilities']) + 1):
        for combo in itertools.combinations(world['abilities'], size):
            target = set(combo)
            reached = holding(world, pickups, target)
            if reached is None:
                continue
            collectable += 1
            seen, opened = reached
            for room in sorted(seen):
                if room[1].endswith('#reward'):
                    continue
                if not escapes(world, pickups, shrines, room, target, opened):
                    stranded.append({'owned': sorted(target), 'room': f'{room[0]}:{room[1]}'})
    return {'collectable_sets': collectable, 'stranded': stranded}


def self_test():
    # start -> a -> pit (one way); pit exits only with `hook`, found in `cave`.
    def world(edges, levers=None):
        nodes = {n for e in edges for n in e[:2]}
        return {'edges': edges, 'levers': levers or {}, 'start': ('r', 'start'), 'nodes': nodes,
                'abilities': sorted({e[2] for e in edges if e[2]} | {'hook'})}
    s, a, pit, cave = ('r', 'start'), ('r', 'a'), ('r', 'pit'), ('r', 'cave')
    base = [(s, a, '', '', ''), (a, s, '', '', ''), (a, pit, '', '', ''), (pit, a, 'hook', '', '')]
    w = world(base)
    assert audit(w, {'hook': cave}, {s})['stranded'], 'a one-way pit whose exit needs an unfound ability strands'
    w = world(base + [(pit, cave, '', '', ''), (cave, pit, '', '', '')])
    assert not audit(w, {'hook': cave}, {s})['stranded'], 'an exit ability found inside the pit is enough'
    w = world([(s, cave, '', '', ''), (cave, s, '', '', ''), (cave, a, '', '', ''), (a, cave, '', '', ''), (a, pit, '', '', ''), (pit, a, 'hook', '', '')])
    assert not audit(w, {'hook': cave}, {s})['stranded'], 'a pit behind the pickup room is only reached owning the ability'
    w = world(base + [(pit, s, '', 'lift', '')], {'lift': pit})
    assert not audit(w, {'hook': cave}, {s})['stranded'], 'a lever inside the pit opening the way out counts'
    print('audit_stranding self-test OK')


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
    world = GRAPH.load_world()
    pickups, shrines, errors = landmarks(world)
    result = audit(world, pickups, shrines)
    result['errors'] = world['errors'] + errors
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"STRANDING collectable_sets={result['collectable_sets']} shrines={len(shrines)} "
              f"stranded={len(result['stranded'])} errors={len(result['errors'])}")
        rooms = sorted({row['room'] for row in result['stranded']})
        for room in rooms:
            sets = [row['owned'] for row in result['stranded'] if row['room'] == room]
            print(f'  stranded in {room} owning e.g. {min(sets, key=len) or "nothing"} ({len(sets)} sets)')
        for line in result['errors']:
            print('  ' + line)
    return 1 if result['stranded'] or result['errors'] else 0


if __name__ == '__main__':
    sys.exit(main())
