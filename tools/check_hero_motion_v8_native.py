"""Verify imported action art and real attack input using an available GL display."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ['player_basic_attack_vfx', 'seal_presentation', 'player_contact_art',
           'hero_animation', 'seal_combat', 'player_ability_art',
           'combat_visual_budget', 'character_art_prewarm']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--suite', action='append')
    parser.add_argument('--output', type=Path, default=ROOT/'artifacts/hero_motion_v8/final-native')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    captures = out/'actual-attacks'
    captures.mkdir(exist_ok=True)
    markers = json.loads((ROOT/'tools/godot_suite_success_markers.json').read_text())
    suites = args.suite or DEFAULT
    if any(suite not in DEFAULT for suite in suites):
        parser.error('Choose a registered hero/native acceptance suite')
    records = []
    with tempfile.TemporaryDirectory(prefix='hero-motion-v8-') as scratch:
        for suite in suites:
            cmd = [args.engine, '--path', str(ROOT/'godot'), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--position',
                   '-20000,-20000', '--script', f'res://scripts/{suite}_validation.gd']
            if suite in ['player_basic_attack_vfx', 'player_contact_art', 'character_art_prewarm']:
                cmd += ['--fixed-fps', '60']
            if suite == 'player_contact_art':
                cmd += ['--', '--output='+captures.as_posix()]
            env = dict(os.environ, APPDATA=str(Path(scratch)/suite), XDG_DATA_HOME=str(Path(scratch)/suite))
            result = subprocess.run(cmd, env=env, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=240)
            text = result.stdout.decode('utf-8', errors='replace').replace('\r\n', '\n')
            (out/(suite+'.log')).write_text(text, encoding='utf-8')
            errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', text, re.M)
            matched = re.search(markers[suite], text, re.M)
            real_gl = 'OpenGL API' in text and 'headless' not in text
            passed = result.returncode == 0 and not errors and matched is not None and real_gl
            records.append({'suite':suite, 'passed':passed, 'exit_code':result.returncode,
                            'errors':errors, 'marker':matched.group(0) if matched else None,
                            'command':cmd})
            (out/'verification.json').write_text(json.dumps({'results':records}, indent=2)+'\n', encoding='utf-8')
            print(suite, 'PASS' if passed else 'FAIL', records[-1]['marker'], flush=True)
            if not passed:
                print(text[-5000:])
                return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
