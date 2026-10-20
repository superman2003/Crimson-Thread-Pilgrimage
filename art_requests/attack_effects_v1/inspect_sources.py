#!/usr/bin/env python3
"""Inspect generated source PNGs without changing their pixels."""
import hashlib
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REQUESTS = json.loads((HERE / 'requests.json').read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def separators(alpha, count, horizontal):
    """Move nominal cuts into nearby completely transparent gutters."""
    size = alpha.height if horizontal else alpha.width
    cuts = [0]
    step = size / count
    search_span = .46 if horizontal and count == 4 else .23
    for i in range(1, count):
        nominal = round(i * step)
        candidates = []
        for limit in (1, 24):
            for n in range(max(cuts[-1] + 1, round(nominal - step * search_span)), min(size - 1, round(nominal + step * search_span)) + 1):
                rect = (0, n, alpha.width, n + 1) if horizontal else (n, 0, n + 1, alpha.height)
                if alpha.crop(rect).getextrema()[1] <= limit:
                    candidates.append(n)
            if candidates:
                break
        if candidates:
            runs = [[candidates[0]]]
            for n in candidates[1:]:
                if n == runs[-1][-1] + 1:
                    runs[-1].append(n)
                else:
                    runs.append([n])
            candidates = [(run[0] + run[-1]) // 2 for run in runs]
        cuts.append(min(candidates, key=lambda n: abs(n - nominal)) if candidates else nominal)
    return cuts + [size]


def inspect(request):
    stem = request['stem']
    path = HERE / 'incoming' / f'{stem}.png'
    if not path.exists():
        return None
    with Image.open(path) as im:
        if im.format != 'PNG' or im.mode != 'RGBA':
            raise ValueError(f'{stem}: expected an RGBA PNG, got {im.format}/{im.mode}')
        alpha = im.getchannel('A')
        if alpha.getextrema()[0] != 0 or alpha.getextrema()[1] < 64:
            raise ValueError(f'{stem}: expected transparent pixels and a visible effect')
        cols, rows = (1, 4) if stem.startswith('FX_B_') else ((3, 2) if stem.startswith('FX_R_') else ((4, 1) if stem == 'FX_H_lure' else (4, 2)))
        frames = []
        issues = []
        ycuts = separators(alpha, rows, True)
        xcuts = [separators(alpha.crop((0, ycuts[row], im.width, ycuts[row + 1])), cols, False) for row in range(rows)]
        for i in range(request['frames']):
            col, row = i % cols, i // cols
            rect = [xcuts[row][col], ycuts[row], xcuts[row][col + 1], ycuts[row + 1]]
            cell = alpha.crop(rect)
            solid = cell.point(lambda x: 255 if x > 24 else 0)
            bbox = solid.getbbox()
            if bbox is None:
                issues.append(f'cel {i + 1}: no alpha > 24')
            else:
                border = [bbox[0], bbox[1], cell.width - bbox[2], cell.height - bbox[3]]
                if min(border[1], border[3]) == 0 or (not stem.startswith('FX_B_') and min(border) == 0):
                    issues.append(f'cel {i + 1}: solid pixels touch frame edge')
            frames.append({'cel': i + 1, 'rect_xyxy': rect, 'bbox_alpha_gt_24_xyxy': None if bbox is None else [bbox[0] + rect[0], bbox[1] + rect[1], bbox[2] + rect[0], bbox[3] + rect[1]], 'fully_transparent_pixels': cell.histogram()[0]})
        metadata = {'schema': 'attack-effect-source-v1', 'image': path.name, 'source_brief': 'art_requests/attack_effects_v1/README.md', 'source_brief_pr': 'https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/140', 'source_brief_commit': '0248ef7432e6cdde3adfe24ffa10dd46034ab234', 'generator': 'built-in image_gen.imagegen', 'prompt_file': f'{stem}.txt', 'prompt_sha256': digest(path.with_suffix('.txt')), 'image_sha256': digest(path), 'image_size': list(im.size), 'requested_frames': request['frames'], 'nominal_grid': [cols, rows], 'fully_transparent_pixels': alpha.histogram()[0], 'references': [{'path': ref, 'sha256': digest(ROOT / ref)} for ref in request['refs']], 'frames': frames, 'measured_issues': issues, 'usage': 'Original imagegen PNG bytes. Rectangles follow nearby transparent gutters in actual source dimensions; do not blindly equal-grid slice. Check animation anchors before runtime import. Source delivery only; collision alignment, beam seams, timing and in-game readability require runtime acceptance.'}
    old = path.with_suffix('.json')
    if old.exists():
        previous = json.loads(old.read_text(encoding='utf-8'))
        if previous.get('image_sha256') == metadata['image_sha256'] and 'visual_review' in previous:
            metadata['visual_review'] = previous['visual_review']
    old.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return metadata


if __name__ == '__main__':
    results = [result for request in REQUESTS if (result := inspect(request))]
    summary = {'expected_sheets': len(REQUESTS), 'expected_frames': sum(r['frames'] for r in REQUESTS), 'saved_sheets': len(results), 'saved_frames': sum(r['requested_frames'] for r in results), 'pending': [r['stem'] for r in REQUESTS if not (HERE / 'incoming' / (r['stem'] + '.png')).exists()], 'measured_issues': {r['image']: r['measured_issues'] for r in results if r['measured_issues']}}
    (HERE / 'incoming' / 'delivery_status.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False))
