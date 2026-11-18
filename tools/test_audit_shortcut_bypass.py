"""Self-test for audit_shortcut_bypass: real data passes, planted bypasses fail."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_shortcut_bypass as A


def world(edges, levers=None):
    nodes = {n for e in edges for n in e[:2]}
    return {'nodes': nodes, 'edges': edges, 'levers': levers or {}, 'start': ('r', 'start'),
            'abilities': sorted({e[2] for e in edges if e[2]}), 'errors': []}


def n(name):
    return ('r', name)


def main():
    failures = []

    def check(ok, label):
        if not ok:
            failures.append(label)

    real = A.load_world()
    result = A.audit(real)
    check(not result['errors'] and not result['bypasses'] and not result['unreachable'], 'shipped world has no bypass')
    check(real['start'] == ('demo_ch01_moss_bell_court', 'entry_bell'), 'new game starts in the bell entry')
    check(real['levers'].get('ch01_vault_hub_shortcut', (None, None))[1] in {'sluice_hall', 'bell_stair_well'},
          'ch01 lever lies at one end of its shortcut')
    check(all(row['opened'] for row in result['savings']) and len(result['savings']) >= 12, 'every shortcut can be opened')
    # The far-side action node must retain its ability requirement independently
    # of both portal directions and their permanent latch.
    action_edges = [e for e in real['edges'] if e[1][1].endswith('#action')]
    check(len(action_edges) == 5, 'all five A01 action-operated returns enter the world audit')
    for a, b, ability, _, _ in action_edges:
        latch = next(key for key, node in real['levers'].items() if node == b)
        _, opened = A.reach(real, set(real['abilities']) - {ability}, True)
        check(latch not in opened, latch + ' cannot open when its action ability is missing')

    # Lever below a one-way drop opens a door into a dash-only vault.
    leak = world([(n('start'), n('hall'), '', '', ''), (n('hall'), n('vault'), 'thread_dash', '', ''),
                  (n('start'), n('pit'), '', '', ''), (n('pit'), n('vault'), '', 'latch', ''),
                  (n('vault'), n('pit'), '', 'latch', '')], {'latch': n('pit')})
    rows = A.audit(leak)['bypasses']
    check({'owned': [], 'room': 'r:vault'} in rows, 'lever shortcut into a gated room is a bypass')
    check(all(r['owned'] == [] for r in rows), 'owning the ability removes the bypass')

    # Same shortcut, lever on the far side of the gate: a return route only.
    safe = world(leak['edges'], {'latch': n('vault')})
    check(not A.audit(safe)['bypasses'], 'lever behind the gate is a return, not a bypass')

    # Portal pair: one side opens the latch, the reverse needs it.
    portal_leak = world([(n('start'), n('dock'), '', '', ''), (n('dock'), n('island'), '', '', 'ferry'),
                         (n('island'), n('dock'), '', 'ferry', ''), (n('start'), n('island'), 'echo_hook', '', ''),
                         (n('island'), n('vault'), '', 'ferry', ''), (n('start'), n('vault'), 'echo_hook', '', '')])
    check({'owned': [], 'room': 'r:vault'} in A.audit(portal_leak)['bypasses'], 'opened portal latch into a gated room is a bypass')
    check(not A.audit(world(portal_leak['edges'][:4]))['bypasses'], 'latch portal between reachable rooms is fine')

    if failures:
        for label in failures:
            print('FAIL', label)
        return 1
    print(f"audit_shortcut_bypass self-test OK ({result['subsets']} ability subsets, {len(result['savings'])} shortcuts)")
    return 0


if __name__ == '__main__':
    sys.exit(main())
