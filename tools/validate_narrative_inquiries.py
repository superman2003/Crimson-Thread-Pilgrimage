#!/usr/bin/env python3
"""Resolve inquiry sources against shipped content, never against a hand copy."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot/data'


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def authorities():
    story = load(DATA / 'world_narrative.json')
    chapters = [load(p) for p in DATA.glob('demo_ch0[1-6]_*.json')
                if 'boss_trial' not in p.name]
    npcs = {row['id']: row for chapter in chapters for row in chapter.get('npcs', [])}
    items = {row['item_id'] for chapter in chapters for row in chapter.get('collectibles', [])}
    history = {row['id']: row for row in load(DATA / 'scene_history.json')['entries']}
    # Production scripts and authored chapter/NPC states own these flags.
    text = '\n'.join(p.read_text(encoding='utf-8') for p in (ROOT / 'godot/scripts').glob('*.gd')
                     if not p.name.startswith('narrative_inquir') and not p.name.endswith('_validation.gd'))
    text += json.dumps(story)
    text += '\n'.join(json.dumps(chapter) for chapter in chapters)
    flags = set(re.findall(r'\b(?:quest_|boss_down_|heard_|seal_|ending_|npc_)[a-z0-9_]+', text))
    flags |= {f'boss_down_ch{n:02}' for n in range(1, 7)}
    flags |= {f'ending_{c}_done' for c in 'abc'}
    return npcs, items, history, flags


def validate_source(source, known):
    assert isinstance(source, dict) and set(source) == {'kind', 'id', 'label'}
    assert source['kind'] in ('item', 'history', 'flag')
    assert isinstance(source['label'], str) and source['label'].strip()
    _, items, history, flags = known
    assert source['id'] in {'item': items, 'history': history, 'flag': flags}[source['kind']], source
    assert len(source['label']) <= 48


def validate_entry(row, known):
    assert isinstance(row, dict)
    assert set(row) <= {'id', 'npc', 'question', 'requires', 'lines', 'reflection', 'continuation'}
    assert re.fullmatch('[a-z][a-z0-9_]{1,79}', row['id'])
    assert row['npc'] in known[0], row['npc']
    for key, limit in [('question', 48), ('reflection', 160)]:
        assert isinstance(row[key], str) and 3 <= len(row[key].strip()) <= limit
    for part in [row] + ([row['continuation']] if 'continuation' in row else []):
        assert isinstance(part['requires'], list) and 1 <= len(part['requires']) <= 6
        identities = []
        for source in part['requires']:
            validate_source(source, known)
            identities.append((source['kind'], source['id']))
        assert len(identities) == len(set(identities)), row['id']
        assert 2 <= len(part['lines']) <= 8
        assert all(isinstance(line, str) and 8 <= len(line.strip()) <= 360 for line in part['lines'])
    if 'continuation' in row:
        assert set(row['continuation']) == {'requires', 'lines'}
        assert len(row['lines']) + len(row['continuation']['lines']) <= 8
        assert not {(s['kind'], s['id']) for s in row['requires']} & {
            (s['kind'], s['id']) for s in row['continuation']['requires']}, row['id']


def validate():
    known = authorities()
    ids = set()
    files = sorted((DATA / 'inquiries').glob('*.json'))
    assert 1 <= len(files) <= 16
    questions = set()
    lines = set()
    for path in files:
        data = load(path)
        assert set(data) == {'version', 'entries'} and type(data['version']) is int and data['version'] == 1
        assert data['entries'], path
        for row in data['entries']:
            validate_entry(row, known)
            assert row['id'] not in ids, row['id']
            ids.add(row['id'])
            key = (row['npc'], row['question'])
            assert key not in questions, key
            questions.add(key)
            for part in [row] + ([row['continuation']] if 'continuation' in row else []):
                for line in part['lines']:
                    assert line not in lines, ('repeated dialogue', row['id'])
                    lines.add(line)
    assert len(ids) <= 256
    archive_files = sorted((DATA / 'inquiry_archive').glob('*.json'))
    assert len(archive_files) <= 16
    archive_count = 0
    for path in archive_files:
        archive = load(path)
        assert set(archive) == {'version', 'entries'} and type(archive['version']) is int and archive['version'] == 1
        for row in archive['entries']:
            validate_entry(row, known)
            archive_count += 1
    assert archive_count <= 256
    print(f'NARRATIVE_INQUIRIES_DATA_PASS files={len(files)} questions={len(ids)} lines={len(lines)} archived={archive_count}')


if __name__ == '__main__':
    validate()
