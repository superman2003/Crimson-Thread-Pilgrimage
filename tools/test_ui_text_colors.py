#!/usr/bin/env python3
"""U01: runtime UI text colours come from a named palette.

Scans the runtime scripts for text colours written as a literal and fails on
any that is not listed in EXEMPT with the reason it stays:

- add_theme_color_override(<text key>, <expr>) and Theme.set_color(<text key>,
  <type>, <expr>), where a text key is font_color and its per-state forms
  (font_hover_color, font_disabled_color, ...), default_color or title_color;
- the interface's _label(..., <colour>) helper;
- modulate / self_modulate on receivers declared as text controls or created
  by a text-control constructor / _label helper. Sprite tints stay separate.

Calls are read whole, so one formatted over several lines is still checked.
Shadows and outlines are not text colour and are not checked.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
# Every shipped runtime-script tree: the main scripts and the journey workbench
# autoload. Addons and tests are not game UI.
ROOTS = (SCRIPTS, ROOT / 'godot' / 'journey')
# Not shipped UI: validations, captures, fixtures and previews.
SKIP = re.compile(r'(validation|capture|fixture|probe|preview|_test|showcase)')
# Every theme colour that paints text: base, per-state (font_hover_color,
# font_disabled_color, ...), RichTextLabel body and window titles. Shadows and
# outlines sit behind the text and are left alone.
TEXT_KEY = re.compile(r'^(?:font(?:_[a-z]+)*_color|default_color|title_color)$')
NOT_TEXT = ('font_shadow_color', 'font_outline_color')
OVERRIDE = re.compile(r'add_theme_color_override\(')
# Theme.set_color(name, theme_type, colour)
SET_COLOR = re.compile(r'\.set_color\(')
LABEL = re.compile(r'(?<![A-Za-z0-9_])_label\(')
TEXT_TYPES = r'(?:Label|RichTextLabel|Button|CheckButton|CheckBox|MenuButton|OptionButton|LinkButton)'
TEXT_TYPED = re.compile(r'\b([A-Za-z_]\w*)\s*:\s*' + TEXT_TYPES + r'\b')
TEXT_CREATED = re.compile(r'\b([A-Za-z_]\w*)\s*(?::\s*\w+\s*)?:?=\s*(?:' + TEXT_TYPES + r'\.new\(|(?:\w+\.)?_label\()')
MODULATION = re.compile(r'(?<![A-Za-z0-9_.])(?:(?:self\.)?(?P<receiver>[A-Za-z_]\w*)\.)?(?:self_)?modulate\s*=(?!=)')
# Color("abc"), Color("#abc"), Color(0.5, ...), Color(.5, ...), Color8(...), Color.html(...)
LITERAL = re.compile(r'Color8?\(\s*(?:"[^"]*"|\'[^\']*\'|[0-9.])|Color\.(?:html|hex|hex64|from_[a-z0-9_]+)\(')
# (file, text the expression must contain): one specific call, never a whole file.
EXEMPT = {
    ('main_level.gd', 'if current else (Color(0.86, 0.94, 0.80) if visited else'):
        'legacy chapter map: current / visited / unvisited room names are told apart by colour',
}


def runtime_scripts():
    for root in ROOTS:
        for path in sorted(root.rglob('*.gd')):
            if not SKIP.search(path.name):
                yield path


def strip_comments(source):
    """Blank out # comments, keeping line breaks and any # inside a string."""
    out, quote, index = [], '', 0
    while index < len(source):
        char = source[index]
        if quote:
            out.append(char)
            if char == '\\' and index + 1 < len(source):
                out.append(source[index + 1])
                index += 1
            elif char == quote:
                quote = ''
        elif char in '"\'':
            quote = char
            out.append(char)
        elif char == '#':
            while index < len(source) and source[index] != '\n':
                index += 1
            continue
        else:
            out.append(char)
        index += 1
    return ''.join(out)


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


def text_key(argument):
    name = argument.lstrip('&').strip('"\'')
    return bool(TEXT_KEY.match(name)) and name not in NOT_TEXT


def assignment_expression(source, start):
    """Read the assignment through balanced constructors, preserving newlines."""
    depth, quote, index = 0, '', start
    while index < len(source):
        char = source[index]
        if quote:
            if char == '\\':
                index += 1
            elif char == quote:
                quote = ''
        elif char in '\"\'':
            quote = char
        elif char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
        elif char in '\n;' and depth == 0:
            break
        index += 1
    return source[start:index]


def text_colours(source):
    """Yield (line number, colour expression) for every text colour set in source."""
    source = strip_comments(source)
    text_receivers = set(TEXT_TYPED.findall(source)) | set(TEXT_CREATED.findall(source))
    if re.search(r'^\s*extends\s+' + TEXT_TYPES + r'\b', source, re.M):
        text_receivers.add('self')
    for match in MODULATION.finditer(source):
        receiver = match['receiver'] or 'self'
        if receiver in text_receivers:
            yield source.count('\n', 0, match.start()) + 1, assignment_expression(source, match.end())
    for match in OVERRIDE.finditer(source):
        args = call_arguments(source, match.end())
        if len(args) >= 2 and text_key(args[0]):
            yield source.count('\n', 0, match.start()) + 1, args[1]
    for match in SET_COLOR.finditer(source):
        args = call_arguments(source, match.end())
        if len(args) == 3 and text_key(args[0]):
            yield source.count('\n', 0, match.start()) + 1, args[2]
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
    for path in runtime_scripts():
        for number, expression in text_colours(path.read_text(encoding='utf-8')):
            if LITERAL.search(expression) and not exempt(path.name, expression):
                found.append('%s:%d %s' % (path.relative_to(ROOT), number, ' '.join(expression.split())[:80]))
    return found


def unused_exemptions():
    used = set()
    for path in runtime_scripts():
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
    assert literals('ui._label(panel,"x",Vector2.ZERO,Vector2.ONE,12,Color("ffffff"))')
    assert literals('x.add_theme_color_override(&"font_color", Color("ffffff"))')
    assert not literals('x.add_theme_color_override(&"font_shadow_color", Color("000000"))')
    assert not literals('ui._label(panel,"x",Vector2.ZERO,Vector2.ONE,12,ui.GOLD)')
    assert literals('x.add_theme_color_override("font_hover_color", Color("ffffff"))')
    assert literals('x.add_theme_color_override("font_disabled_color", Color.hex(0xffffffff))')
    assert literals('x.add_theme_color_override("font_color", Color.from_hsv(0.5, 1.0, 1.0))')
    assert literals('target.set_color("font_color","Button",Color("ffffff"))')
    assert literals('target.set_color("title_color","Window",Color.from_rgba8(1, 2, 3))')
    assert not literals('target.set_color("font_hover_color","Button",GOLD)')
    assert not literals('target.set_color("font_outline_color","Label",Color("000000"))')
    assert not literals('image.set_color("font_color", Color("ffffff"))')
    assert literals('x.add_theme_color_override("font_color", Color("red"))')
    assert literals("x.add_theme_color_override('font_color', Color('red'))")
    assert literals('var hearts: Label\nhearts.modulate = Color("red")')
    assert literals('var caption := Label.new()\ncaption.self_modulate = Color(\n 1, 0, 0\n)')
    assert literals('var title = ui._label(panel,"x",Vector2.ZERO,Vector2.ONE,12,GOLD)\ntitle.modulate = Color("red")')
    assert literals('func tint(label: RichTextLabel):\n label.modulate = Color("red")')
    assert literals('extends Label\nfunc tint():\n self_modulate = Color("red")')
    assert not literals('var icon := Sprite2D.new()\nicon.modulate = Color("red")')
    assert not literals('var hearts: Label\nhearts.modulate = RED if hp < 2 else IVORY')
    assert not literals('var hearts: Label\n# hearts.modulate = Color("red")')
    assert not literals('# x.add_theme_color_override("font_color", Color("ffffff"))')
    assert not literals('y = 1  # was: x.add_theme_color_override("font_color", Color("ffffff"))')
    assert literals('x.text = "a # b"; x.add_theme_color_override("font_color", Color("ffffff"))')
    assert [line for line, _e in text_colours('# c\n\nx.add_theme_color_override("font_color", Color("fff"))')] == [3]
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
