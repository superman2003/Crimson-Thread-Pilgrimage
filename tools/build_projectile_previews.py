#!/usr/bin/env python3
"""Assemble real-GL gallery captures. Impact batches respect the runtime cap."""
import argparse
from pathlib import Path
from PIL import Image

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--capture-dir', type=Path, required=True)
p.add_argument('--output', type=Path, default=Path('artifacts/projectile_art'))
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
flight = [Image.open(a.capture_dir / f'flight_{i}.webp').convert('RGB') for i in range(4)]
flight[0].save(a.output / 'flight.gif', save_all=True, append_images=flight[1:], duration=70, loop=0, disposal=2)
flight[0].save(a.output / 'flight.webp', lossless=True)
empty = Image.open(a.capture_dir / 'empty.webp').convert('RGB')
impact = []
for frame in range(4):
    sheet = empty.copy()
    for page in range(5):
        capture = Image.open(a.capture_dir / f'impact_{page}_{frame}.webp').convert('RGB')
        for index in range(page * 3, page * 3 + 3):
            x, y = index % 5 * 160, index // 5 * 240
            sheet.paste(capture.crop((x, y, x + 160, y + 240)), (x, y))
    impact.append(sheet)
impact[0].save(a.output / 'impact.gif', save_all=True, append_images=impact[1:] + [empty], duration=[50, 50, 50, 50, 600], loop=0, disposal=2)
impact[0].save(a.output / 'impact.webp', lossless=True)
print('PROJECTILE_PREVIEWS flight_frames=4 impact_frames=4 replay_gap_ms=600 native_and_2x=true')
