#!/usr/bin/env python3
"""Audit what the desktop export presets ship, from actual runtime references.

Starting at the main scene and autoloads, follow every literal res:// path in
scripts, scenes, resources and JSON data, plus class_name identifiers. For each
explicit all_resources export preset:
  * any reachable resource must not be excluded (the release would break);
  * an unreachable script or scene must be excluded (no test fixtures, replays,
    probes or capture scenes in the player's package);
  * every reachable res:// file must exist.
Empty, malformed, incomplete or unsupported presets fail closed. Filter matching
follows Godot's case-insensitive * / ? rules, with or without the res:// prefix.
Dynamic script paths built at runtime are reported for manual review; constructed
asset paths, binary resource dependencies and export plugins are not simulated.
"""
from __future__ import annotations
import argparse
import configparser
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = re.compile(r'res://[A-Za-z0-9_./-]+\.(?:gdshaderinc|gdshader|tscn|tres|json|res|gd|png|webp|jpe?g|svg|ogg|wav|ttf|otf|cfg|txt|md|csv)(?![A-Za-z0-9_])')
TEXT_RESOURCES = {'.gd', '.tscn', '.tres', '.json', '.gdshader', '.gdshaderinc', '.cfg'}
# Built paths for code or scenes cannot be followed statically; assets and data
# built from region ids are shipped wholesale by the include filter.
DYNAMIC = re.compile(r'"res://(?:scripts|scenes)/[^"]*(?:%s|%d)[^"]*"|load\(\s*"res://(?:scripts|scenes)/[^"]*"\s*\+')


def discovered_scripts(godot: Path, text: str) -> list[str]:
    """Explicit direct-child script discovery contracts on reachable loaders only.

    Directories are opt-in; this never blesses the surrounding tree or tests.
    The loader owns the contract that every matching script can be loaded.
    """
    result = []
    for pattern in re.findall(r'^# export-discovery: (res://[A-Za-z0-9_/-]+/\*\.gd)$', text, re.M):
        relative = pattern.removeprefix('res://').removesuffix('/*.gd')
        directory = godot / relative
        if not directory.is_dir():
            raise ValueError(f'missing script discovery directory: {pattern}')
        scripts = sorted(directory.glob('*.gd'))
        if not scripts:
            raise ValueError(f'empty script discovery directory: {pattern}')
        result.extend('res://' + path.relative_to(godot).as_posix() for path in scripts)
    return result


def project_roots(godot: Path) -> set[str]:
    text = (godot / 'project.godot').read_text(encoding='utf-8')
    main = re.search(r'^run/main_scene="(res://[^"]+)"', text, re.M)
    if main is None:
        raise ValueError('project.godot must declare a res:// main scene')
    roots = {main.group(1)}
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
        # Images, audio, fonts and binary resources are leaves, not source text.
        if path.suffix not in TEXT_RESOURCES:
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        todo.extend(REFERENCE.findall(text))
        if path.suffix == '.gd' and DYNAMIC.search(text):
            dynamic.append(resource)
        if path.suffix == '.gd':
            todo.extend(discovered_scripts(godot, text))
            for name, script in classes.items():
                if script != resource and re.search(r'\b%s\b' % name, text):
                    todo.append(script)
    return seen, sorted(set(missing)), sorted(dynamic)


def presets(godot: Path) -> list[tuple[str, list[str]]]:
    # ConfigFile strings used by these presets share JSON's quoting/escapes.
    # Refuse unsupported export modes rather than treating them as all_resources.
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read_string((godot / 'export_presets.cfg').read_text(encoding='utf-8'))
    result = []
    for section in config.sections():
        if re.fullmatch(r'preset\.\d+\.options', section):
            continue
        if not re.fullmatch(r'preset\.\d+', section):
            raise ValueError(f'unsupported export section: {section}')
        values = {}
        for field in ('name', 'export_filter', 'exclude_filter'):
            raw = config.get(section, field, raw=True, fallback=None)
            if raw is None:
                raise ValueError(f'{section}: missing {field}')
            values[field] = json.loads(raw)
            if not isinstance(values[field], str):
                raise ValueError(f'{section}: {field} must be a quoted string')
        name = values['name']
        if not name.strip() or name in [item[0] for item in result]:
            raise ValueError(f'{section}: empty or duplicate preset name: {name!r}')
        if values['export_filter'] != 'all_resources':
            raise ValueError(f'{name}: unsupported export_filter: {values["export_filter"]}')
        result.append((name, [item.strip() for item in values['exclude_filter'].split(',') if item.strip()]))
    if not result:
        raise ValueError('no export presets declared')
    return result


def filter_matches(resource: str, patterns: list[str]) -> bool:
    # Godot 4.6.1 _edit_files_with_filter uses String.matchn on both forms.
    # Unlike Python fnmatch, only * and ? are special; ? cannot match a dot.
    for pattern in patterns:
        expression = ''.join('.*' if ch == '*' else '[^.]' if ch == '?' else re.escape(ch)
                             for ch in pattern)
        if any(re.fullmatch(expression, path, re.I) is not None
               for path in (resource, resource.removeprefix('res://'))):
            return True
    return False


def audit(root: Path) -> dict:
    godot = root / 'godot'
    report = {'reachable': [], 'reachable_resources': [], 'dynamic_loaders': [], 'presets': {}, 'errors': []}
    try:
        export_presets = presets(godot)
        seen, missing, dynamic = reachable(godot)
    except (OSError, ValueError, configparser.Error) as error:
        report['errors'].append(f'invalid audit configuration: {error}')
        return report
    candidates = sorted('res://' + path.relative_to(godot).as_posix() for path in godot.rglob('*')
                        if path.suffix in ('.gd', '.tscn') and '.godot' not in path.parts and 'addons' not in path.parts)
    errors = [f'missing runtime reference: {item}' for item in missing]
    errors.extend(f'script or scene path is built dynamically, review export by hand: {item}' for item in dynamic)
    report.update(reachable=sorted(item for item in seen if item in candidates),
                  reachable_resources=sorted(seen), dynamic_loaders=dynamic)
    for name, patterns in export_presets:
        def excluded(item: str) -> bool:
            return filter_matches(item, patterns)
        broken = sorted(item for item in seen if excluded(item))
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
