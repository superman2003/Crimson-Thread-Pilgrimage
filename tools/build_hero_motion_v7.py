#!/usr/bin/env python3
"""Register newly drawn hero movement cels; keep the original art recoverable.

Only source cropping, alpha cleanup, fixed sheet scaling and padding are used.
No pose interpolation, duplicated drawings or per-frame size normalization.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / 'art_requests/hero_motion_v7'
OUT = ROOT / 'godot/assets/sprites/player/generated_hero_motion_v7'
PLAYER = ROOT / 'godot/assets/sprites/player/generated_hero_v3/manifest.json'
RES = 'res://assets/sprites/player/generated_hero_motion_v7/frames/'
COUNTS = {'jump': 4, 'landing': 4, 'dash': 6, 'hurt': 6, 'death': 8}
# Preserve nominal playback lengths, including the two short production aliases.
PLAYBACK = {'jump': ('jump', 10.0), 'jump_start': ('jump', 36.0),
            'landing': ('landing', 10.0), 'land': ('landing', 88.0 / 3.0),
            'dash': ('dash', 15.0), 'hurt': ('hurt', 15.0), 'death': ('death', 20.0)}


def encoded(image: Image.Image) -> bytes:
    buffer = BytesIO()
    image.save(buffer, format='PNG')
    return buffer.getvalue()


def register(cell: Image.Image, scale: float, airborne: bool) -> tuple[Image.Image, dict]:
    rgba = np.array(cell)
    solid = rgba[:, :, 3] > 96
    labels, count = ndimage.label(solid, structure=np.ones((3, 3)))
    if not count:
        raise ValueError('Empty source cel')
    areas = ndimage.sum(solid, labels, range(1, count + 1))
    body = labels == int(np.argmax(areas)) + 1
    # Preserve the painted body and its AA rim; discard disconnected faint matte.
    keep = ndimage.binary_dilation(body, iterations=3)
    rgba[~keep] = 0
    ys, xs = np.nonzero(body)
    if xs.min() <= 3 or ys.min() <= 3 or xs.max() >= cell.width - 4 or ys.max() >= cell.height - 4:
        raise ValueError('Source body touches a cell edge')
    top, bottom = int(ys.min()), int(ys.max()) + 1
    rgb = rgba[:, :, :3].astype(int)
    band = np.zeros_like(body)
    band[int(top + .38 * (bottom-top)):int(top + .62 * (bottom-top))] = True
    dark = body & band & (rgb.mean(-1) < 75) & (rgb[:, :, 2]-rgb[:, :, 0] < 12) & (rgb[:, :, 0]-rgb[:, :, 1] < 30)
    ty, tx = np.nonzero(dark)
    if tx.size < 50:
        raise ValueError('Cannot register the dark torso')
    anchor = (float(np.median(tx)), float(np.median(ty)) if airborne else float(bottom))
    # The production rig puts its floor at row 280. Older v4 run cels use 287;
    # copying that row would introduce a new 4.6px step against standing/death.
    target = (200.0, 222.0 if airborne else 280.0)
    box = (max(0, int(xs.min())-3), max(0, top-3), min(cell.width, int(xs.max())+4), min(cell.height, bottom+3))
    trimmed = Image.fromarray(rgba).crop(box)
    size = (round(trimmed.width*scale), round(trimmed.height*scale))
    scaled = trimmed.resize(size, Image.Resampling.LANCZOS)
    origin = (round(target[0]+(box[0]-anchor[0])*scale), round(target[1]+(box[1]-anchor[1])*scale))
    if origin[0] <= 0 or origin[1] <= 0 or origin[0]+size[0] >= 384 or origin[1]+size[1] >= 384:
        raise ValueError('Registered cel would be clipped')
    canvas = Image.new('RGBA', (384, 384))
    canvas.alpha_composite(scaled, origin)
    return canvas, {'source_bounds': list(box), 'source_anchor': list(anchor), 'target_anchor': list(target),
                    'output_origin': list(origin), 'output_size': list(size),
                    'visible_sha256': sha256(canvas.tobytes()).hexdigest()}


def build(check: bool = False) -> None:
    record = json.loads((REQUEST/'generation_manifest.json').read_text(encoding='utf-8'))
    outputs: dict[Path, bytes] = {}
    registration = {'schema': 'hero-motion-v7-registration', 'frame_size': [384, 384], 'new_drawings': 28, 'animations': {}}
    unique: set[str] = set()
    for action, count in COUNTS.items():
        spec = record['animations'][action]
        source = REQUEST / spec['source']
        if sha256(source.read_bytes()).hexdigest() != spec['source_sha256']:
            raise ValueError(f'{action}: source differs from the generation record')
        if sha256((REQUEST / spec['prompt']).read_bytes()).hexdigest() != spec['prompt_sha256']:
            raise ValueError(f'{action}: actual prompt differs from the generation record')
        sheet = Image.open(source).convert('RGBA')
        if len(spec['regions']) != count:
            raise ValueError(f'{action}: wrong authored cel count')
        entries = []
        for index, (x, y, width, height) in enumerate(spec['regions']):
            if x < 0 or y < 0 or width <= 0 or height <= 0 or x+width > sheet.width or y+height > sheet.height:
                raise ValueError(f'{action}/{index}: invalid source region')
            canvas, entry = register(sheet.crop((x,y,x+width,y+height)), spec['scale'], action == 'jump' and index >= 2)
            if entry['visible_sha256'] in unique:
                raise ValueError(f'{action}/{index}: repeated drawing')
            unique.add(entry['visible_sha256'])
            entry['source_region'] = [x,y,width,height]
            entries.append(entry)
            outputs[OUT/'frames'/f'{action}_{index:02d}.png'] = encoded(canvas)
        registration['animations'][action] = {'source': spec['source'], 'source_sha256': spec['source_sha256'],
                                                'scale': spec['scale'], 'frames': entries}
    original = json.loads((REQUEST/'previous_animations.json').read_text(encoding='utf-8'))
    manifest = json.loads(PLAYER.read_text(encoding='utf-8'))
    indexed = {a['name']: a for a in manifest['animations']}
    for name, (source_action, fps) in PLAYBACK.items():
        animation = indexed[name]
        frames = [RES+f'{source_action}_{index:02d}.png' for index in range(COUNTS[source_action])]
        if check:
            if animation['frames'] != frames or animation['fps'] != fps or animation['loop']:
                raise ValueError(f'{name}: production manifest is not registered')
        else:
            # Detect incompatible edits instead of silently overwriting another batch.
            if animation['frames'] != original[name]['frames'] and animation['frames'] != frames:
                raise ValueError(f'{name}: unexpected production animation')
            animation.update(frames=frames, fps=fps, loop=False)
        before = original[name]
        if abs(len(before['frames']) / before['fps'] - len(frames) / fps) > 1e-9:
            raise ValueError(f'{name}: playback duration changed')
    outputs[OUT/'registration.json'] = (json.dumps(registration, ensure_ascii=False, indent=2)+'\n').encode()
    if not check:
        outputs[PLAYER] = (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode()
    for path, content in outputs.items():
        if check:
            if not path.is_file():
                raise ValueError(f'{path}: missing output')
            if path.suffix == '.png':
                if not np.array_equal(np.asarray(Image.open(path)), np.asarray(Image.open(BytesIO(content)))):
                    raise ValueError(f'{path}: stale pixels')
            elif path.read_bytes() != content:
                raise ValueError(f'{path}: stale registration')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    print(f'HERO_MOTION_V7 actions={len(COUNTS)} drawings={len(unique)} aliases={len(PLAYBACK)} check={check}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
