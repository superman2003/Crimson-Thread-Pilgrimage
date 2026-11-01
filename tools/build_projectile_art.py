#!/usr/bin/env python3
"""Pack 15 authored projectile families; source PNG/TXT/JSON are read-only."""
from __future__ import annotations
import argparse, hashlib, io, json
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'art_requests/attack_effects_v1/incoming'
OUTPUT = ROOT / 'godot/assets/vfx/projectiles'
FAMILIES = ('blade bolt chime incense key light net page pollen seed slug spore stinger thorn wheel').split()
CELL = 128
BODY = 64

def digest(data):
    return hashlib.sha256(data).hexdigest()

def build():
    atlas = Image.new('RGBA', (CELL * 8, CELL * len(FAMILIES)))
    records = {}
    for row, family in enumerate(FAMILIES):
        stem = SOURCES / ('FX_P_' + family)
        raw = stem.with_suffix('.png').read_bytes()
        meta = json.loads(stem.with_suffix('.json').read_text())
        if digest(raw) != meta['image_sha256']:
            raise ValueError(f'{family}: source checksum differs from delivered JSON')
        image = Image.open(io.BytesIO(raw)).convert('RGBA')
        frames = meta['frames']
        if len(frames) != 8 or list(image.size) != meta['image_size']:
            raise ValueError(f'{family}: wrong source dimensions/frame count')
        spans = [max(f['bbox_alpha_gt_24_xyxy'][2] - f['bbox_alpha_gt_24_xyxy'][0],
                     f['bbox_alpha_gt_24_xyxy'][3] - f['bbox_alpha_gt_24_xyxy'][1]) for f in frames[:4]]
        scale = BODY / max(spans)
        entries = []
        for column, f in enumerate(frames):
            rect = f['rect_xyxy']
            cel = image.crop(rect)
            mask = cel.getchannel('A').point(lambda x: 255 if x > 24 else 0)
            bounds = mask.getbbox()
            if bounds is None:
                raise ValueError(f'{family}/{column}: empty delivered cel')
            cx, cy = (bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2
            # One scale for all eight cels. Only registration changes per cel;
            # an impact's authored expansion is retained instead of normalized.
            inv = 1 / scale
            packed = cel.transform((CELL, CELL), Image.Transform.AFFINE,
                (inv, 0, cx - CELL * .5 * inv, 0, inv, cy - CELL * .5 * inv),
                resample=Image.Resampling.BICUBIC)
            # A subpixel pale inner edge over a dark ink rim keeps the authored
            # dark thorn/net silhouettes readable at the game's 22px scale.
            solid = packed.getchannel('A').point(lambda a: 255 if a > 128 else 0)
            dark = Image.new('RGBA', packed.size, (15, 19, 22, 0))
            dark.putalpha(solid.filter(ImageFilter.MaxFilter(7)).point(lambda a: round(a * .90)))
            pale = Image.new('RGBA', packed.size, (206, 192, 154, 0))
            pale.putalpha(solid.filter(ImageFilter.MaxFilter(3)).point(lambda a: round(a * .75)))
            packed = Image.alpha_composite(Image.alpha_composite(dark, pale), packed)
            alpha = packed.getchannel('A')
            edges = [alpha.crop((0, 0, CELL, 1)), alpha.crop((0, CELL-1, CELL, CELL)),
                     alpha.crop((0, 0, 1, CELL)), alpha.crop((CELL-1, 0, CELL, CELL))]
            if any(edge.getextrema()[1] > 0 for edge in edges):
                raise ValueError(f'{family}/{column}: packed cel touches an atlas boundary')
            atlas.paste(packed, (column * CELL, row * CELL))
            entries.append({'source_rect': rect, 'source_anchor': [cx + rect[0], cy + rect[1]],
                            'atlas_rect': [column * CELL, row * CELL, CELL, CELL],
                            'packed_alpha_gt_24_bbox': alpha.point(lambda x: 255 if x > 24 else 0).getbbox()})
        records[family] = {'source': str(stem.with_suffix('.png').relative_to(ROOT)),
                           'sha256': digest(raw), 'shared_scale': scale, 'frames': entries}
    stream = io.BytesIO()
    atlas.save(stream, 'PNG', optimize=True)
    png = stream.getvalue()
    manifest = {'schema': 1, 'cell': CELL, 'flight_body_extent': BODY,
        'families': FAMILIES, 'flight_frames': [0, 1, 2, 3], 'impact_frames': [4, 5, 6, 7],
        'flight_fps': 14, 'impact_fps': 20, 'atlas_rgba_sha256': digest(atlas.tobytes()), 'ink_rim': 'solid alpha>128: dark radius3, pale radius1; original pixels overlaid', 'sources': records}
    return png, (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    png, manifest = build()
    outputs = {OUTPUT / 'projectiles.png': png, OUTPUT / 'manifest.json': manifest}
    if args.check:
        for path, data in outputs.items():
            if not path.exists():
                raise SystemExit(f'PROJECTILE_ART missing output: {path.relative_to(ROOT)}')
            same = (Image.open(path).convert('RGBA').tobytes() == Image.open(io.BytesIO(data)).convert('RGBA').tobytes()) if path.suffix == '.png' else path.read_bytes() == data
            if not same:
                raise SystemExit(f'PROJECTILE_ART stale output: {path.relative_to(ROOT)}')
    else:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for path, data in outputs.items():
            path.write_bytes(data)
    print(f'PROJECTILE_ART_BUILD families=15 frames=120 atlas={len(png)}B check={args.check}')

if __name__ == '__main__':
    main()
