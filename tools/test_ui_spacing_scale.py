#!/usr/bin/env python3
"""U01: exported runtime container gaps follow the shared spacing scale."""
import bisect
import configparser
import fnmatch
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / 'godot'
SCALE_FILE = GODOT / 'scripts/ui_spacing_scale.gd'
GAP = re.compile(r'(?:(?P<receiver>\b[A-Za-z_]\w*)\s*\.\s*)?\badd_theme_constant_override\(\s*&?"(?P<name>(?:[hv]_)?separation)"\s*,\s*(?P<gap>-?\d+)\s*,?\s*\)', re.M)
FUNCTION = re.compile(r'^func\s+([A-Za-z_]\w*)\s*\(', re.M)
# Only these two calls in this settings function compress the 17-action grid.
DENSE = {
    ('scripts/pilgrimage_interface.gd', '_build_settings_controls', 'remap_grid', 'h_separation', 6),
    ('scripts/pilgrimage_interface.gd', '_build_settings_controls', 'remap_grid', 'v_separation', 1),
}

def scale():
    return {int(value) for value in re.findall(r'^const [A-Z_]+ := (\d+)', SCALE_FILE.read_text(encoding='utf-8'), re.M)}

def export_exclusions():
    config = configparser.ConfigParser(interpolation=None)
    config.read(GODOT / 'export_presets.cfg', encoding='utf-8')
    return [config[s].get('exclude_filter', '').strip('"').split(',') for s in config.sections() if re.fullmatch(r'preset\.\d+', s)]

def shipped(relative, exclusions):
    return not any(part.startswith('.') for part in Path(relative).parts) and not (
        exclusions and all(any(fnmatch.fnmatchcase(relative, pattern) for pattern in patterns if pattern) for patterns in exclusions)
    )

def scan(text, relative, allowed):
    functions = list(FUNCTION.finditer(text))
    starts = [m.start() for m in functions]
    found, used = [], set()
    for match in GAP.finditer(text):
        index = bisect.bisect_right(starts, match.start()) - 1
        function = functions[index].group(1) if index >= 0 else ''
        gap = int(match['gap'])
        key = (relative, function, match['receiver'], match['name'], gap)
        if key in DENSE:
            used.add(key)
        elif gap not in allowed:
            found.append((text.count('\n', 0, match.start()) + 1, gap))
    return found, used

def violations():
    allowed, exclusions = scale(), export_exclusions()
    found, used = [], set()
    for path in sorted(GODOT.rglob('*.gd')):
        relative = path.relative_to(GODOT).as_posix()
        if not shipped(relative, exclusions):
            continue
        issues, applied = scan(path.read_text(encoding='utf-8'), relative, allowed)
        used.update(applied)
        found.extend('godot/%s:%d gap %d' % (relative, number, gap) for number, gap in issues)
    found.extend('unused dense-gap exemption: %r' % (key,) for key in sorted(DENSE - used))
    return found

def self_test():
    allowed = {8, 10, 12, 16}
    assert scale() == allowed
    assert scan('a.add_theme_constant_override(\n "separation",\n 11\n)', 'journey/fieldwork/quest_reader/view.gd', allowed)[0] == [(1, 11)]
    assert scan('a.add_theme_constant_override(&"h_separation", 11,)', 'journey/view.gd', allowed)[0]
    assert not scan('l.add_theme_constant_override("outline_size",4)', 'scripts/ui.gd', allowed)[0]
    remap = 'func _build_settings_controls():\n remap_grid.add_theme_constant_override("h_separation",6)'
    assert not scan(remap, 'scripts/pilgrimage_interface.gd', allowed)[0]
    assert scan(remap.replace('remap_grid.', 'bag_grid.'), 'scripts/pilgrimage_interface.gd', allowed)[0]
    assert scan(remap.replace('_build_settings_controls', '_build_bag'), 'scripts/pilgrimage_interface.gd', allowed)[0]
    assert scan(remap, 'journey/other.gd', allowed)[0]
    assert shipped('journey/fieldwork/quest_reader/view.gd', [['tests/*', 'journey/tests/*']])
    assert not shipped('journey/tests/example.gd', [['tests/*', 'journey/tests/*']])
    assert shipped('scripts/ui.gd', [['scripts/ui.gd'], []])  # One preset still ships it.

def main():
    self_test()
    found = violations()
    for item in found:
        print('OFF_SCALE ' + item)
    print('UI_SPACING_SCALE %s off_scale=%d scale=%s' % ('PASS' if not found else 'FAIL', len(found), sorted(scale())))
    return bool(found)

if __name__ == '__main__':
    sys.exit(main())
