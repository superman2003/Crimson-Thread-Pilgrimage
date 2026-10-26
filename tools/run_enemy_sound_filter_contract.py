#!/usr/bin/env python3
"""Strict enemy occlusion routing/voice fixtures; full World checks remain in integration CI."""
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
        output += '\nERROR: native floor contract exceeded 120 seconds\n'
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
    vfx = ROOT / 'godot/assets/vfx'
    atlas = vfx / 'player_contact/player_contact.png'
    if not atlas.is_file() or atlas.read_bytes().startswith(b'version https://git-lfs'):
        parser.error('hydrate the actual enemy VFX dependencies')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='crimson-s03-filter-') as scratch:
        project = Path(scratch) / 'godot'
        project.mkdir()
        for directory in ('scripts', 'data', 'shaders', 'assets/vfx'):
            shutil.copytree(ROOT / 'godot' / directory, project / directory)
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Enemy sound filter contracts"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = dict(os.environ, XDG_DATA_HOME=str(Path(scratch) / 'userdata'))
        base = [engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project)]
        if not invoke(base + ['--editor', '--recovery-mode', '--import', '--quit'], env,
                      args.log_dir / 'import.log'):
            return 1
        marker = r'^ENEMY_SOUND_FILTER checks=[1-9][0-9]* failures=0$'
        good = invoke(base + ['--script', 'res://scripts/enemy_sound_filter_validation.gd'], env,
                      args.log_dir / 'contracts.log', marker)
        return 0 if good else 1

if __name__ == '__main__':
    raise SystemExit(main())
