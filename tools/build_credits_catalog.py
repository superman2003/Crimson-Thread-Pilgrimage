#!/usr/bin/env python3
"""Bundle byte-exact release notices for the native read-only credits reader."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from build_release import notice_files

ROOT = Path(__file__).resolve().parents[1]
MAX_DOCUMENT = 262144
MAX_TOTAL = 1048576
MAX_ENTRIES = 64
OUTPUT = Path('godot/data/credits')


def build(root: Path) -> dict[Path, bytes]:
    documents = notice_files(root)
    if not documents or len(documents) > MAX_ENTRIES:
        raise ValueError('release notice count outside supported range')
    result: dict[Path, bytes] = {}
    entries = []
    total = 0
    for path in documents:
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'notice must be a regular file: {path}')
        source = path.relative_to(root).as_posix()
        raw = path.read_bytes()
        if not raw or len(raw) > MAX_DOCUMENT:
            raise ValueError(f'notice size outside supported range: {source}')
        text = raw.decode('utf-8-sig', errors='strict')
        if not text.strip() or '\x00' in text:
            raise ValueError(f'notice is not readable text: {source}')
        total += len(raw)
        if total > MAX_TOTAL:
            raise ValueError('release notices exceed total reader budget')
        identity = hashlib.sha256(source.encode('utf-8')).hexdigest()[:12]
        target = OUTPUT / (identity + '.txt')
        if target in result:
            raise ValueError('notice identity collision')
        result[target] = raw
        group = ('项目说明' if path.parent == root else
                 '引擎扩展' if 'addons' in path.parts else
                 '字体' if 'fonts' in path.parts else '素材记录')
        title = ('项目代码许可' if source == 'LICENSE' else
                 '项目第三方来源说明' if source == 'THIRD_PARTY_NOTICES.md' else
                 path.parent.name + ' / ' + path.name)
        entries.append({'id': identity, 'title': title, 'group': group,
                        'source': source, 'file': 'res://data/credits/' + target.name,
                        'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)})
    index = {'version': 1, 'entries': entries}
    result[OUTPUT / 'index.json'] = (json.dumps(index, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    return result


def synchronize(root: Path, check: bool) -> list[str]:
    expected = build(root)
    output = root / OUTPUT
    actual = set(output.iterdir()) if output.is_dir() else set()
    errors = []
    for relative, raw in expected.items():
        path = root / relative
        actual.discard(path)
        if not path.is_file() or path.is_symlink() or path.read_bytes() != raw:
            errors.append('stale or missing credit document: ' + relative.as_posix())
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.is_symlink():
                    raise ValueError('output may not replace a symlink')
                path.write_bytes(raw)
    for path in sorted(actual):
        if path.name.endswith('.import'):
            continue
        errors.append('unexpected credit payload: ' + path.relative_to(root).as_posix())
        if not check:
            if not path.is_file() or path.is_symlink():
                raise ValueError('unexpected non-regular credits payload')
            path.unlink()
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        errors = synchronize(ROOT, args.check)
    except (OSError, UnicodeError, ValueError) as error:
        print('CREDITS_CATALOG_FAIL:', error)
        return 1
    if args.check and errors:
        for error in errors: print('FAIL:', error)
        return 1
    print('CREDITS_CATALOG_PASS byte_exact=true mode=' + ('check' if args.check else 'build'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
