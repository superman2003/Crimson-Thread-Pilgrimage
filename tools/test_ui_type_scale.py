#!/usr/bin/env python3
"""U01: runtime UI text sizes stay on the shared type scale.

Scans the runtime scripts for literal font sizes (theme overrides and the
interface's _label(..., size, COLOR) helper) and fails on any size that is not
in godot/scripts/ui_type_scale.gd. Text drawn in the world rather than on a
screen window is listed in WORLD_SPACE with the reason it is exempt.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
SCALE_FILE = SCRIPTS / 'ui_type_scale.gd'
# Not shipped UI: validations, captures, fixtures and previews.
SKIP = re.compile(r'(validation|capture|fixture|probe|preview|_test|showcase)')
OVERRIDE = re.compile(r'add_theme_font_size_override\(\s*"[a-z_]*font_size"\s*,\s*(\d+)\s*\)')
LABEL = re.compile(r'_label\([^\n]*?,\s*(\d+)\s*,\s*[A-Z][A-Z_]*\)')
# 1px: progress bars and inscription placeholders that draw no text.
NO_TEXT = {1}
WORLD_SPACE = {
    'main_level.gd': {13: 'practice-target and tool captions drawn above world props'},
    'cave_lift.gd': {15: 'lift basket prompt and floor labels drawn in the world'},
}


def scale():
    values = {}
    for name, value in re.findall(r'^const ([A-Z_]+) := (\d+)', SCALE_FILE.read_text(encoding='utf-8'), re.M):
        values[name] = int(value)
    return set(values.values())


def violations():
    allowed = scale() | NO_TEXT
    found = []
    for path in sorted(SCRIPTS.glob('*.gd')):
        if SKIP.search(path.name):
            continue
        exempt = WORLD_SPACE.get(path.name, {})
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            for pattern in (OVERRIDE, LABEL):
                for match in pattern.finditer(line):
                    size = int(match.group(1))
                    if size not in allowed and size not in exempt:
                        found.append('%s:%d size %d' % (path.relative_to(ROOT), number, size))
    return found


def main():
    found = violations()
    for item in found:
        print('OFF_SCALE ' + item)
    print('UI_TYPE_SCALE %s off_scale=%d scale=%s' % ('PASS' if not found else 'FAIL', len(found), sorted(scale())))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
