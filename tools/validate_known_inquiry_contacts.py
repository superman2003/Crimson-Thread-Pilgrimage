"""Check all known-speaker destinations against authored room geometry."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def containing_room(chapter, point):
    x, y = point
    best, best_area = '', float('inf')
    for room in chapter['map_rooms']:
        rects = [room.get('layout_rect', room.get('play_rect', []))] + room.get('visit_rects', [])
        for rect in rects:
            if not isinstance(rect, list) or len(rect) < 4:
                continue
            rx, ry, width, height = rect[:4]
            if width > 0 and height > 0 and rx <= x <= rx + width and ry <= y <= ry + height and width * height < best_area:
                best, best_area = room['id'], width * height
    return best


def errors(data, story, chapters):
    if not isinstance(data, dict) or set(data) != {'version', 'homes'} or type(data.get('version')) not in (int, float) or data['version'] != 1:
        return ['invalid speaker-contact envelope']
    if not isinstance(data['homes'], dict) or set(data['homes']) != set(story['npcs']):
        return ['exactly the shipped twenty-five speakers are required']
    found = []
    for npc, home in data['homes'].items():
        if not isinstance(home, dict) or set(home) != {'region', 'room'}:
            found.append(f'{npc}: home cannot grant progress')
            continue
        region = 'demo_' + story['npcs'][npc]['region']
        if home['region'] != region or region not in chapters:
            found.append(f'{npc}: wrong source region')
            continue
        chapter = chapters[region]
        actor = next((row for row in chapter['npcs'] if row['id'] == npc), None)
        if not actor or home['room'] != containing_room(chapter, actor['position']):
            found.append(f'{npc}: destination differs from the nested production room')
    return found


def validate():
    story = json.loads((ROOT / 'godot/data/world_narrative.json').read_text())
    chapters = {('demo_' + guardian['region']): json.loads((ROOT / ('godot/data/demo_' + guardian['region'] + '.json')).read_text()) for guardian in story['guardians']}
    data = json.loads((ROOT / 'godot/data/known_inquiry_contacts.json').read_text())
    assert not errors(data, story, chapters), errors(data, story, chapters)
    for fault in ['unknown', 'region', 'outer_room', 'room', 'grant', 'version']:
        bad = copy.deepcopy(data)
        home = bad['homes']['npc_broken_singer']
        if fault == 'unknown':
            bad['homes']['unknown'] = bad['homes'].pop('npc_broken_singer')
        elif fault == 'region':
            home['region'] = 'demo_ch01_moss_bell_court'
        elif fault == 'outer_room':
            home['room'] = 'tree_crown'
        elif fault == 'room':
            home['room'] = 'future_room'
        elif fault == 'grant':
            home['grant_flags'] = ['fake']
        else:
            bad['version'] = True
        assert errors(bad, story, chapters), fault
    print('KNOWN_INQUIRY_CONTACTS_DATA_PASS speakers=25 regions=6 fault_cases=6')


if __name__ == '__main__':
    validate()
