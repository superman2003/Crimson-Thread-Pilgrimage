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
- CanvasItem/Font draw_string, draw_multiline_string and draw_char text tint;
- local/member variables and containers directly initialized with literals.

Calls are read whole, so one formatted over several lines is still checked.
Shadows and outlines are not text colour and are not checked.
"""
import re
from fnmatch import fnmatchcase
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
# Every shipped runtime-script tree: the main scripts and the journey workbench
# autoload. Addons and tests are not game UI.
ROOTS = (SCRIPTS, ROOT / 'godot' / 'journey')
# Every theme colour that paints text: base, per-state (font_hover_color,
# font_disabled_color, ...), RichTextLabel body and window titles. Shadows and
# outlines sit behind the text and are left alone.
TEXT_KEY = re.compile(r'^(?:font(?:_[a-z]+)*_color|default_color|title_color)$')
NOT_TEXT = ('font_shadow_color', 'font_outline_color')
OVERRIDE = re.compile(r'add_theme_color_override\(')
# Theme.set_color(name, theme_type, colour)
SET_COLOR = re.compile(r'\.set_color\(')
LABEL = re.compile(r'(?<![A-Za-z0-9_])_label\(')
TEXT_TYPES = r'(?:Label|RichTextLabel|Button|CheckButton|CheckBox|MenuButton|OptionButton|LinkButton|LineEdit|TextEdit|CodeEdit|ItemList|Tree|TabBar|TabContainer|SpinBox|MenuBar|PopupMenu|Window|AcceptDialog|ConfirmationDialog|FileDialog)'
DRAW_TEXT = re.compile(r'(?<![A-Za-z0-9_])(?P<method>draw_string|draw_multiline_string|draw_char)\(')
DRAW_COLOR_ARGUMENT = {'draw_string': 6, 'draw_multiline_string': 7, 'draw_char': 4}
ASSIGNMENT = re.compile(r'^[ \t]*(?:(?P<declaration>var|const)\s+)?(?P<name>[A-Za-z_]\w*)\s*(?::\s*[^=\n]+)?\s*(?::=|=(?!=))', re.M)
TEXT_TYPED = re.compile(r'\b([A-Za-z_]\w*)\s*:\s*' + TEXT_TYPES + r'\b')
TEXT_CREATED = re.compile(r'\b([A-Za-z_]\w*)\s*(?::\s*\w+\s*)?:?=\s*(?:' + TEXT_TYPES + r'\.new\(|(?:\w+\.)?_label\()')
# var title := find_child(...) as Label
TEXT_CAST = re.compile(r'\b([A-Za-z_]\w*)\s*(?::\s*\w+\s*)?:?=[^\n=][^\n]*\bas\s+' + TEXT_TYPES + r'\b')
FUNC = re.compile(r'^(?:static\s+)?func\b', re.M)
MODULATION = re.compile(r'(?<![A-Za-z0-9_.])(?:(?:self\.)?(?P<receiver>[A-Za-z_]\w*)\.)?(?:self_)?modulate\s*=(?!=)')
# Color("abc"), Color("#abc"), Color(0.5, ...), Color(.5, ...), Color8(...), Color.html(...)
# A constructor or factory only counts when its first argument is itself a
# literal: Color.from_hsv(hue, s, v) built from variables is not hard-coded.
LITERAL = re.compile(r'(?:Color8?|Color\.(?:html|hex|hex64|from_[a-z0-9_]+))\(\s*(?:"[^"]*"|\'[^\']*\'|[0-9.])')
# (file, text the expression must contain): one specific call, never a whole file.
EXEMPT = {
    ('main_level.gd', 'if current else (Color(0.86, 0.94, 0.80) if visited else'):
        'legacy chapter map: current / visited / unvisited room names are told apart by colour',
}


def export_exclusions():
    presets = (ROOT / 'godot/export_presets.cfg').read_text(encoding='utf-8')
    filters = re.findall(r'^exclude_filter="([^"]*)"', presets, re.M)
    if not filters:
        raise ValueError('No export exclusion filters found')
    # A file is unshipped only when every configured export excludes it.
    return set.intersection(*(set(value.split(',')) for value in filters))


def shipped_script(path, excluded):
    relative = path.relative_to(ROOT / 'godot').as_posix()
    return not any(fnmatchcase(relative, pattern) for pattern in excluded)


def runtime_scripts():
    excluded = export_exclusions()
    for root in ROOTS:
        for path in sorted(root.rglob('*.gd')):
            if shipped_script(path, excluded):
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


def mask_strings(source):
    """Same length as source, with every string body blanked: code quoted in a
    help or diagnostic string is not a call."""
    out, quote, index = [], '', 0
    while index < len(source):
        char = source[index]
        if quote:
            if char == '\\' and index + 1 < len(source):
                out.append('  ')
                index += 2
                continue
            if char == quote:
                quote = ''
                out.append(char)
            else:
                out.append(char if char == '\n' else ' ')
        else:
            if char in '"\'':
                quote = char
            out.append(char)
        index += 1
    return ''.join(out)


def text_receivers(masked, start, end):
    """Names declared as text controls at member level or inside the function
    that spans [start, end): a Label called marker in one function says nothing
    about a Sprite2D called marker in another."""
    bounds = [match.start() for match in FUNC.finditer(masked)] + [len(masked)]
    scopes = [masked[:bounds[0]]]
    for index in range(len(bounds) - 1):
        if bounds[index] <= start < bounds[index + 1]:
            scopes.append(masked[bounds[index]:bounds[index + 1]])
    names = set()
    for scope in scopes:
        for pattern in (TEXT_TYPED, TEXT_CREATED, TEXT_CAST):
            names.update(pattern.findall(scope))
    return names


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
        elif char == '\\' and source[index + 1:index + 2] == '\n':
            index += 1  # explicit line continuation
        elif char in '\n;' and depth == 0:
            break
        index += 1
    return source[start:index]


def colour_expression(source, position, expression):
    """Follow local/member variable initializers; explicit constants are palettes.

    Only the active function and members are visible, and only assignments
    before this use count. Resolve whole container initializers when an index
    is dynamic, so a literal palette dictionary cannot hide behind colors[key].
    """
    masked = mask_strings(source)
    bounds = [m.start() for m in FUNC.finditer(masked)] + [len(source)]
    scopes = [(0, min(position, bounds[0]))]
    for left, right in zip(bounds, bounds[1:]):
        if left <= position < right:
            scopes.append((left, position))
    initializers = {}
    for left, right in scopes:
        for match in ASSIGNMENT.finditer(masked, left, right):
            name = match['name']
            if match['declaration'] == 'const':
                initializers.pop(name, None)
            else:
                initializers[name] = assignment_expression(source, match.end())
    seen = set()
    def expand(value):
        extras = []
        for name in re.findall(r'\b[A-Za-z_]\w*\b', mask_strings(value)):
            if name in initializers and name not in seen:
                seen.add(name)
                extras.append(expand(initializers[name]))
        return value + ('\n' + '\n'.join(extras) if extras else '')
    return expand(expression)


def text_colours(source):
    """Yield (line number, colour expression) for every text colour set in source."""
    source = strip_comments(source)
    # Calls are located in a copy with string bodies blanked; their arguments
    # are then read from the real text at the same offsets.
    masked = mask_strings(source)
    extends_text = bool(re.search(r'^\s*extends\s+' + TEXT_TYPES + r'\b', masked, re.M))
    for match in MODULATION.finditer(masked):
        receiver = match['receiver'] or 'self'
        if (receiver == 'self' and extends_text) or receiver in text_receivers(masked, match.start(), match.end()):
            yield source.count('\n', 0, match.start()) + 1, colour_expression(source, match.start(), assignment_expression(source, match.end()))
    for match in OVERRIDE.finditer(masked):
        args = call_arguments(source, match.end())
        if len(args) >= 2 and text_key(args[0]):
            yield source.count('\n', 0, match.start()) + 1, colour_expression(source, match.start(), args[1])
    for match in SET_COLOR.finditer(masked):
        args = call_arguments(source, match.end())
        if len(args) == 3 and text_key(args[0]):
            yield source.count('\n', 0, match.start()) + 1, colour_expression(source, match.start(), args[2])
    for match in LABEL.finditer(masked):
        line_start = masked.rfind('\n', 0, match.start()) + 1
        if masked[line_start:match.start()].lstrip().startswith('func '):
            continue
        args = call_arguments(source, match.end())
        if args:
            yield source.count('\n', 0, match.start()) + 1, colour_expression(source, match.start(), args[-1])
    for match in DRAW_TEXT.finditer(masked):
        args = call_arguments(source, match.end())
        index = DRAW_COLOR_ARGUMENT[match['method']]
        if len(args) > index:
            yield source.count('\n', 0, match.start()) + 1, colour_expression(source, match.start(), args[index])


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
    for control in ('LineEdit', 'TextEdit', 'CodeEdit', 'ItemList', 'Tree', 'TabBar', 'PopupMenu'):
        assert literals('var query: '+control+'\nquery.modulate = Color("red")')
    assert literals('draw_string(font, pos, "text", 0, -1, 16, Color("red"))')
    assert literals('font.draw_string(canvas, pos, "text", 0, -1, 16, Color("red"))')
    assert literals('draw_multiline_string(font, pos, "text", 0, -1, 16, -1, Color("red"))')
    assert literals('draw_char(font, pos, "x", 16, Color("red"))')
    assert not literals('draw_string(font, pos, "text")')
    assert literals('var tint := Color("red")\nfunc draw():\n draw_string(font,pos,"x",0,-1,16,tint)')
    assert literals('var colors := {"x": Color("red")}\nfunc draw():\n x.add_theme_color_override("font_color", colors[key])')
    assert literals('func draw():\n var tint := Color("red")\n var alias := tint\n x.add_theme_color_override("font_color", alias)')
    assert not literals('const COLORS := {"x": Color("red")}\nfunc draw():\n x.add_theme_color_override("font_color", COLORS[key])')
    assert not literals('func a():\n var tint := Color("red")\nfunc b(tint):\n x.add_theme_color_override("font_color", tint)')
    exclusions = export_exclusions()
    for relative in ('scripts/example_playback.gd', 'scripts/example_helper.gd', 'scripts/example_checks.gd', 'scripts/inscription_specimen.gd', 'journey/tests/case.gd'):
        assert not shipped_script(ROOT/'godot'/relative, exclusions)
    assert shipped_script(ROOT/'godot/scripts/field_contract_desk.gd', exclusions)
    assert shipped_script(ROOT/'godot/journey/trajectory/plot.gd', exclusions)
    assert not literals('var hearts: Label\nhearts.modulate = RED if hp < 2 else IVORY')
    assert not literals('var hearts: Label\n# hearts.modulate = Color("red")')
    assert literals('var title := find_child("T") as Label\ntitle.modulate = Color("red")')
    assert not literals('var icon := find_child("I") as TextureRect\nicon.modulate = Color("red")')
    assert literals('var hearts: Label\nhearts.modulate = \\\n    Color("red")')
    assert not literals('var help := "x.add_theme_color_override(\\"font_color\\", Color(\\"red\\"))"')
    assert literals('x.add_theme_color_override("font_color", Color("a,b") if "(" in t else GOLD)')
    assert not literals('x.add_theme_color_override("font_color", Color.from_hsv(hue, saturation, value))')
    assert not literals('x.add_theme_color_override("font_color", Color.html(configured_code))')
    assert literals('x.add_theme_color_override("font_color", Color.html("#fff"))')
    assert not literals('func a():\n var marker: Label\n marker.text = ""\nfunc b():\n var marker := Sprite2D.new()\n marker.modulate = Color("red")')
    assert literals('func a():\n var marker := Sprite2D.new()\nfunc b():\n var marker: Label\n marker.modulate = Color("red")')
    assert literals('var marker: Label\nfunc b():\n marker.modulate = Color("red")')
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
