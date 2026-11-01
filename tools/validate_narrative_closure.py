"""Validate canon, story sources and ending callbacks."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def validate():
    journey = read('godot/data/narrative_journey.json')
    story = read('godot/data/world_narrative.json')
    assert journey['version'] == 1
    canon = journey['canon']
    assert canon['present_year'] - canon['hush_year'] == canon['silent_years'] == 65
    evidence = {row['id'] for row in story['evidence']}
    flags = {flag for npc in story['npcs'].values() for state in npc['states']
             for key in ['grant_flags', 'flags_all', 'flags_none']
             for flag in state.get(key, [])}
    ids = set()
    for row in journey['reflections']:
        assert row['id'] not in ids
        ids.add(row['id'])
        assert row.get('evidence_all') or row.get('flags_all'), 'No unconditional plot revelations'
        assert set(row.get('evidence_all', [])) <= evidence
        assert set(row.get('flags_all', [])) <= flags
        assert all(isinstance(row[key], str) and row[key].strip() for key in ['title', 'text', 'question'])
    assert set(journey['endings']) == set(story['endings'])
    for ending in journey['endings'].values():
        assert set(ending['decision']) == {'action', 'promise', 'cost', 'question'}
        assert all(ending['decision'].values())
        assert len([row for row in ending['scenes'] if not row.get('flags_all')]) == 3
        for row in ending['scenes']:
            assert all(isinstance(row[key], str) and row[key].strip() for key in ['title', 'text', 'response'])
            assert set(row.get('flags_all', [])) <= flags
    print(f'NARRATIVE_CLOSURE_DATA_PASS reflections={len(ids)} relationships=5 endings=3')



if __name__ == '__main__':
    validate()
