#!/usr/bin/env python3
"""Package the 2026-10-17 hero supplement sheets into 384px runtime frames.

Only crop/resize/pad generated source pixels; no interpolated or painted poses.
Each cel keeps its largest connected silhouette, which drops effects that the
game already spawns itself (the sword-wave arc and the thrown tool).
Registration matches the v4 run frames: same character scale (head size),
torso centre on the run torso column and soles on the run ground row.
"""
from pathlib import Path
from hashlib import sha256
from io import BytesIO
import json
from PIL import Image
import numpy as np
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
V4 = ROOT / 'godot/assets/sprites/player/generated_hero_motion_v4'
SOURCE = V4 / 'sources/supplement_20261017'
OUTDIR = V4 / 'runtime_supplement'
MANIFEST = ROOT / 'godot/assets/sprites/player/generated_hero_v3/manifest.json'
RES = 'res://assets/sprites/player/generated_hero_motion_v4/runtime_supplement/'
CANVAS = 384
# Run frames: alpha>24 soles end on row 287, torso median column is 200 (+-2).
GROUND_ROW = 287
TORSO_X = 200
# Character scale of each sheet relative to run_sheet.png, matched by head size.
SHEETS = {
    'run_attack': {'file': 'B_run_attack.png', 'relative_scale': 1.08, 'lift': [0, 4, 0, 0, 4, 0], 'fps': 14},
    'skill_melee': {'file': 'C_skill_melee.png', 'relative_scale': 0.92, 'lift': [0, 0, 0, 0], 'fps': 10},
    'skill_wave': {'file': 'C_skill_wave.png', 'relative_scale': 0.91, 'lift': [0, 0, 0, 0], 'fps': 10},
    'item_use': {'file': 'C_item_use.png', 'relative_scale': 0.86, 'lift': [0, 0, 0, 0], 'fps': 10},
}


def run_scale():
    """Same shared scale that build_expanded_hero_run.py derives for run_sheet.png."""
    record = json.loads((V4 / 'run_generation.json').read_text())
    reference = Image.open(V4 / record['reference']).convert('RGBA').getchannel('A').getbbox()
    sheet = Image.open(V4 / record['sheet']).convert('RGBA')
    x, y, w, h = record['regions'][0]
    alpha = np.asarray(sheet.crop((x, y, x + w, y + h)))[:, :, 3]
    ys, _ = np.nonzero(alpha > 24)
    top, bottom = max(0, int(ys.min()) - 2), min(h, int(ys.max()) + 3)
    return (reference[3] - reference[1]) / (bottom - top)


def silhouette(cell):
    """Largest 8-connected alpha>24 body plus its 3px anti-aliased rim."""
    rgba = np.asarray(cell).copy()
    solid = rgba[:, :, 3] > 24
    labels, count = ndimage.label(solid, structure=np.ones((3, 3)))
    if count == 0:
        raise ValueError('empty cel')
    areas = ndimage.sum(solid, labels, range(1, count + 1))
    body = labels == int(np.argmax(areas)) + 1
    keep = ndimage.binary_dilation(body, iterations=3)
    rgba[~keep] = 0
    dropped = sorted((int(a) for i, a in enumerate(areas) if i != int(np.argmax(areas)) and a >= 200), reverse=True)
    return Image.fromarray(rgba), body, dropped


def torso_x(rgba):
    """Median column of dark tunic pixels in the middle band, excluding cape/scarf/blade."""
    alpha = rgba[:, :, 3] > 200
    rgb = rgba[:, :, :3].astype(int)
    ys, _ = np.nonzero(alpha)
    top, height = ys.min(), ys.max() - ys.min()
    band = np.zeros_like(alpha)
    band[int(top + 0.38 * height):int(top + 0.62 * height)] = True
    dark = alpha & band & (rgb.mean(-1) < 75) & (rgb[:, :, 2] - rgb[:, :, 0] < 12) & (rgb[:, :, 0] - rgb[:, :, 1] < 30)
    if dark.sum() < 50:
        raise ValueError('torso not found')
    return float(np.median(np.nonzero(dark)[1]))


def build(check=False):
    record = json.loads((SOURCE / 'generation_manifest.json').read_text())
    assets = {asset['file']: asset for asset in record['assets']}
    base = run_scale()
    OUTDIR.mkdir(exist_ok=True)
    registration = {'source': 'sources/supplement_20261017', 'run_shared_scale': round(base, 9),
        'ground_row': GROUND_ROW, 'torso_x': TORSO_X, 'animations': {}}
    hashes = set()
    for name, spec in SHEETS.items():
        asset = assets[spec['file']]
        sheet = Image.open(SOURCE / spec['file'])
        if sha256((SOURCE / spec['file']).read_bytes()).hexdigest() != asset['sha256']:
            raise ValueError(f'{spec["file"]}: source hash differs from generation_manifest.json')
        sheet = sheet.convert('RGBA')
        scale = base * spec['relative_scale']
        frames = []
        for index, region in enumerate(asset['regions']):
            x, y, w, h = region['region']
            cell, body, dropped = silhouette(sheet.crop((x, y, x + w, y + h)))
            if body[0].any() or body[-1].any() or body[:, 0].any() or body[:, -1].any():
                raise ValueError(f'{name} {index}: silhouette touches its region')
            box = cell.getchannel('A').point(lambda v: 255 if v > 0 else 0).getbbox()
            pose = cell.crop(box)
            pose = pose.resize((round(pose.width * scale), round(pose.height * scale)), Image.Resampling.LANCZOS)
            pixels = np.asarray(pose)
            soles = int(np.nonzero((pixels[:, :, 3] > 24).any(1))[0].max())
            left = round(TORSO_X - torso_x(pixels))
            top = GROUND_ROW - spec['lift'][index] - soles
            if left < 1 or top < 1 or left + pose.width > CANVAS - 1 or top + pose.height > CANVAS - 1:
                raise ValueError(f'{name} {index}: pose does not fit the {CANVAS}px canvas')
            canvas = Image.new('RGBA', (CANVAS, CANVAS))
            canvas.alpha_composite(pose, (left, top))
            digest = sha256(canvas.tobytes()).hexdigest()
            if digest in hashes:
                raise ValueError(f'{name} {index}: duplicate pose')
            hashes.add(digest)
            path = OUTDIR / f'{name}_{index:02d}.png'
            if check:
                if not path.exists() or not np.array_equal(np.asarray(Image.open(path).convert('RGBA')), np.asarray(canvas)):
                    raise ValueError(f'{path}: rebuild')
            else:
                buffer = BytesIO()
                canvas.save(buffer, format='PNG')
                path.write_bytes(buffer.getvalue())
            frames.append({'frame': path.name, 'source_region': region['region'], 'dropped_components_px': dropped,
                'offset': [left, top], 'size': [pose.width, pose.height]})
        registration['animations'][name] = {'sheet': spec['file'], 'relative_scale': spec['relative_scale'],
            'scale': round(scale, 9), 'frames': frames}
    registration_path = OUTDIR / 'registration.json'
    registration_text = json.dumps(registration, ensure_ascii=False, indent=2) + '\n'
    manifest = json.loads(MANIFEST.read_text())
    animations = {animation['name']: animation for animation in manifest['animations']}
    for name, spec in SHEETS.items():
        frames = [RES + f'{name}_{index:02d}.png' for index in range(len(assets[spec['file']]['regions']))]
        if check:
            if name not in animations or animations[name]['frames'] != frames:
                raise ValueError(f'{name}: manifest not connected')
        elif name in animations:
            animations[name]['frames'] = frames
        else:
            manifest['animations'].append({'name': name, 'fps': spec['fps'], 'loop': False, 'frames': frames})
    if check:
        if registration_path.read_text() != registration_text:
            raise ValueError(f'{registration_path}: rebuild')
    else:
        registration_path.write_text(registration_text)
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('HERO_SUPPLEMENT_MOTION animations=%d frames=%d run_scale=%.9f' % (len(SHEETS), len(hashes), base))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
