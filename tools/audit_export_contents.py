#!/usr/bin/env python3
"""Audit what the desktop export presets ship, from actual runtime references.

Starting at the main scene and autoloads, follow every literal res:// path in
scripts, scenes, resources and JSON data, plus class_name identifiers. For each
export preset:
  * a reachable script or scene must not be excluded (the release would break);
  * an unreachable script or scene must be excluded (no test fixtures, replays,
    probes or capture scenes in the player's package);
  * every reachable res:// file must exist.
Dynamic paths built at runtime are reported so they can be reviewed by hand.
"""
from __future__ import annotations
import argparse
import fnmatch
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = re.compile(r'res://[A-Za-z0-9_./-]+\.(?:gdshader|tscn|tres|json|res|gd)(?![A-Za-z0-9_])')
# Built paths for code or scenes cannot be followed statically; assets and data
# built from region ids are shipped wholesale by the include filter.
DYNAMIC = re.compile(r'"res://(?:scripts|scenes)/[^"]*(?:%s|%d)[^"]*"|load\(\s*"res://(?:scripts|scenes)/[^"]*"\s*\+')


def project_roots(godot: Path) -> set[str]:
    text = (godot / 'project.godot').read_text(encoding='utf-8')
    roots = {re.search(r'run/main_scene="(res://[^"]+)"', text).group(1)}
    if '[autoload]' in text:
        section = text.split('[autoload]', 1)[1].split('\n[', 1)[0]
        roots.update(re.findall(r'"\*?(res://[^"]+)"', section))
    return roots


def class_names(godot: Path) -> dict[str, str]:
    result = {}
    for path in godot.rglob('*.gd'):
        if '.godot' in path.parts:
            continue
        match = re.search(r'^class_name\s+(\w+)', path.read_text(encoding='utf-8', errors='replace'), re.M)
        if match:
            result[match.group(1)] = 'res://' + path.relative_to(godot).as_posix()
    return result


def reachable(godot: Path) -> tuple[set[str], list[str], list[str]]:
    classes = class_names(godot)
    seen: set[str] = set()
    missing: list[str] = []
    dynamic: list[str] = []
    todo = sorted(project_roots(godot))
    while todo:
        resource = todo.pop()
        if resource in seen:
            continue
        seen.add(resource)
        path = godot / resource[len('res://'):]
        if not path.is_file():
            missing.append(resource)
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        todo.extend(REFERENCE.findall(text))
        if path.suffix == '.gd' and DYNAMIC.search(text):
            dynamic.append(resource)
        for name, script in classes.items():
            if script != resource and re.search(r'\b%s\b' % name, text):
                todo.append(script)
    return seen, sorted(set(missing)), sorted(dynamic)


def presets(godot: Path) -> list[tuple[str, list[str]]]:
    text = (godot / 'export_presets.cfg').read_text(encoding='utf-8')
    result = []
    for block in re.split(r'\n(?=\[preset\.\d+\]\n)', text):
        name = re.search(r'^name="([^"]*)"', block, re.M)
        excludes = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
        if name and excludes is not None:
            result.append((name.group(1), [item for item in excludes.group(1).split(',') if item]))
    return result


def audit(root: Path) -> dict:
    godot = root / 'godot'
    seen, missing, dynamic = reachable(godot)
    candidates = sorted('res://' + path.relative_to(godot).as_posix() for path in godot.rglob('*')
                        if path.suffix in ('.gd', '.tscn') and '.godot' not in path.parts and 'addons' not in path.parts)
    errors = [f'missing runtime reference: {item}' for item in missing]
    errors.extend(f'script or scene path is built dynamically, review export by hand: {item}' for item in dynamic)
    report = {'reachable': sorted(item for item in seen if item in candidates), 'dynamic_loaders': dynamic, 'presets': {}}
    for name, patterns in presets(godot):
        def excluded(item: str) -> bool:
            return any(fnmatch.fnmatch(item[len('res://'):], pattern) for pattern in patterns)
        broken = [item for item in candidates if item in seen and excluded(item)]
        shipped = [item for item in candidates if item not in seen and not excluded(item)]
        errors.extend(f'{name}: runtime file excluded from export: {item}' for item in broken)
        errors.extend(f'{name}: development-only file shipped: {item}' for item in shipped)
        report['presets'][name] = {'excluded_runtime': broken, 'shipped_unreachable': shipped}
    report['errors'] = errors
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    report = audit(args.root)
    if args.report:
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for error in report['errors']:
        print('FAIL: ' + error)
    print(f"EXPORT_AUDIT_{'FAIL' if report['errors'] else 'PASS'} presets={len(report['presets'])} "
          f"reachable={len(report['reachable'])} dynamic_loaders={len(report['dynamic_loaders'])} errors={len(report['errors'])}")
    return 1 if report['errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
