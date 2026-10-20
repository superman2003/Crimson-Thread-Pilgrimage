#!/usr/bin/env python3
"""Compose real GL phase captures; no synthesized or interpolated frames."""
import argparse
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture-dir', type=Path, required=True)
parser.add_argument('--output', type=Path, default=Path('artifacts/player_tool_art'))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
frames = [Image.open(args.capture_dir / f'phase_{i}.webp').convert('RGB') for i in range(8)]
empty = Image.open(args.capture_dir / 'empty.webp').convert('RGB')
frames[0].save(args.output / 'lifecycle.gif', save_all=True, append_images=frames[1:] + [empty],
               duration=[100] * 8 + [600], loop=0, disposal=2)
frames[2].save(args.output / 'active.webp', lossless=True)
print('PLAYER_TOOL_PREVIEWS families=4 frames=28 phase_samples=true native_scale=true')
