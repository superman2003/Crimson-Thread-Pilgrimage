#!/usr/bin/env python3
"""Compose native-scale real-GL beam captures without generated replacement art."""
import argparse
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-dir',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('artifacts/beam_art'));a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
frames=[Image.open(a.capture_dir/f'phase_{i}.webp').convert('RGB') for i in range(5)];empty=Image.open(a.capture_dir/'empty.webp').convert('RGB')
sequence=frames[:4]+frames[2:4]+[frames[4],empty]
sequence[0].save(a.output/'lifecycle.gif',save_all=True,append_images=sequence[1:],duration=[200,200,83,83,83,83,80,600],loop=0,disposal=2)
frames[2].save(a.output/'active.webp',lossless=True)
Image.open(a.capture_dir/'clips.webp').save(a.output/'clips.webp',lossless=True)
print('BEAM_PREVIEWS families=4 parts=16 source_frames=2 clipping_examples=12 native_scale=true')
