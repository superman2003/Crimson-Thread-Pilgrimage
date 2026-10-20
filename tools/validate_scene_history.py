#!/usr/bin/env python3
"""Validate authored, floor-supported environment observations against current source data."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot/data'


def validate():
    notes = json.loads((DATA/'scene_history.json').read_text(encoding='utf-8'))
    story = json.loads((DATA/'world_narrative.json').read_text(encoding='utf-8'))
    proofs = {row['id']: row for row in story['evidence']}
    assert notes['version'] == 1 and len(notes['entries']) == 12
    rendered_looks = set(re.findall(r'^        "([a-z_]+)":$', (ROOT/'godot/scripts/scene_history_prop.gd').read_text(encoding='utf-8'), re.MULTILINE))
    ids = set()
    roles = {}
    looks = set()
    witnesses = set()
    for row in notes['entries']:
        assert row['id'] not in ids
        ids.add(row['id'])
        looks.add(row['look'])
        assert row['look'] in rendered_looks, 'authored artifact needs an implemented renderer'
        assert row['role'] in ['daily', 'witness']
        assert len(row['position']) == 2 and all(isinstance(x, (int,float)) for x in row['position'])
        roles.setdefault(row['region_id'], []).append(row['role'])
        region = json.loads((DATA/(row['region_id']+'.json')).read_text(encoding='utf-8'))
        room = next(room for room in region['map_rooms'] if room['id'] == row['room_id'])
        floor = next(floor for floor in region['platforms'] if floor['id'] == row['floor_id'])
        x,y = row['position']
        fx,fy,fw,_ = floor['rect']
        rx,ry,rw,rh = room['layout_rect']
        assert fx+45 <= x <= fx+fw-45 and y+32 == fy, row['id']+' unsupported floor anchor'
        assert rx <= x <= rx+rw and ry <= y <= ry+rh, row['id']+' outside authored room'
        assert row['room_title'] == room['name']
        if row['role'] == 'witness':
            proof = proofs[row['evidence_id']]
            assert proof['scene_witness']['room'] == row['room_id']
            assert proof['region'] == row['region_id'].removeprefix('demo_')
            assert row['evidence_id'] not in witnesses
            witnesses.add(row['evidence_id'])
            assert 'title' not in row and 'text' not in row, 'witness text has one canonical source'
        else:
            assert len(row['title']) >= 4 and len(row['text']) >= 60
            assert any('一' <= c <= '鿿' for c in row['text'])
    assert len(roles) == 6 and all(sorted(value) == ['daily', 'witness'] for value in roles.values())
    assert len(looks) == 12 and witnesses == set(proofs)
    print('SCENE_HISTORY_DATA_PASS regions=6 artifacts=12 witnesses=6 floor_anchors=12')


if __name__ == '__main__':
    validate()
