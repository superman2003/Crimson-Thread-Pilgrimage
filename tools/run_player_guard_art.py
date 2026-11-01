#!/usr/bin/env python3
"""Freeze exact guard sources and run bounded CPU/native evidence without player saves."""
from pathlib import Path
import argparse, gzip, hashlib, json, subprocess, time
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ['godot/scripts/player_controller.gd', 'godot/scripts/player_guard_art.gd', 'godot/scripts/player_guard_art_validation.gd', 'godot/scripts/player_guard_art_capture_validation.gd', 'godot/scripts/player_guard_world_validation.gd', 'artifacts/t04_obsidian_route/earned_camp_seed.json', 'godot/assets/vfx/player_guard/player_guard.png', 'godot/assets/vfx/player_guard/manifest.json', 'tools/build_player_guard_art.py', 'tools/run_player_guard_art.py', 'tools/run_godot_regressions.py', 'tools/godot_suite_success_markers.json', 'tools/test_regression_runner.py']
def hashes():
    return {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in SOURCES}
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',required=True); parser.add_argument('--output',required=True)
    parser.add_argument('--native',action='store_true'); parser.add_argument('--suite', action='append'); args=parser.parse_args()
    output=ROOT/args.output; output.mkdir(parents=True,exist_ok=False)
    frozen=hashes(); (output/'source.json').write_text(json.dumps(frozen,indent=2)+'\n',encoding='utf8')
    results=[]
    suites=['player_guard_art','player_state_cleanup','ui_build_accessibility'] if not args.native else ['player_guard_art','player_guard_art_capture','seal_combat','combat_visual_budget']
    if args.suite: suites = args.suite
    for suite in suites:
        command=[args.engine,'--path',str(ROOT/'godot'),'--audio-driver','Dummy','--fixed-fps','60']
        command+=['--position','-32000,-32000','--rendering-method','gl_compatibility'] if args.native else ['--headless']
        command+=['--script','res://scripts/'+suite+'_validation.gd']
        if suite.endswith('_capture') or suite == 'player_guard_world': command+=['--','--output='+str(output)]
        start=time.monotonic(); timed_out=False
        try:
            process=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
            raw=process.stdout; code=process.returncode
        except subprocess.TimeoutExpired as ex:
            raw=ex.stdout or b''; code=None; timed_out=True
        (output/(suite+'.log')).write_bytes(raw)
        (output/(suite+'.log.gz')).write_bytes(gzip.compress(raw,mtime=0))
        text=raw.decode('utf8',errors='replace'); clean=not any(token in text for token in ['ERROR:','SCRIPT ERROR:','WARNING:'])
        results.append(dict(suite=suite,returncode=code,timeout=timed_out,clean=clean,seconds=round(time.monotonic()-start,3)))
        print(suite,code,'clean='+str(clean),flush=True)
        assert hashes()==frozen, 'source changed during engine execution'
    (output/'result.json').write_text(json.dumps(dict(results=results,source_unchanged=hashes()==frozen),indent=2)+'\n',encoding='utf8')
    assert all(item['returncode']==0 and item['clean'] and not item['timeout'] for item in results), results
if __name__=='__main__':main()
