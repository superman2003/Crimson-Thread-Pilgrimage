#!/usr/bin/env python3
"""Rebuild the bounded movement atlas from checked-in delivered crops, without generation."""
from pathlib import Path
import hashlib, json
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/assets/vfx/player_movement'
def main():
    manifest = json.loads((OUT / 'manifest.json').read_text())
    atlas = Image.new('RGBA', (1152, 576))
    for family, source in manifest['sources'].items():
        path = ROOT / source['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'], path
        image = Image.open(path).convert('RGBA')
        for frame in source['frames']:
            crop = image.crop(frame['source_crop'])
            x, y, width, height = frame['paint_rect']
            atlas.alpha_composite(crop.resize((width, height), Image.Resampling.LANCZOS), (x, y))
    atlas.save(OUT / 'player_movement.png')
    print(hashlib.sha256((OUT / 'player_movement.png').read_bytes()).hexdigest())
if __name__ == '__main__': main()
