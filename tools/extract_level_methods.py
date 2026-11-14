"""Move a set of methods out of a large script into a static helper.

usage: tools/extract_level_methods.py m1,m2,... helper_name HELPER_CONST "doc line"
           [--source godot/scripts/main_level.gd] [--param level]
The source keeps one-line forwarders with the original names; moved functions
take the object as their first argument and call each other through
`<param>.<name>`, so overrides in validation subclasses still run. Locals typed
from a source method's declared return type keep that type; preload constants
used as types are copied into the helper. Methods using `await` or `super`
stay in the source (reported as KEPT). Afterwards: parse-check both scripts (godot --check-only), check
wrappers whose default arguments contain a comma, run the related suites.
"""
import argparse,re,keyword
from pathlib import Path
ap=argparse.ArgumentParser()
for a in ('names','helper','const','doc'): ap.add_argument(a)
ap.add_argument('--source',default='godot/scripts/main_level.gd'); ap.add_argument('--param',default='level')
args=ap.parse_args()
SRC=Path(args.source); MOVE=args.names.split(','); HELPER=args.helper; CONST=args.const; DOC=args.doc; PARAM=args.param
text=SRC.read_text(); lines=text.split('\n')
members=set()
for l in lines:
    m=re.match(r'^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|const|func|signal)\s+(\w+)',l)
    if m: members.add(m.group(1))
INHERITED={'add_child','remove_child','move_child','get_child','get_children','get_child_count','get_node','get_node_or_null','has_node','get_tree','get_parent','get_viewport','get_viewport_rect','create_tween','queue_redraw','queue_free','is_inside_tree','add_to_group','remove_from_group','is_in_group','set_meta','get_meta','has_meta','call_deferred','set_process','set_physics_process','global_position','position','get_path','get_path_to','find_child','get_window','to_local','to_global','get_global_mouse_position','get_local_mouse_position','set_deferred','has_method','has_signal','connect','emit_signal','get_canvas_transform','get_global_transform','scale','visible','z_index','modulate','name','get_script','process_mode','tree_exiting','is_queued_for_deletion','call','callv','get','set','get_instance_id','set_process_input','set_process_unhandled_input','get_physics_process_delta_time','get_process_delta_time','propagate_call','get_world_2d','reset_physics_interpolation','global_rotation','rotation','monitoring','monitorable','collision_layer','collision_mask','get_overlapping_bodies','get_overlapping_areas','top_level','show','hide','is_visible_in_tree','get_index','get_rid','velocity','is_on_floor','is_on_wall','is_on_ceiling','is_on_floor_only','is_on_wall_only','move_and_slide','get_wall_normal','get_floor_normal','get_real_velocity','get_slide_collision_count','get_slide_collision','get_last_slide_collision','floor_snap_length','up_direction','test_move','get_position_delta','apply_floor_snap','add_collision_exception_with','remove_collision_exception_with','move_and_collide'}
starts=[i for i,l in enumerate(lines) if re.match(r'^(static )?func ',l)]
spans={}
for a,b in zip(starts,starts[1:]+[len(lines)]):
    name=re.match(r'^(?:static )?func (\w+)',lines[a]).group(1)
    e=b
    # A top-level declaration between two methods belongs to neither.
    for k in range(a+1,b):
        if re.match(r'^(?:@\w+|const |var |signal |enum |class )',lines[k]): e=k; break
    while e>a+1 and (not lines[e-1].strip() or lines[e-1].startswith('#')): e-=1
    spans[name]=(a,e)
for n in MOVE: assert n in spans,n
# Coroutines and methods calling super stay where they are.
kept=[n for n in MOVE if re.search(r'\b(await|super)\b','\n'.join(lines[spans[n][0]+1:spans[n][1]]))]
if kept: print('KEPT (await/super):',','.join(kept))
MOVE=[n for n in MOVE if n not in kept]
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
                elif t=='self': res.append(PARAM)
                elif t in MOVE:
                    # Keep virtual dispatch: a level subclass (tests override
                    # several of these) must still run its own version.
                    res.append(PARAM+'.'+t)
                elif t in members or t in INHERITED: res.append(PARAM+'.'+t)
                else:
                    res.append(t)
                    if not keyword.iskeyword(t) and not t[0].isupper(): unknown.setdefault(t,name)
            else:
                if t.startswith('$'): raise SystemExit('node path shorthand in '+name)
                res.append(t)
            if t.strip(): prev=t
        s=''.join(res)
        s=re.sub('\0\\(\\s*\\)','('+PARAM+')',s); s=re.sub('\0\\(','('+PARAM+', ',s)
        assert '\0' not in s,line
        # loosen inferred declarations that now read through the untyped level
        d=re.match(r'^(\s*)var (\w+)\s*:=\s*(.*)$',s)
        if d and (re.search(r'\b'+PARAM+r'\.',d.group(3)) or any(re.search(r'(?<![\w.])'+re.escape(v)+r'\b',d.group(3)) for v in loose)):
            if not re.match(r'^(float|int|String|bool|Vector2|Vector2i|Rect2|Color|Array|Dictionary|str|maxf|minf|maxi|mini|clampf|clampi|absf|absi)\(',d.group(3)):
                loose.add(d.group(2)); s=f'{d.group(1)}var {d.group(2)} = {d.group(3)}'
        out.append(s)
    sig=f'static func {public(name)}({PARAM}: Node{", "+params if params else ""}){ret}:'
    call=f'{CONST}.{public(name)}(self{", "+", ".join(pnames) if pnames else ""})'
    void=ret.replace(' ','') in ('','->void')
    wrapper=[head,'    '+('' if void else 'return ')+call]
    return [sig]+out,wrapper,loose
helper=['extends RefCounted',f'## {DOC}',f'## Moved out of {SRC.name} unchanged in behaviour; it keeps one-line','## methods of the same names, so callers and validations are unaffected.','']
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
# The helper constant goes after the last top-level preload constant (or after
# the extends/class_name header).
olines=out.split('\n'); at=None
for k,l in enumerate(olines):
    if re.match(r'^const \w+\s*:?=\s*preload\("[^"]*"\)\s*$',l): at=k+1
    if re.match(r'^(static )?func ',l): break
if at is None: at=next(k for k,l in enumerate(olines) if l.startswith('extends ') or l.startswith('class_name '))+1
olines.insert(at,f'const {CONST} := preload("res://scripts/{HELPER}.gd")'); out='\n'.join(olines)
# Locals read through the untyped object regain the source method's return type.
ret={m.group(1):m.group(2).strip() for m in re.finditer(r'^func (\w+)\(.*\)\s*->\s*([\w\[\]]+)\s*:',text,re.M)}
for k,l in enumerate(helper):
    m=re.match(r'^(\s*)var (\w+) = '+PARAM+r'\.(\w+)\((.*)\)\s*$',l)
    if m and ret.get(m.group(3)) not in (None,'void','Variant'):
        helper[k]=f'{m.group(1)}var {m.group(2)}: {ret[m.group(3)]} = {PARAM}.{m.group(3)}({m.group(4)})'
# Constants used as types cannot be read through a parameter: copy the preload.
body='\n'.join(helper); typed=sorted(set(re.findall(r'(?:->|:|\bas|\bis)\s*'+PARAM+r'\.([A-Z_][A-Z0-9_]*)\b',body)))
consts=[]
for n in typed:
    m=re.search(r'^const '+n+r'\s*:?=\s*preload\([^)]*\)\s*$',text,re.M)
    if not m: raise SystemExit('type constant is not a preload: '+n)
    consts.append(m.group(0)); body=re.sub(r'((?:->|:)\s*|\bas |\bis )'+PARAM+r'\.'+n+r'\b',r'\1'+n,body)
# Calls through a preload constant (`level.POLICY.f([a, b])`) lose static
# typing, so typed-array arguments arrive untyped: read those constants directly.
for n in sorted(set(re.findall(r'\b'+PARAM+r'\.([A-Z][A-Z0-9_]*)\.',body))):
    m=re.search(r'^const '+n+r'\s*:?=\s*preload\("[^"]*"\)\s*$',text,re.M)
    if m:
        if m.group(0) not in consts: consts.append(m.group(0))
        body=re.sub(r'\b'+PARAM+r'\.'+n+r'\.',n+'.',body)
helper=body.split('\n'); helper[4:4]=consts
GD={'true','false','null','and','or','not','if','elif','else','for','while','in','is','as','var','const','func','return','pass','break','continue','match','await','preload','load','print','push_error','push_warning','range','len','str','int','float','bool','min','max','abs','clamp','lerp','sign','round','floor','ceil','sqrt','pow','absf','absi','minf','maxf','mini','maxi','clampf','clampi','lerpf','roundf','roundi','floorf','floori','ceilf','ceili','signf','signi','snappedf','snapped','is_instance_valid','is_equal_approx','is_zero_approx','typeof','weakref','randf','randi','randf_range','randi_range','deg_to_rad','rad_to_deg','sin','cos','tan','atan2','fmod','fposmod','posmod','wrapf','wrapi','move_toward','remap','inverse_lerp','smoothstep','is_finite','is_nan','var_to_str','str_to_var','hash','void','static',PARAM,'super','PI','TAU','INF','NAN','instance_from_id','type_string','error_string','printerr','print_rich','when'}
left={k:v for k,v in unknown.items() if k not in GD}
print('UNKNOWN bare identifiers:',left)
(SRC.parent/f'{HELPER}.gd').write_text('\n'.join(helper).rstrip('\n')+'\n')
SRC.write_text(out)
print(SRC.name,'lines',len(lines),'->',out.count('\n')+1,'helper lines',len(helper))
