"""V04: particle systems must go through the combat visual budget.

The game currently draws every effect as budgeted Node2D decoration
(combat_visual_policy.attach_secondary: 24 units, motion/state/environment
limits). A particle node outside that budget could flood the screen in a mixed
fight, so for every runtime file under godot/ (scripts, scenes, journey
features, addons; only *_validation.gd and godot/tests/ are exempt):

- a scene (.tscn) may not contain particle nodes at all;
- a script may construct a particle node only as `var name := XParticles2D.new()`
  (code, not comments or strings), must pass that same variable to
  combat_visual_policy.attach_secondary, and must cap it with
  `name.amount = N` where N <= MAX_AMOUNT, since the budget charges one unit
  per node regardless of how many particles it emits.

--self-test checks the rule on planted files.
"""
import argparse
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_AMOUNT = 24
PARTICLE_CLASS = r'(?:GPU|CPU)Particles(?:2D|3D)'
CONSTRUCT = re.compile(rf'\b{PARTICLE_CLASS}\.new\(\)')
ASSIGNED = re.compile(rf'\bvar\s+(\w+)\s*(?::\s*\w+)?\s*:?=\s*{PARTICLE_CLASS}\.new\(\)')
SCENE_NODE = re.compile(rf'^\[node [^\]]*type="{PARTICLE_CLASS}"', re.M)
STRING = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')


def exempt(rel: Path) -> bool:
    return rel.parts[0] in {'tests', '.godot'} or rel.name.endswith('_validation.gd')


def code_only(text: str) -> str:
    """Drop string literals and # comments so only real code is matched."""
    lines = []
    for line in text.splitlines():
        line = STRING.sub('""', line)
        lines.append(line.split('#', 1)[0])
    return '\n'.join(lines)


def script_problems(rel: str, text: str) -> list[str]:
    code = code_only(text)
    found = []
    names = ASSIGNED.findall(code)
    if len(CONSTRUCT.findall(code)) != len(names):
        found.append(f'{rel} constructs a particle node without naming it (`var name := ...Particles2D.new()`)')
    for name in names:
        if not re.search(rf'\battach_secondary\([^)\n]*\b{re.escape(name)}\b', code):
            found.append(f'{rel}: particle `{name}` is never passed to combat_visual_policy.attach_secondary')
        amounts = [int(n) for n in re.findall(rf'\b{re.escape(name)}\.amount\s*=\s*(\d+)', code)]
        if not amounts or max(amounts) > MAX_AMOUNT:
            found.append(f'{rel}: particle `{name}` needs `{name}.amount = N` with N <= {MAX_AMOUNT}')
    return found


def problems(godot=ROOT / 'godot'):
    found = []
    for pattern in ('*.gd', '*.tscn'):
        for path in sorted(godot.rglob(pattern)):
            rel = path.relative_to(godot)
            if exempt(rel):
                continue
            text = path.read_text(encoding='utf-8')
            if path.suffix == '.tscn':
                if SCENE_NODE.search(text):
                    found.append(f'{rel.as_posix()} places particle nodes outside the combat visual budget')
            else:
                found.extend(script_problems(rel.as_posix(), text))
    return found


def self_test():
    with tempfile.TemporaryDirectory() as tmp:
        godot = Path(tmp)
        for folder in ('scripts', 'scenes', 'journey/features', 'tests'):
            (godot / folder).mkdir(parents=True)
        def write(rel, body):
            (godot / rel).write_text(body, encoding='utf-8')
        def rejected(name):
            return any(name in p for p in problems(godot))
        assert not problems(godot), 'an empty project is clean'
        write('scripts/sparks.gd', 'var p := GPUParticles2D.new()\n')
        assert rejected('sparks.gd'), 'an unbudgeted particle is rejected'
        write('scripts/sparks.gd', 'var p := CPUParticles2D.new()\np.amount = 12\nPOLICY.attach_secondary(host, p, &"motion", self)\n')
        assert not problems(godot), 'a budgeted, capped particle is accepted'
        write('scripts/sparks.gd', 'var p := CPUParticles2D.new()\np.amount = 400\nPOLICY.attach_secondary(host, p, &"motion", self)\n')
        assert rejected('sparks.gd'), 'an emission above the cap is rejected'
        write('scripts/sparks.gd', 'var p := CPUParticles2D.new()\np.amount = 8\nvar q := Node2D.new()\nPOLICY.attach_secondary(host, q, &"motion", self)\n')
        assert rejected('sparks.gd'), 'budgeting a different node does not admit the particle'
        write('scripts/sparks.gd', '# GPUParticles2D nodes are forbidden here\nvar label := "CPUParticles2D.new()"\nvar kind: GPUParticles2D\n')
        assert not problems(godot), 'comments, strings and type mentions are not constructions'
        write('scripts/sparks.gd', 'add_child(GPUParticles2D.new())\n')
        assert rejected('sparks.gd'), 'an unnamed construction is rejected'
        (godot / 'scripts' / 'sparks.gd').unlink()
        write('journey/features/glow.gd', 'var p := GPUParticles2D.new()\n')
        assert rejected('glow.gd'), 'journey feature scripts are scanned'
        (godot / 'journey' / 'features' / 'glow.gd').unlink()
        write('scenes/Burst.tscn', '[node name="Burst" type="GPUParticles2D" parent="."]\n')
        assert rejected('Burst.tscn'), 'scene particles are rejected'
        (godot / 'scenes' / 'Burst.tscn').unlink()
        write('scenes/boss_validation_arena.tscn', '[node name="Burst" type="CPUParticles2D" parent="."]\n')
        assert rejected('boss_validation_arena.tscn'), 'a scene is never exempt by its name'
        (godot / 'scenes' / 'boss_validation_arena.tscn').unlink()
        write('scripts/fx_validation.gd', 'var p := GPUParticles2D.new()\n')
        write('tests/verify_fx.gd', 'var p := GPUParticles2D.new()\n')
        assert not problems(godot), 'validation scripts and tests are exempt'
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
    print(f'PARTICLE_BUDGET_OK no particle nodes outside the combat visual budget (cap {MAX_AMOUNT} per node)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
