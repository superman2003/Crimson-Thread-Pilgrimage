"""Check narrative IDs against shipped chapter entities and reachable state contracts."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot/data/world_narrative.json'


def validate() -> None:
    data = json.loads(DATA.read_text(encoding='utf-8'))
    configs = [json.loads(path.read_text(encoding='utf-8')) for path in (ROOT / 'godot/data').glob('demo_ch0[1-6]_*.json') if 'boss_trial' not in path.name]
    npc_ids = {npc['id'] for chapter in configs for npc in chapter.get('npcs', [])}
    item_ids = {item['item_id'] for chapter in configs for item in chapter.get('collectibles', [])}
    rooms_by_region = {chapter['id'].removeprefix('demo_'): {room['id'] for room in chapter.get('map_rooms', [])} for chapter in configs}
    assert data['schema_version'] == 2
    assert data['main_story']['optional_quests_required'] is False
    assert set(data['npcs']) <= npc_ids, 'Narrative must use actual runtime NPC IDs'
    assert {e['id'] for e in data['evidence']} == {f'testimony_{n:02}' for n in range(1, 7)}
    assert len({e['region'] for e in data['evidence']}) == 6
    for evidence in data['evidence']:
        assert evidence['independent'] is True
        assert set(evidence['items_any']) <= item_ids, f"Missing evidence source: {evidence['id']}"
        assert evidence['claim'] and evidence['location_hint']
    reward_flags: set[str] = set()
    count = 0
    for npc_id, npc in data['npcs'].items():
        state_ids = [state['id'] for state in npc['states']]
        assert len(state_ids) == len(set(state_ids)), f'{npc_id}: duplicate state IDs'
        for state in npc['states']:
            count += 1
            assert state['lines'] and all(isinstance(line, str) and line.strip() for line in state['lines'])
            assert len(state['lines']) <= 4, f'{npc_id}: interruptions should remain brief'
            assert not set(state.get('flags_all', [])) & set(state.get('flags_none', []))
            if state.get('grant_rewards'):
                marker = state.get('reward_flag')
                assert marker and marker not in reward_flags, 'Every reward needs a unique persistent claim marker'
                reward_flags.add(marker)
                assert state.get('grant_flags'), 'Reward must complete a real quest state'
                assert all(isinstance(value, int) and value > 0 for value in state['grant_rewards'].values())
        for state in npc.get('world_states', []):
            assert state['room'] in rooms_by_region[state['region']], f"{npc_id}: missing relocation room {state['room']}"
    for ending_id, ending in data['endings'].items():
        assert ending_id in {'ending_a', 'ending_b', 'ending_c'}
        assert ending['requires_evidence'] == (ending_id == 'ending_c')
        assert ending['message'] and ending['consequence_flags'] and ending['consequences']
        assert not any(flag.startswith('quest_') for flag in ending['consequence_flags'])
    print(f'WORLD_NARRATIVE_DATA_PASS npcs={len(data["npcs"])} states={count} evidence=6 rewards={len(reward_flags)}')


if __name__ == '__main__':
    validate()
