"""Native GL acceptance for the complete production cloth-thread protagonist."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SUITES=['hero_animation','grounded_run','player_motion_continuity','player_idle_motion',
        'character_art_prewarm','player_basic_attack_vfx','player_melee_feedback',
        'player_hook_art','player_dash_art','player_hurt_art','player_heal_art',
        'player_guard_art','player_ability_art','player_contact_art','seal_combat',
        'combat_visual_budget','ability_movement','camera_focus','room_camera_stability',
        'audio_construction','audio_retirement','ai_music_pack']
CLOCKED={'grounded_run','player_motion_continuity','player_idle_motion','character_art_prewarm',
         'player_basic_attack_vfx','player_melee_feedback','player_contact_art','ability_movement',
         'camera_focus','room_camera_stability'}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--engine',required=True)
    p.add_argument('--suite',action='append',choices=SUITES)
    p.add_argument('--output',type=Path,default=ROOT/'artifacts/thread_doll_v1/native')
    a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    markers=json.loads((ROOT/'tools/godot_suite_success_markers.json').read_text())
    records=[]
    with tempfile.TemporaryDirectory(prefix='doll-native-',dir=a.output) as scratch:
        for suite in a.suite or SUITES:
            cmd=[a.engine,'--path',str(ROOT/'godot'),'--rendering-method','gl_compatibility',
                 '--audio-driver','Dummy','--script',f'res://scripts/{suite}_validation.gd']
            if suite in CLOCKED:cmd+=['--fixed-fps','60']
            if suite=='room_camera_stability':cmd+=['--','--player']
            env=dict(os.environ,APPDATA=str(Path(scratch)/suite),XDG_DATA_HOME=str(Path(scratch)/suite))
            r=subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',
                             timeout=240,env=env,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            output=r.stdout+'\n'+r.stderr
            (a.output/(suite+'.log')).write_text(output,encoding='utf-8')
            errors=re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$',output,re.M)
            marker=re.search(markers[suite],output,re.M)
            ok=r.returncode==0 and not errors and marker is not None and 'OpenGL API' in output
            records.append(dict(suite=suite,passed=ok,marker=marker.group(0) if marker else None,errors=errors))
            (a.output/'verification.json').write_text(json.dumps({'results':records},indent=2)+'\n',encoding='utf-8')
            print(suite,'PASS' if ok else 'FAIL',records[-1]['marker'],flush=True)
            if not ok:
                print(output[-4000:]);return 1
    return 0

if __name__=='__main__':raise SystemExit(main())
