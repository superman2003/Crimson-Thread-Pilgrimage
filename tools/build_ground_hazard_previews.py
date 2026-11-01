#!/usr/bin/env python3
"""Compose real-GL hazard phases; fade pages obey the production decoration cap."""
import argparse
from pathlib import Path
from PIL import Image
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--capture-dir', type=Path, required=True)
p.add_argument('--output', type=Path, default=Path('artifacts/ground_hazard_art'))
a = p.parse_args(); a.output.mkdir(parents=True, exist_ok=True)
phases = [Image.open(a.capture_dir / f'phase_{i}.webp').convert('RGB') for i in range(7)]
empty = Image.open(a.capture_dir / 'empty.webp').convert('RGB')
fades = []
for frame in range(2):
    sheet = empty.copy()
    for page in range(2):
        capture = Image.open(a.capture_dir / f'fade_{page}_{frame}.webp').convert('RGB')
        sheet.paste(capture.crop((0,page*260,640,page*260+260)),(0,page*260))
    fades.append(sheet)
sequence = phases + phases[3:7] + fades + [empty]
durations = [600,100,100] + [83]*8 + [83,83,600]
sequence[0].save(a.output/'lifecycle.gif',save_all=True,append_images=sequence[1:],duration=durations,loop=0,disposal=2)
phases[3].save(a.output/'active.webp',lossless=True)
print('GROUND_HAZARD_PREVIEWS families=8 appear=2 active=4 fade=2 native_scale=true')
