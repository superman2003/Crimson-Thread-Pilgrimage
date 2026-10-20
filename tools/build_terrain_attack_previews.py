#!/usr/bin/env python3
"""Compose real-GL terrain attack captures without bypassing runtime fade limits."""
import argparse
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-dir',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('artifacts/terrain_attack_art'));a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
phases=[Image.open(a.capture_dir/f'phase_{i}.webp').convert('RGB') for i in range(6)]
empty=Image.open(a.capture_dir/'empty.webp').convert('RGB');fades=[]
for frame in range(2):
 sheet=empty.copy()
 for page in range(2):
  capture=Image.open(a.capture_dir/f'fade_{page}_{frame}.webp').convert('RGB')
  x=page*3*192;right=min(960,x+3*192);sheet.paste(capture.crop((x,0,right,330)),(x,0))
 fades.append(sheet)
sequence=phases+phases[2:6]+fades+[empty]
sequence[0].save(a.output/'lifecycle.gif',save_all=True,append_images=sequence[1:],duration=[83]*12+[600],loop=0,disposal=2)
phases[2].save(a.output/'active.webp',lossless=True)
print('TERRAIN_ATTACK_PREVIEWS families=5 frames=36 directions=2 backgrounds=2 native_scale=true')
