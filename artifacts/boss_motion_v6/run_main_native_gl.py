"""Replay the eight motion CI suites with native Windows GL and strict markers."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SUITES = ['expanded_character_motion', 'character_art_prewarm', 'enemy_atlas_integrity',
          'hero_animation', 'player_motion_continuity', 'enemy_lifecycle_regression',
          'enemy_visibility', 'boss_trial']
FIXED = {'expanded_character_motion', 'character_art_prewarm', 'enemy_atlas_integrity', 'player_motion_continuity'}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--engine', required=True)
args = parser.parse_args()
markers = json.loads((ROOT/'tools/godot_suite_success_markers.json').read_text(encoding='utf-8'))
logs = ROOT/'artifacts/boss_motion_v6/main_native_gl'
logs.mkdir(parents=True, exist_ok=True)
results = []
with tempfile.TemporaryDirectory(prefix='boss-v6-native-gl-') as scratch:
    for suite in SUITES:
        print('Running '+suite, flush=True)
        log = logs/(suite+'.log')
        command = [args.engine, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility']
        if suite in FIXED: command += ['--fixed-fps', '60']
        command += ['--path', str(ROOT/'godot'), '--script', 'res://scripts/'+suite+'_validation.gd']
        env = dict(os.environ, APPDATA=str(Path(scratch)/suite), XDG_DATA_HOME=str(Path(scratch)/suite))
        with log.open('w', encoding='utf-8') as output:
            result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, env=env, timeout=180)
        output = log.read_text(encoding='utf-8', errors='replace')
        plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
        errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', plain, re.MULTILINE)
        marker = re.search(markers[suite], plain, re.MULTILINE)
        passed = result.returncode == 0 and not errors and marker is not None
        results.append(dict(suite=suite,exit=result.returncode,engine_errors=errors,
                            completion=marker.group(0) if marker else None,passed=passed))
        print(('PASS: ' if passed else 'FAIL: ')+suite, flush=True)
        if marker: print(marker.group(0), flush=True)
        if not passed: print(plain[-5000:], flush=True)
summary = dict(suites=len(results),failures=sum(not r['passed'] for r in results),results=results)
(logs/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print('NATIVE_GL_REGRESSIONS suites=%d failures=%d' % (summary['suites'],summary['failures']), flush=True)
raise SystemExit(1 if summary['failures'] else 0)
