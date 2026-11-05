"""Validate five relationships across three endings without adding quest rewards."""
import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENDINGS = {'ending_a': 'resound', 'ending_b': 'severed', 'ending_c': 'rewritten'}
NPCS = {'npc_threadsmith_apprentice', 'npc_root_prisoner', 'npc_beeswax_vendor',
        'npc_lantern_sister', 'npc_deserter_flagbearer'}


def errors(story):
    found = []
    quests = {row['id']: row for row in story['quests']}
    identities = set()
    total = 0
    for npc_id in NPCS:
        npc = story['npcs'][npc_id]
        rows = [state for state in npc['states'] if 'quest_coda' in state]
        if {row.get('ending') for row in rows} != set(ENDINGS) or len(rows) != 3:
            found.append(f'{npc_id}: one coda per selected ending is required')
        reflection = next(row for row in npc['states'] if row['id'].startswith('reflection_'))
        for row in rows:
            total += 1
            ending = row.get('ending')
            quest = quests.get(row.get('quest_coda'), {})
            if ending not in ENDINGS or row.get('id') != 'coda_' + ENDINGS[ending]:
                found.append(f'{npc_id}: invalid ending identity')
                continue
            if not quest or not any(state.get('reward_flag') == quest.get('reward_flag') for state in npc['states']):
                found.append(f'{npc_id}: personal coda belongs to another relationship')
            needed = set(row.get('flags_all', []))
            if not set(reflection['flags_all']) <= needed:
                found.append(f'{npc_id}: coda cannot precede the committed quest, reward or relocation')
            if needed & {key + '_done' for key in ENDINGS} != {ending + '_done'}:
                found.append(f'{npc_id}: opposing ending prerequisites are ambiguous')
            markers = row.get('grant_flags', [])
            if len(markers) != 1 or not markers[0].startswith('story_coda_') or markers[0] in identities:
                found.append(f'{npc_id}: coda needs one unique persistent narrative identity')
            identities.update(markers)
            if row.get('flags_none') != markers or row.get('continues_after_ending') is not True:
                found.append(f'{npc_id}: coda must be a fresh, explicitly authored post-ending continuation')
            if row.get('grant_rewards') or row.get('reward_flag'):
                found.append(f'{npc_id}: completed quest cannot be paid again')
            if not 2 <= len(row.get('lines', [])) <= 3 or any(not isinstance(line, str) or not line.strip() or len(line) > 120 for line in row.get('lines', [])):
                found.append(f'{npc_id}: personal conversation must remain brief and explicit')
            response = row.get('response')
            if not isinstance(response, str) or not response.startswith('你') or len(response) > 48 or '\n' in response or row.get('response_mode') != 'gesture':
                found.append(f'{npc_id}: a short protagonist gesture must retain the quiet voice boundary')
    if total != 15:
        found.append('exactly fifteen new personal endings are required')
    return found


def validate():
    story = json.loads((ROOT / 'godot/data/world_narrative.json').read_text())
    found = errors(story)
    assert not found, '\n'.join(found)
    source = (ROOT / 'godot/scripts/npc_recollections.gd').read_text()
    capacity = int(re.search(r'^const MAX_STATES := (\d+)', source, re.M)[1])
    for npc_id in NPCS:
        npc = story['npcs'][npc_id]
        chapter = json.loads((ROOT / ('godot/data/demo_' + npc['region'] + '.json')).read_text())
        local = next(row for row in chapter['npcs'] if row['id'] == npc_id)
        count = len(npc['states']) + 1 + len(local.get('story_dialogue', {}))
        assert count <= capacity, f'{npc_id}: new codas would truncate existing local recollections'
    for fault in ['ending', 'reward_gate', 'double_pay', 'identity', 'long_response']:
        bad = copy.deepcopy(story)
        row = bad['npcs']['npc_root_prisoner']['states'][0]
        if fault == 'ending':
            row['flags_all'][-1] = 'ending_b_done'
        elif fault == 'reward_gate':
            row['flags_all'].remove('reward_root_rescue_claimed')
        elif fault == 'double_pay':
            row['grant_rewards'] = {'currency': 45}
        elif fault == 'identity':
            row['grant_flags'] = []
        else:
            row['response'] = '你' * 49
        assert errors(bad), f'undetected personal-ending fault: {fault}'
    print('PERSONAL_CODAS_DATA_PASS relationships=5 endings=3 codas=15 fault_cases=5')


if __name__ == '__main__':
    validate()
