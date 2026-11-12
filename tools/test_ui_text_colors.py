#!/usr/bin/env python3
"""U01: runtime UI text colours come from a named palette.

Scans the runtime scripts for text colours written as a literal and fails on
any that is not listed in EXEMPT with the reason it stays:

- add_theme_color_override("font_color" | "default_color", <expr>)
  (Label / Button text and RichTextLabel body text);
- the interface's _label(..., <colour>) helper.

Calls are read whole, so one formatted over several lines is still checked.
Shadows and outlines are not text colour and are not checked.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
# Not shipped UI: validations, captures, fixtures and previews.
SKIP = re.compile(r'(validation|capture|fixture|probe|preview|_test|showcase)')
TEXT_KEYS = ('font_color', 'default_color')
OVERRIDE = re.compile(r'add_theme_color_override\(')
LABEL = re.compile(r'(?<![A-Za-z0-9_.])_label\(')
# Color("abc"), Color("#abc"), Color(0.5, ...), Color(.5, ...), Color8(...), Color.html(...)
LITERAL = re.compile(r'Color8?\(\s*(?:"#?[0-9a-fA-F]+"|[0-9.])|Color\.html\(')
# (file, text the expression must contain): one specific call, never a whole file.
EXEMPT = {
    ('main_level.gd', 'if current else (Color(0.86, 0.94, 0.80) if visited else'):
        'legacy chapter map: current / visited / unvisited room names are told apart by colour',
}


def call_arguments(text, start):
    """Top-level arguments of the call whose '(' is at text[start - 1]."""
    args, depth, quote, current, index = [], 0, '', [], start
    while index < len(text):
        char = text[index]
        if quote:
            current.append(char)
            if char == '\\':
                current.append(text[index + 1])
                index += 1
            elif char == quote:
                quote = ''
        elif char in '"\'':
            quote = char
            current.append(char)
        elif char in '([{':
            depth += 1
            current.append(char)
        elif char in ')]}':
            if depth == 0:
                args.append(''.join(current).strip())
                return args
            depth -= 1
            current.append(char)
        elif char == ',' and depth == 0:
            args.append(''.join(current).strip())
            current = []
        else:
            current.append(char)
        index += 1
    return args


def text_colours(source):
    """Yield (line number, colour expression) for every text colour set in source."""
    for match in OVERRIDE.finditer(source):
        args = call_arguments(source, match.end())
        if len(args) >= 2 and args[0].strip('"\'') in TEXT_KEYS:
            yield source.count('\n', 0, match.start()) + 1, args[1]
    for match in LABEL.finditer(source):
        line_start = source.rfind('\n', 0, match.start()) + 1
        if source[line_start:match.start()].lstrip().startswith('func '):
            continue
        args = call_arguments(source, match.end())
        if args:
            yield source.count('\n', 0, match.start()) + 1, args[-1]


def exempt(name, expression):
    flat = ' '.join(expression.split())
    return any(name == file and needle in flat for file, needle in EXEMPT)


def violations():
    found = []
    for path in sorted(SCRIPTS.glob('*.gd')):
        if SKIP.search(path.name):
            continue
        for number, expression in text_colours(path.read_text(encoding='utf-8')):
            if LITERAL.search(expression) and not exempt(path.name, expression):
                found.append('%s:%d %s' % (path.relative_to(ROOT), number, ' '.join(expression.split())[:80]))
    return found


def unused_exemptions():
    used = set()
    for path in sorted(SCRIPTS.glob('*.gd')):
        for _number, expression in text_colours(path.read_text(encoding='utf-8')):
            flat = ' '.join(expression.split())
            for file, needle in EXEMPT:
                if path.name == file and needle in flat:
                    used.add((file, needle))
    return sorted(set(EXEMPT) - used)


def self_test():
    def literals(source):
        return [expression for _line, expression in text_colours(source) if LITERAL.search(expression)]
    assert literals('x.add_theme_color_override("font_color", Color("ffffff"))')
    assert literals('x.add_theme_color_override("font_color", Color("#ffffff"))')
    assert literals('x.add_theme_color_override("default_color", Color(0.5, 1, 1))')
    assert literals('x.add_theme_color_override("font_color", Color(.5, 1, 1))')
    assert literals('x.add_theme_color_override(\n    "font_color",\n    Color("ffffff"),\n)')
    assert literals('x.add_theme_color_override("font_color", SURFACE.GOLD if open else Color("8d6a5a"))')
    assert literals('_label(panel,"x",Vector2.ZERO,Vector2.ONE,12,Color("ffffff"))')
    assert literals('_label(panel, "a, (b",\n    Vector2.ZERO, Vector2.ONE, 12,\n    Color8(1, 2, 3))')
    assert not literals('x.add_theme_color_override("font_color", SURFACE.GOLD)')
    assert not literals('x.add_theme_color_override("font_color", IVORY if a else GOLD)')
    assert not literals('x.add_theme_color_override("font_shadow_color", Color.BLACK)')
    assert not literals('x.add_theme_color_override("font_outline_color", Color("18252c"))')
    assert not literals('func _label(parent: Control, text: String, color: Color = Color("ffffff")) -> Label:')
    assert not literals('_label(panel,"x",Vector2.ZERO,Vector2.ONE,12,GOLD)')
    assert exempt('main_level.gd', 'Color(0.88, 1.0, 0.95) if current else (Color(0.86, 0.94, 0.80) if visited else Color(0.50, 0.56, 0.52))')
    assert not exempt('main_level.gd', 'Color("ffffff")')
    assert not exempt('other.gd', 'Color(0.88, 1.0, 0.95) if current else (Color(0.86, 0.94, 0.80) if visited else Color(0.50, 0.56, 0.52))')


def main():
    self_test()
    found = violations()
    stale = unused_exemptions()
    for item in found:
        print('LITERAL_TEXT_COLOR ' + item)
    for file, needle in stale:
        print('UNUSED_EXEMPTION %s: %s' % (file, needle))
    failed = bool(found or stale)
    print('UI_TEXT_COLORS %s literal=%d exemptions=%d unused=%d' % ('FAIL' if failed else 'PASS', len(found), len(EXEMPT), len(stale)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
