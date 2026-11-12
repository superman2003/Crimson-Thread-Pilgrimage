#!/usr/bin/env python3
"""U01: runtime window and page container gaps stay on the shared spacing scale.

Scans the shipped runtime scripts for literal container gaps
(separation, h_separation, v_separation theme overrides) and fails on any gap
that is not in godot/scripts/ui_spacing_scale.gd. Dense layouts that need a
smaller gap are listed in DENSE with the reason.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
SCALE_FILE = SCRIPTS / 'ui_spacing_scale.gd'
SKIP = re.compile(r'(validation|capture|fixture|probe|preview|_test|showcase)')
GAP = re.compile(r'add_theme_constant_override\(\s*"([hv]_)?separation"\s*,\s*(\d+)\s*\)')
DENSE = {
    'pilgrimage_interface.gd': {6: 'remap grid columns, sized to fit 17 actions in the settings page',
                                1: 'remap grid rows, sized to fit 17 actions in the settings page'},
}


def scale():
    text = SCALE_FILE.read_text(encoding='utf-8')
    return {int(value) for value in re.findall(r'^const [A-Z_]+ := (\d+)', text, re.M)}


def violations():
    allowed = scale()
    found = []
    for path in sorted(SCRIPTS.glob('*.gd')):
        if SKIP.search(path.name):
            continue
        exempt = DENSE.get(path.name, {})
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            for match in GAP.finditer(line):
                gap = int(match.group(2))
                if gap not in allowed and gap not in exempt:
                    found.append('%s:%d gap %d' % (path.relative_to(ROOT).as_posix(), number, gap))
    return found


def self_test():
    assert GAP.search('a.add_theme_constant_override("separation",9)').group(2) == '9'
    assert GAP.search('g.add_theme_constant_override("h_separation", 6)').group(2) == '6'
    assert not GAP.search('l.add_theme_constant_override("outline_size",4)')
    assert scale() == {8, 10, 12, 16}


def main():
    self_test()
    found = violations()
    for item in found:
        print('OFF_SCALE ' + item)
    print('UI_SPACING_SCALE %s off_scale=%d scale=%s' % ('PASS' if not found else 'FAIL', len(found), sorted(scale())))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
