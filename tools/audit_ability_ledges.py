#!/usr/bin/env python3
"""A01: optional high ledges that only the double jump can reach.

Each ledge listed in world_routes.json `ability_ledges` sits above an existing
floor of its region. Using the player's real jump numbers (player_controller.gd)
with generous margins, the audit proves for every ledge that
  * from its base floor a single jump is too low and a double jump reaches it;
  * no other standable surface in the region reaches it with a single jump plus
    a dash (including stepping off a higher surface);
  * no tall wall is close enough to climb with wall grip, and no hook ring is
    in range;
  * the column between the base floor and the ledge, and the headroom above
    the ledge, are free of solids, and the reward rests on the ledge.
Enemy bounce envelopes include movement bounds and the strongest authored
crest pogo multiplier; real player/enemy contact is covered by a Godot suite."""
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
HOOK_REACH = 460
HEADROOM = 110
# Player.tscn body reaches 84px above the feet; production pickups have radius18.
PLAYER_HEIGHT, PLAYER_HALF_WIDTH = 84.0, 17.0
PICKUP_RADIUS, PICKUP_MARGIN = 18.0, 8.0


def _air_time(rise, velocity=JUMP):
    """Seconds airborne until a single jump comes down `rise` px above its
    start (negative = lower). None if that height is never reached."""
    disc = velocity ** 2 - 2 * GRAVITY * rise
    if disc < 0:
        return None
    return (velocity + math.sqrt(disc)) / GRAVITY


def single_jump_reaches(rise, gap):
    """Can one jump plus one dash cover `gap` px and land `rise` px higher?"""
    if rise > SINGLE * 1.07:
        return False
    t = _air_time(min(rise, SINGLE))
    return t is not None and gap <= (SPEED * t + DASH) * MARGIN


def single_jump_collects(x0, x1, surface_y, pickup_x, pickup_y):
    """Conservative body/pickup contact envelope from a standable surface."""
    rise = surface_y - pickup_y - (PLAYER_HEIGHT + PICKUP_RADIUS + PICKUP_MARGIN)
    gap = max(x0 - pickup_x, pickup_x - x1, 0) - (PLAYER_HALF_WIDTH + PICKUP_RADIUS + PICKUP_MARGIN)
    return single_jump_reaches(rise, max(gap, 0))


def enemy_pogo_collects(enemy, config, pickup, multiplier):
    """Allow a bounce anywhere in the enemy's full horizontal movement bounds.

    Use the complete authored visual/hurtbox height above its node as a
    conservative contact origin, rather than assuming a launch from the floor.
    This includes recoil on stationary enemies, whose leash still clamps it.
    """
    profile = config.get('ai_profiles', {}).get(enemy.get('kind'), {})
    x, y = enemy['position']
    leash = float(enemy.get('leash_radius', profile.get('leash_radius', 240)))
    support = next((p for p in config['platforms'] if p['id'] == enemy.get('platform_id')), None)
    half = float(enemy.get('spawn_half_width', 36))
    x0, x1 = (x-leash, x+leash) if leash > 0 else (-math.inf, math.inf)
    flight = profile.get('locomotion', enemy.get('locomotion')) == 'flight'
    if support:
        sx, _, sw, _ = support['rect']
        x0, x1 = max(x0, sx+half-(100 if flight else 0)), min(x1, sx+sw-half+(100 if flight else 0))
    x0 = max(x0, float(enemy.get('arena_min_x', -math.inf)))
    x1 = min(x1, float(enemy.get('arena_max_x', math.inf)))
    if x0 > x1:
        raise ValueError('Invalid enemy movement envelope: '+enemy['id'])
    contact_y = y - max(float(enemy.get('spawn_visual_height', 56)), float(enemy.get('hurtbox_size', [58,56])[1]))
    if flight:
        contact_y -= float(profile.get('hover_height', 95)) + 24
    velocity = 620.0 * multiplier
    peak = velocity**2 / (2*GRAVITY)
    rise = contact_y-pickup[1]-(PLAYER_HEIGHT+PICKUP_RADIUS+PICKUP_MARGIN)
    gap = max(x0-pickup[0], pickup[0]-x1, 0)-(half+PLAYER_HALF_WIDTH+PICKUP_RADIUS+PICKUP_MARGIN)
    if rise > peak*1.07:
        return False
    time = _air_time(min(rise, peak), velocity)
    return time is not None and max(gap,0) <= (SPEED*time+DASH)*MARGIN


def standable(config):
    out = []
    for p in config['platforms']:
        if p.get('collision_role') in ('ceiling', 'wall', 'decorative', 'no_collision'):
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
    out += [(f'cave_{i}', r) for i, r in enumerate(config.get('cave_world', {}).get('solid_rects', []))]
    for t in config.get('terrain', []):
        depth = t.get('depth', 104)
        for (ax, ay), (bx, by) in zip(t['surface'], t['surface'][1:]):
            out.append((t['id'], [min(ax, bx), min(ay, by), abs(bx - ax) + 1, abs(by - ay) + depth]))
    return out


def overlaps(a, b):
    return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]


def check_ledge(config, ledge_id, ledge, base_id, anchors):
    """Problems with ledge rect [x, y, w, h] (platform `ledge_id`) over `base_id`."""
    problems = []
    lx, ly, lw, _ = ledge
    base = next((p for p in config['platforms'] if p['id'] == base_id), None)
    if base is None:
        return [f'base floor {base_id} missing']
    bx, by, bw, _ = base['rect']
    rise = by - ly
    if not (lx >= bx and lx + lw <= bx + bw):
        problems.append('ledge must sit over its base floor')
    if rise <= SINGLE * 1.25:
        problems.append(f'rise {rise:.0f} reachable by a single jump ({SINGLE:.0f})')
    if rise > DOUBLE * 0.85:
        problems.append(f'rise {rise:.0f} too high for a dependable double jump ({DOUBLE:.0f})')
    column = [lx - 50, ly - HEADROOM, lw + 100, by - (ly - HEADROOM) - 1]
    for sid, rect in solids(config):
        if sid in (base_id, ledge_id):
            continue
        if overlaps(column, rect):
            problems.append(f'solid {sid} intrudes on the jump column or headroom')
            continue
        rx, ry, rw, rh = rect
        if rh >= 100 and ry < by and ry + rh > ly - 60:
            gap = max(rx - (lx + lw), lx - (rx + rw), 0)
            if gap < WALL_GRIP_REACH:
                problems.append(f'wall {sid} within {gap:.0f}px allows a wall-grip climb')
    for sid, x0, x1, y in standable(config):
        if sid in (base_id, ledge_id):
            continue
        gap = max(x0 - (lx + lw), lx - x1, 0)
        if single_jump_reaches(y - ly, gap):
            problems.append(f'surface {sid} reaches the ledge without the double jump (gap {gap:.0f}, rise {y - ly:.0f})')
    for anchor in anchors:
        if math.dist(anchor['position'], [lx + lw / 2, ly]) < HOOK_REACH:
            problems.append(f"hook ring {anchor['id']} in range")
    return problems


def audit(routes_path=DATA / 'world_routes.json', data_root=DATA):
    routes = json.loads(Path(routes_path).read_text(encoding='utf-8'))
    catalog = json.loads((Path(data_root)/'build_catalog.json').read_text(encoding='utf-8'))
    pogo_multiplier = max(1.0, *(float(c.get('pogo_bounce_mult',1)) for c in catalog['crests'].values()))
    errors, checked = [], 0
    for entry in routes.get('ability_ledges', []):
        region = entry['region_id']
        config = effective_config(Path(data_root) / f'{region}.json', Path(data_root))
        overlay = routes['chapters'][region]
        platform = next((p for p in overlay.get('platforms', []) if p['id'] == entry['platform_id']), None)
        reward = next((c for c in overlay.get('collectibles', []) if c['id'] == entry['reward_id']), None)
        if platform is None or reward is None:
            errors.append(f"{entry['id']}: platform or reward missing")
            continue
        if entry.get('required_ability') != 'double_thread_jump':
            errors.append(f"{entry['id']}: only double jump ledges are defined")
        anchors = config.get('grapple_anchors', []) + overlay.get('grapple_anchors', [])
        for problem in check_ledge(config, platform['id'], platform['rect'], entry['base_platform_id'], anchors):
            errors.append(f"{entry['id']}: {problem}")
        for sid, x0, x1, surface_y in standable(config):
            if sid == platform['id']:
                continue
            if single_jump_collects(x0, x1, surface_y, *reward['position']):
                errors.append(f"{entry['id']}: surface {sid} can collect the reward with a single jump and dash before reaching the ledge")
        for enemy in config.get('enemy_spawns', []):
            if enemy_pogo_collects(enemy, config, reward['position'], pogo_multiplier):
                errors.append(f"{entry['id']}: enemy {enemy['id']} permits a pogo and dash to collect the reward without double jump")
        px, py, pw, _ = platform['rect']
        rx, ry = reward['position']
        if not (px + 18 <= rx <= px + pw - 18 and 25 <= py - ry <= 70):
            errors.append(f"{entry['id']}: reward does not rest on the ledge")
        if reward.get('room_id') != entry['room_id'] or reward.get('reward_role') != 'optional_exploration':
            errors.append(f"{entry['id']}: reward must be an optional pickup in {entry['room_id']}")
        room = next((r for r in config['map_rooms'] if r['id'] == entry['room_id']), None)
        if room is None:
            errors.append(f"{entry['id']}: room missing")
        else:
            x, y, w, h = room['layout_rect']
            if not (x <= px and px + pw <= x + w and y <= py - HEADROOM and py <= y + h):
                errors.append(f"{entry['id']}: ledge and headroom must be inside {entry['room_id']}")
        checked += 1
    return checked, errors


def self_test():
    assert 130 < SINGLE < 140 and 240 < DOUBLE < 260
    assert single_jump_reaches(100, 50) and not single_jump_reaches(180, 0)
    assert single_jump_reaches(-150, 300) and not single_jump_reaches(-150, 900)
    assert single_jump_collects(1960, 2340, 1752, 2505, 1524)
    assert not single_jump_collects(1960, 2340, 1752, 2505, 1490)
    assert not single_jump_collects(0, 20, 1752, 2505, 1490)
    config = dict(platforms=[dict(id='gallery', rect=[1960,1752,380,36])])
    enemy = dict(id='E06', kind='index_scribe', position=[2285,1712],
                 platform_id='gallery', leash_radius=90, spawn_half_width=24, spawn_visual_height=56)
    assert enemy_pogo_collects(enemy, config, [2505,1490], 1.2)
    enemy.update(position=[2000,1712], leash_radius=24)
    assert not enemy_pogo_collects(enemy, config, [2505,1490], 1.2)


def main():
    self_test()
    checked, errors = audit()
    for error in errors:
        print('LEDGE_FAIL ' + error)
    print(f"ABILITY_LEDGES {'PASS' if checked and not errors else 'FAIL'} ledges={checked} errors={len(errors)}")
    return 0 if checked and not errors else 1


if __name__ == '__main__':
    sys.exit(main())
