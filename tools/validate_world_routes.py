#!/usr/bin/env python3
"""Validate overlay topology and geometry; this is NOT a physical playthrough."""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def validate(routes_path, data_root):
    routes = json.loads(routes_path.read_text())
    chapters = routes['chapters']
    errors = []
    checks = 0
    configs = {key: json.loads((data_root / (key + '.json')).read_text()) for key in chapters}
    for key, overlay in chapters.items():
        for override in overlay.get('terrain_overrides', []):
            for terrain in configs[key].get('terrain', []):
                if terrain['id'] == override['id']:
                    terrain.update(override)
        for override in overlay.get('platform_overrides', []):
            for platform in configs[key]['platforms']:
                if platform['id'] == override['id']:
                    platform.update(override)
        configs[key]['platforms'].extend(overlay.get('platforms', []))
        configs[key].setdefault('terrain', []).extend(overlay.get('terrain', []))
        for override in overlay.get('locked_gate_overrides', []):
            for gate in configs[key].get('locked_gates', []):
                if gate['id'] == override['id']:
                    gate.update(override)
    def check(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            errors.append(message)
    def supported(config, point):
        x, y = point
        for platform in config.get('platforms', []):
            px, py, width, height = platform['rect']
            if platform.get('collision_role') != 'ceiling' and px + 18 <= x <= px + width - 18 and 25 <= py - y <= 70:
                return True
        return False
    def solid_overlap(config, point):
        x, y = point
        # Player.tscn collider is 34 x 84, offset (0,-42) from feet.
        # Visual environment blocks are excluded.
        for platform in config.get('platforms', []):
            px, py, width, height = platform['rect']
            if x + 17 > px and x - 17 < px + width and y > py and y - 84 < py + height:
                return True
        return False
    for region, overlay in chapters.items():
        config = configs[region]
        portal_ids = [p['id'] for p in overlay['portals']]
        check(len(portal_ids) == len(set(portal_ids)), f'{region}: duplicate portals')
        for p in overlay['portals']:
            destination = p['target_config_id']
            peer = next((v for v in chapters.get(destination, {}).get('portals', []) if v['id'] == p['target_portal_id']), None)
            check(peer is not None, f"{p['id']}: missing paired portal")
            if peer:
                check(peer['target_config_id'] == region and peer['target_portal_id'] == p['id'], f"{p['id']}: asymmetric pairing")
                check(peer['position'] == p['target_spawn'], f"{p['id']}: spawn differs from peer landing")
            check(not p.get('requires_demo_complete'), f"{p['id']}: routes must not depend on boss clear")
            check(supported(config, p['position']), f"{p['id']}: portal position lacks existing ground support")
            check(supported(configs[destination], p['target_spawn']), f"{p['id']}: arrival lacks existing ground support")
            check(not solid_overlap(configs[destination], p['target_spawn']), f"{p['id']}: arrival collider overlaps platform")
        for anchor in overlay.get('grapple_anchors', []):
            check(anchor.get('required_ability') == 'echo_hook', f"{anchor['id']}: grappling must require acquired hook")
            check(math.dist(anchor['position'], anchor['test_from']) <= 430, f"{anchor['id']}: unreachable from designated ground")
            check(supported(config, anchor['test_from']), f"{anchor['id']}: hook approach lacks supported landing")
            check(not solid_overlap(config, anchor['position']), f"{anchor['id']}: ring embedded in platform")
            x, y = anchor['position']
            for terrain in config.get('terrain', []):
                points = terrain.get('surface', [])
                for (ax, ay), (bx, by) in zip(points, points[1:]):
                    if ax <= x <= bx and bx > ax:
                        surface_y = ay + (by-ay) * (x-ax)/(bx-ax)
                        check(not surface_y - 10 <= y <= surface_y + terrain.get('depth', 104) + 10, f"{anchor['id']}: ring embedded in terrain {terrain['id']}")
        for platform in overlay.get('platform_overrides', []):
            px, py, width, height = platform['rect']
            for x in [px + 17, px + width/2, px + width - 17]:
                for terrain in config.get('terrain', []):
                    points = terrain.get('surface', [])
                    for (ax, ay), (bx, by) in zip(points, points[1:]):
                        if ax <= x <= bx and bx > ax:
                            surface_y = ay + (by-ay) * (x-ax)/(bx-ax)
                            if surface_y < py - 5:
                                check(surface_y + terrain.get('depth', 104) + 4 <= py - 84, f"{platform['id']}: standing body lacks headroom under {terrain['id']} at x={x}")
        base_items = {v['id']: v for v in config.get('collectibles', [])}
        room_ids = {v['id'] for v in config.get('map_rooms', [])}
        for override in overlay.get('collectible_overrides', []):
            check(override['id'] in base_items, f"{region}: nonexistent collectible override")
            collectible = dict(base_items.get(override['id'], {}), **override)
            check(supported(config, collectible['position']), f"{region}: override unsupported")
            check(collectible['room_id'] in room_ids, f"{region}: invalid override room")
        for collectible in overlay.get('collectibles', []):
            check(collectible['id'] not in base_items, f"{region}: added collectible duplicates original")
            check(supported(config, collectible['position']), f"{region}: added collectible unsupported")
            check(collectible['room_id'] in room_ids, f"{region}: invalid added room")
    moss = chapters['demo_ch01_moss_bell_court']
    arch = {v['id']: v['rect'] for v in moss['platforms']}
    roof = arch['world_salt_arch_roof']
    foundation = arch['world_salt_arch_foundation']
    backwall = arch['world_salt_arch_backwall']
    gate_rect = moss['locked_gate_overrides'][0]['rect']
    check(gate_rect[1] <= roof[1] + roof[3] and gate_rect[1] + gate_rect[3] >= foundation[1] + foundation[3], 'salt gate must overlap roof and foundation to prevent climbing or dropping around it')
    check(roof[0] <= gate_rect[0] and roof[0] + roof[2] >= backwall[0] + backwall[2] and backwall[1] + backwall[3] >= foundation[1] + foundation[3], 'salt reward chamber must have no exterior opening around the gate')
    base_gate = next(g for g in configs['demo_ch01_moss_bell_court']['locked_gates'] if g['id'] == 'gate_jump_salt')
    check(base_gate['required_ability'] == 'double_thread_jump', 'salt gate must use real double jump ability')
    reward = next(v for v in moss['collectibles'] if v['item_id'] == 'testimony_returned_name')
    check(reward['position'][0] > base_gate['rect'][0] + base_gate['rect'][2], 'testimony must be beyond physical salt gate')
    rain = chapters['demo_ch02_rain_foundry_canal']
    check(next(p for p in rain['portals'] if p['id'] == 'rain_archive_riser')['required_ability'] == 'silk_wall_grip', 'archive entry must need wall grip')
    print(json.dumps({'checks': checks, 'errors': errors, 'limitation': 'Static geometry and paired routes only. Actual input-based traversal is a separate Godot test.'}, ensure_ascii=False, indent=2))
    return 1 if errors else 0

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--data-root', type=Path, default=ROOT / 'godot/data')
    parser.add_argument('--routes', type=Path, default=ROOT / 'godot/data/world_routes.json')
    args = parser.parse_args()
    raise SystemExit(validate(args.routes, args.data_root))
