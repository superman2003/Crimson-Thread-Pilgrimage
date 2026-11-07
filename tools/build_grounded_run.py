#!/usr/bin/env python3
"""Render/check the native grounded run and wire its fallback cels into Player."""
from hashlib import sha256
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'godot/assets/sprites/player/grounded_run_v1'
MANIFEST = ROOT / 'godot/assets/sprites/player/generated_hero_v3/manifest.json'
SOURCES = [FOLDER / 'source/rig_parts.png', FOLDER / 'source/part_regions.json',
           FOLDER / 'source/rig_parts.png.import',
           ROOT / 'godot/assets/sprites/player/generated_hero_motion_v4/runtime_run/run_00.png',
           ROOT / 'godot/scripts/grounded_run_cycle.gd', ROOT / 'godot/scripts/grounded_run_presentation.gd',
           ROOT / 'godot/shaders/grounded_run_part.gdshader', ROOT / 'tools/bake_grounded_run.gd']


def build(check=False, engine=None):
    receipt_path = FOLDER / 'build_receipt.json'
    if not check:
        task_temp = Path(os.environ.get('TEMP', '/tmp'))
        candidates = [engine, os.environ.get('GODOT'), task_temp / 'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe', shutil.which('godot')]
        executable = next((str(p) for p in candidates if p and Path(p).is_file()), None)
        if executable is None:
            raise ValueError('Godot is required to render grounded run cels; supply --engine or GODOT')
        logs = ROOT / 'output/grounded_run'
        logs.mkdir(parents=True, exist_ok=True)
        with (logs / 'build.log').open('w', encoding='utf-8') as output:
            result = subprocess.run([executable, '--path', str(ROOT / 'godot'), '--script', str(ROOT / 'tools/bake_grounded_run.gd'),
                                     '--audio-driver', 'Dummy', '--log-file', str(logs / 'engine.log')],
                                    stdout=output, stderr=subprocess.STDOUT, timeout=120,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        text = (logs / 'build.log').read_text(encoding='utf-8')
        if result.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:)', text, re.M) or 'GROUNDED_RUN_BAKE frames=24' not in text:
            raise ValueError(text[-3000:])
    hashes = {}
    for index in range(24):
        path = FOLDER / f'frames/run_{index:02d}.png'
        image = Image.open(path)
        if image.mode != 'RGBA' or image.size != (384, 384) or not image.getchannel('A').getbbox():
            raise ValueError(f'{path}: invalid cel')
        hashes[path.name] = sha256(image.tobytes()).hexdigest()
    if len(set(hashes.values())) != 24:
        raise ValueError('duplicate grounded run cels')
    # Importer/shader text may be checked out as CRLF on Windows. Hash its
    # canonical text so the same committed pack checks on Windows and Linux.
    receipt = dict(schema=1, source_sha256={p.relative_to(ROOT).as_posix(): sha256(
        p.read_bytes() if p.suffix == '.png' else p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
        for p in SOURCES}, rgba_sha256=hashes)
    if check:
        if json.loads(receipt_path.read_text(encoding='utf-8')) != receipt:
            raise ValueError('grounded run inputs/output changed; rebuild the cels')
    else:
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    run = next(a for a in manifest['animations'] if a['name'] == 'run')
    paths = [f'res://assets/sprites/player/grounded_run_v1/frames/run_{i:02d}.png' for i in range(24)]
    if check:
        if run['frames'] != paths or manifest.get('run_presentation') != 'grounded_v1':
            raise ValueError('grounded run is not wired to the production Player manifest')
    else:
        run.update(frames=paths, fps=24.0 * 285.0 / 95.0, loop=True)
        manifest['run_presentation'] = 'grounded_v1'
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'GROUNDED_RUN_ASSETS frames=24 unique=24 continuous=true check={check}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--engine')
    args = parser.parse_args()
    build(args.check, args.engine)
