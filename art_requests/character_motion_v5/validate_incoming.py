#!/usr/bin/env python3
"""Validate delivered v5 sheets against the existing request and delivery manifest.

Requires Pillow. Run: python art_requests/character_motion_v5/validate_incoming.py
This verifies file structure and pixel geometry, not in-game animation playback.
"""

import hashlib
import json
import re
from pathlib import Path

from PIL import Image


def validate(check_manifest=True):
    base = Path(__file__).resolve().parent
    incoming = base / 'incoming'
    request = (base / 'README.md').read_text(encoding='utf-8')
    blocks = re.findall(r'^#### .+? · `([^`]+)`\n(.*?)```text\n(.*?)\n```', request, re.M | re.S)
    assert len(blocks) == 32, 'Expected exactly 32 requested sheets'
    expected = {name for name, _, _ in blocks}
    assert {p.name for p in incoming.glob('*.png')} == expected, 'Missing or unexpected PNG'
    assert {p.name for p in incoming.glob('*.txt')} == {Path(name).with_suffix('.txt').name for name in expected}, 'Prompt pairing mismatch'
    results = []
    for name, details, prompt in blocks:
        frames = int(re.search(r'幀數：(\d+)', details).group(1))
        path = incoming / name
        saved_prompt = path.with_suffix('.txt').read_text(encoding='utf-8')
        assert saved_prompt.startswith(prompt), f'{name}: original request prompt was truncated'
        cols, rows = (2, 2) if frames == 4 else (2, 1) if frames == 2 else (1, 1)
        expected_size = (1024, 1024) if frames == 1 else (1536, 1024)
        with Image.open(path) as im:
            assert im.format == 'PNG' and im.mode == 'RGBA', f'{name}: must be RGBA PNG'
            assert im.size == expected_size, f'{name}: wrong canvas size {im.size}'
            alpha = im.getchannel('A')
            lo, hi = alpha.getextrema()
            assert lo == 0 and hi >= 240, f'{name}: missing transparent background or substantial character opacity'
            bounds, frame_hashes = [], []
            for row in range(rows):
                for col in range(cols):
                    cw, ch = im.width//cols, im.height//rows
                    cell = im.crop((col*cw, row*ch, (col+1)*cw, (row+1)*ch))
                    a = cell.getchannel('A')
                    for edge in ((0,0,cw,1),(0,ch-1,cw,ch),(0,0,1,ch),(cw-1,0,cw,ch)):
                        assert a.crop(edge).getextrema() == (0,0), f'{name}: cel {len(bounds)+1} has no clear transparent border'
                    box = a.point(lambda value: 255 if value >= 16 else 0).getbbox()
                    assert box, f'{name}: empty cel'
                    assert box[2]-box[0] <= cw*.8+2 and box[3]-box[1] <= ch*.85+2, f'{name}: oversized silhouette'
                    bounds.append(list(box))
                    frame_hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
            assert len(set(frame_hashes)) == frames, f'{name}: duplicate cels'
            results.append(dict(name=name, frames=frames, size=list(im.size), alpha_range=[lo,hi],
                                cel_bounds=bounds, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    assert sum(item['frames'] for item in results) == 67, 'Expected 67 cels'
    assert len({item['sha256'] for item in results}) == 32, 'Duplicate sheets'
    manifest = incoming / 'delivery_manifest.json'
    if check_manifest and manifest.exists():
        recorded = json.loads(manifest.read_text(encoding='utf-8'))
        assert recorded['sheet_count'] == 32 and recorded['frame_count'] == 67
        assert {item['name']: item['sha256'] for item in recorded['assets']} == {item['name']: item['sha256'] for item in results}, 'Manifest checksums are stale'
    return results


if __name__ == '__main__':
    assets = validate()
    print(f'PASS: {len(assets)} sheets, {sum(item["frames"] for item in assets)} cels, paired complete prompts, RGBA transparency, canvas sizes, clear cel borders, silhouette margins, unique frames and SHA-256 checksums.')
