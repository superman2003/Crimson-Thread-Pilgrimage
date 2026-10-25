"""Validate material-only exchanges and a strictly decreasing trade potential."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate(data, configs):
    errors = []
    drops = {region: config['enemy_drop_item'] for region, config in configs.items()}
    rows = data.get('recipes', [])
    if data.get('version') != 1 or data.get('batch_limit') != 10 or len(rows) != 12:
        errors.append('expected version 1, batch limit 10, twelve authored exchanges')
    ids, pairs = set(), set()
    for row in rows:
        rid, region, target = row.get('id'), row.get('region'), row.get('target_region')
        if rid in ids or (region, target) in pairs or region == target:
            errors.append('duplicate exchange or self-loop')
        ids.add(rid); pairs.add((region, target))
        if row.get('input') != drops.get(region) or row.get('output') != drops.get(target):
            errors.append(f'{rid}: only native enemy-drop materials may enter or leave')
        if (row.get('input_amount'), row.get('output_amount'), row.get('currency')) != (3, 1, 8):
            errors.append(f'{rid}: each trade must lose two material units and eight currency')
        expected = f'pilgrim_permit_{sorted(configs).index(region)+1:02d}' if region in configs else ''
        if not expected or row.get('requires_item') != expected:
            errors.append(f'{rid}: source-region permit required')
    order = sorted(configs)
    expected_pairs = {(region, order[(i+step) % len(order)]) for i, region in enumerate(order) for step in [-1, 1]}
    if pairs != expected_pairs:
        errors.append('exchange links must be exactly the two adjacent known regions')
    # Sum(native material counts) decreases by two for every trade. Together with
    # positive currency cost this proves every non-empty trade cycle loses value.
    return errors


def audit():
    data_dir = ROOT / 'godot/data'
    regions = json.loads((data_dir / 'world_routes.json').read_text())['chapters']
    configs = {region: json.loads((data_dir / f'{region}.json').read_text()) for region in regions}
    return validate(json.loads((data_dir / 'material_exchange.json').read_text()), configs)


if __name__ == '__main__':
    errors = audit()
    for error in errors: print('FAIL: ' + error)
    print(f'MATERIAL_EXCHANGE_AUDIT recipes=12 errors={len(errors)}')
    raise SystemExit(bool(errors))
