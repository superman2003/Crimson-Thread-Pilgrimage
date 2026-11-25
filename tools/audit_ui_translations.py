#!/usr/bin/env python3
"""Check English coverage, legacy button lengths and runtime substitutions."""
import json
import re
import sys
from collections import Counter
from pathlib import Path

from ui_translation_sources import HAN, inventory

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'godot/data/ui_translations.json'
FORMAT = re.compile(r'%(?:%|[+#0-]*\d*(?:\.\d+)?[sdifxXoc])')
NAMED = re.compile(r'\{[a-zA-Z_][a-zA-Z_\d:]*\}')
MARKUP = re.compile(r'\[/?(?:b|i|color|font_size|center|url)(?:=[^\]]+)?\]')
SEMANTIC_GUARDS = {
    '装备': 'Equipment',
    '入口会在战斗时封闭。': 'The entrance closes during combat.',
    '用已取得能力、已获装备、已知任务和持有物资建立成长观察快照，比较两次观察间的变化。个人目标只引用已知条目，不授予成长或自动跟踪未知目标。':
        'Create a growth snapshot from acquired abilities, equipment, known quests, and carried supplies, then compare two observations. Personal goals reference known entries only. They grant no growth and do not track unknown goals.',
}


def entry_errors(source, text):
    if not isinstance(text, str) or not text.strip():
        return ['missing translation']
    errors = []
    if HAN.search(text):
        errors.append('English still contains Chinese')
    source_fields = [field for field in FORMAT.findall(source) if field != '%%']
    text_fields = [field for field in FORMAT.findall(text) if field != '%%']
    if source_fields != text_fields:
        errors.append('format fields changed')
    if source_fields and '%' in FORMAT.sub('', text):
        errors.append('literal percent in formatted translation must be escaped as %%')
    if Counter(NAMED.findall(source)) != Counter(NAMED.findall(text)):
        errors.append('named fields changed')
    if MARKUP.findall(source) != MARKUP.findall(text) or source.count('\n') != text.count('\n'):
        errors.append('rich text or line breaks changed')
    if source in SEMANTIC_GUARDS and text != SEMANTIC_GUARDS[source]:
        errors.append('reviewed semantic guard changed')
    return errors


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
        assert not entry_errors('槽 %d · %.2f%%', 'Slot %d · %.2f%%')
        assert entry_errors('松脂 %d', 'Resin')
        assert entry_errors('按 {key:jump}', 'Press {key:dash}')
        assert entry_errors('旅记', 'Journal 旅记')
        assert not entry_errors('保留%d', 'Keep %d and 60%%')
        assert entry_errors('保留%d', 'Keep %d and 60%')
        assert entry_errors('装备', 'Recorded Time')
        assert entry_errors('入口会在战斗时封闭。', 'The entrance requires a Crimson Dash.')
        print('UI_TRANSLATIONS self-test OK')
        return 0
    data = json.loads(PATH.read_text(encoding='utf-8'))
    sources = dict(inventory())
    authored = set().union(*sources.values())
    found = problems(data, {f'"{s}"' for s in authored})
    messages = dict(data['messages'])
    for name in ('hints', 'journal', 'story', 'game'):
        path = PATH.with_name(f'ui_en_{name}.json')
        for source, text in json.loads(path.read_text(encoding='utf-8'))['messages'].items():
            if source in messages:
                found.append(f'{path.name}: duplicate source: {source}')
            messages[source] = text
            for error in entry_errors(source, text):
                found.append(f'{path.name}: {error}: {source}')
    for path, strings in sources.items():
        for source in sorted(strings - messages.keys()):
            found.append(f'{path.relative_to(ROOT)}: missing English: {source}')
    for line in found:
        print('UI_TRANSLATIONS', line)
    print(f'UI_TRANSLATIONS entries={len(messages)} problems={len(found)}')
    return 1 if found else 0


if __name__ == '__main__':
    raise SystemExit(main())
