#!/usr/bin/env python3
"""Decode the real combat SFX from an isolated PCK with no source fallback."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"^\s*(?:ERROR:|SCRIPT ERROR:|WARNING: ObjectDB)", re.M)

SCRIPT = '''extends Node
const SOURCE := preload("res://scripts/audio_stream_source.gd")
const MATERIAL := preload("res://scripts/enemy_combat_audio.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok:failures+=1;push_error(message)
func _ready() -> void:
    var entries: Array=JSON.parse_string(FileAccess.get_file_as_string("res://entries.json"))
    for entry in entries:
        var path: String=entry.path
        check(not FileAccess.file_exists(path),"PCK test must have no raw source fallback")
        check(SOURCE.exists(path),"imported material is discoverable: "+entry.id)
        var first:=SOURCE.load_stream(path) as AudioStreamOggVorbis
        var second:=SOURCE.load_stream(path) as AudioStreamOggVorbis
        check(first!=null and second!=null,"imported Ogg decodes: "+entry.id)
        if first==null or second==null:continue
        check(absf(first.get_length()-float(entry.duration_seconds))<.05,"import preserves duration: "+entry.id)
        first.loop=true;second.loop=false
        check(first.loop and not second.loop,"loop variants have independent stream ownership")
        var family: String=entry.family
        var variant:=int(String(entry.id).rsplit("_",true,1)[1])
        check(MATERIAL.path(family,variant)==path,"production dynamic path resolves inside the PCK")
    check(entries.size()==30,"all 30 original combat cues are exported")
    print("COMBAT_SFX_EXPORT clips=%d failures=%d raw_source_fallback=false" % [entries.size(),failures])
    get_tree().quit(0 if failures==0 else 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--log-dir', type=Path, default=ROOT/'output/silksong_research/audio-export')
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:parser.error('Godot executable not found')
    engine = str(Path(engine).resolve())
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='combat-sfx-export-') as temporary:
        scratch = Path(temporary)
        project = scratch/'source'
        project.mkdir()
        entries = json.loads((ROOT/'godot/assets/audio/sfx/ai_combat/manifest.json').read_text(encoding='utf-8'))['entries']
        for entry in entries:
            relative = Path(entry['path'].removeprefix('res://'))
            target = project/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT/'godot'/relative, target)
        scripts = project/'scripts'
        scripts.mkdir()
        for name in ['audio_stream_source.gd', 'enemy_combat_audio.gd']:
            shutil.copyfile(ROOT/'godot/scripts'/name, scripts/name)
        (project/'entries.json').write_text(json.dumps(entries), encoding='utf-8')
        (project/'main.gd').write_text(SCRIPT, encoding='utf-8')
        (project/'Main.tscn').write_text(
            '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n'
            '[node name="Main" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        (project/'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Combat SFX export validation"\n'
            'run/main_scene="res://Main.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        (project/'export_presets.cfg').write_text(
            '[preset.0]\nname="Combat Audio"\nplatform="Windows Desktop"\nrunnable=true\n'
            'export_filter="all_resources"\ninclude_filter="*.json,*.txt,*.md"\nexclude_filter=""\n'
            'export_path="probe.exe"\n[preset.0.options]\nbinary_format/architecture="x86_64"\n', encoding='utf-8')
        player = scratch/'player'
        player.mkdir()
        pack = player/'combat.pck'
        env = dict(os.environ, APPDATA=str(scratch/'userdata'), XDG_DATA_HOME=str(scratch/'userdata'))
        steps = [
            ('import', [engine, '--headless', '--path', str(project), '--editor', '--import', '--quit']),
            ('pack', [engine, '--headless', '--path', str(project), '--export-pack', 'Combat Audio', str(pack)]),
            ('player', [engine, '--headless', '--audio-driver', 'Dummy', '--main-pack', str(pack)]),
        ]
        for name, command in steps:
            result = subprocess.run(command, cwd=player, env=env, capture_output=True, timeout=180)
            output = (result.stdout+result.stderr).decode('utf-8', errors='replace')
            (args.log_dir/(name+'.log')).write_text(output, encoding='utf-8')
            if result.returncode or ERROR.search(output):
                print(output[-5000:])
                return 1
        if 'COMBAT_SFX_EXPORT clips=30 failures=0 raw_source_fallback=false' not in output:
            print(output[-2000:])
            return 1
        print('COMBAT_SFX_EXPORT_PASS clips=30 raw_source_fallback=false independent_loop_variants=true')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
