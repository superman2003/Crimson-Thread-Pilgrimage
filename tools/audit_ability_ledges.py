#!/usr/bin/env python3
"""A01: optional places that only the double jump, the echo hook or the crown
resonance opens, in ordinary rooms outside the ability workshops.

`world_routes.json` lists them in `ability_ledges`. Two shapes:

* ``ledge`` (double jump only): an open shelf above a floor.
* ``niche``: a shelf boxed in by a roof and two side walls, entered only from
  below, so nothing beside or above can reach it.
  - double jump: the opening is too high for one jump and low enough for two;
  - echo hook: the opening is above double-jump reach and a ring hangs inside;
  - crown resonance: a bell plate seals the opening and only the resonance
    action opens it (an action gate; owning the ability alone does not).

Using the player's real movement numbers (player_controller.gd) with generous
margins the audit proves, per entry, that nothing else in the region reaches
the reward without the ability (single jump + dash, double jump + dash, wall
grip, other hook rings), that the box is closed, that it does not overlap
existing solids or sit in the way of nearby platforms, and that the reward
rests inside. Static geometry only; real input is the Godot suite
`ability_ledges`."""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_platform_geometry import effective_config  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot/data'
JUMP, AIR_JUMP, GRAVITY = 710.0, 650.0, 1850.0
SPEED, DASH = 285.0, 780.0 * 0.16
SINGLE = JUMP ** 2 / (2 * GRAVITY)                 # ~136 px
DOUBLE = SINGLE + AIR_JUMP ** 2 / (2 * GRAVITY)    # ~250 px
MARGIN = 1.15                                      # generous to the player
WALL_GRIP_REACH = 160
HOOK_REACH = 460                                   # other rings stay further away
HOOK_RANGE = 430.0 * 0.95                          # player grapple_range, with margin
ACTION_RANGE = 150.0                               # main_level action gate default
HEADROOM = 110
PLAYER_HEIGHT, PLAYER_HALF_WIDTH = 84.0, 17.0
PICKUP_RADIUS, PICKUP_MARGIN = 18.0, 8.0
HOOK_GAP = 76                                      # open shaft beside an echo hook shelf
ROUTE_CLEARANCE = 160                              # keep away from other platforms
ABILITIES = ('double_thread_jump', 'echo_hook', 'crown_resonance')


def _air_time(rise):
    disc = JUMP ** 2 - 2 * GRAVITY * rise
    if disc < 0:
        return None
    return (JUMP + math.sqrt(disc)) / GRAVITY


def single_jump_reaches(rise, gap):
    """One jump plus one dash covers `gap` px and lands `rise` px higher."""
    if rise > SINGLE * 1.07:
        return False
    t = _air_time(min(rise, SINGLE))
    return t is not None and gap <= (SPEED * t + DASH) * MARGIN


def single_jump_collects(x0, x1, surface_y, pickup_x, pickup_y, double=False):
    """Conservative body/pickup contact envelope, including an airborne dash."""
    rise = surface_y - pickup_y - (PLAYER_HEIGHT + PICKUP_RADIUS + PICKUP_MARGIN)
    gap = max(x0 - pickup_x, pickup_x - x1, 0) - (PLAYER_HALF_WIDTH + PICKUP_RADIUS + PICKUP_MARGIN)
    reaches = double_jump_reaches if double else single_jump_reaches
    return reaches(rise, max(gap, 0))


def double_jump_reaches(rise, gap):
    """Jump, air jump at the first apex, plus one dash."""
    if rise > DOUBLE * 1.07:
        return False
    second_top = AIR_JUMP ** 2 / (2 * GRAVITY)
    fall = max(SINGLE + second_top - rise, 0.0)
    t = JUMP / GRAVITY + AIR_JUMP / GRAVITY + math.sqrt(2 * fall / GRAVITY)
    return gap <= (SPEED * t + DASH) * MARGIN


def segment_hits(a, b, rect):
    """Does segment a-b cross rect [x, y, w, h]? (Liang-Barsky clip.)"""
    x0, y0 = a
    dx, dy = b[0] - x0, b[1] - y0
    lo, hi = 0.0, 1.0
    for p, q in ((-dx, x0 - rect[0]), (dx, rect[0] + rect[2] - x0),
                 (-dy, y0 - rect[1]), (dy, rect[1] + rect[3] - y0)):
        if p == 0:
            if q < 0:
                return False
            continue
        t = q / p
        if p < 0:
            lo = max(lo, t)
        else:
            hi = min(hi, t)
        if lo > hi:
            return False
    return True


def standable(config):
    out = []
    for p in config['platforms']:
        if p.get('collision_role') in ('ceiling', 'wall', 'ungrippable_wall', 'decorative', 'no_collision'):
            continue
        x, y, w, _ = p['rect']
        out.append((p['id'], x, x + w, y))
    for t in config.get('terrain', []):
        for (ax, ay), (bx, by) in zip(t['surface'], t['surface'][1:]):
            out.append((t['id'], min(ax, bx), max(ax, bx), min(ay, by)))
    return out


def solids(config):
    out = [(p['id'], p['rect']) for p in config['platforms']
           if p.get('collision_role') not in ('decorative', 'no_collision')]
    out += [(g['id'], g['rect']) for g in config.get('locked_gates', [])]
    out += [(f'cave_{i}', r) for i, r in enumerate(config.get('cave_world', {}).get('solid_rects', []))]
    for t in config.get('terrain', []):
        depth = t.get('depth', 104)
        for (ax, ay), (bx, by) in zip(t['surface'], t['surface'][1:]):
            out.append((t['id'], [min(ax, bx), min(ay, by), abs(bx - ax) + 1, abs(by - ay) + depth]))
    return out


def overlaps(a, b):
    return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]


def blocks_observation(rectangles, point):
    cx, cy = point
    approach = [cx - PLAYER_HALF_WIDTH, cy - PLAYER_HEIGHT, PLAYER_HALF_WIDTH * 2, PLAYER_HEIGHT]
    return any(overlaps(approach, rect) or segment_hits((cx, cy - 42), (cx, cy), rect) for rect in rectangles)


def niche_shell(ledge, ability, wall=24):
    """Roof, side walls and (resonance) bell plate around ledge [x, y, w, h]."""
    lx, ly, lw, lh = ledge
    head = 190 if ability == 'echo_hook' else 130
    # Echo hook: an open shaft beside the shelf; the ring hangs above it, so the
    # pull line never crosses the shelf (rays do hit one-way shelves).
    gap = HOOK_GAP if ability == 'echo_hook' else 0
    gate = [lx, ly + lh, lw, 8] if ability == 'crown_resonance' else None
    bottom = (gate[1] + gate[3]) if gate else ly + lh
    top = ly - head - wall
    shell = {
        'roof': [lx - gap - wall, top, lw + gap + 2 * wall, wall],
        'wall_l': [lx - gap - wall, top, wall, bottom - top],
        'wall_r': [lx + lw, top, wall, bottom - top],
    }
    return shell, gate


def ring_for(ledge):
    lx, ly, lw, _ = ledge
    return [lx - HOOK_GAP / 2, ly - 100]


def check_place(config, entry, ledge, base_id, anchors, shell=None, gate=None, ring=None, things=()):
    """Problems with one place. `shell`/`gate`/`ring` describe a niche."""
    problems = []
    ability = entry['required_ability']
    kind = entry.get('kind', 'ledge')
    lx, ly, lw, lh = ledge
    base = next((p for p in config['platforms'] if p['id'] == base_id), None)
    if base is None:
        return [f'base floor {base_id} missing']
    bx, by, bw, _ = base['rect']
    rise = by - ly
    own = {base_id, entry.get('platform_id', 'probe'), entry.get('gate_id', 'probe_gate')}
    own |= {f"{entry.get('id', 'probe')}_{k}" for k in ('roof', 'wall_l', 'wall_r')}
    left_edge = lx - (HOOK_GAP if ability == 'echo_hook' and kind == 'niche' else 0)
    if not (left_edge >= bx and lx + lw <= bx + bw):
        problems.append('ledge (and its shaft) must sit over its base floor')
    if kind == 'ledge' and ability != 'double_thread_jump':
        problems.append('open ledges are for the double jump only')
    if ability == 'double_thread_jump':
        if rise <= SINGLE * 1.25:
            problems.append(f'rise {rise:.0f} reachable by a single jump ({SINGLE:.0f})')
        if rise > DOUBLE * 0.85:
            problems.append(f'rise {rise:.0f} too high for a dependable double jump ({DOUBLE:.0f})')
    elif ability == 'echo_hook':
        if rise <= DOUBLE * 1.25:
            problems.append(f'rise {rise:.0f} reachable by a double jump ({DOUBLE:.0f})')
    elif ability == 'crown_resonance':
        if rise > SINGLE * 0.9:
            problems.append(f'rise {rise:.0f}: once the bell opens a single jump must reach ({SINGLE:.0f})')
        if gate is not None and gate[1] + gate[3] > by - 90:
            problems.append('bell plate hangs too low to walk under')
    reaches = double_jump_reaches if ability == 'echo_hook' else single_jump_reaches
    all_solids = [(sid, r) for sid, r in solids(config) if sid not in own]
    if kind == 'niche':
        if shell is None:
            return problems + ['niche without its shell']
        roof, left, right = shell['roof'], shell['wall_l'], shell['wall_r']
        bottom = (gate[1] + gate[3]) if gate else ly + lh
        if not (roof[0] <= left[0] and roof[0] + roof[2] >= right[0] + right[2]
                and left[1] <= roof[1] and right[1] <= roof[1]
                and left[1] + left[3] >= bottom and right[1] + right[3] >= bottom
                and left[0] + left[2] <= lx and right[0] >= lx + lw):
            problems.append('niche shell is not closed around the ledge')
        if ly - (roof[1] + roof[3]) < 120:
            problems.append('niche headroom under the roof is too low for the body')
        if ability == 'crown_resonance':
            if gate is None or not (gate[0] <= lx and gate[0] + gate[2] >= lx + lw and gate[1] >= ly + lh - 1):
                problems.append('bell plate must seal the whole opening under the ledge')
            else:
                origin = ((lx + lw / 2), by - 42)
                closest = (min(max(origin[0], gate[0]), gate[0] + gate[2]), min(max(origin[1], gate[1]), gate[1] + gate[3]))
                if math.dist(origin, closest) > ACTION_RANGE * 0.8:
                    problems.append('bell plate out of resonance range from the floor below')
        body = [roof[0], roof[1], roof[2], bottom - roof[1]]
        column = [roof[0] - 16, bottom, roof[2] + 32, by - bottom - 1]
        for sid, rect in all_solids:
            if overlaps(body, rect):
                problems.append(f'niche overlaps solid {sid}')
            elif column[3] > 0 and overlaps(column, rect):
                problems.append(f'solid {sid} intrudes on the column under the niche')
        near = [body[0] - ROUTE_CLEARANCE, body[1] - ROUTE_CLEARANCE, body[2] + 2 * ROUTE_CLEARANCE, by - body[1] + ROUTE_CLEARANCE - 1]
        for sid, x0, x1, y in standable(config):
            if sid in own:
                continue
            if overlaps(near, [x0, y, x1 - x0, 1]):
                problems.append(f'surface {sid} is too close: the niche may block its jumps')
    else:
        column = [lx - 50, ly - HEADROOM, lw + 100, by - (ly - HEADROOM) - 1]
        for sid, rect in all_solids:
            if overlaps(column, rect):
                problems.append(f'solid {sid} intrudes on the jump column or headroom')
        for sid, x0, x1, y in standable(config):
            if sid in own:
                continue
            gap = max(x0 - (lx + lw), lx - x1, 0)
            if single_jump_reaches(y - ly, gap):
                problems.append(f'surface {sid} reaches the ledge without the double jump (gap {gap:.0f}, rise {y - ly:.0f})')
    if ability != 'crown_resonance':
        for sid, x0, x1, y in standable(config):
            if sid in own or y <= ly:
                continue
            gap = max(x0 - (lx + lw), lx - x1, 0)
            if reaches(y - ly, gap):
                problems.append(f'surface {sid} reaches the opening without {ability} (gap {gap:.0f}, rise {y - ly:.0f})')
        for sid, rect in all_solids:
            rx, ry, rw, rh = rect
            if rh >= 100 and ry < by and ry + rh > ly - 60:
                gap = max(rx - (lx + lw), lx - (rx + rw), 0)
                if gap < WALL_GRIP_REACH:
                    problems.append(f'wall {sid} within {gap:.0f}px allows a wall-grip climb')
    if ability == 'echo_hook':
        if ring is None:
            problems.append('echo hook niche has no ring')
        else:
            rx, ry = ring['position']
            fx, fy = ring['test_from']
            source = (fx, fy - 42)
            if not (bx + 18 <= fx <= bx + bw - 18 and abs(fy - (by - 40)) <= 2):
                problems.append('ring test_from must stand on the base floor')
            if math.dist(source, (rx, ry)) > HOOK_RANGE:
                problems.append(f'ring {math.dist(source, (rx, ry)):.0f}px from the base, beyond hook range')
            if not (lx - HOOK_GAP + 20 <= rx <= lx - 20 and ly - 140 <= ry <= ly - 90):
                problems.append('ring must hang inside the shaft beside the shelf, 90-140px above it')
            if abs(fx - rx) > 60:
                problems.append('ring must be almost straight above its test point (aim up)')
            for sid, rect in all_solids:
                if segment_hits(source, (rx, ry), rect):
                    problems.append(f'solid {sid} blocks the line to the ring')
    for anchor in anchors:
        if ring is not None and anchor['id'] == ring['id']:
            continue
        if math.dist(anchor['position'], [lx + lw / 2, ly]) < HOOK_REACH:
            problems.append(f"hook ring {anchor['id']} in range")
    top = (shell['roof'][1] if shell else ly - HEADROOM)
    for t in things:
        if lx - 150 < t[0] < lx + lw + 150 and top - 40 < t[1] < by + 5:
            problems.append(f'something placed at {t} sits under or beside the place')
            break
    return problems


def audit(routes_path=DATA / 'world_routes.json', data_root=DATA):
    routes = json.loads(Path(routes_path).read_text(encoding='utf-8'))
    errors, checked = [], 0
    counts = {a: 0 for a in ABILITIES}
    for entry in routes.get('ability_ledges', []):
        region = entry['region_id']
        config = effective_config(Path(data_root) / f'{region}.json', Path(data_root))
        overlay = routes['chapters'][region]
        platforms = {p['id']: p for p in overlay.get('platforms', [])}
        platform = platforms.get(entry['platform_id'])
        reward = next((c for c in overlay.get('collectibles', []) if c['id'] == entry['reward_id']), None)
        ability = entry.get('required_ability')
        if platform is None or reward is None:
            errors.append(f"{entry['id']}: platform or reward missing")
            continue
        if ability not in ABILITIES:
            errors.append(f"{entry['id']}: unsupported ability {ability}")
            continue
        anchors = config.get('grapple_anchors', []) + overlay.get('grapple_anchors', [])
        shell = gate = ring = None
        if entry.get('kind') == 'niche':
            shell = {}
            for part in ('roof', 'wall_l', 'wall_r'):
                piece = platforms.get(f"{entry['id']}_{part}")
                if piece is None:
                    errors.append(f"{entry['id']}: shell part {part} missing")
                    break
                shell[part] = piece['rect']
                expected_role = 'ceiling' if part == 'roof' else 'ungrippable_wall'
                if piece.get('collision_role') != expected_role:
                    errors.append(f"{entry['id']}: niche sides must not offer a wall-jump bypass")
            else:
                expected, _ = niche_shell(platform['rect'], ability)
                if shell != expected:
                    errors.append(f"{entry['id']}: shell differs from the generated niche")
            if len(shell) != 3:
                continue
        if ability == 'crown_resonance':
            g = next((v for v in overlay.get('locked_gates', []) if v['id'] == entry.get('gate_id')), None)
            if g is None or g.get('requires_action') != 'crown_resonance' or g.get('required_ability') != 'crown_resonance' \
                    or g.get('permanent_action_unlock_id') != g['id']:
                errors.append(f"{entry['id']}: bell plate must be a permanent crown resonance action gate")
                continue
            gate = g['rect']
        if ability == 'echo_hook':
            ring = next((a for a in overlay.get('grapple_anchors', []) if a['id'] == entry.get('ring_id')), None)
            if ring is None or ring.get('required_ability') != 'echo_hook' or ring.get('room_id') != entry['room_id']:
                errors.append(f"{entry['id']}: echo hook ring missing or outside the room")
                continue
        for problem in check_place(config, entry, platform['rect'], entry['base_platform_id'], anchors, shell, gate, ring):
            errors.append(f"{entry['id']}: {problem}")
        # Existing entrance observations must remain visible even when the
        # player approaches at the clue's authored height (e.g. during a jump).
        new_rects = [platform['rect']] + (list(shell.values()) if shell else []) + ([gate] if gate else [])
        for hidden in routes.get('hidden_route_plan', []):
            if hidden['region_id'] != region:
                continue
            if blocks_observation(new_rects, hidden['clue']['position']):
                errors.append(f"{entry['id']}: new geometry blocks the observation of {hidden['id']}")
        px, py, pw, _ = platform['rect']
        rx, ry = reward['position']
        base = next(p for p in config['platforms'] if p['id'] == entry['base_platform_id'])
        if ability != 'crown_resonance':
            jump_height = DOUBLE if ability == 'echo_hook' else SINGLE
            pickup_reach = jump_height * 1.07 + PLAYER_HEIGHT + PICKUP_RADIUS + PICKUP_MARGIN
            if base['rect'][1] - ry <= pickup_reach:
                errors.append(f"{entry['id']}: player head can collect the reward without the intended ability")
            for sid, x0, x1, sy in standable(config):
                if sid == platform['id'] or (shell and sy < py):
                    continue  # the closed roof/sides exclude drop-ins from above
                if single_jump_collects(x0, x1, sy, rx, ry, double=ability == 'echo_hook'):
                    errors.append(f"{entry['id']}: surface {sid} can collect its reward before landing")
        if not (px + 18 <= rx <= px + pw - 18 and 25 <= py - ry <= 70):
            errors.append(f"{entry['id']}: reward does not rest on the shelf")
        if reward.get('room_id') != entry['room_id'] or reward.get('reward_role') != 'optional_exploration':
            errors.append(f"{entry['id']}: reward must be an optional pickup in {entry['room_id']}")
        room = next((r for r in config['map_rooms'] if r['id'] == entry['room_id']), None)
        top = shell['roof'][1] if shell else py - HEADROOM
        if room is None:
            errors.append(f"{entry['id']}: room missing")
        else:
            x, y, w, h = room['layout_rect']
            pad = 24 if shell else 0
            if not (x <= px - pad and px + pw + pad <= x + w and y <= top and py <= y + h):
                errors.append(f"{entry['id']}: the place must lie inside {entry['room_id']}")
        checked += 1
        counts[ability] += 1
    for entry in routes.get('ability_routes', []):
        overlay = routes['chapters'][entry['region_id']]
        gate = next((g for g in overlay.get('locked_gates', []) if g['id'] == entry['gate_id']), {})
        pair = [next((p for p in overlay['portals'] if p['id'] == entry[key]), {})
                for key in ('entry_portal_id', 'return_portal_id')]
        ability = entry['required_ability']
        if ability not in ('echo_hook', 'crown_resonance'):
            errors.append(f"{entry['id']}: unsupported action route")
            continue
        if (gate.get('requires_action') != ability or gate.get('required_ability') != ability
                or gate.get('permanent_action_unlock_id') != gate.get('id')
                or gate.get('unlock_shortcut_id') != entry['id']):
            errors.append(f"{entry['id']}: latch must open only through its permanent ability action")
        if any(p.get('requires_shortcut') != entry['id'] or p.get('required_ability') != ability for p in pair):
            errors.append(f"{entry['id']}: both portal directions must retain the latch and ability conditions")
        if any(p.get('unlock_shortcut_id') for p in pair):
            errors.append(f"{entry['id']}: entering a portal cannot substitute for performing the action")
        if (pair[0].get('room_id') != entry['room_id'] or pair[1].get('room_id') != entry['return_room_id']
                or gate.get('from_room') != entry['room_id']
                or any(p.get('target_config_id') != entry['region_id'] for p in pair)):
            errors.append(f"{entry['id']}: gate and portal graph endpoints disagree with their region/rooms")
        if pair[0] and ability == 'echo_hook':
            ring = next((r for r in overlay.get('grapple_anchors', []) if r['id'] == entry['id'] + '_ring'), None)
            if ring is None or ring.get('test_from') != pair[0]['position']:
                errors.append(f"{entry['id']}: hook line needs a ring at its opening-side approach")
            elif gate:
                source = (ring['test_from'][0], ring['test_from'][1] - 2)
                if segment_hits(source, ring['position'], gate['rect']):
                    errors.append(f"{entry['id']}: its seal blocks the grapple ray")
        if pair[0] and gate:
            px, py = pair[0]['position']
            gx, gy, gw, gh = gate['rect']
            for hidden in routes.get('hidden_route_plan', []):
                if hidden['region_id'] == entry['region_id'] and blocks_observation([gate['rect']], hidden['clue']['position']):
                    errors.append(f"{entry['id']}: action seal blocks the observation of {hidden['id']}")
            if gy + gh > py - 50:
                errors.append(f"{entry['id']}: the overhead seal blocks walking headroom")
            if math.dist((px, py - 2), (min(max(px, gx), gx + gw), min(max(py - 2, gy), gy + gh))) > gate.get('action_range', 150) * .9:
                errors.append(f"{entry['id']}: action seal is too far from the supported approach")
        if ability == 'crown_resonance':
            record = entry.get('record_id', '')
            catalog = overlay.get('inventory_catalog', {}).get(record, {})
            if not record or gate.get('unlock_item_id') != record or catalog.get('category') != 'Relics':
                errors.append(f"{entry['id']}: sleeping bell must grant its optional journal record")
        checked += 1
        counts[ability] += 1
    if any(count < 3 for count in counts.values()):
        errors.append('each of the three abilities needs at least three ordinary-world uses')
    return checked, errors, counts


def self_test():
    assert 130 < SINGLE < 140 and 240 < DOUBLE < 260
    assert single_jump_reaches(100, 50) and not single_jump_reaches(180, 0)
    assert single_jump_reaches(-150, 300) and not single_jump_reaches(-150, 900)
    assert single_jump_collects(1960, 2340, 1752, 2505, 1524)
    assert not single_jump_collects(1960, 2340, 1752, 2505, 1490)
    assert not single_jump_collects(0, 20, 1752, 2505, 1490)
    assert double_jump_reaches(240, 0) and not double_jump_reaches(300, 0)
    assert double_jump_reaches(0, 400) and not double_jump_reaches(0, 900)
    assert segment_hits((0, 0), (10, 10), [4, 4, 2, 2]) and not segment_hits((0, 0), (10, 0), [4, 4, 2, 2])
    shell, gate = niche_shell([100, 100, 120, 22], 'crown_resonance')
    assert gate == [100, 122, 120, 8] and shell['wall_l'][1] + shell['wall_l'][3] == 130
    old = [1760, 4646, 120, 16]
    shell, gate = niche_shell(old, 'crown_resonance')
    assert blocks_observation([old, gate, *shell.values()], (1830, 4690)), 'old bell plate hid the tide-cell clue'
    moved = [2606, 2562, 72, 16]
    shell, gate = niche_shell(moved, 'crown_resonance')
    assert not blocks_observation([moved, gate, *shell.values()], (1830, 4690))


def main():
    self_test()
    checked, errors, counts = audit()
    for error in errors:
        print('LEDGE_FAIL ' + error)
    detail = ' '.join(f'{k}={v}' for k, v in counts.items())
    print(f"ABILITY_LEDGES {'PASS' if checked and not errors else 'FAIL'} places={checked} {detail} errors={len(errors)}")
    return 0 if checked and not errors else 1


if __name__ == '__main__':
    sys.exit(main())
