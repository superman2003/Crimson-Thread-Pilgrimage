#!/usr/bin/env python3
"""Replay a damage-enabled three-region input route against frozen sources.

This optional real-GL playback is separate from the default component suites.
It is not a campaign completion, human usability test or frame-rate benchmark.
"""
from __future__ import annotations
import argparse
from contextlib import nullcontext
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from software_gl import software_gl

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = 'godot/scripts/world_damage_route_playback.gd'
MARKER = r'^WORLD_DAMAGE_ROUTE_PLAYBACK steps=\d+ physics_frames=\d+ damage_events=[1-9]\d* heals=[1-9]\d* deaths=0 failures=0 damage_suppression=false$'


def freeze():
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot', 'tools/run_damage_route.py', 'tools/software_gl.py'], cwd=ROOT).decode().split('\0')
    names += [SCRIPT, 'tools/run_damage_route.py']
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in sorted(set(names)) if name and (ROOT / name).is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--native-gl', action='store_true', help='Use native GL in an offscreen window; otherwise use software GL.')
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:
        parser.error('Godot executable not found')
    logs = args.log_dir.resolve()
    logs.mkdir(parents=True, exist_ok=True)
    before = freeze()
    (logs / 'source-before.json').write_text(json.dumps(before, indent=2)+'\n', encoding='utf-8')
    (logs / 'source.diff').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD', '--', 'godot', 'tools/run_damage_route.py'], cwd=ROOT))
    (logs / 'playback.gd.txt').write_bytes((ROOT / SCRIPT).read_bytes())
    (logs / 'runner.py.txt').write_bytes(Path(__file__).read_bytes())
    started = time.monotonic()
    code, timed_out = None, False
    display = nullcontext({}) if args.native_gl else software_gl(logs / 'display')
    with tempfile.TemporaryDirectory(prefix='pilgrimage-damage-route-') as scratch, display as renderer_env:
        env = dict(os.environ, **renderer_env, XDG_DATA_HOME=scratch)
        renderer = ['--position', '-32000,-32000'] if args.native_gl else ['--display-driver', 'x11']
        command = [engine, *renderer, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--fixed-fps', '60', '--path', str(ROOT / 'godot'), '--script', 'res://scripts/world_damage_route_playback.gd']
        with (logs / 'runtime.log').open('w', encoding='utf-8') as output:
            try:
                code = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=180, check=False).returncode
            except subprocess.TimeoutExpired:
                timed_out = True
    after = freeze()
    (logs / 'source-after.json').write_text(json.dumps(after, indent=2)+'\n', encoding='utf-8')
    output = (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace')
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
    errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', plain, re.MULTILINE)
    marker = re.search(MARKER, plain, re.MULTILINE)
    result = dict(date=datetime.datetime.now().astimezone().isoformat(),
                  head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  command=command, seconds=round(time.monotonic()-started, 2), timeout_seconds=180,
                  exit=code, timed_out=timed_out, engine_errors=errors,
                  objectdb_warnings=plain.count('ObjectDB instances leaked'),
                  source_files=len(before), source_unchanged=before == after,
                  completion=marker.group(0) if marker else None,
                  passed=code == 0 and not timed_out and not errors and bool(marker) and before == after)
    (logs / 'verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
