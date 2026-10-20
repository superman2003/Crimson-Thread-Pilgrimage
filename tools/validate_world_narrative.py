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
    chapters_by_region = {chapter['id'].removeprefix('demo_'): chapter for chapter in configs}
    assert data['schema_version'] == 2
    assert data['main_story']['optional_quests_required'] is False
    assert set(data['npcs']) == npc_ids, 'Every shipped NPC needs a localized ending response'
    assert {e['id'] for e in data['evidence']} == {f'testimony_{n:02}' for n in range(1, 7)}
    assert len({e['region'] for e in data['evidence']}) == 6
    for evidence in data['evidence']:
        assert evidence['independent'] is True
        assert set(evidence['items_any']) <= item_ids, f"Missing evidence source: {evidence['id']}"
        assert evidence['claim'] and evidence['location_hint']
        witness = evidence['scene_witness']
        chapter = chapters_by_region[evidence['region']]
        sources = [item for item in chapter.get('collectibles', []) if item['id'] == witness['collectible_id']]
        assert len(sources) == 1 and sources[0]['item_id'] in evidence['items_any'], 'Scene witness must name its actual collectible'
        assert sources[0]['room_id'] == witness['room'] and witness['room'] in rooms_by_region[evidence['region']], 'Scene hint drifted from shipped pickup room'
        assert witness['title'] and witness['text'] and witness['room_title']
    evidence_ids = {entry['id'] for entry in data['evidence']}
    link_ids = set()
    for link in data['evidence_links']:
        assert link['id'] not in link_ids and link['text']
        link_ids.add(link['id'])
        assert len(link['evidence_all']) >= 2 and len(set(link['evidence_all'])) == len(link['evidence_all'])
        assert set(link['evidence_all']) <= evidence_ids
    reward_flags: set[str] = set()
    count = 0
    for npc_id, npc in data['npcs'].items():
        assert npc['display_name'] and npc['region'] in chapters_by_region
        assert npc_id in {entry['id'] for entry in chapters_by_region[npc['region']]['npcs']}
        state_ids = [state['id'] for state in npc['states']]
        assert len(state_ids) == len(set(state_ids)), f'{npc_id}: duplicate state IDs'
        for ending_id, state_id in [('ending_a', 'aftermath_resound'), ('ending_b', 'aftermath_severed'), ('ending_c', 'aftermath_rewritten')]:
            aftermath = next(state for state in npc['states'] if state['id'] == state_id)
            assert aftermath['flags_all'] == [ending_id + '_done'] and not aftermath.get('grant_flags')
        for state in npc['states']:
            count += 1
            assert state['lines'] and all(isinstance(line, str) and line.strip() for line in state['lines'])
            assert len(state['lines']) <= 4, f'{npc_id}: interruptions should remain brief'
            assert not set(state.get('flags_all', [])) & set(state.get('flags_none', []))
            if state.get('continues_after_ending'):
                assert state.get('grant_flags') and not state['id'].startswith('aftermath_')
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
        assert set(ending['consequences']) <= {'world'} | set(data['npcs']), 'Consequences need player-facing NPC names'
        assert not any(flag.startswith('quest_') for flag in ending['consequence_flags'])
    # N05: every region shows what the chosen ending changed, at a real, visible shrine.
    scenes = data['aftermath_scenes']
    assert {scene['region'] for scene in scenes} == set(chapters_by_region) and len(scenes) == 6, 'One aftermath scene per region'
    for scene in scenes:
        assert scene['region_name'], f"{scene['region']}: aftermath needs a region name"
        shrines = [point for point in chapters_by_region[scene['region']].get('save_points', []) if point['id'] == scene['anchor']]
        assert len(shrines) == 1 and not shrines[0].get('hidden', False), f"{scene['region']}: aftermath must stand at a visible shrine"
        assert set(scene['endings']) == set(data['endings']), f"{scene['region']}: every ending changes this region"
        for ending_id, variant in scene['endings'].items():
            assert variant['look'] in {'bells', 'barrier', 'names'} and variant['line'] and variant['text'], f"{scene['region']}/{ending_id}: incomplete aftermath"
    print(f'WORLD_NARRATIVE_DATA_PASS npcs={len(data["npcs"])} states={count} evidence=6 rewards={len(reward_flags)} aftermath={len(scenes)}')


if __name__ == '__main__':
    validate()
