#!/usr/bin/env python3
"""Compose source-phase inspection captures; no synthetic animation frames."""
import argparse
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-dir',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('artifacts/player_skill_art'));a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
frames=[Image.open(a.capture_dir/f'phase_{i}.webp').convert('RGB') for i in range(8)];empty=Image.open(a.capture_dir/'empty.webp').convert('RGB')
frames[0].save(a.output/'lifecycle.gif',save_all=True,append_images=frames[1:]+[empty],duration=[80]*8+[600],loop=0,disposal=2)
frames[2].save(a.output/'active.webp',lossless=True)
print('PLAYER_SKILL_PREVIEWS families=3 frames=24 phase_samples=true native_scale=true')
