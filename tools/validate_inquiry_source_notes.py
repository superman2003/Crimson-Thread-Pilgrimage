"""Audit speakers and linkable sources across live and published inquiry versions."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROOFS = {f'testimony_{number:02}' for number in range(1, 7)}


def errors(entries, speakers, histories):
    found = []
    for entry in entries:
        if entry.get('npc') not in speakers or not speakers.get(entry.get('npc'), '').strip():
            found.append('confirmed speech needs a shipped localized speaker')
        sources = entry.get('requires', []) + entry.get('continuation', {}).get('requires', [])
        if len(sources) > 12:
            found.append('source window bound exceeded')
        for source in sources:
            if source.get('kind') not in {'item', 'history', 'flag'} or not isinstance(source.get('id'), str):
                found.append('invalid recorded source type')
            elif source['kind'] == 'history' and source['id'] not in histories:
                found.append('published observation source no longer exists')
            elif source['kind'] == 'item' and source['id'].startswith('testimony_') and source['id'] not in PROOFS:
                found.append('an alias cannot masquerade as another independent testimony')
    return found


def validate():
    story = json.loads((ROOT / 'godot/data/world_narrative.json').read_text())
    speakers = {key: row['display_name'] for key, row in story['npcs'].items()}
    histories = {row['id'] for row in json.loads((ROOT / 'godot/data/scene_history.json').read_text())['entries']}
    entries = []
    for folder in ['inquiries', 'inquiry_archive']:
        for file in sorted((ROOT / 'godot/data' / folder).glob('*.json')):
            entries.extend(json.loads(file.read_text())['entries'])
    assert not errors(entries, speakers, histories), errors(entries, speakers, histories)
    for fault in ['speaker', 'history', 'proof', 'kind', 'bound']:
        bad = copy.deepcopy(entries)
        row = bad[0]
        if fault == 'speaker':
            row['npc'] = 'unknown_person'
        elif fault == 'history':
            row['requires'] = [{'kind': 'history', 'id': 'future_room'}]
        elif fault == 'proof':
            row['requires'] = [{'kind': 'item', 'id': 'testimony_99'}]
        elif fault == 'kind':
            row['requires'] = [{'kind': 'command', 'id': 'run'}]
        else:
            row['requires'] *= 13
        assert errors(bad, speakers, histories), fault
    versions = sum(1 + int('continuation' in row) for row in entries)
    print(f'INQUIRY_SOURCE_NOTES_DATA_PASS entries={len(entries)} versions={versions} fault_cases=5')


if __name__ == '__main__':
    validate()
