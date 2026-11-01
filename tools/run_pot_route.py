#!/usr/bin/env python3
"""Replay a real pot throw from a normally earned checkpoint, under real GL.

This is a continuation test, not a new-save campaign, human playtest or FPS test.
The seed comes from the recorded #180 map/quill journey and is copied verbatim
to a dedicated test save by the playback. It never replaces a player's save.
"""
from __future__ import annotations

import argparse
from contextlib import nullcontext
import datetime
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from run_damage_route import freeze
from software_gl import software_gl

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = 'godot/scripts/world_pot_route_playback.gd'
SEED = 'artifacts/t04_pot_fuse/earned_seed.json'
SEED_SHA256 = '3113392acc89b2992e4897df014d98d1359dc849b4ec9d67ddf782c27e03f094'
MARKER = r'^WORLD_POT_ROUTE steps=\d+ failures=0 damage_suppression=false earned_checkpoint=true$'


def sources():
    result = freeze()
    for name in [SCRIPT, SEED, 'tools/run_pot_route.py']:
        result[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--native-gl', action='store_true')
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:
        parser.error('Godot executable not found')
    before = sources()
    if before[SEED] != SEED_SHA256:
        parser.error('earned checkpoint differs from its recorded provenance')
    logs = args.log_dir.resolve()
    logs.mkdir(parents=True, exist_ok=True)
    (logs / 'playback.gd.txt').write_bytes((ROOT / SCRIPT).read_bytes())
    (logs / 'runner.py.txt').write_bytes(Path(__file__).read_bytes())
    (logs / 'runtime.gd.txt').write_bytes((ROOT / 'godot/scripts/player_tool_effect.gd').read_bytes())
    (logs / 'source.diff').write_bytes(subprocess.check_output(
        ['git', '-c', 'core.safecrlf=false', 'diff', 'HEAD', '--', 'godot', 'tools/run_pot_route.py'], cwd=ROOT))
    started = time.monotonic()
    code, timed_out = None, False
    display = nullcontext({}) if args.native_gl else software_gl(logs / 'display')
    with tempfile.TemporaryDirectory(prefix='pilgrimage-pot-route-') as scratch, display as renderer_env:
        env = dict(os.environ, **renderer_env, XDG_DATA_HOME=scratch)
        renderer = ['--position', '-32000,-32000'] if args.native_gl else ['--display-driver', 'x11']
        command = [engine, *renderer, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
                   '--fixed-fps', '60', '--path', str(ROOT / 'godot'), '--script', 'res://scripts/world_pot_route_playback.gd']
        with (logs / 'runtime.log').open('w', encoding='utf-8') as output:
            try:
                code = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT,
                                      timeout=180, check=False).returncode
            except subprocess.TimeoutExpired:
                timed_out = True
    after = sources()
    for name, values in [('before', before), ('after', after)]:
        (logs / f'source-{name}.json.gz').write_bytes(gzip.compress(
            (json.dumps(values, indent=2)+'\n').encode(), mtime=0))
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace'))
    errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', plain, re.MULTILINE)
    marker = re.search(MARKER, plain, re.MULTILINE)
    result = dict(date=datetime.datetime.now().astimezone().isoformat(),
                  scope='real-input continuation from the earned #180 checkpoint',
                  head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  command=command, seed_sha256=before[SEED], seconds=round(time.monotonic()-started, 2),
                  timeout_seconds=180, exit=code, timed_out=timed_out, engine_errors=errors,
                  objectdb_warnings=plain.count('ObjectDB instances leaked'), source_files=len(before),
                  source_unchanged=before == after, completion=marker.group(0) if marker else None,
                  passed=code == 0 and not timed_out and not errors and bool(marker) and before == after)
    (logs / 'verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
