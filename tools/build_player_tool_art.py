#!/usr/bin/env python3
"""Pack the four delivered tool sheets without changing source bytes."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'art_requests/attack_effects_v1/incoming'
OUTPUT = ROOT / 'godot/assets/vfx/player_tools'
FAMILIES = ['shard', 'mine', 'fog', 'lure']
CELL = 256


def digest(data):
    return hashlib.sha256(data).hexdigest()


def build():
    atlas = Image.new('RGBA', (CELL * 8, CELL * 4))
    records = {}
    for row, family in enumerate(FAMILIES):
        stem = SOURCES / ('FX_H_' + family)
        raw = stem.with_suffix('.png').read_bytes()
        # Git's text checkout may use CRLF on Windows; hashes refer to LF blobs.
        prompt = stem.with_suffix('.txt').read_bytes().replace(b'\r\n', b'\n')
        metadata = stem.with_suffix('.json').read_bytes().replace(b'\r\n', b'\n')
        meta = json.loads(metadata)
        if digest(raw) != meta['image_sha256'] or digest(prompt) != meta['prompt_sha256']:
            raise ValueError(f'{family}: source or prompt hash differs')
        image = Image.open(io.BytesIO(raw)).convert('RGBA')
        frames = meta['frames']
        if len(frames) != (4 if family == 'lure' else 8) or list(image.size) != meta['image_size']:
            raise ValueError(f'{family}: delivered size/frame count differs')
        entries = []
        for column, frame in enumerate(frames):
            # The delivered jar/burst drawing ratio is much smaller than the
            # gameplay's 20px jar / 150px blast. Normalize these stages separately.
            group = frames[:4] if family == 'shard' and column < 4 else frames[4:] if family == 'shard' else frames
            body = 64 if family == 'shard' and column < 4 else 128
            scale = body / max(f['bbox_alpha_gt_24_xyxy'][2] - f['bbox_alpha_gt_24_xyxy'][0] for f in group)
            rect = frame['rect_xyxy']
            cel = image.crop(rect)
            bounds = cel.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
            if not bounds:
                raise ValueError(f'{family}/{column}: empty source')
            bottom = family in ['mine', 'lure'] or family == 'shard' and column in [2, 3]
            anchor = (128, 192 if bottom else 128)
            cx = (bounds[0] + bounds[2]) / 2
            cy = bounds[3] if bottom else (bounds[1] + bounds[3]) / 2
            packed = cel.transform((CELL, CELL), Image.Transform.AFFINE,
                                   (1 / scale, 0, cx - anchor[0] / scale, 0, 1 / scale, cy - anchor[1] / scale),
                                   resample=Image.Resampling.BICUBIC)
            solid = packed.getchannel('A').point(lambda a: 255 if a > 128 else 0)
            dark = Image.new('RGBA', packed.size, (15, 19, 22, 0))
            dark.putalpha(solid.filter(ImageFilter.MaxFilter(5)).point(lambda a: round(a * .9)))
            pale = Image.new('RGBA', packed.size, (220, 208, 178, 0))
            pale.putalpha(solid.filter(ImageFilter.MaxFilter(3)).point(lambda a: round(a * .6)))
            packed = Image.alpha_composite(Image.alpha_composite(dark, pale), packed)
            alpha = packed.getchannel('A')
            edges = [(0, 0, CELL, 1), (0, CELL - 1, CELL, CELL), (0, 0, 1, CELL), (CELL - 1, 0, CELL, CELL)]
            if any(alpha.crop(edge).getextrema()[1] for edge in edges):
                raise ValueError(f'{family}/{column}: frame touches packed boundary')
            atlas.paste(packed, (column * CELL, row * CELL))
            width = (20 if column < 4 else 150) if family == 'shard' else {'mine': 72, 'fog': 260, 'lure': 40}[family]
            entries.append({'source_rect': rect, 'source_anchor': [cx + rect[0], cy + rect[1]],
                            'shared_stage_scale': scale, 'packed_anchor': anchor, 'body_width': body,
                            'native_width': width, 'atlas_rect': [column * CELL, row * CELL, CELL, CELL],
                            'packed_alpha_gt_24_bbox': alpha.point(lambda a: 255 if a > 24 else 0).getbbox()})
        records[family] = {'source': str(stem.with_suffix('.png').relative_to(ROOT)).replace('\\', '/'),
                           'sha256': digest(raw), 'prompt_sha256': digest(prompt),
                           'metadata_sha256': digest(metadata), 'opacity': .45 if family == 'fog' else 1.0, 'frames': entries}
    stream = io.BytesIO()
    atlas.save(stream, 'PNG', optimize=True)
    manifest = {'schema': 1, 'families': FAMILIES, 'cell': CELL, 'frame_count': 28,
                'atlas_size': list(atlas.size), 'atlas_rgba_sha256': digest(atlas.tobytes()),
                'registration': 'center; ground bottom for mine/lure/landed jar; two explicit jar/blast scales',
                'sources': records}
    return stream.getvalue(), (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    png, manifest = build()
    for path, data in {OUTPUT / 'player_tools.png': png, OUTPUT / 'manifest.json': manifest}.items():
        if args.check:
            if not path.exists():
                raise SystemExit(f'PLAYER_TOOL_ART missing {path}')
            same = (Image.open(path).convert('RGBA').tobytes() == Image.open(io.BytesIO(data)).convert('RGBA').tobytes()
                    if path.suffix == '.png' else path.read_bytes() == data)
            if not same:
                raise SystemExit(f'PLAYER_TOOL_ART stale {path}')
        else:
            OUTPUT.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(f'PLAYER_TOOL_ART_BUILD families=4 frames=28 atlas={len(png)}B check={args.check}')


if __name__ == '__main__':
    main()
