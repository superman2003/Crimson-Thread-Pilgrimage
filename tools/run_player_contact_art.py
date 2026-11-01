#!/usr/bin/env python3
"""Freeze exact contact sources and run bounded CPU/native evidence with exact earned camp and explicit direct-damage component fixtures."""
from pathlib import Path
import argparse, gzip, hashlib, json, subprocess, time
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ['godot/scripts/player_controller.gd', 'godot/scripts/enemy_actor.gd', 'godot/scripts/player_melee_feedback.gd', 'godot/scripts/player_contact_art.gd', 'godot/scripts/player_contact_art_validation.gd', 'godot/scripts/player_contact_world_validation.gd', 'godot/scripts/player_dash_art_validation.gd', 'godot/scripts/combat_visual_policy.gd', 'godot/scripts/main_level.gd', 'godot/scripts/build_system.gd', 'godot/scripts/player_tool_effect.gd', 'godot/scripts/audio_retirement.gd', 'godot/scripts/world_ready_validation_helper.gd', 'godot/data/build_catalog.json', 'godot/assets/sprites/player/generated_hero_motion_v4/runtime_supplement/blade_anchors.json', 'artifacts/t04_obsidian_route/earned_camp_seed.json', 'artifacts/v04_contact_material/pre_player_controller.gd', 'artifacts/v04_contact_material/pre_enemy_actor.gd', 'artifacts/v04_contact_material/pre_player_melee_feedback.gd', 'artifacts/v04_contact_material/baseline_player_execution.gd', 'godot/assets/vfx/player_contact/player_contact.png', 'godot/assets/vfx/player_contact/player_contact.png.import', 'godot/assets/vfx/player_contact/manifest.json', 'tools/build_player_contact_art.py', 'tools/run_player_contact_art.py', 'tools/run_godot_regressions.py', 'tools/godot_suite_success_markers.json', 'tools/test_regression_runner.py', 'art_requests/combat_presentation_v2/incoming/delivery_status.json', 'godot/scripts/combat_visual_budget_validation.gd', 'godot/scripts/secondary_visual_budget_validation.gd', 'godot/scripts/enemy_effect_lifetime_validation.gd', 'godot/scripts/player_melee_feedback_validation.gd', 'godot/scripts/spike_pogo_validation.gd', 'godot/scripts/combat_resource_cycle_validation.gd']

def hashes():
    return {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in SOURCES}
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',required=True); parser.add_argument('--output',required=True)
    parser.add_argument('--reverse',action='store_true'); parser.add_argument('--native',action='store_true'); parser.add_argument('--suite', action='append'); args=parser.parse_args()
    output=ROOT/args.output; output.mkdir(parents=True,exist_ok=False)
    frozen=hashes(); (output/'source.json').write_text(json.dumps(frozen,indent=2)+'\n',encoding='utf8')
    results=[]
    suites=['player_contact_art','player_contact_world','player_melee_feedback','spike_pogo','combat_resource_cycle'] if not args.native else ['player_contact_art','player_contact_world']
    if args.suite: suites = args.suite
    for suite in suites:
        command=[args.engine,'--path',str(ROOT/'godot'),'--audio-driver','Dummy','--fixed-fps','60']
        command+=['--position','-32000,-32000','--rendering-method','gl_compatibility'] if args.native else ['--headless']
        command+=['--script','res://scripts/'+suite+'_validation.gd']
        if args.native and suite in ['player_contact_art','player_contact_world']: command+=['--','--output='+str(output)]
        if args.reverse:
            assert suite == 'player_contact_art'
            command+=['--','--contact-legacy']
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
