#!/usr/bin/env python3
"""Keep godot/data/ui_translations.json honest.

Every source line must still be written somewhere in the game's scripts (a
reworded label would otherwise silently fall back to Chinese), translations
must be present, short enough for a button, and free of format placeholders:
the engine only translates text that matches an entry exactly.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'godot/data/ui_translations.json'


def problems(data, sources):
    found = []
    if data.get('schema') != 1 or data.get('locale') != 'en' or not isinstance(data.get('messages'), dict):
        return ['catalogue header is invalid']
    seen = {}
    for source, text in data['messages'].items():
        if not isinstance(text, str) or not text.strip():
            found.append(f'missing translation: {source}')
            continue
        if '%' in source or '%' in text or '{' in text:
            found.append(f'placeholders cannot be translated by exact match: {source}')
        if len(text) > 32:
            found.append(f'translation too long for a control ({len(text)}): {source}')
        if text in seen:
            found.append(f'same translation for two sources: {seen[text]} / {source}')
        seen[text] = source
        if f'"{source}"' not in sources:
            found.append(f'source text no longer appears in any script: {source}')
    return found


def main():
    if '--self-test' in sys.argv:
        good = dict(schema=1, locale='en', messages={'返回': 'Back'})
        assert problems(good, 'x="返回"') == []
        assert problems(good, 'x="回去"') == ['source text no longer appears in any script: 返回']
        assert problems(dict(schema=1, locale='en', messages={'槽 %d': 'Slot %d'}), '"槽 %d"')
        assert problems(dict(schema=1, locale='en', messages={'返回': ''}), '"返回"') == ['missing translation: 返回']
        assert problems(dict(schema=2, locale='en', messages={}), '') == ['catalogue header is invalid']
        print('UI_TRANSLATIONS self-test OK')
        return 0
    data = json.loads(PATH.read_text(encoding='utf-8'))
    scripts = '\n'.join(p.read_text(encoding='utf-8') for p in sorted((ROOT / 'godot/scripts').glob('*.gd'))
                        if not p.name.endswith('_validation.gd'))
    found = problems(data, scripts)
    for line in found:
        print('UI_TRANSLATIONS', line)
    print(f'UI_TRANSLATIONS entries={len(data["messages"])} problems={len(found)}')
    return 1 if found else 0


if __name__ == '__main__':
    raise SystemExit(main())
