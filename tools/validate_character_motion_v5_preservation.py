#!/usr/bin/env python3
"""Compare v5 packed pixels/rig origins to a pre-integration git revision.

This independently checks actual packed output, including untouched animations
and original recovery tails. It does not infer preservation from registrations.
"""
import argparse
from functools import lru_cache
from io import BytesIO
import json
from pathlib import Path
import subprocess

import numpy as np
from PIL import Image

from build_character_motion_v5 import ROOT, plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-ref', required=True)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()

    @lru_cache(maxsize=None)
    def old_bytes(path):
        return subprocess.check_output(['git', 'show', args.baseline_ref+':'+path], cwd=ROOT)

    @lru_cache(maxsize=None)
    def atlas(path, before):
        return Image.open(BytesIO(old_bytes(path))) if before else Image.open(ROOT/path)

    def pixels(frame, before):
        path = 'godot/'+frame['atlas'].removeprefix('res://')
        x, y, w, h = frame['region']
        rgba = np.array(atlas(path, before).crop((x, y, x+w, y+h)))
        rgba[rgba[:, :, 3] == 0] = 0  # invisible RGB is not rendered
        return rgba

    def origin(manifest, frame):
        return np.array([(frame['margin'][i]-manifest['canvas'][i]/2)*manifest['visual_scale']
                         + manifest['visual_offset'][i] for i in (0, 1)])

    results = []
    sheets = plan()
    for folder in dict.fromkeys(sheet['folder'] for sheet in sheets):
        kind = folder.rsplit('/', 1)[-1]
        path = f'godot/assets/sprites/{folder}/motion_manifest.json'
        before = json.loads(old_bytes(path))
        after = json.loads((ROOT/path).read_text(encoding='utf-8'))
        specs = [sheet for sheet in sheets if sheet['folder'] == folder]
        current = {animation['name']: animation for animation in after['animations']}
        preserved = 0
        for animation in before['animations']:
            name = animation['name']
            changes = [sheet for sheet in specs if sheet['animation'] == name]
            if any(sheet['op'] == 'replace_animation' for sheet in changes):
                continue
            # new_animation sheets add `<move>_bridge`/`_settle`; existing ones keep their frames.
            shift = sum(sheet['grid'][0]*sheet['grid'][1] for sheet in changes if sheet['op'] == 'prepend_frames')
            replaced = {index for sheet in changes if sheet['op'] == 'replace_frames' for index in sheet['indices']}
            for index, frame in enumerate(animation['frames']):
                if index in replaced:
                    continue
                new_frame = current[name]['frames'][index+shift]
                if not np.array_equal(pixels(frame, True), pixels(new_frame, False)):
                    raise ValueError(f'{kind}/{name}/{index}: existing visible RGBA changed')
                if np.max(np.abs(origin(before, frame)-origin(after, new_frame))) >= 1e-5:
                    raise ValueError(f'{kind}/{name}/{index}: existing rig origin moved')
                preserved += 1
        results.append(dict(kind=kind, preserved_pixel_and_rig_frames=preserved))
    result = dict(baseline_ref=args.baseline_ref, characters=len(results),
                  unchanged_frames=sum(item['preserved_pixel_and_rig_frames'] for item in results),
                  failures=0, coverage=results)
    if args.report:
        args.report.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(f'CHARACTER_MOTION_V5_PRESERVATION characters={len(results)} frames={result["unchanged_frames"]} failures=0')


if __name__ == '__main__':
    main()
