"""Validate evidence-gated concepts against the shipped narrative vocabulary."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def errors(data, evidence):
    found = []
    if not isinstance(data, dict) or set(data) != {'version', 'entries'} or type(data.get('version')) not in (int, float) or data['version'] != 1:
        return ['invalid concept envelope']
    if not isinstance(data['entries'], list) or not 1 <= len(data['entries']) <= 16:
        return ['invalid concept collection']
    seen = set()
    for row in data['entries']:
        if not isinstance(row, dict) or set(row) != {'id', 'title', 'stages'} or not isinstance(row.get('id'), str) or not row['id'].isidentifier() or row['id'] in seen:
            found.append('invalid or duplicated concept identity')
            continue
        seen.add(row['id'])
        if not isinstance(row['title'], str) or not row['title'].strip() or len(row['title']) > 24:
            found.append('invalid public concept title')
        if not isinstance(row['stages'], list) or not 1 <= len(row['stages']) <= 3:
            found.append('invalid concept stages')
            continue
        previous = set()
        for stage in row['stages']:
            if not isinstance(stage, dict) or set(stage) != {'evidence_all', 'definition', 'limit'}:
                found.append('concept text cannot add progress fields')
                continue
            required = stage['evidence_all']
            if not isinstance(required, list) or not required or any(not isinstance(key, str) for key in required):
                found.append('unconditional or malformed concept stage')
                continue
            current = set(required)
            if len(current) != len(required) or not current <= evidence or not previous < current:
                found.append('concept stages require unique known sources and strict growth')
            previous = current
            for field, maximum in [('definition', 160), ('limit', 140)]:
                value = stage[field]
                if not isinstance(value, str) or not value.strip() or len(value) > maximum or '\n' in value:
                    found.append('unbounded public concept text')
    return found


def validate():
    story = json.loads((ROOT / 'godot/data/world_narrative.json').read_text())
    evidence = {row['id'] for row in story['evidence']}
    data = json.loads((ROOT / 'godot/data/known_world_terms.json').read_text())
    assert not errors(data, evidence), errors(data, evidence)
    assert len(data['entries']) == 8 and sum(len(row['stages']) for row in data['entries']) == 14
    for fault in ['unseen', 'unconditional', 'duplicate', 'regression', 'grant', 'long', 'no_limit', 'version']:
        bad = copy.deepcopy(data)
        stage = bad['entries'][0]['stages'][0]
        if fault == 'unseen':
            stage['evidence_all'] = ['future_proof']
        elif fault == 'unconditional':
            stage['evidence_all'] = []
        elif fault == 'duplicate':
            bad['entries'].append(copy.deepcopy(bad['entries'][0]))
        elif fault == 'regression':
            bad['entries'][0]['stages'][1]['evidence_all'] = ['testimony_03']
        elif fault == 'grant':
            stage['grant_flags'] = ['fake']
        elif fault == 'long':
            stage['definition'] = '字' * 161
        elif fault == 'no_limit':
            del stage['limit']
        else:
            bad['version'] = True
        assert errors(bad, evidence), fault
    print('KNOWN_WORLD_TERMS_DATA_PASS concepts=8 stages=14 fault_cases=8')


if __name__ == '__main__':
    validate()
