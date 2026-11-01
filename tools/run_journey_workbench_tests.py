#!/usr/bin/env python3
"""Run workbench tests serially against one exact checkout and isolated user data."""
from pathlib import Path
import argparse
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FEATURES = ['core', 'supplies', 'build_lab', 'routes', 'caseboard', 'photo', 'trajectory', 'inputs', 'tactics', 'backups']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--feature', choices=FEATURES, required=True)
    parser.add_argument('--backend', choices=['headless', 'gl'], default='headless')
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    args.log_dir.mkdir(parents=True, exist_ok=True)
    names = ['core'] + ([] if args.feature == 'core' else [args.feature]) + ['world']
    failures = 0
    with tempfile.TemporaryDirectory(prefix='journey-test-') as data:
        for name in names:
            env = os.environ.copy()
            env['XDG_DATA_HOME'] = str(Path(data) / name)
            flags = ['--headless'] if args.backend == 'headless' else ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility']
            command = [args.engine, '--path', str(ROOT / 'godot'), '--audio-driver', 'Dummy', *flags, '--script', f'res://journey/tests/{name}.gd']
            try:
                result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
                text = result.stdout.decode(errors='replace')
                clean = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
                marker = f'JOURNEY_{name.upper()}'
                good = result.returncode == 0 and not re.search(r'^\s*(SCRIPT ERROR|ERROR|USER ERROR):', clean, re.M) and re.search(rf'^{marker} checks=[1-9][0-9]* failures=0$', clean, re.M)
            except subprocess.TimeoutExpired as error:
                text = (error.stdout or b'').decode(errors='replace') + '\nTEST PROCESS TIMEOUT\n'
                good = False
            (args.log_dir / f'{name}.log').write_text(text)
            failures += not good
            print(f'{name}: {"PASS" if good else "FAIL"}', flush=True)
    print(f'JOURNEY_RUNNER tests={len(names)} failures={failures}', flush=True)
    return 1 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
