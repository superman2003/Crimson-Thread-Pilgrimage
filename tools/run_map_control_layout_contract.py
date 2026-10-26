#!/usr/bin/env python3
"""Strict native map control bounds, readable legends and lifecycle regressions."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def invoke(command, env, log, marker=None):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        good = result.returncode == 0
    except subprocess.TimeoutExpired as exc:
        value = exc.stdout or b''
        output = value.decode(errors='replace') if isinstance(value, bytes) else value
        output += '\nERROR: Map layout contract exceeded 120 seconds\n'
        good = False
    log.write_text(output)
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
    good = good and not re.search(r'^\s*(?:ERROR|SCRIPT ERROR|USER ERROR):', plain, re.M)
    if marker is not None:
        good = good and re.search(marker, plain, re.M) is not None
    print(output, end='')
    return bool(good)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if engine is None:
        parser.error('Godot executable missing')
    dependencies = (
        'assets/fonts/GlobalTypeface.otf',
        'assets/vfx/player_contact/player_contact.png',
        'assets/ui/inscription/v2/folio.png',
        'assets/ui/inscription/v2/needle_seal.svg',
        'assets/ui/seals/crimson.svg',
    )
    for relative in dependencies:
        dependency = ROOT / 'godot' / relative
        if not dependency.is_file() or dependency.read_bytes().startswith(b'version https://git-lfs'):
            parser.error('hydrate the actual UI/font/VFX dependency: ' + relative)
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='crimson-u01-map-layout-') as scratch:
        project = Path(scratch) / 'godot'
        project.mkdir()
        for directory in ('scripts', 'data', 'shaders', 'assets/vfx', 'assets/fonts', 'assets/ui/inscription/v2', 'assets/ui/seals'):
            shutil.copytree(ROOT / 'godot' / directory, project / directory)
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Map control layout contracts"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = dict(os.environ, XDG_DATA_HOME=str(Path(scratch) / 'userdata'))
        base = [engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project)]
        if not invoke(base + ['--editor', '--recovery-mode', '--import', '--quit'], env,
                      args.log_dir / 'import.log'):
            return 1
        cases = (
            ('map_control_layout_validation.gd', r'^MAP_CONTROL_LAYOUT checks=[1-9][0-9]* failures=0$'),
            ('permanent_ability_roles_validation.gd', r'^PERMANENT_ABILITY_ROLES checks=[1-9][0-9]* failures=0$'),
            ('world_reading_session_validation.gd', r'^WORLD_READING_SESSION checks=[1-9][0-9]* failures=0$'),
            ('build_slots_ui_validation.gd', r'^BUILD_SLOTS_UI_VALIDATION .* checks=[1-9][0-9]* failures=0 capture='),
        )
        good = True
        for script, marker in cases:
            passed = invoke(base + ['--script', 'res://scripts/' + script], env,
                            args.log_dir / (script + '.log'), marker)
            good = passed and good
        return 0 if good else 1

if __name__ == '__main__':
    raise SystemExit(main())
