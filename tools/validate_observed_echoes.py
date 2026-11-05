"""Require every short protagonist response to have encountered source material."""
import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def errors(data, history, story):
    failures = []
    facilities = {row['id']: row for row in history['entries'] if row['role'] == 'daily'}
    evidence = {row['id']: row for row in story['evidence']}
    entries = data.get('entries', [])
    if type(data.get('version')) is not int or data['version'] != 1:
        failures.append('response version must be integer 1')
    if not isinstance(entries, list) or not 1 <= len(entries) <= 24:
        return failures + ['responses need a bounded nonempty list']
    identities = set()
    for row in entries:
        if set(row) != {'id', 'title', 'text', 'observations_all', 'evidence_all'}:
            failures.append('response data must contain only identity, text and source conditions')
        identity = row.get('id')
        if not isinstance(identity, str) or not re.fullmatch('[a-z][a-z0-9_]*', identity) or identity in identities:
            failures.append('response identities must be unique stable identifiers')
        identities.add(identity)
        for key, limit in [('title', 24), ('text', 90)]:
            value = row.get(key)
            if not isinstance(value, str) or not value.strip() or len(value) > limit or '\n' in value:
                failures.append(f'{identity}: {key} must remain a short single paragraph')
        if isinstance(row.get('text'), str) and '我' not in row['text']:
            failures.append(f'{identity}: responses need the protagonist\'s personal perspective')
        observations = row.get('observations_all', [])
        proofs = row.get('evidence_all', [])
        if not isinstance(observations, list) or not 1 <= len(observations) <= 3 or len(set(observations)) != len(observations):
            failures.append(f'{identity}: observations need distinct known facilities')
            continue
        if not set(observations) <= set(facilities):
            failures.append(f'{identity}: unknown or non-facility observation')
        if not isinstance(proofs, list) or len(proofs) > 3 or len(set(proofs)) != len(proofs) or not set(proofs) <= set(evidence):
            failures.append(f'{identity}: unknown or duplicated evidence condition')
            continue
        if len(observations) + len(proofs) < 2:
            failures.append(f'{identity}: a combined reading needs more than one source')
        if proofs and observations[0] in facilities and proofs[0] in evidence:
            if facilities[observations[0]]['region_id'] != 'demo_' + evidence[proofs[0]]['region']:
                failures.append(f'{identity}: local artifact reflection must use its own region\'s evidence')
    return failures


def validate():
    data = load('godot/data/observed_echoes.json')
    history = load('godot/data/scene_history.json')
    story = load('godot/data/world_narrative.json')
    found = errors(data, history, story)
    assert not found, '\n'.join(found)
    local = [row for row in data['entries'] if row['evidence_all']]
    cross = [row for row in data['entries'] if not row['evidence_all']]
    assert len(local) == len(cross) == 6
    assert {row['evidence_all'][0] for row in local} == {row['id'] for row in story['evidence']}
    for fault in ['unknown', 'alone', 'duplicate', 'reward', 'long', 'evidence']:
        broken = copy.deepcopy(data)
        row = broken['entries'][0]
        if fault == 'unknown':
            row['observations_all'] = ['invented_facility']
        elif fault == 'alone':
            row['evidence_all'] = []
        elif fault == 'duplicate':
            row['observations_all'] *= 2
        elif fault == 'reward':
            row['grant_flags'] = ['invented_progress']
        elif fault == 'long':
            row['text'] = '我' * 91
        else:
            row['evidence_all'] = ['invented_testimony']
        assert errors(broken, history, story), f'undetected response fault: {fault}'
    print('OBSERVED_ECHOES_DATA_PASS notes=12 local=6 cross_city=6 fault_cases=6')


if __name__ == '__main__':
    validate()
