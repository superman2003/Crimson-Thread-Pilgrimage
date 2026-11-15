"""Move top-level functions (and everything they depend on) out of a large tool.

usage: tools/split_python_module.py tools/big.py new_module "doc line" name1,name2,...
           [--keep main,other]

The named functions, plus every top-level function, class and constant they
reach, move verbatim into tools/<new_module>.py together with the imports they
use. The source imports each moved name back explicitly, so its namespace (and
anything importing from it) is unchanged. Names listed in --keep, `main`, and
anything that reads globals()/sys.modules[__name__] stay put; the script fails
if a moved definition would depend on a kept one.
"""
import argparse
import ast
import re
import sys
from pathlib import Path


def loads(node):
    return {n.id for n in ast.walk(node) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)} | \
        {n.value.id for n in ast.walk(node) if isinstance(n, ast.Attribute) and isinstance(n.value, ast.Name)}


def bound(node):
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
        return {node.name}
    if isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        return {n.id for t in targets for n in ast.walk(t) if isinstance(n, ast.Name)}
    if isinstance(node, (ast.Import, ast.ImportFrom)):
        return {(a.asname or a.name).split('.')[0] for a in node.names}
    return set()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source'); ap.add_argument('module'); ap.add_argument('doc'); ap.add_argument('names')
    ap.add_argument('--keep', default='main')
    args = ap.parse_args()
    path = Path(args.source); text = path.read_text(encoding='utf-8'); lines = text.split('\n')
    tree = ast.parse(text)
    keep = set(args.keep.split(',')) | {'main'}
    defs, imports, order = {}, {}, []
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            for name in bound(node):
                imports[name] = node
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Assign, ast.AnnAssign)):
            for name in bound(node):
                defs[name] = node
            order.append(node)
    seeds = [n for n in args.names.split(',') if n]
    for n in seeds:
        if n not in defs:
            raise SystemExit(f'not a top-level definition: {n}')
    moving, queue = set(), list(seeds)
    while queue:
        node = defs[queue.pop()]
        if id(node) in moving:
            continue
        names = bound(node)
        if names & keep:
            raise SystemExit(f'{sorted(names)} is kept but a moved definition needs it')
        segment = ast.get_source_segment(text, node) or ''
        if re.search(r'\bglobals\(\)|sys\.modules\[__name__\]|\bglobal\b', segment):
            raise SystemExit(f'{sorted(names)} reads module globals and cannot move')
        moving.add(id(node))
        for dep in loads(node):
            if dep in defs and id(defs[dep]) not in moving:
                queue.append(dep)
    moved = [node for node in order if id(node) in moving]
    # Line spans include decorators and the comment block directly above.
    def span(node):
        start = min([node.lineno] + [d.lineno for d in getattr(node, 'decorator_list', [])]) - 1
        while start > 0 and lines[start - 1].lstrip().startswith('#'):
            start -= 1
        return start, node.end_lineno
    spans = [span(node) for node in moved]
    used = set().union(*(loads(node) for node in moved))
    needed = []
    for name, node in imports.items():
        if name in used and node not in needed:
            needed.append(node)
    needed += [n for n in tree.body if isinstance(n, ast.ImportFrom) and n.module == '__future__' and n not in needed]
    needed.sort(key=lambda n: n.lineno)
    header = [f'"""{args.doc}', '', f'Moved out of {path.name} unchanged; {path.name} imports these names back."""']
    body = header + [ast.get_source_segment(text, n) for n in needed] + ['']
    for (a, b) in spans:
        body += [''] + lines[a:b] + ['']
    out_path = path.parent / f'{args.module}.py'
    if out_path.exists():
        raise SystemExit(f'{out_path} already exists')
    out_path.write_text('\n'.join(body).rstrip('\n') + '\n', encoding='utf-8')
    names = sorted(set().union(*(bound(n) for n in moved)))
    drop = set()
    for (a, b) in spans:
        drop.update(range(a, b))
    kept = [l for i, l in enumerate(lines) if i not in drop]
    src = '\n'.join(kept)
    src = re.sub(r'\n{3,}', '\n\n\n', src)
    new_tree = ast.parse(src)
    last_import = max((n.end_lineno for n in new_tree.body if isinstance(n, (ast.Import, ast.ImportFrom))), default=0)
    kept_lines = src.split('\n')
    wrapped, line = [], f'from {args.module} import ('
    for name in names:
        if len(line) + len(name) + 2 > 100:
            wrapped.append(line.rstrip()); line = '    '
        line += name + ', '
    wrapped.append(line.rstrip().rstrip(',') + ')')
    kept_lines[last_import:last_import] = wrapped
    path.write_text('\n'.join(kept_lines), encoding='utf-8')
    print(f'{path.name}: {len(lines)} -> {len(kept_lines)} lines; {out_path.name}: {len(body)} lines, {len(names)} names')


if __name__ == '__main__':
    main()
