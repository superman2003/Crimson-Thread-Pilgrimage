"""Keep post-ending return context bounded and tied to canonical quest IDs."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENDINGS = {'ending_a', 'ending_b', 'ending_c'}


def errors(data, quests):
    found = []
    if not isinstance(data, dict) or set(data) != {'version', 'quests'} or type(data.get('version')) not in (int, float) or data['version'] != 1:
        return ['invalid return-context envelope']
    if not isinstance(data['quests'], dict) or set(data['quests']) != quests:
        return ['return context must cover exactly the five canonical quests']
    for quest, row in data['quests'].items():
        if not isinstance(row, dict) or set(row) != ENDINGS:
            found.append(f'{quest}: exactly three ending contexts required')
            continue
        for ending, context in row.items():
            if not isinstance(context, dict) or set(context) != {'active', 'reunion'}:
                found.append(f'{quest}/{ending}: presentation cannot add progress fields')
                continue
            for key, value in context.items():
                if not isinstance(value, str) or not value.strip() or len(value) > 100 or '\n' in value:
                    found.append(f'{quest}/{ending}/{key}: invalid public context')
                elif any(internal in value for internal in ('npc_', 'quest_', 'demo_', 'ending_')):
                    found.append(f'{quest}/{ending}/{key}: internal identifier leaked')
    return found


def validate():
    story = json.loads((ROOT / 'godot/data/world_narrative.json').read_text())
    quests = {row['id'] for row in story['quests']}
    assert len(quests) == 5
    data = json.loads((ROOT / 'godot/data/ending_return_journal.json').read_text())
    assert not errors(data, quests), errors(data, quests)
    for fault in ['unknown_quest', 'missing_ending', 'grant', 'blank', 'long', 'newline', 'version', 'internal']:
        bad = copy.deepcopy(data)
        context = bad['quests']['root_rescue']['ending_b']
        if fault == 'unknown_quest':
            bad['quests']['hidden'] = bad['quests'].pop('root_rescue')
        elif fault == 'missing_ending':
            del bad['quests']['root_rescue']['ending_c']
        elif fault == 'grant':
            context['grant_flags'] = ['fake']
        elif fault == 'version':
            bad['version'] = True
        else:
            context['active'] = {'blank': ' ', 'long': '字' * 101, 'newline': '两\n行', 'internal': 'npc_root_prisoner'}[fault]
        assert errors(bad, quests), f'undetected return-context fault: {fault}'
    print('ENDING_RETURN_JOURNAL_DATA_PASS quests=5 endings=3 contexts=30 fault_cases=8')


if __name__ == '__main__':
    validate()
