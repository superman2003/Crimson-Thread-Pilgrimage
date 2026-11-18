#!/usr/bin/env python3
"""Run production GDScript in a small isolated native Godot project."""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DEPS = ['scripts/ui_type_scale.gd', 'scripts/display_preferences.gd', 'scripts/display_dialog.gd', 'scripts/ui_language.gd', 'data/ui_translations.json', 'scripts/colour_assist.gd', 'shaders/colour_assist.gdshader', 'scripts/colour_assist_validation.gd', 'scripts/settings_dialog_layout.gd', 'scripts/journey_window_layout.gd', 'scripts/journey_desk_store.gd', 'scripts/display_settings_validation.gd']
MARKER = '^DISPLAY_SETTINGS checks=[1-9][0-9]* failures=0$'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--gl', action='store_true', help='Also render the colour assist under real GL (needs a display)')
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
        command = [args.engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://scripts/display_settings_validation.gd']
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
        if good and args.gl:
            # The filter reads the screen: only a real renderer can show its effect.
            picture = [args.engine, '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                       '--path', str(project), '--script', 'res://scripts/colour_assist_validation.gd']
            try:
                rendered = subprocess.run(picture, env=env, capture_output=True, text=True, timeout=120)
                shown = rendered.stdout+rendered.stderr
            except subprocess.TimeoutExpired as exc:
                shown = str(exc)+'\nERROR: colour assist timeout\n'
            (args.log_dir/'colour.log').write_text(shown)
            print(shown, end='')
            good = (re.search(r'^COLOUR_ASSIST checks=[1-9][0-9]* failures=0$', shown, re.M) is not None
                    and re.search(r'^\s*(?:SCRIPT ERROR|ERROR|USER ERROR):', shown, re.M) is None)
        return 0 if good else 1
if __name__=='__main__':raise SystemExit(main())
