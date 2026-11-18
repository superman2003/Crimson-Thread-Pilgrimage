"""Remove one-line forwarders left behind by tools/extract_level_methods.py.

usage: tools/inline_forwarders.py godot/scripts/main_level.gd [--dry-run]

A forwarder `func _name(args): return HELPER.name(self, args)` is removed only
when every use of `_name` is a direct call, all of those calls sit in the
source script itself or in HELPER (the script it forwards to), no other file
names it (validations, tools, scenes, data), no script extending the source
overrides it, and it is not public API (no leading underscore). Calls become
`HELPER.name(self, …)` in the source and `name(<param>, …)` inside HELPER, so
no new preload, and therefore no preload cycle, is introduced.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')


def forwarders(lines):
    out = {}
    for i, line in enumerate(lines[:-1]):
        m = re.match(r'^func (_\w+)\((.*)\)(\s*->\s*[\w\[\], .]+)?\s*:\s*$', line)
        if not m:
            continue
        body = re.match(r'^    (return )?(await )?([A-Z_][A-Z0-9_]*)\.(\w+)\(self(?:, (.*))?\)\s*$', lines[i + 1])
        following = [l for l in lines[i + 2:i + 3] if l.strip()]
        if body and not (following and following[0].startswith('    ')):
            out[m.group(1)] = {'line': i, 'const': body.group(3), 'target': body.group(4), 'await': bool(body.group(2)), 'defaults': '=' in m.group(2)}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source'); ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()
    src = Path(args.source); base = src.name
    text = src.read_text(encoding='utf-8'); lines = text.split('\n')
    fw = forwarders(lines)
    consts = {m.group(1): m.group(2) for m in re.finditer(r'^const ([A-Z_][A-Z0-9_]*) := preload\("res://scripts/(\w+)\.gd"\)', text, re.M)}
    helpers = {}
    for path in SCRIPTS.glob('*.gd'):
        body = path.read_text(encoding='utf-8')
        if f'## Moved out of {base} ' in body:
            pm = re.search(r'^static func \w+\((\w+): ', body, re.M)
            helpers[path.stem] = (path, body, pm.group(1) if pm else None)
    own = {src.resolve()} | {h[0].resolve() for h in helpers.values()}
    # Every identifier used anywhere else in the project.
    elsewhere = set()
    for pattern in ('godot/**/*.gd', 'godot/**/*.tscn', 'godot/**/*.tres', 'godot/**/*.json', 'tools/**/*.py', 'tools/**/*.gd', 'tools/**/*.mjs'):
        for path in ROOT.glob(pattern):
            if path.resolve() in own or '.godot' in path.parts:
                continue
            try:
                elsewhere |= set(IDENT.findall(path.read_text(encoding='utf-8', errors='ignore')))
            except OSError:
                pass
    overridden = set()
    for path in SCRIPTS.glob('*.gd'):
        body = path.read_text(encoding='utf-8')
        if f'extends "res://scripts/{base}"' in body:
            overridden |= set(re.findall(r'^\s*func (\w+)\(', body, re.M))
    chosen = {}
    for name, info in fw.items():
        if name in overridden or name in elsewhere:
            continue
        helper = consts.get(info['const'])
        if helper not in helpers:
            continue
        hpath, hbody, param = helpers[helper]
        # Callers may rely on defaults the helper signature no longer has.
        sig = re.search(r'^static func ' + info['target'] + r'\((.*)\)', hbody, re.M)
        if sig is None or (info['defaults'] and '=' not in sig.group(1)):
            continue
        # A bare `name(param, …)` call would be shadowed by a local of that name.
        if re.search(r'\b(?:var|for)\s+' + info['target'] + r'\b', hbody):
            continue
        ok = True
        for path, body in [(src, text)] + [(h[0], h[1]) for h in helpers.values()]:
            # Strings and method references (no call) keep the forwarder.
            if re.search(r'["\']' + name + r'["\']|&"' + name + '"', body):
                ok = False; break
            for m in re.finditer(r'(?<![\w])(?:(\w+)\.)?' + name + r'\b(\s*\()?', body):
                # A call on another instance (`candidate._name(`) needs the method.
                if m.group(1) and m.group(1) not in ('self', param):
                    ok = False; break
                start = m.start()
                line_start = body.rfind('\n', 0, start) + 1
                if body[line_start:start].lstrip().startswith('func ') and body[line_start:].startswith('func ' + name + '('):
                    continue  # the forwarder's own definition
                if not m.group(2):
                    ok = False; break
                if path.resolve() not in (src.resolve(), hpath.resolve()):
                    ok = False; break
            if not ok:
                break
        if ok:
            chosen[name] = info
    print(f'{base}: forwarders={len(fw)} removable={len(chosen)}')
    if args.dry_run or not chosen:
        return
    # Rewrite calls in the source: `_name(` / `self._name(` -> `CONST.target(self, `.
    def rewrite(body, mapping, receiver, in_helper=None):
        for name, info in mapping.items():
            if in_helper is not None and consts[info['const']] != in_helper:
                continue
            if in_helper is None:
                call = f"{info['const']}.{info['target']}("
                body = re.sub(r'(?<![\w.])(?:self\.)?' + name + r'\s*\(\s*\)', call + 'self)', body)
                body = re.sub(r'(?<![\w.])(?:self\.)?' + name + r'\s*\(', call + 'self, ', body)
            else:
                body = re.sub(r'(?<![\w.])' + receiver + r'\.' + name + r'\s*\(\s*\)', f"{info['target']}({receiver})", body)
                body = re.sub(r'(?<![\w.])' + receiver + r'\.' + name + r'\s*\(', f"{info['target']}({receiver}, ", body)
        return body
    # Drop the forwarder definitions first (with the blank line after them).
    drop = set()
    for info in chosen.values():
        drop |= {info['line'], info['line'] + 1}
    kept = [l for i, l in enumerate(lines) if i not in drop]
    new_src = re.sub(r'\n{4,}', '\n\n\n', rewrite('\n'.join(kept), chosen, 'self'))
    src.write_text(new_src, encoding='utf-8')
    for stem, (hpath, hbody, param) in helpers.items():
        if param:
            new = rewrite(hbody, chosen, param, in_helper=stem)
            if new != hbody:
                hpath.write_text(new, encoding='utf-8')
    print(f'{base}: {len(lines)} -> {new_src.count(chr(10)) + 1} lines')


if __name__ == '__main__':
    main()
