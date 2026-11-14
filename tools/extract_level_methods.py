"""Move a set of main_level.gd methods into a static helper taking `level`."""
import re,sys,keyword
from pathlib import Path
SRC=Path('godot/scripts/main_level.gd')
MOVE=sys.argv[1].split(','); HELPER=sys.argv[2]; CONST=sys.argv[3]; DOC=sys.argv[4]
text=SRC.read_text(); lines=text.split('\n')
members=set()
for l in lines:
    m=re.match(r'^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|const|func|signal)\s+(\w+)',l)
    if m: members.add(m.group(1))
INHERITED={'add_child','remove_child','move_child','get_child','get_children','get_child_count','get_node','get_node_or_null','has_node','get_tree','get_parent','get_viewport','get_viewport_rect','create_tween','queue_redraw','queue_free','is_inside_tree','add_to_group','remove_from_group','is_in_group','set_meta','get_meta','has_meta','call_deferred','set_process','set_physics_process','global_position','position','get_path','get_path_to','find_child','get_window','to_local','to_global','get_global_mouse_position','get_local_mouse_position','set_deferred','has_method','has_signal','connect','emit_signal','get_canvas_transform','get_global_transform','scale','visible','z_index','modulate','name','get_script','process_mode','tree_exiting'}
starts=[i for i,l in enumerate(lines) if re.match(r'^(static )?func ',l)]
spans={}
for a,b in zip(starts,starts[1:]+[len(lines)]):
    name=re.match(r'^(?:static )?func (\w+)',lines[a]).group(1)
    e=b
    while e>a+1 and (not lines[e-1].strip() or lines[e-1].startswith('#')): e-=1
    spans[name]=(a,e)
for n in MOVE: assert n in spans,n
TOKEN=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#.*$|&"(?:\\.|[^"\\])*"|[A-Za-z_][A-Za-z0-9_]*|\$[A-Za-z_/%][\w/%]*|.',re.S)
def public(n): return n.lstrip('_')
unknown={}
def convert(name):
    a,e=spans[name]; body=lines[a:e]
    head=body[0]
    m=re.match(r'^func (\w+)\((.*)\)(\s*->\s*[\w\[\], .]+)?\s*:\s*$',head)
    assert m,head
    params=m.group(2).strip(); ret=m.group(3) or ''
    locals_=set(re.findall(r'(\w+)\s*(?::[^=,]+)?(?:=[^,]*)?(?:,|$)',params)) if params else set()
    pnames=[p.split(':')[0].split('=')[0].strip() for p in re.split(r',(?![^\[]*\])',params)] if params else []
    locals_=set(pnames)
    joined='\n'.join(body[1:])
    locals_|=set(re.findall(r'\bvar\s+(\w+)',joined))|set(re.findall(r'\bfor\s+(\w+)\s+in\b',joined))
    for lam in re.findall(r'\bfunc\s*\(([^)]*)\)',joined):
        locals_|={p.split(':')[0].split('=')[0].strip() for p in lam.split(',') if p.strip()}
    out=[]; loose=set()
    for line in body[1:]:
        toks=TOKEN.findall(line); res=[]; prev=''
        for i,t in enumerate(toks):
            if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',t):
                nxt=''.join(toks[i+1:]).lstrip()[:1]
                if prev=='.' or t in locals_: res.append(t)
                elif t=='self': res.append('level')
                elif t in MOVE:
                    if nxt=='(':
                        res.append(public(t)); res.append('\0')   # marker: insert level arg
                    else: res.append('level.'+t)
                elif t in members or t in INHERITED: res.append('level.'+t)
                else:
                    res.append(t)
                    if not keyword.iskeyword(t) and not t[0].isupper(): unknown.setdefault(t,name)
            else:
                if t.startswith('$'): raise SystemExit('node path shorthand in '+name)
                res.append(t)
            if t.strip(): prev=t
        s=''.join(res)
        s=re.sub('\0\\(\\s*\\)','(level)',s); s=re.sub('\0\\(','(level, ',s)
        assert '\0' not in s,line
        # loosen inferred declarations that now read through the untyped level
        d=re.match(r'^(\s*)var (\w+) := (.*)$',s)
        if d and (re.search(r'\blevel\.',d.group(3)) or any(re.search(r'(?<![\w.])'+re.escape(v)+r'\b',d.group(3)) for v in loose)):
            if not re.match(r'^(float|int|String|bool|Vector2|Vector2i|Rect2|Color|Array|Dictionary|str|maxf|minf|maxi|mini|clampf|clampi|absf|absi)\(',d.group(3)):
                loose.add(d.group(2)); s=f'{d.group(1)}var {d.group(2)} = {d.group(3)}'
        out.append(s)
    sig=f'static func {public(name)}(level: Node{", "+params if params else ""}){ret}:'
    call=f'{CONST}.{public(name)}(self{", "+", ".join(pnames) if pnames else ""})'
    void=ret.replace(' ','') in ('','->void')
    wrapper=[head,'    '+('' if void else 'return ')+call]
    return [sig]+out,wrapper,loose
helper=['extends RefCounted',f'## {DOC}','## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line','## methods of the same names, so callers and validations are unaffected.','']
replace={}
for n in sorted(MOVE,key=lambda n:spans[n][0]):
    body,wrapper,loose=convert(n)
    helper+=body+['','']
    replace[n]=wrapper
    if loose: print('LOOSE',n,sorted(loose))
new=[];i=0
order=sorted(MOVE,key=lambda n:spans[n][0]); idx={spans[n][0]:n for n in order}
while i<len(lines):
    if i in idx:
        n=idx[i]; new+=replace[n]; i=spans[n][1]
    else: new.append(lines[i]); i+=1
out='\n'.join(new)
anchor='const WORLD_ATLAS := preload("res://scripts/world_atlas.gd")\n'
assert out.count(anchor)==1
out=out.replace(anchor,anchor+f'const {CONST} := preload("res://scripts/{HELPER}.gd")\n')
GD={'true','false','null','and','or','not','if','elif','else','for','while','in','is','as','var','const','func','return','pass','break','continue','match','await','preload','load','print','push_error','push_warning','range','len','str','int','float','bool','min','max','abs','clamp','lerp','sign','round','floor','ceil','sqrt','pow','absf','absi','minf','maxf','mini','maxi','clampf','clampi','lerpf','roundf','roundi','floorf','floori','ceilf','ceili','signf','signi','snappedf','snapped','is_instance_valid','is_equal_approx','is_zero_approx','typeof','weakref','randf','randi','randf_range','randi_range','deg_to_rad','rad_to_deg','sin','cos','tan','atan2','fmod','fposmod','posmod','wrapf','wrapi','move_toward','remap','inverse_lerp','smoothstep','is_finite','is_nan','var_to_str','str_to_var','hash','void','static','level','super','PI','TAU','INF','NAN','instance_from_id','type_string','error_string','printerr','print_rich','when'}
left={k:v for k,v in unknown.items() if k not in GD}
print('UNKNOWN bare identifiers:',left)
Path(f'godot/scripts/{HELPER}.gd').write_text('\n'.join(helper).rstrip('\n')+'\n')
SRC.write_text(out)
print('main_level lines',len(lines),'->',out.count('\n')+1,'helper lines',len(helper))
