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
from collections import deque
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'godot/assets/sprites/player/grounded_run_v1'
MANIFEST = ROOT / 'godot/assets/sprites/player/generated_hero_v3/manifest.json'
SOURCES = [FOLDER / 'source/rig_parts.png', FOLDER / 'source/part_regions.json',
           FOLDER / 'source/run_upper_16.png', FOLDER / 'upper_body_generation.json',
           FOLDER / 'source/rig_parts.png.import',
           ROOT / 'godot/assets/sprites/player/generated_hero_motion_v4/runtime_run/run_00.png',
           ROOT / 'godot/scripts/grounded_run_cycle.gd', ROOT / 'godot/scripts/grounded_run_presentation.gd',
           ROOT / 'godot/shaders/grounded_run_part.gdshader', ROOT / 'tools/bake_grounded_run.gd']

def package_upper(check=False):
    recipe = json.loads((FOLDER / 'upper_body_generation.json').read_text(encoding='utf-8'))
    source = Image.open(FOLDER / recipe['source']).convert('RGBA')
    target = FOLDER / 'upper'
    if not check:
        target.mkdir(exist_ok=True)
    hashes = {}
    anchors = []
    for index in range(16):
        row, column = divmod(index, 4)
        region = [round(column * source.width / 4), round(row * source.height / 4),
                  round((column + 1) * source.width / 4), round((row + 1) * source.height / 4)]
        cell = source.crop(region)
        pixels = np.asarray(cell)
        red, green, blue, alpha = [pixels[:, :, k].astype(float) for k in range(4)]
        mask = ((red > 100) & (green > 70) & (blue < 110) & (red > green * 1.1)
                & (red < green * 1.85) & (alpha > 128))
        mask[:110] = False
        mask[225:] = False
        mask[:, :190] = False
        mask[:, 218:] = False
        components = []
        for y, x in zip(*np.nonzero(mask)):
            if not mask[y, x]:
                continue
            queue = deque([(int(x), int(y))]);mask[y, x] = False;points = []
            while queue:
                x, y = queue.popleft();points.append((x, y))
                for nx, ny in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]:
                    if 0 <= nx < cell.width and 0 <= ny < cell.height and mask[ny, nx]:
                        mask[ny, nx] = False;queue.append((nx, ny))
            components.append(points)
        clasp = max(components, key=len)
        if len(clasp) < 40:
            raise ValueError(f'upper cel {index}: ambiguous neck clasp')
        anchor = np.mean(clasp, axis=0)
        yy, xx = np.nonzero(alpha > 24)
        bounds = [max(0, int(xx.min()) - 2), max(0, int(yy.min()) - 2),
                  min(cell.width, int(xx.max()) + 3), min(cell.height, int(yy.max()) + 3)]
        if any((edge > 24).any() for edge in [alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]]):
            raise ValueError(f'upper cel {index}: clipped source')
        scale = recipe['shared_scale']
        part = cell.crop(bounds)
        part = part.resize((round(part.width * scale), round(part.height * scale)), Image.Resampling.LANCZOS)
        origin = [round(recipe['clasp_target'][axis] + (bounds[axis] - anchor[axis]) * scale) for axis in range(2)]
        canvas = Image.new('RGBA', (384, 384));canvas.alpha_composite(part, tuple(origin))
        path = target / f'upper_{index:02d}.png'
        digest = sha256(canvas.tobytes()).hexdigest();hashes[path.name] = digest
        if check:
            if sha256(Image.open(path).convert('RGBA').tobytes()).hexdigest() != digest:
                raise ValueError(f'{path}: upper cel requires rebuild')
        else:
            canvas.save(path)
        anchors.append(dict(index=index, source_region=region, clasp=[round(float(v), 5) for v in anchor], origin=origin))
    if len(set(hashes.values())) != 16:
        raise ValueError('duplicate upper-body drawings')
    report = dict(frames=16, source_sha256=sha256((FOLDER / recipe['source']).read_bytes()).hexdigest(),
                  shared_scale=recipe['shared_scale'], anchors=anchors, rgba_sha256=hashes)
    path = FOLDER / 'upper_registration.json'
    if check:
        if json.loads(path.read_text(encoding='utf-8')) != report:
            raise ValueError('upper-body registration differs')
    else:
        path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return hashes


def build(check=False, engine=None):
    upper_hashes = package_upper(check)
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
    receipt = dict(schema=1, upper_rgba_sha256=upper_hashes, source_sha256={p.relative_to(ROOT).as_posix(): sha256(
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
        run.update(frames=paths, fps=24.0 * 285.0 / 125.0, loop=True)
        manifest['run_presentation'] = 'grounded_v1'
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'GROUNDED_RUN_ASSETS frames=24 unique=24 continuous=true check={check}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--engine')
    args = parser.parse_args()
    build(args.check, args.engine)
