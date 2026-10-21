#!/usr/bin/env python3
"""Apply/check/restore one real font across Godot and the browser prototype.

No dependencies for applying or restoring. Backups are local, content checked,
and never overwrite edits made after a font change. Run from any directory.
"""
from __future__ import annotations
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
GLOBAL='res://assets/fonts/GlobalTypeface.otf'
THEME='res://assets/ui/global_typeface.tres'
BOOTSTRAP='res://scripts/global_typography.gd'
BOOTSTRAP_TEXT='''extends Node
## Runtime installation avoids loading an imported font before a fresh editor scan.
func _enter_tree() -> void:
    get_tree().root.theme=load("res://assets/ui/global_typeface.tres") as Theme
'''
THEME_TEXT='''[gd_resource type="Theme" load_steps=2 format=3]

[ext_resource type="FontFile" path="res://assets/fonts/GlobalTypeface.otf" id="1"]

[resource]
default_font = ExtResource("1")
default_font_size = 18
'''
CSS_BLOCK='''/* global-typeface:start */
@font-face {
  font-family: "FengMingGlobal";
  src: url("../godot/assets/fonts/GlobalTypeface.otf") format("opentype");
  font-display: swap;
}
/* global-typeface:end */
'''

def digest(data):return hashlib.sha256(data).hexdigest()
def local(root,relative):
    path=(root/relative).resolve()
    if not path.is_relative_to(root.resolve()):raise ValueError('Backup path leaves the project: '+relative)
    return path
def atomic(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.font-switch.tmp')
    temporary.write_bytes(data)
    os.replace(temporary,path)
def sources(root):
    for folder in ('godot/scripts','godot/scenes','godot/tests'):
        for path in sorted((root/folder).rglob('*')):
            if path.is_file() and path.suffix in ('.gd','.tscn','.tres'):yield path
def section_setting(text,name,key,value):
    line=f'{key}="{value}"'
    section=re.search(r'(?ms)^\['+re.escape(name)+r'\]\s*\n(.*?)(?=^\[|\Z)',text)
    if section:
        body=section.group(1)
        body=re.sub(r'(?m)^'+re.escape(key)+r'=.*$',line,body) if re.search(r'(?m)^'+re.escape(key)+r'=',body) else body.rstrip()+'\n'+line+'\n\n'
        return text[:section.start(1)]+body+text[section.end(1):]
    return text.rstrip()+'\n\n['+name+']\n\n'+line+'\n'
def make_plan(root,font):
    font_data=font.read_bytes()
    if font_data[:4] not in (b'OTTO',b'\x00\x01\x00\x00',b'true'):
        raise ValueError('Choose a real .otf or .ttf font file, not an image.')
    result={root/'godot/assets/fonts/GlobalTypeface.otf':font_data,
            root/'godot/assets/ui/global_typeface.tres':THEME_TEXT.encode(),
            root/'godot/scripts/global_typography.gd':BOOTSTRAP_TEXT.encode()}
    for path in sources(root):
        original=path.read_text(encoding='utf-8-sig')
        changed=original
        changed=re.sub(r'res://[^\s"\']+\.(?:ttf|otf)',GLOBAL,changed)
        changed=changed.replace('ThemeDB.fallback_font',f'preload("{GLOBAL}")')
        if changed!=original:result[path]=changed.encode('utf-8')
    project=root/'godot/project.godot'
    text=project.read_text(encoding='utf-8-sig')
    # Editor boot runs before first-time font import. Install the root theme at
    # runtime instead; remove only the old managed GUI entries, preserving others.
    for key,value in [('theme/custom',THEME),('theme/custom_font',GLOBAL)]:
        text=re.sub(r'(?m)^'+re.escape(key)+r'="'+re.escape(value)+r'"\s*\n','',text)
    text=re.sub(r'(?ms)^\[gui\]\s*(?=^\[|\Z)','',text)
    text=section_setting(text,'autoload','GlobalTypography','*'+BOOTSTRAP)
    result[project]=(text.rstrip()+'\n').encode('utf-8')
    css=root/'src/styles.css'
    if css.exists():
        text=css.read_text(encoding='utf-8-sig')
        text=re.sub(r'/\* global-typeface:start \*/.*?/\* global-typeface:end \*/\s*','',text,flags=re.S)
        text=re.sub(r'font-family:\s*[^;]+;','font-family: "FengMingGlobal", serif;',text)
        result[css]=(CSS_BLOCK+'\n'+text).encode('utf-8')
    web=root/'src/main.js'
    if web.exists():
        text=web.read_text(encoding='utf-8-sig')
        text=text.replace('800 22px Microsoft YaHei, sans-serif','22px FengMingGlobal, serif')
        result[web]=text.encode('utf-8')
    return {p:d for p,d in result.items() if not p.exists() or p.read_bytes()!=d}

def apply(root,font):
    plan=make_plan(root,font)
    if not plan:
        print('Already applied. All text uses the shared font. No new backup needed.')
        return 0
    folder=root/'tmp/font_switch_backups'
    latest=folder/'latest.json'
    baseline={}
    if latest.exists():
        previous=local(folder,json.loads(latest.read_text(encoding='utf-8'))['backup'])
        baseline={item['path']:item for item in json.loads(previous.read_text(encoding='utf-8'))['entries']}
        for item in baseline.values():
            path=local(root,item['path'])
            if not path.exists() or digest(path.read_bytes())!=item['applied_sha256']:
                raise ValueError('File changed since the last apply; preserve or restore that edit before switching fonts: '+item['path'])
    for path,data in plan.items():
        name=path.relative_to(root).as_posix()
        baseline[name]={'path':name,'before':baseline[name]['before'] if name in baseline else base64.b64encode(path.read_bytes()).decode() if path.exists() else None,'applied_sha256':digest(data)}
    entries=list(baseline.values())
    # Rollback this application only; the persistent restore snapshot retains the
    # first pre-application contents across font A -> font B and bypass repairs.
    rollback={path:path.read_bytes() if path.exists() else None for path in plan}
    backup=folder/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ.json')
    snapshot={'version':1,'font':str(font),'entries':entries}
    atomic(backup,json.dumps(snapshot,ensure_ascii=False,indent=2).encode('utf-8'))
    try:
        for path,data in plan.items():atomic(path,data)
    except OSError:
        for path,before in rollback.items():
            if before is not None:atomic(path,before)
            elif path.exists():path.unlink()
        raise
    atomic(backup.parent/'latest.json',json.dumps({'backup':backup.name}).encode())
    print(f'Applied one shared font to {len(plan)} files. Menus, body text, dialogue, maps, loading, signs, numbers and browser text are included.')
    print('Backup: '+str(backup.relative_to(root)))
    return check(root)

def check(root):
    failures=[]
    font=root/'godot/assets/fonts/GlobalTypeface.otf'
    if not font.exists():failures.append('Shared font is missing')
    theme=root/'godot/assets/ui/global_typeface.tres'
    if not theme.exists() or GLOBAL not in theme.read_text(encoding='utf-8'):failures.append('Global theme is missing')
    project=(root/'godot/project.godot').read_text(encoding='utf-8')
    if 'GlobalTypography="*'+BOOTSTRAP+'"' not in project:failures.append('Runtime root theme is not installed')
    bootstrap=root/'godot/scripts/global_typography.gd'
    if not bootstrap.exists() or THEME not in bootstrap.read_text(encoding='utf-8'):failures.append('Root theme bootstrap is missing')
    for path in sources(root):
        text=path.read_text(encoding='utf-8-sig')
        for match in re.finditer(r'res://[^\s"\']+\.(?:ttf|otf)|ThemeDB\.fallback_font',text):
            if match.group()!=GLOBAL:failures.append(f'{path.relative_to(root)}: uncentralized font {match.group()}')
    css=root/'src/styles.css'
    if css.exists() and 'global-typeface:start' not in css.read_text(encoding='utf-8'):failures.append('Browser theme is not connected')
    for failure in failures:print('FAIL: '+failure)
    if not failures:print('GLOBAL_FONT_CHECK_PASS: no old font references or default-font bypasses remain.')
    return 1 if failures else 0

def restore(root):
    folder=root/'tmp/font_switch_backups'
    latest=folder/'latest.json'
    if not latest.exists():
        print('No font backup to restore. Nothing changed.')
        return 0
    selected=json.loads(latest.read_text(encoding='utf-8'))['backup']
    backup=local(folder,selected)
    entries=json.loads(backup.read_text(encoding='utf-8'))['entries']
    # Complete preflight: do not partially restore or clobber subsequent edits.
    conflicts=[]
    for item in entries:
        path=local(root,item['path'])
        if not path.exists() or digest(path.read_bytes())!=item['applied_sha256']:conflicts.append(item['path'])
    if conflicts:
        print('Restore stopped: these files changed after applying the font. No files were overwritten:')
        print('\n'.join(conflicts))
        return 1
    for item in entries:
        path=local(root,item['path'])
        if item['before'] is None:path.unlink()
        else:atomic(path,base64.b64decode(item['before']))
    latest.unlink()
    print(f'Restored {len(entries)} files to their exact pre-application contents.')
    return 0

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['apply','check','restore'],nargs='?',default='apply')
    parser.add_argument('--font',type=Path,help='Optional .otf/.ttf file; defaults to the bundled Feng Ming Inscription font')
    args=parser.parse_args()
    try:
        if args.action=='apply':return apply(ROOT,(args.font or ROOT/'tools/font_assets/FengMingInscription.otf').resolve())
        if args.action=='check':return check(ROOT)
        return restore(ROOT)
    except (OSError,ValueError,KeyError) as error:
        print('Font switch failed: '+str(error),file=sys.stderr)
        return 1

if __name__=='__main__':raise SystemExit(main())
