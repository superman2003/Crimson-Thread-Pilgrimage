#!/usr/bin/env python3
"""Strict isolated Godot checks for observed challenge models and native controls.

This does not replace the repository's full World, GPU or export regressions.
The fixture imports the actual scripts and data, without production autoloads.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--module', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'k(?:0[1-9]|1[0-9]|20)_[a-z_]+', args.module):
        parser.error('invalid challenge module name')
    source = ROOT / 'godot' / 'journey' / 'tests' / (args.module + '.gd')
    if not source.is_file():
        parser.error('challenge test does not exist at this revision')
    engine = shutil.which(args.engine)
    if engine is None:
        parser.error('Godot executable not found')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='crimson-observation-') as scratch:
        project = Path(scratch) / 'godot'
        project.mkdir()
        for name in ('journey', 'scripts', 'data'):
            shutil.copytree(ROOT / 'godot' / name, project / name)
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Observation contract fixtures"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = dict(os.environ, XDG_DATA_HOME=str(Path(scratch) / 'user-data'))
        command = [engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project),
                   '--script', f'res://journey/tests/{args.module}.gd']
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=90)
            output = result.stdout + result.stderr
            code = result.returncode
        except subprocess.TimeoutExpired as exc:
            raw = exc.stdout or b''
            output = raw.decode(errors='replace') if isinstance(raw, bytes) else raw
            output += '\nERROR: observation contract exceeded its 90 second budget\n'
            code = 124
        plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
        marker = r'^JOURNEY_' + args.module.upper() + r' checks=[1-9][0-9]* failures=0$'
        good = (code == 0 and re.search(marker, plain, re.M) is not None
                and re.search(r'^\s*(?:SCRIPT ERROR|ERROR|USER ERROR):', plain, re.M) is None)
        (args.log_dir / (args.module + '.log')).write_text(output)
        print(output, end='')
        print(f'OBSERVATION_CONTRACT module={args.module} failures={0 if good else 1}')
        return 0 if good else 1

if __name__ == '__main__':
    raise SystemExit(main())
