#!/usr/bin/env python3
"""Freeze exact ability sources and run bounded CPU/native evidence with exact earned camp and explicit direct-damage component fixtures."""
from pathlib import Path
import argparse, gzip, hashlib, json, subprocess, time
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ['godot/scripts/player_controller.gd', 'godot/scripts/player_ability_art.gd', 'godot/scripts/player_ability_art_validation.gd', 'godot/scripts/player_ability_world_validation.gd', 'godot/scripts/player_dash_art_validation.gd', 'godot/scripts/combat_visual_policy.gd', 'godot/scripts/main_level.gd', 'godot/scripts/build_system.gd', 'godot/data/build_catalog.json', 'artifacts/t04_obsidian_route/earned_camp_seed.json', 'artifacts/v04_ability_material/pre_ability_player_controller.gd', 'godot/assets/vfx/player_ability/player_ability.png', 'godot/assets/vfx/player_ability/player_ability.png.import', 'godot/assets/vfx/player_ability/manifest.json', 'tools/build_player_ability_art.py', 'tools/run_player_ability_art.py', 'tools/run_godot_regressions.py', 'tools/godot_suite_success_markers.json', 'tools/test_regression_runner.py', 'art_requests/combat_presentation_v2/incoming/delivery_status.json', 'godot/scripts/player_resonance_world_validation.gd', 'godot/data/world_routes.json','artifacts/t04_bride_retry/earned_bride_seed.json', 'godot/scripts/world_obsidian_tower_playback.gd', 'godot/scripts/world_obsidian_earned_playback.gd', 'godot/scripts/world_greenhouse_vault_playback.gd', 'godot/scripts/world_greenhouse_route_playback.gd', 'godot/scripts/world_archive_lower_playback.gd', 'godot/scripts/world_archive_ascent_playback.gd', 'godot/scripts/world_waterwheel_route_playback.gd', 'godot/scripts/world_damage_route_playback.gd']

def hashes():
    return {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in SOURCES}
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',required=True); parser.add_argument('--output',required=True)
    parser.add_argument('--reverse',action='store_true'); parser.add_argument('--native',action='store_true'); parser.add_argument('--suite', action='append'); args=parser.parse_args()
    output=ROOT/args.output; output.mkdir(parents=True,exist_ok=False)
    frozen=hashes(); (output/'source.json').write_text(json.dumps(frozen,indent=2)+'\n',encoding='utf8')
    results=[]
    suites=['player_ability_art','player_ability_world','player_resonance_world','ability_movement','spike_pogo','player_state_cleanup','combat_resource_cycle'] if not args.native else ['player_ability_art','player_ability_world','player_resonance_world']
    if args.suite: suites = args.suite
    for suite in suites:
        command=[args.engine,'--path',str(ROOT/'godot'),'--audio-driver','Dummy','--fixed-fps','60']
        command+=['--position','-32000,-32000','--rendering-method','gl_compatibility'] if args.native else ['--headless']
        command+=['--script','res://scripts/'+suite+'_validation.gd']
        if args.native and suite in ['player_ability_art','player_ability_world','player_resonance_world']: command+=['--','--output='+str(output)]
        if args.reverse:
            assert suite == 'player_ability_art'
            command+=['--','--ability-player-script=res://../artifacts/v04_ability_material/pre_ability_player_controller.gd']
        start=time.monotonic(); timed_out=False
        try:
            process=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
            raw=process.stdout; code=process.returncode
        except subprocess.TimeoutExpired as ex:
            raw=ex.stdout or b''; code=None; timed_out=True
        (output/(suite+'.log')).write_bytes(raw)
        (output/(suite+'.log.gz')).write_bytes(gzip.compress(raw,mtime=0))
        text=raw.decode('utf8',errors='replace'); clean=not any(token in text for token in ['ERROR:','SCRIPT ERROR:','WARNING:'])
        results.append(dict(suite=suite,returncode=code,timeout=timed_out,clean=clean,raw_bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),seconds=round(time.monotonic()-start,3)))
        print(suite,code,'clean='+str(clean),flush=True)
        assert hashes()==frozen, 'source changed during engine execution'
    (output/'result.json').write_text(json.dumps(dict(results=results,source_unchanged=hashes()==frozen),indent=2)+'\n',encoding='utf8')
    if args.reverse:
        assert all(item['returncode']==1 and not item['timeout'] for item in results)
        return
    assert all(item['returncode']==0 and item['clean'] and not item['timeout'] for item in results), results
if __name__=='__main__':main()
