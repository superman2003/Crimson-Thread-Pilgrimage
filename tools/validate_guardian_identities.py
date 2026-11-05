"""Bind post-fight recognition to shipped speakers and immutable spoken lines."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def errors(data, topics, story):
    found = []
    if not isinstance(data, dict) or set(data) != {'version', 'entries'} or type(data.get('version')) not in (int, float) or data['version'] != 1:
        return ['invalid recognition envelope']
    if not isinstance(data['entries'], list) or len(data['entries']) != 6:
        return ['six regional recognitions required']
    regions = {row['region'] for row in story['guardians']}
    ids = set()
    seen_regions = set()
    for row in data['entries']:
        if not isinstance(row, dict) or set(row) != {'id', 'region', 'boss_flag', 'title', 'accounts', 'recognition', 'limit'}:
            found.append('recognition is presentation only')
            continue
        region = row['region'].removeprefix('demo_') if isinstance(row['region'], str) else ''
        if region not in regions or region in seen_regions:
            found.append('invalid or duplicate region')
        seen_regions.add(region)
        if row['id'] in ids or row['id'] != 'chapter_' + region[2:4] or row['boss_flag'] != 'boss_down_' + region[:4]:
            found.append('recognition cannot bind a different fight')
        ids.add(row['id'])
        for field in ['title', 'recognition', 'limit']:
            value = row[field]
            if not isinstance(value, str) or not value.strip() or len(value) > 180 or '\n' in value:
                found.append('unbounded recognition text')
        if not isinstance(row['accounts'], list) or not 1 <= len(row['accounts']) <= 3:
            found.append('recognition requires confirmed testimony')
            continue
        used = set()
        for account in row['accounts']:
            if not isinstance(account, dict) or set(account) != {'inquiry', 'lines'} or account.get('inquiry') not in topics:
                found.append('unknown or malformed account')
                continue
            topic = topics[account['inquiry']]
            if account['inquiry'] in used or story['npcs'][topic['npc']]['region'] != region:
                found.append('duplicate or wrong-region speaker')
            used.add(account['inquiry'])
            if not isinstance(account['lines'], list) or not 1 <= len(account['lines']) <= 2 or any(line not in topic['lines'] for line in account['lines']):
                found.append('recognition requires exact existing base speech')
    return found


def validate():
    data = json.loads((ROOT / 'godot/data/guardian_identities.json').read_text())
    story = json.loads((ROOT / 'godot/data/world_narrative.json').read_text())
    topics = {row['id']: row for file in (ROOT / 'godot/data/inquiries').glob('*.json') for row in json.loads(file.read_text())['entries']}
    assert not errors(data, topics, story), errors(data, topics, story)
    for fault in ['fight', 'region', 'unheard', 'future', 'duplicate', 'grant', 'blank', 'version']:
        bad = copy.deepcopy(data)
        row = bad['entries'][1]
        if fault == 'fight':
            row['boss_flag'] = 'boss_down_ch01'
        elif fault == 'region':
            row['accounts'][0]['inquiry'] = 'chapter_04_02'
        elif fault == 'unheard':
            row['accounts'][0]['lines'] = ['unpublished answer']
        elif fault == 'future':
            row['accounts'][0]['lines'] = topics['chapter_02_02']['continuation']['lines'][:1]
        elif fault == 'duplicate':
            row['accounts'].append(copy.deepcopy(row['accounts'][0]))
        elif fault == 'grant':
            row['grant_flags'] = ['fake']
        elif fault == 'blank':
            row['limit'] = ' '
        else:
            bad['version'] = True
        assert errors(bad, topics, story), fault
    print('GUARDIAN_IDENTITIES_DATA_PASS regions=6 topics=9 fault_cases=8')


if __name__ == '__main__':
    validate()
