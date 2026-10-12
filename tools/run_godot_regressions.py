#!/usr/bin/env python3
"""Run isolated Godot suites; failures, engine errors and timeouts all fail CI."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SUITES = (
    'world_map world_route_access world_state world_integration world_route_walk ability_movement '
    'enemy_effect_lifetime enemy_visibility world_material hero_animation cave_exploration cave_route_walk '
    'chapter_route_regression ch01_room_reconstruction pilgrimage_merge_regression pilgrimage_review_regression '
    'all_chapters_demo pilgrimage_overhaul demo ch02_demo inventory_map boss_trial '
    'combat generated_runtime chapter_registry story_guidance chinese_story metsys '
    'player_upgrade_regression build_system world_upgrade upgrade_integration save_product '
    'ui_build_accessibility ui_world_integration ui_redesign '
    'seal_system seal_combat seal_ui seal_acceptance seal_acquisition seal_presentation'
).split()
NARRATIVE_SUITES = ['tests/verify_world_narrative', 'tests/verify_narrative_ui', 'tests/verify_narrative_progression', 'tests/verify_narrative_runtime']

def suite_path(name):
    if not re.fullmatch(r'(?:tests/)?[a-z0-9_]+', name):
        raise ValueError(f'invalid suite name: {name}')
    return f'res://{name}.gd' if name.startswith('tests/') else f'res://scripts/{name}_validation.gd'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--suite', action='append', help='Repeat to select suites; defaults to the CI suite list.')
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--log-dir', type=Path)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:
        parser.error(f'Godot executable not found: {args.engine}; set GODOT or --engine')
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    suites = args.suite or DEFAULT_SUITES + NARRATIVE_SUITES
    failures = []
    with tempfile.TemporaryDirectory(prefix='pilgrimage-regressions-') as scratch:
        logs = args.log_dir or Path(scratch) / 'logs'
        logs.mkdir(parents=True, exist_ok=True)
        for suite in suites:
            script = suite_path(suite)
            name = suite.replace('/', '_')
            log = logs / f'{name}.log'
            if not (ROOT / 'godot' / script.removeprefix('res://')).is_file():
                failures.append(f'{suite}: missing validation script')
                print('FAIL: ' + failures[-1], flush=True)
                continue
            env = dict(os.environ, XDG_DATA_HOME=str(Path(scratch) / name))
            print(f'Running {suite}', flush=True)
            try:
                with log.open('w') as output:
                    # Frame-counted ability/actuator probes use a fixed clock.
                    # Audio lifetime suites must retain normal playback timing.
                    simulation = ['--fixed-fps', '60'] if suite in ['ability_movement', 'world_upgrade'] else []
                    result = subprocess.run([engine, '--headless', *simulation, '--path', str(ROOT / 'godot'), '--script', script], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=args.timeout, check=False)
                output = log.read_text(errors='replace')
                errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', output, re.MULTILINE)
                if result.returncode != 0 or errors:
                    failures.append(f'{suite}: exit={result.returncode} engine_errors={len(errors)}')
                    print('FAIL: ' + failures[-1] + '\n' + '\n'.join(output.splitlines()[-40:]), flush=True)
                else:
                    print('PASS: ' + suite + '\n' + '\n'.join(output.splitlines()[-2:]), flush=True)
            except subprocess.TimeoutExpired:
                failures.append(f'{suite}: timeout after {args.timeout:g}s')
                print('FAIL: ' + failures[-1], flush=True)
    print(f'GODOT_REGRESSIONS suites={len(suites)} failures={len(failures)}')
    return 1 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
