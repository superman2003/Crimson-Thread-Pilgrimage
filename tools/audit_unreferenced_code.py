#!/usr/bin/env python3
"""List (or with --apply, delete) functions and constants of one GDScript file
that nothing in godot/ or tools/ mentions.

"Mentions" is any occurrence of the identifier, including inside strings, so
methods called by name (`call("x")`, job tables, signals) count as used. Engine
callbacks are always kept. Removing one unit can strand its helpers, so the
scan repeats until nothing else falls out. Read the list before applying.

    python3 tools/audit_unreferenced_code.py godot/scripts/main_level.gd [--apply]
"""
import re,sys
from collections import Counter
from pathlib import Path
word=re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
ENGINE={'_ready','_process','_physics_process','_input','_unhandled_input','_unhandled_key_input','_shortcut_input','_gui_input','_notification','_exit_tree','_enter_tree','_draw','_init','_to_string','_get','_set','_get_property_list','_get_minimum_size','_make_custom_tooltip','_can_drop_data','_drop_data','_get_drag_data','_has_point','_get_configuration_warnings','_integrate_forces','_validate_property'}
def corpus_without(target):
    c=Counter()
    for root,pats in [('godot',['*.gd','*.tscn']),('tools',['*.py','*.gd','*.mjs'])]:
        for pat in pats:
            for p in Path(root).rglob(pat):
                if '.godot' in p.parts or 'third_party' in p.parts or p.as_posix()==target: continue
                c.update(word.findall(p.read_text(errors='ignore')))
    return c
def units(text):
    lines=text.split('\n'); out=[]; i=0
    while i<len(lines):
        l=lines[i]
        m=re.match(r'^(?:static )?func (\w+)',l); c=re.match(r'^const (\w+)',l)
        if m:
            j=i+1
            while j<len(lines) and not re.match(r'^(?:static )?func |^const |^var |^@|^signal |^class |^enum |^#',lines[j]): j+=1
            k=j
            while k>i+1 and not lines[k-1].strip(): k-=1
            out.append(('func',m.group(1),i,k)); i=j
        elif c:
            j=i
            if l.rstrip().endswith(('{','[','(')):
                j=i+1
                while j<len(lines) and not re.match(r'^[}\]\)]',lines[j]): j+=1
            out.append(('const',c.group(1),i,j+1)); i=j+1
        else: i+=1
    return lines,out
target=sys.argv[1]; apply='--apply' in sys.argv
other=corpus_without(target); src=Path(target).read_text(); before=src.count('\n')+1; removed=[]
while True:
    lines,us=units(src); own=Counter(word.findall(src))
    kill=[u for u in us if u[1] not in ENGINE and other[u[1]]==0 and own[u[1]]<=1]
    if not kill: break
    drop=set()
    for kind,name,a,b in kill:
        removed.append((kind,name,b-a)); k=a
        while k>0 and lines[k-1].startswith('#'): k-=1
        drop.update(range(k,b))
    src='\n'.join(l for i,l in enumerate(lines) if i not in drop)
src=re.sub(r'\n{4,}','\n\n\n',src)
print(target,'lines',before,'->',src.count('\n')+1,'funcs',sum(r[0]=='func' for r in removed),'consts',sum(r[0]=='const' for r in removed))
print(' consts:',[r[1] for r in removed if r[0]=='const'])
print(' funcs:',[(r[1],r[2]) for r in removed if r[0]=='func'])
if apply: Path(target).write_text(src)
