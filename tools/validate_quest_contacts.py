"""Check quest destinations against NPCs, pickup rooms and acquisition plans."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def errors(data, story, regions, routes):
    found = []
    quests = {row['id']: row for row in story['quests']}
    if type(data.get('version')) is not int or data['version'] != 1:
        found.append('contact schema version must be integer 1')
    if set(data.get('quests', {})) != set(quests):
        found.append('contacts must cover exactly the canonical optional quests')
    for key, title in data.get('places', {}).items():
        region_id, room_id = key.split(':', 1)
        room = next((room for room in regions.get(region_id, {}).get('map_rooms', []) if room['id'] == room_id), None)
        if room is None or title != room.get('name', room.get('title', room_id)):
            found.append(f'{key}: destination must use a real localized room')
    for npc_id, home in data.get('homes', {}).items():
        region = regions.get(home.get('region'), {})
        npc = next((row for row in region.get('npcs', []) if row['id'] == npc_id), None)
        if npc is None or npc_id not in story['npcs']:
            found.append(f'{npc_id}: contact must be a real narrative NPC')
            continue
        x, y = npc['position']
        hits = []
        for room in region['map_rooms']:
            a, b, width, height = room.get('play_rect') or room['layout_rect']
            if a <= x <= a + width and b <= y <= b + height:
                hits.append((width * height, room['id']))
        if not hits or home.get('room') != min(hits)[1]:
            found.append(f'{npc_id}: home disagrees with the actual NPC position')
        for state in story['npcs'][npc_id].get('world_states', []):
            if 'demo_' + state['region'] + ':' + state['room'] not in data['places']:
                found.append(f'{npc_id}: missing localized migration destination')
    for ability, plan in data.get('acquisitions', {}).items():
        if plan != routes['acquisition_plan'].get(ability):
            found.append(f'{ability}: acquisition guidance differs from the real pickup plan')
    for identity, context in data.get('quests', {}).items():
        if identity not in quests:
            continue
        quest = quests[identity]
        contact = story['npcs'].get(context.get('return_to'), {})
        if not any(state.get('reward_flag') == quest['reward_flag'] for state in contact.get('states', [])):
            found.append(f'{identity}: return contact does not own this quest reward')
        steps = context.get('steps', [])
        if len(steps) != len(quest['journal_steps']):
            found.append(f'{identity}: context must align with canonical journal steps')
        if not isinstance(context.get('completed_reason'), str) or not context['completed_reason'].strip():
            found.append(f'{identity}: reunion needs an authored explanation')
        for step, canonical in zip(steps, quest['journal_steps']):
            if sum(key in step for key in ['npc', 'room', 'ability']) != 1:
                found.append(f'{identity}: each objective needs exactly one target kind')
            if not isinstance(step.get('why'), str) or not 0 < len(step['why']) <= 160:
                found.append(f'{identity}: objectives need a short player-facing reason')
            if 'npc' in step and step['npc'] not in data['homes']:
                found.append(f'{identity}: unknown NPC target')
            if 'ability' in step and (step['ability'] not in canonical.get('abilities_all', []) or step['ability'] not in data['acquisitions']):
                found.append(f'{identity}: acquisition target does not satisfy this step')
            if 'room' in step:
                region = regions.get(step.get('region'), {})
                matching = [row for row in region.get('collectibles', []) if row.get('room_id') == step['room'] and row.get('item_id') in canonical.get('items_any', [])]
                if not matching:
                    found.append(f'{identity}: search destination contains none of the accepted items')
    return found


def validate():
    data = load('godot/data/quest_contacts.json')
    story = load('godot/data/world_narrative.json')
    routes = load('godot/data/world_routes.json')
    regions = {'demo_' + proof['region']: load('godot/data/demo_' + proof['region'] + '.json') for proof in story['evidence']}
    found = errors(data, story, regions, routes)
    assert not found, '\n'.join(found)
    for fault in ['reward', 'migration', 'acquisition', 'search', 'ambiguous']:
        broken = copy.deepcopy(data)
        if fault == 'reward':
            broken['quests']['root_rescue']['return_to'] = 'npc_beeswax_vendor'
        elif fault == 'migration':
            del broken['places']['demo_ch04_broken_string_greenhouse:west_gate']
        elif fault == 'acquisition':
            broken['acquisitions']['lantern_phase']['room_id'] = 'mirror_pool'
        elif fault == 'search':
            broken['quests']['wax_lamps']['steps'][0]['room'] = 'west_gate'
        else:
            broken['quests']['root_rescue']['steps'][0]['npc'] = 'npc_root_prisoner'
        assert errors(broken, story, regions, routes), f'undetected contact fault: {fault}'
    print(f'QUEST_CONTACTS_DATA_PASS quests={len(data["quests"])} steps=13 fault_cases=5')


if __name__ == '__main__':
    validate()
