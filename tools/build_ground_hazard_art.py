#!/usr/bin/env python3
"""Pack eight ground hazards using delivered rectangles and a registered floor."""
from __future__ import annotations
import argparse, hashlib, io, json
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'art_requests/attack_effects_v1/incoming'
OUTPUT = ROOT / 'godot/assets/vfx/ground_hazards'
FAMILIES = 'caltrops focus fungus haze seal shadow slag snare'.split()
CELL, BODY, ANCHOR = 192, 128, (96, 144)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def build():
    atlas = Image.new('RGBA', (CELL * 8, CELL * len(FAMILIES)))
    records = {}
    for row, family in enumerate(FAMILIES):
        stem = SOURCES / ('FX_A_' + family)
        raw, prompt = stem.with_suffix('.png').read_bytes(), stem.with_suffix('.txt').read_bytes()
        meta = json.loads(stem.with_suffix('.json').read_text())
        if digest(raw) != meta['image_sha256'] or digest(prompt) != meta['prompt_sha256']:
            raise ValueError(f'{family}: delivered source checksum differs')
        image = Image.open(io.BytesIO(raw)).convert('RGBA')
        frames = meta['frames']
        if len(frames) != 8 or list(image.size) != meta['image_size']:
            raise ValueError(f'{family}: wrong source dimensions/frame count')
        # All phases share one scale. Register each hand-painted cel to the
        # bottom of its visible footprint, not the nominal 70% grid baseline.
        # Delivery rectangles have unequal row heights and variable margins.
        scale = BODY / max(f['bbox_alpha_gt_24_xyxy'][2] - f['bbox_alpha_gt_24_xyxy'][0] for f in frames[2:6])
        entries = []
        for column, f in enumerate(frames):
            rect = f['rect_xyxy']
            cel = image.crop(rect)
            bounds = cel.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
            if bounds is None: raise ValueError(f'{family}/{column}: empty delivered cel')
            cx, floor = (bounds[0] + bounds[2]) / 2, bounds[3]
            inv = 1 / scale
            packed = cel.transform((CELL, CELL), Image.Transform.AFFINE,
                (inv, 0, cx - ANCHOR[0] * inv, 0, inv, floor - ANCHOR[1] * inv),
                resample=Image.Resampling.BICUBIC)
            solid = packed.getchannel('A').point(lambda a: 255 if a > 128 else 0)
            dark = Image.new('RGBA', packed.size, (15, 19, 22, 0))
            dark.putalpha(solid.filter(ImageFilter.MaxFilter(5)).point(lambda a: round(a * .90)))
            pale = Image.new('RGBA', packed.size, (206, 192, 154, 0))
            pale.putalpha(solid.filter(ImageFilter.MaxFilter(3)).point(lambda a: round(a * .60)))
            packed = Image.alpha_composite(Image.alpha_composite(dark, pale), packed)
            alpha = packed.getchannel('A')
            edges = [alpha.crop((0, 0, CELL, 1)), alpha.crop((0, CELL-1, CELL, CELL)),
                     alpha.crop((0, 0, 1, CELL)), alpha.crop((CELL-1, 0, CELL, CELL))]
            if any(edge.getextrema()[1] > 0 for edge in edges):
                raise ValueError(f'{family}/{column}: packed cel touches atlas boundary')
            atlas.paste(packed, (column * CELL, row * CELL))
            entries.append({'source_rect': rect, 'source_floor_anchor': [cx + rect[0], floor + rect[1]],
                            'atlas_rect': [column * CELL, row * CELL, CELL, CELL],
                            'packed_alpha_gt_24_bbox': alpha.point(lambda a: 255 if a > 24 else 0).getbbox()})
        records[family] = {'source': str(stem.with_suffix('.png').relative_to(ROOT)),
            'sha256': digest(raw), 'prompt_sha256': digest(prompt), 'metadata_sha256': digest(stem.with_suffix('.json').read_bytes()),
            'shared_scale': scale, 'frames': entries}
    stream = io.BytesIO(); atlas.save(stream, 'PNG', optimize=True)
    manifest = {'schema': 1, 'cell': CELL, 'body_width': BODY, 'floor_anchor': ANCHOR,
        'families': FAMILIES, 'appear_frames': [0, 1], 'active_frames': [2, 3, 4, 5], 'fade_frames': [6, 7],
        'appear_seconds': .2, 'active_fps': 12, 'fade_fps': 12,
        'atlas_rgba_sha256': digest(atlas.tobytes()),
        'registration': 'alpha>24 footprint bottom at floor, shared active width; dark radius2/pale radius1 rim', 'sources': records}
    return stream.getvalue(), (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    png, manifest = build()
    for path, data in {OUTPUT / 'ground_hazards.png': png, OUTPUT / 'manifest.json': manifest}.items():
        if args.check:
            if not path.exists(): raise SystemExit(f'GROUND_HAZARD_ART missing: {path}')
            same = Image.open(path).convert('RGBA').tobytes() == Image.open(io.BytesIO(data)).convert('RGBA').tobytes() if path.suffix == '.png' else path.read_bytes() == data
            if not same: raise SystemExit(f'GROUND_HAZARD_ART stale: {path}')
        else:
            OUTPUT.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
    print(f'GROUND_HAZARD_ART_BUILD families=8 frames=64 atlas={len(png)}B check={args.check}')

if __name__ == '__main__': main()
