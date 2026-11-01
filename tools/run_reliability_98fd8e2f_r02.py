#!/usr/bin/env python3
"""Run production GDScript in a small isolated native Godot project."""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DEPS = ['scripts/settings_profiles.gd', 'scripts/settings_profile_codec.gd', 'scripts/controller_preferences.gd', 'scripts/input_binding_policy.gd', 'scripts/input_prompt_bindings.gd', 'scripts/journey_desk_store.gd', 'scripts/settings_persistence.gd', 'scripts/preference_file_transaction.gd', 'scripts/reliability_98fd8e2f_r02_validation.gd']
MARKER = '^RELIABILITY_R02 checks=[1-9][0-9]* failures=0$'

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
        command = [args.engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://scripts/reliability_98fd8e2f_r02_validation.gd']
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
            output = result.stdout+result.stderr
            good = result.returncode == 0
        except subprocess.TimeoutExpired as exc:
            output = str(exc)+'\nERROR: native fixture timeout\n';good = False
        (args.log_dir/'native.log').write_text(output)
        print(output, end='')
        good = good and re.search(MARKER, output, re.M) is not None
        good = good and re.search(r'^\s*(?:SCRIPT ERROR|ERROR|USER ERROR):', output, re.M) is None
        return 0 if good else 1
if __name__=='__main__':raise SystemExit(main())
