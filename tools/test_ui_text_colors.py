#!/usr/bin/env python3
"""U01: runtime UI text colours come from a named palette.

Scans the runtime scripts for text colours written as a literal (font colour
overrides and the interface's _label(..., size, Color(...)) helper) and fails on
any that is not listed in EXEMPT with the reason it stays. Shadows and outlines
are not text colour and are not checked.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
# Not shipped UI: validations, captures, fixtures and previews.
SKIP = re.compile(r'(validation|capture|fixture|probe|preview|_test|showcase)')
OVERRIDE = re.compile(r'add_theme_color_override\(\s*"font_color"\s*,\s*(.*)$')
LABEL = re.compile(r'_label\([^\n]*,\s*(Color\([^\n]*\))\s*\)\s*$')
LITERAL = re.compile(r'Color\(\s*(?:"[0-9a-fA-F]+"|[0-9.])')
EXEMPT = {
    'main_level.gd': 'legacy chapter map: current / visited / unvisited room names are told apart by colour',
}


def violations():
    found = []
    for path in sorted(SCRIPTS.glob('*.gd')):
        if SKIP.search(path.name) or path.name in EXEMPT:
            continue
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            for pattern in (OVERRIDE, LABEL):
                match = pattern.search(line)
                if match and LITERAL.search(match.group(1)):
                    found.append('%s:%d %s' % (path.relative_to(ROOT), number, match.group(1).strip()[:80]))
    return found


def self_test():
    assert OVERRIDE.search('x.add_theme_color_override("font_color", Color("ffffff"))')
    assert LITERAL.search('Color("ffffff"))') and LITERAL.search('Color(0.5, 1, 1))')
    assert not LITERAL.search('SURFACE.GOLD)') and not LITERAL.search('IVORY if a else GOLD)')
    assert LITERAL.search('SURFACE.GOLD if open else Color("8d6a5a"))')
    assert LABEL.search('_label(panel,"x",Vector2.ZERO,Vector2.ONE,12,Color("ffffff"))')
    assert not OVERRIDE.search('x.add_theme_color_override("font_shadow_color", Color.BLACK)')


def main():
    self_test()
    found = violations()
    for item in found:
        print('LITERAL_TEXT_COLOR ' + item)
    print('UI_TEXT_COLORS %s literal=%d exempt_files=%d' % ('PASS' if not found else 'FAIL', len(found), len(EXEMPT)))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
