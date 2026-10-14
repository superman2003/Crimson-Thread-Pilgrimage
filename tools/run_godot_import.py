#!/usr/bin/env python3
"""Import Godot resources twice, retaining logs and rejecting zero-exit engine errors."""
from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=float, default=180,
                        help='Maximum seconds per import pass (default: 180).')
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--recovery-mode', action='store_true',
                        help='Import resources without editor plugins/tool scripts; '
                             'does not validate editor-plugin behavior.')
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('--timeout must be finite and positive')
    engine = shutil.which(args.engine)
    if not engine:
        parser.error(f'Godot executable not found: {args.engine}; set GODOT or --engine')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    # Both passes must succeed: a later clean import must not hide an error.
    # Recovery mode deliberately separates resource import from editor-plugin
    # QA. Runtime regression suites must still run normally after this step.
    recovery = ['--recovery-mode'] if args.recovery_mode else []
    if args.recovery_mode:
        print('Resource import only: editor plugins/tool scripts are disabled; '
              'editor-plugin behavior is not validated.', flush=True)
    for number in (1, 2):
        log = args.log_dir / f'import-{number}.log'
        failure = None
        result = None
        print(f'Importing Godot resources (pass {number}/2)', flush=True)
        try:
            with log.open('w', encoding='utf-8') as output:
                result = subprocess.run(
                    [engine, '--headless', '--path', str(ROOT / 'godot'),
                     '--editor', *recovery, '--import', '--quit'],
                    stdout=output, stderr=subprocess.STDOUT,
                    timeout=args.timeout, check=False)
        except subprocess.TimeoutExpired:
            failure = f'timeout after {args.timeout:g}s'
        except OSError as error:
            failure = f'could not launch engine: {error}'
        output = log.read_text(encoding='utf-8', errors='replace')
        # Godot may emit colored diagnostics even when redirected.
        plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
        errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', plain, re.MULTILINE)
        if failure is None and (result.returncode != 0 or errors):
            failure = f'exit={result.returncode} engine_errors={len(errors)}'
        if failure:
            print(f'FAIL: import pass {number}: {failure}\n'
                  + '\n'.join(plain.splitlines()[-40:]), flush=True)
            print(f'Import log: {log}', flush=True)
            return 1
        print(f'PASS: import pass {number}', flush=True)
    print('GODOT_IMPORT passes=2 failures=0')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
