#!/usr/bin/env python3
"""Run production GDScript in a small isolated native Godot project."""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DEPS = ['scripts/audio_director.gd', 'scripts/audio_retirement.gd', 'scripts/audio_volume_preferences.gd', 'scripts/duck_mix.gd', 'scripts/music_layer_phase.gd', 'scripts/npc_landmark_schedule.gd', 'scripts/room_reverb_mix.gd', 'scripts/spatial_enemy_alert.gd', 'scripts/reliability_98fd8e2f_r09_validation.gd']
MARKER = '^RELIABILITY_R09 checks=[1-9][0-9]* failures=0$'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='crimson-reliability-') as temporary:
        base = Path(temporary)
        project = base / 'project'; project.mkdir()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Reliability fixtures"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in DEPS:
            target = project/name;target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT/'godot'/name, target)
        env = dict(os.environ, XDG_DATA_HOME=str(base/'userdata'), APPDATA=str(base/'userdata'), GODOT_SILENCE_ROOT_WARNING='1')
        command = [args.engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://scripts/reliability_98fd8e2f_r09_validation.gd']
        imported = subprocess.run(command[:-2]+['--editor','--recovery-mode','--import','--quit'], env=env, capture_output=True, text=True, timeout=120)
        (args.log_dir/'import.log').write_text(imported.stdout+imported.stderr)
        if imported.returncode or re.search(r'^\s*(?:SCRIPT ERROR|ERROR):', imported.stdout+imported.stderr,re.M):
            print(imported.stdout+imported.stderr);return 1
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
            output = result.stdout+result.stderr
            good = result.returncode == 0
        except subprocess.TimeoutExpired as exc:
            output = str(exc)+'\nERROR: native fixture timeout\n';good = False
        (args.log_dir/'native.log').write_text(output)
        print(output, end='')
        good = good and re.search(MARKER, output, re.M) is not None
        good = good and re.search(r'(?:^\s*(?:SCRIPT ERROR|ERROR|USER ERROR):|ObjectDB instances leaked|Resources still in use)', output, re.M) is None
        return 0 if good else 1
if __name__=='__main__':raise SystemExit(main())
