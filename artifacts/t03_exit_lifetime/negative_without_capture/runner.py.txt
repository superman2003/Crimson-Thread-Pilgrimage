#!/usr/bin/env python3
"""Diagnose fixture exit ownership with verbose logs and frozen inputs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = ('chapter_route_regression', 'cave_route_walk', 'world_platform_streaming')


def freeze():
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot', 'tools'], cwd=ROOT).decode().split('\0')
    names.append('tools/run_exit_lifetime.py')
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in sorted(set(names)) if name and (ROOT / name).is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', required=True, type=Path)
    parser.add_argument('--suite', choices=SUITES, action='append')
    parser.add_argument('--native-gl', action='store_true')
    parser.add_argument('--verbose', action='store_true')
    args = parser.parse_args()
    args.log_dir.mkdir(parents=True, exist_ok=True)
    (args.log_dir / 'runner.py.txt').write_bytes(Path(__file__).read_bytes())
    (args.log_dir / 'source.diff').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD', '--', 'godot'], cwd=ROOT))
    for suite in set(args.suite or SUITES):
        (args.log_dir / f'{suite}.gd.txt').write_bytes((ROOT / f'godot/scripts/{suite}_validation.gd').read_bytes())
    before = freeze()
    (args.log_dir / 'source-before.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
    results = []
    with tempfile.TemporaryDirectory(prefix='ctp-exit-lifetime-') as scratch:
        env = dict(os.environ, APPDATA=scratch, XDG_DATA_HOME=scratch)
        for suite in args.suite or SUITES:
            render = ['--position', '-32000,-32000', '--rendering-method', 'gl_compatibility'] if args.native_gl else ['--headless']
            command = [args.engine, *render, '--audio-driver', 'Dummy', '--fixed-fps', '60', *(['--verbose'] if args.verbose else []), '--path', str(ROOT / 'godot'), '--script', f'res://scripts/{suite}_validation.gd']
            started = time.monotonic()
            timeout = False
            with (args.log_dir / f'{suite}.log').open('w', encoding='utf-8') as output:
                try:
                    code = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=180).returncode
                except subprocess.TimeoutExpired:
                    code, timeout = None, True
            log = (args.log_dir / f'{suite}.log').read_text(encoding='utf-8', errors='replace')
            errors = len(re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:)', log, re.M))
            warnings = len(re.findall(r'^\s*WARNING:', log, re.M))
            marker = json.loads((ROOT / 'tools/godot_suite_success_markers.json').read_text())[suite]
            completed = re.search(marker, log, re.M) is not None
            result = dict(suite=suite, command=command, exit=code, timeout=timeout, errors=errors, warnings=warnings, completed=completed, seconds=round(time.monotonic()-started, 3))
            results.append(result)
            print(json.dumps(result), flush=True)
    after = freeze()
    (args.log_dir / 'source-after.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
    passed = before == after and all(r['exit'] == 0 and not r['timeout'] and not r['errors'] and not r['warnings'] and r['completed'] for r in results)
    (args.log_dir / 'verification.json').write_text(json.dumps(dict(passed=passed, source_equal=before == after, files=len(before), results=results), indent=2), encoding='utf-8')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
