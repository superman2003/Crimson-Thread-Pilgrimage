"""V04: particle systems must go through the combat visual budget.

The game currently draws every effect as budgeted Node2D decoration
(combat_visual_policy.attach_secondary: 24 units, motion/state/environment
limits). A particle node outside that budget could flood the screen in a mixed
fight, so:

- a runtime scene (.tscn) may not contain particle nodes at all;
- a runtime script may create particle nodes only if it also hands them to
  combat_visual_policy.attach_secondary.

Validation scripts are exempt. --self-test checks the rule on planted files.
"""
import argparse
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTICLES = re.compile(r'\b(?:GPU|CPU)Particles(?:2D|3D)\b')
BUDGET = 'attach_secondary'


def problems(godot=ROOT / 'godot'):
    found = []
    for folder, pattern in (('scripts', '*.gd'), ('scenes', '*.tscn')):
        for path in sorted((godot / folder).rglob(pattern)):
            if 'validation' in path.name:
                continue
            text = path.read_text(encoding='utf-8')
            if not PARTICLES.search(text):
                continue
            rel = path.relative_to(godot).as_posix()
            if path.suffix == '.tscn':
                found.append(f'{rel} places particle nodes outside the combat visual budget')
            elif BUDGET not in text:
                found.append(f'{rel} creates particle nodes without combat_visual_policy.{BUDGET}')
    return found


def self_test():
    with tempfile.TemporaryDirectory() as tmp:
        godot = Path(tmp)
        (godot / 'scripts').mkdir()
        (godot / 'scenes').mkdir()
        assert not problems(godot), 'an empty project is clean'
        (godot / 'scripts' / 'sparks.gd').write_text('var p := GPUParticles2D.new()\n', encoding='utf-8')
        assert any('sparks.gd' in p for p in problems(godot)), 'unbudgeted script particles are rejected'
        (godot / 'scripts' / 'sparks.gd').write_text('var p := CPUParticles2D.new()\nPOLICY.attach_secondary(host, p, &"motion", self)\n', encoding='utf-8')
        assert not problems(godot), 'budgeted script particles are accepted'
        (godot / 'scenes' / 'Burst.tscn').write_text('[node name="Burst" type="GPUParticles2D"]\n', encoding='utf-8')
        assert any('Burst.tscn' in p for p in problems(godot)), 'scene particles are rejected'
        (godot / 'scenes' / 'Burst.tscn').unlink()
        (godot / 'scripts' / 'fx_validation.gd').write_text('var p := GPUParticles2D.new()\n', encoding='utf-8')
        assert not problems(godot), 'validation scripts are exempt'
    print('PARTICLE_BUDGET self-test OK')


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
    found = problems()
    for line in found:
        print('PARTICLE_BUDGET_ERROR ' + line)
    if found:
        return 1
    print('PARTICLE_BUDGET_OK no particle nodes outside the combat visual budget')
    return 0


if __name__ == '__main__':
    sys.exit(main())
