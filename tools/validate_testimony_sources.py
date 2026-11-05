"""Keep provenance attached to real evidence, rooms and independent sources."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(relative):
    return json.loads((ROOT / relative).read_text(encoding='utf-8'))


def errors(data, story, regions):
    failures = []
    evidence = {row['id']: row for row in story['evidence']}
    sources = data.get('sources', {})
    if type(data.get('version')) is not int or data['version'] != 1:
        failures.append('source schema version must be the integer 1')
    if set(sources) != set(evidence):
        failures.append('source dossiers must cover exactly the original evidence set')
    for identity, row in sources.items():
        if identity not in evidence:
            continue
        proof = evidence[identity]
        region_id = 'demo_' + proof['region']
        region = regions[region_id]
        witness = proof['scene_witness']
        if row.get('region') != region_id or row.get('room') != witness['room']:
            failures.append(f'{identity}: source must retain the collected artifact location')
        if row.get('place') != witness['room_title']:
            failures.append(f'{identity}: place name disagrees with the existing scene witness')
        if row.get('room') not in {room['id'] for room in region['map_rooms']}:
            failures.append(f'{identity}: source room is absent from the production region')
        if witness['collectible_id'] not in {item['id'] for item in region.get('collectibles', [])}:
            failures.append(f'{identity}: collected object is absent from the production region')
        for key in ['medium', 'place', 'region', 'room', 'supports']:
            value = row.get(key)
            if not isinstance(value, str) or not value.strip() or len(value) > 180 or '\n' in value:
                failures.append(f'{identity}: invalid {key}')
        for key in ['observations', 'limits']:
            values = row.get(key)
            if not isinstance(values, list) or not 1 <= len(values) <= 3:
                failures.append(f'{identity}: {key} needs one to three short statements')
                continue
            if any(not isinstance(value, str) or not value.strip() or len(value) > 180 or '\n' in value for value in values):
                failures.append(f'{identity}: invalid {key} statement')
        comparisons = row.get('cross_checks', [])
        if not isinstance(comparisons, list) or len(comparisons) > 3:
            failures.append(f'{identity}: comparisons must be a bounded list')
            continue
        for comparison in comparisons:
            needed = comparison.get('evidence_all', [])
            if not 2 <= len(needed) <= len(evidence) or len(set(needed)) != len(needed):
                failures.append(f'{identity}: corroboration needs distinct independent sources')
            if identity not in needed or not set(needed) <= set(evidence):
                failures.append(f'{identity}: corroboration references an unknown or unrelated source')
            text = comparison.get('text')
            if not isinstance(text, str) or not text.strip() or len(text) > 180 or '\n' in text:
                failures.append(f'{identity}: invalid comparison text')
    return failures


def validate():
    story = load('godot/data/world_narrative.json')
    data = load('godot/data/testimony_sources.json')
    regions = {'demo_' + proof['region']: load('godot/data/demo_' + proof['region'] + '.json') for proof in story['evidence']}
    found = errors(data, story, regions)
    assert not found, '\n'.join(found)
    # Prove the gate detects a missing dossier, a false location and a copied
    # source masquerading as independent corroboration.
    for fault in ['missing', 'location', 'duplicate', 'unknown', 'inference']:
        broken = copy.deepcopy(data)
        row = broken['sources']['testimony_01']
        if fault == 'missing':
            del broken['sources']['testimony_02']
        elif fault == 'location':
            row['room'] = 'not_a_real_room'
        elif fault == 'duplicate':
            row['cross_checks'][0]['evidence_all'] = ['testimony_01', 'testimony_01']
        elif fault == 'unknown':
            row['cross_checks'][0]['evidence_all'].append('invented_testimony')
        else:
            row['limits'] = []
        assert errors(broken, story, regions), f'fault injection was not detected: {fault}'
    comparisons = sum(len(row['cross_checks']) for row in data['sources'].values())
    print(f'TESTIMONY_SOURCES_DATA_PASS sources={len(data["sources"])} comparisons={comparisons} fault_cases=5')


if __name__ == '__main__':
    validate()
