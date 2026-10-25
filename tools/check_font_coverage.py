#!/usr/bin/env python3
"""Check full bundled-font coverage and Godot text without dependencies.

Reads the font's own Unicode cmap, not installed system fonts. A new unsupported
character fails CI with its source location. Rebuild from the full upstream
font or add a native symbol; never silently reduce the font to current strings.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import struct
import unicodedata

ROOT=Path(__file__).resolve().parents[1]
MIN_UPSTREAM_CHARACTERS=44777

def unicode_cmap(path):
    data=Path(path).read_bytes()
    def u16(offset):return struct.unpack_from('>H',data,offset)[0]
    def i16(offset):return struct.unpack_from('>h',data,offset)[0]
    def u32(offset):return struct.unpack_from('>I',data,offset)[0]
    cmap=None
    for index in range(u16(4)):
        offset=12+index*16
        if data[offset:offset+4]==b'cmap':cmap=u32(offset+8)
    if cmap is None:raise ValueError('Font has no Unicode cmap: '+str(path))
    supported=set()
    for index in range(u16(cmap+2)):
        record=cmap+4+index*8
        platform,encoding=u16(record),u16(record+2)
        if platform!=0 and not (platform==3 and encoding in (1,10)):continue
        table=cmap+u32(record+4)
        kind=u16(table)
        if kind in (12,13):
            for group in range(u32(table+12)):
                offset=table+16+group*12
                start,end,glyph=u32(offset),u32(offset+4),u32(offset+8)
                if end>0x10ffff:raise ValueError('Invalid Unicode cmap range')
                if glyph or kind==12:
                    supported.update(range(start+(1 if glyph==0 else 0),end+1))
        elif kind==4:
            count=u16(table+6)//2
            ends=table+14
            starts=ends+count*2+2
            deltas=starts+count*2
            offsets=deltas+count*2
            for segment in range(count):
                delta=i16(deltas+segment*2)
                relative=u16(offsets+segment*2)
                for code in range(u16(starts+segment*2),min(u16(ends+segment*2),0xfffe)+1):
                    glyph=u16(offsets+segment*2+relative+(code-u16(starts+segment*2))*2) if relative else code
                    if (relative==0 or glyph!=0) and (glyph+delta)&0xffff:supported.add(code)
    if not supported:raise ValueError('Font has no supported Unicode cmap format 4/12/13')
    return supported

def runtime_sources(root):
    for folder,directories,files in os.walk(root/'godot'):
        directories[:]=[name for name in directories if name not in ('.godot','addons')]
        for name in sorted(files):
            path=Path(folder)/name
            if path.suffix in ('.gd','.json','.tscn','.tres','.godot'):yield path

def missing_runtime_characters(root,supported):
    missing=[]
    for path in runtime_sources(root):
        for line_number,line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(),1):
            characters=set(line)
            for run in re.findall(r'(?:\\u[0-9a-fA-F]{4})+',line):
                characters.update(json.loads('"'+run+'"'))
            for escaped in re.findall(r'\\u\{([0-9a-fA-F]{1,6})\}|\\U([0-9a-fA-F]{8})',line):
                characters.add(chr(int(next(value for value in escaped if value),16)))
            for char in sorted(characters):
                code=ord(char)
                if char.isspace() or unicodedata.category(char) in ('Cc','Cf','Cs') or 0xfe00<=code<=0xfe0f:continue
                if code not in supported:missing.append({'character':char,'codepoint':f'U+{code:04X}','path':path.relative_to(root).as_posix(),'line':line_number})
    return missing

def check(root,report=None):
    supported=unicode_cmap(root/'godot/assets/fonts/GlobalTypeface.otf')
    manifest=json.loads((root/'godot/assets/fonts/FengMingInscription.json').read_text(encoding='utf-8'))
    required={code for start,end in manifest['required_unicode_ranges'] for code in range(start,end+1)}
    missing=missing_runtime_characters(root,supported)
    errors=[]
    if manifest['upstream_characters']<MIN_UPSTREAM_CHARACTERS or len(supported)<MIN_UPSTREAM_CHARACTERS:
        errors.append('A complete upstream Unicode repertoire is required; text-based subsets are not supported')
    if required-supported:errors.append('Font lost required characters: '+', '.join(f'U+{code:04X}' for code in sorted(required-supported)[:30]))
    errors.extend(f"{item['path']}:{item['line']}: missing {item['character']} ({item['codepoint']})" for item in missing)
    result={'supported_characters':len(supported),'upstream_characters':manifest['upstream_characters'],
            'required_characters':len(required),'missing_required':len(required-supported),'missing_runtime':missing,'errors':errors}
    if report:
        report.parent.mkdir(parents=True,exist_ok=True)
        report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for error in errors:print('FAIL: '+error)
    print(f"FONT_COVERAGE_{'FAIL' if errors else 'PASS'} characters={len(supported)} missing={len(required-supported)+len(missing)} system_fonts_used=false")
    return 1 if errors else 0

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    try:return check(ROOT,args.report)
    except (OSError,ValueError,KeyError,struct.error) as error:
        print('FONT_COVERAGE_FAIL: '+str(error))
        return 1

if __name__=='__main__':raise SystemExit(main())
