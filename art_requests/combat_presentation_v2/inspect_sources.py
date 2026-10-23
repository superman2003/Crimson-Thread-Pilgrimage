"""Inspect original imagegen PNGs; never modify their pixels.

Default writes per-image measurements and a delivery summary. --check verifies
that saved records still match the original PNGs, prompts and references.
Passing measurements is source QA, not animation or in-game hitbox acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def registered_sources():
    """Report runtime linkage separately from the historical source QA records."""
    root = HERE.parents[1]
    result = {}
    boss = root / 'godot/assets/vfx/boss_skills/manifest.json'
    if boss.is_file():
        data = json.loads(boss.read_text(encoding='utf-8'))
        entries = list(data.get('charges', {}).values())
        for command in data.get('commands', {}).values():
            entries += [command[key] for key in ('warning', 'execution') if key in command]
        for entry in entries:
            result[Path(entry['source']).name] = entry['sha256']
    guard = root / 'godot/assets/vfx/player_guard/manifest.json'
    if guard.is_file():
        for entry in json.loads(guard.read_text(encoding='utf-8')).get('sources', {}).values():
            result[Path(entry['path']).name] = entry['sha256']
    return result


def separators(alpha, count, horizontal):
    size = alpha.height if horizontal else alpha.width
    step = size / count
    cuts = [0]
    for i in range(1, count):
        nominal = round(i * step)
        candidates = []
        for threshold in (1, 24):
            for pos in range(max(cuts[-1] + 1, round(nominal - step * .22)), min(size - 1, round(nominal + step * .22)) + 1):
                rect = (0, pos, alpha.width, pos + 1) if horizontal else (pos, 0, pos + 1, alpha.height)
                if alpha.crop(rect).getextrema()[1] <= threshold:
                    candidates.append(pos)
            if candidates:
                break
        # Pick the centre of the nearest transparent gutter, not its outer edge.
        if candidates:
            runs = [[candidates[0]]]
            for pos in candidates[1:]:
                if pos == runs[-1][-1] + 1:
                    runs[-1].append(pos)
                else:
                    runs.append([pos])
            centres = [(run[0] + run[-1]) // 2 for run in runs]
            cuts.append(min(centres, key=lambda value: abs(value - nominal)))
        else:
            cuts.append(nominal)
    return cuts + [size]


def inspect(request):
    path = HERE / 'incoming' / request['file']
    if not path.is_file():
        return None
    prompt = path.with_suffix('.txt')
    if not prompt.is_file():
        raise ValueError(f'{path.name}: missing actual generation prompt')
    previous = json.loads(path.with_suffix('.json').read_text(encoding='utf-8')) if path.with_suffix('.json').is_file() else {}
    with Image.open(path) as im:
        if im.format != 'PNG' or im.mode != 'RGBA':
            raise ValueError(f'{path.name}: expected RGBA PNG, got {im.format}/{im.mode}')
        alpha = im.getchannel('A')
        if alpha.getextrema()[0] != 0 or alpha.getextrema()[1] < 64:
            raise ValueError(f'{path.name}: missing clear alpha or visible material')
        columns = request['requested_layout']['columns']
        rows = request['requested_layout']['rows']
        tile = request['topology'] == 'beam' or request['playback'] == 'tile'
        ycuts = separators(alpha, rows, True)
        frames, issues = [], []
        for row in range(rows):
            band = alpha.crop((0, ycuts[row], im.width, ycuts[row + 1]))
            xcuts = [round(i * im.width / columns) for i in range(columns + 1)] if tile else separators(band, columns, False)
            for column in range(columns):
                rect = [xcuts[column], ycuts[row], xcuts[column + 1], ycuts[row + 1]]
                cell = alpha.crop(rect)
                bbox = cell.point(lambda value: 255 if value > 24 else 0).getbbox()
                index = row * columns + column + 1
                if bbox is None:
                    issues.append(f'cel {index}: no visible alpha > 24')
                else:
                    margins = [bbox[0], bbox[1], cell.width - bbox[2], cell.height - bbox[3]]
                    if margins[1] == 0 or margins[3] == 0 or (not tile and min(margins) == 0):
                        issues.append(f'cel {index}: solid material touches an unsupported frame edge')
                frames.append(dict(cel=index, rect_xyxy=rect, bbox_alpha_gt_24_xyxy=None if bbox is None else [bbox[0]+rect[0], bbox[1]+rect[1], bbox[2]+rect[0], bbox[3]+rect[1]], fully_transparent_pixels=cell.histogram()[0]))
        record = dict(schema='combat-presentation-source-v2', image=path.name, generator='built-in image_gen.imagegen', source_brief='art_requests/combat_presentation_v2/README.md', source_brief_pr='https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/202',
                      image_sha256=digest(path), image_size=list(im.size), prompt_file=prompt.name, prompt_sha256=digest(prompt), requested_frames=request['frame_count'], requested_layout=request['requested_layout'], nominal_grid=[columns,rows],
                      requested_anchor=request['anchor'], actual_runtime_anchor='not_registered_yet', frames=frames, measured_issues=issues,
                      references=[dict(path=ref, sha256=digest(HERE/ref)) for ref in request['refs']],
                      usage='Original PNG bytes retained. Actual slicing rectangles follow measured gutters; requested dimensions may differ. No runtime import, anchor registration, beam seam acceptance, timing or hitbox verification is implied.')
        if previous.get('image_sha256') == record['image_sha256'] and 'visual_review' in previous:
            record['visual_review'] = previous['visual_review']
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    requests = json.loads((HERE/'requests.json').read_text(encoding='utf-8'))['requests']
    results = [result for request in requests if (result := inspect(request))]
    registered = registered_sources()
    connected = [r['image'] for r in results if registered.get(r['image']) == r['image_sha256']]
    summary = dict(expected_sheets=len(requests), expected_frames=sum(r['frame_count'] for r in requests), saved_sheets=len(results), saved_frames=sum(r['requested_frames'] for r in results),
                   pending=[r['file'] for r in requests if not (HERE/'incoming'/r['file']).is_file()],
                   measured_issues={r['image']:r['measured_issues'] for r in results if r['measured_issues']},
                   visual_review_pending=[r['image'] for r in results if r.get('visual_review',{}).get('status') != 'source_reviewed'],
                   runtime_import='complete' if len(connected) == len(requests) else 'partial' if connected else 'not_started',
                   runtime_connected=connected, runtime_pending=[r['file'] for r in requests if r['file'] not in connected])
    output = {'incoming/'+Path(r['image']).stem+'.json':r for r in results}
    output['incoming/delivery_status.json'] = summary
    for name, data in output.items():
        target = HERE/name
        text = json.dumps(data,ensure_ascii=False,indent=2)+'\n'
        if args.check:
            if not target.is_file() or target.read_text(encoding='utf-8') != text:
                raise ValueError('Missing or stale measurement: '+name)
        else:
            target.write_text(text,encoding='utf-8',newline='\n')
    print(json.dumps({key:summary[key] for key in ['expected_sheets','expected_frames','saved_sheets','saved_frames','measured_issues','runtime_import']},ensure_ascii=False))
    return 1 if summary['measured_issues'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
