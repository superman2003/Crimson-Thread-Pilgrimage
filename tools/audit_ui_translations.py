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
CJK_PUNCT = re.compile(r'[，。！？；：（）【】《》、\u3000「」]')
FORBIDDEN_MT = (
    (re.compile(r'\binvincible group\b', re.I), 'mistranslation: "无敌群" means no enemy horde, not invincible group'),
    (re.compile(r'\b(?:spork master|candle caster)\b', re.I), 'mistranslation: "孢钟匠" must be Spore Bellmaker'),
    (re.compile(r'\bbell fingers\b', re.I), 'mistranslation: "钟舌" must be bell clapper'),
    (re.compile(r'\bslow subtitles for large characters\b', re.I), 'mistranslation: "大字慢字幕" means large text & slow subtitles'),
    (re.compile(r'\b(?:clockboard|clock hands|clock moths|sleepless clock|clock tide|clock path)\b', re.I), 'mistranslation: bell term rendered as clock'),
    (re.compile(r'\b(?:rainforge|rain cast)\b', re.I), 'terminology drift: use Rain Foundry'),
    (re.compile(r'\bsalt white\b'), 'terminology drift: use Saltwhite'),
    (re.compile(r'\b(?:bell niche|chime shrine)\b', re.I), 'terminology drift: use Bell Shrine'),
    (re.compile(r'\bweapon slot\b', re.I), 'terminology drift: use Tool slot'),
    (re.compile(r'\bunfounded testimonies\b', re.I), 'mistranslation: "未发现证言" means undiscovered testimonies, not unfounded'),
    (re.compile(r'\bcontinuous battle\b', re.I), 'mistranslation: "连战" must be Boss Rush'),
    (re.compile(r'\bfull armor\b', re.I), 'mistranslation: "全甲" means flawless/unscathed top grade, not full armor'),
)
SEMANTIC_GUARDS = {
    '装备': 'Equipment',
    '绯线攀壁': 'Crimson Wall Climb',
    '荆棘下刺': 'Thorn Downstrike',
    '线技费用倍率': 'Thread Art Cost Multiplier',
    '入口会在战斗时封闭。': 'The entrance closes during combat.',
    '击败苔脉守卫，取回绯线冲刺。': 'Defeat the Moss Vein Guardian and claim Crimson Dash.',
    '击败苔钟守母，取回王冠裂片。': 'Defeat the Moss Bell Matriarch and claim the Crown Shard.',
    '假苔地板一踩就塌。': 'The false moss floor collapses as soon as you step on it.',
    '巡礼战车沿古道往返。': 'Pilgrim war chariots patrol back and forth along the old road.',
    '用已取得能力、已获装备、已知任务和持有物资建立成长观察快照，比较两次观察间的变化。个人目标只引用已知条目，不授予成长或自动跟踪未知目标。':
        'Create a growth snapshot from acquired abilities, equipment, known quests, and carried supplies, then compare two observations. Personal goals reference known entries only. They grant no growth and do not track unknown goals.',
}


def entry_errors(source, text):
    if not isinstance(text, str) or not text.strip():
        return ['missing translation']
    errors = []
    if HAN.search(text):
        errors.append('English still contains Chinese')
    if CJK_PUNCT.search(text):
        errors.append('English contains fullwidth CJK punctuation')
    if '不推定为空槽' in source and 'likely an empty slot' in text.lower():
        errors.append('inverted warning meaning for empty slot')
    for pattern, reason in FORBIDDEN_MT:
        if pattern.search(text):
            errors.append(reason)
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
        assert entry_errors('安全工房无敌群', 'Invincible group in the safety workshop')
        assert entry_errors('旧记录未说明；不推定为空槽', 'Old records are not specified; likely an empty slot')
        assert entry_errors('孢钟匠', 'Candle Caster')
        assert entry_errors('钟龛', 'bell niche')
        assert entry_errors('雨铸匠', 'Rainforge Smith')
        assert entry_errors('说明', 'Note，with CJK comma')
        assert entry_errors('方案', 'Plan 「1」')
        assert entry_errors('已退出连战。', 'Exited the continuous battle.')
        assert entry_errors('尚有%d条未发现证言', 'There are still %d unfounded testimonies')
        assert entry_errors('回声复考·全甲', 'Echo retake · Full armor')
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
