#!/usr/bin/env python3
"""Check one fieldwork module on the exact checkout, with isolated save data."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--module', required=True)
    parser.add_argument('--backend', choices=['headless', 'gl'], default='headless')
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--world', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'i_[0-9]{2}_[a-z_]+', args.module):
        parser.error('module must name an i_NN_feature test')
    if not (ROOT / f'godot/journey/tests/{args.module}.gd').is_file():
        parser.error('module test is absent in this checkout')
    names = [args.module]
    if args.world:
        names += ['world']
        if (ROOT / 'godot/journey/tests/i_live_world.gd').is_file():
            names += ['i_live_world']
    args.log_dir.mkdir(parents=True, exist_ok=True)
    failures = 0
    with tempfile.TemporaryDirectory(prefix='fieldwork-test-') as data:
        for name in names:
            env = dict(os.environ, XDG_DATA_HOME=str(Path(data) / name))
            flags = ['--headless'] if args.backend == 'headless' else [
                '--display-driver', 'x11', '--rendering-method', 'gl_compatibility']
            command = [args.engine, '--path', str(ROOT / 'godot'),
                       '--audio-driver', 'Dummy', *flags,
                       '--script', f'res://journey/tests/{name}.gd']
            marker = 'JOURNEY_' + name.upper().replace('I_', 'I', 1) if re.match(r'i_\d', name) else 'JOURNEY_' + name.upper()
            try:
                result = subprocess.run(command, env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, timeout=90)
                output = result.stdout.decode(errors='replace')
                clean = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
                good = (result.returncode == 0
                        and not re.search(r'^\s*(SCRIPT ERROR|ERROR|USER ERROR):', clean, re.M)
                        and re.search(rf'^{marker} checks=[1-9][0-9]* failures=0$', clean, re.M))
            except subprocess.TimeoutExpired as error:
                output = (error.stdout or b'').decode(errors='replace') + '\nPROCESS TIMEOUT\n'
                good = False
            (args.log_dir / f'{name}.log').write_text(output)
            failures += not good
            print(f'{name}: {"PASS" if good else "FAIL"}', flush=True)
    print(f'FIELDWORK_RUNNER tests={len(names)} failures={failures}', flush=True)
    return int(bool(failures))


if __name__ == '__main__':
    raise SystemExit(main())
