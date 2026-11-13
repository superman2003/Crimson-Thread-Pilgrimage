"""Check reviewed production handoffs on the authored fixed canvas.

Never recenter silhouettes or apply frame_fit corrections: either would hide
the body-anchor jumps this check is meant to catch. Frame selection follows
enemy_actor's direct windup/active/recovery switches; 'all' covers interruptions
of a walking or idle loop at any frame.
"""
import json
from pathlib import Path
import numpy as np
import build_creature_frame_fit as fit
from build_creature_redraw_list import change, placed

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / 'art_requests/creature_redraw_v1/handoffs.json'
MAX_CHANGE = 0.5


def indices(selection, count):
    if selection == 'all':
        return range(count)
    if type(selection) is not int or not -count <= selection < count:
        raise ValueError('Invalid handoff frame: ' + str(selection))
    return [selection % count]


def production_edges(manifest, edges):
    """Include arbitrary loop interruption and honor move-specific recoveries."""
    names = {c['name'] for c in fit.animations_of(manifest)}
    result = list(edges)
    for edge in edges:
        source = edge['source']
        own_recovery = source + '_recover'
        if own_recovery in names and edge['target'] != own_recovery:
            raise ValueError('Production selects '+own_recovery+' before shared recovery bridges')
        if source == 'windup' or source.endswith('_windup'):
            for loop in ('idle', 'walk'):
                if loop in names:
                    entry = dict(source=loop, source_frame='all', target=source, target_frame=0)
                    if entry not in result:
                        result.append(entry)
    return result


def measure(manifest, edges, alpha):
    clips = {c['name']: c for c in fit.animations_of(manifest)}
    canvas = manifest['canvas']
    masks, rows = {}, []
    def mask(name, index):
        key = name, index
        if key not in masks:
            frame = clips[name]['frames'][index]
            image = alpha(frame)
            x, y = frame['margin'][:2]
            if x < 0 or y < 0 or x + image.width > canvas[0] or y + image.height > canvas[1]:
                raise ValueError('Handoff drawing leaves the fixed canvas: ' + name)
            masks[key] = placed(image, frame, canvas)
            if not np.any(masks[key]):
                raise ValueError('Empty handoff drawing: ' + name)
        return masks[key]
    for edge in edges:
        source, target = edge['source'], edge['target']
        if source not in clips or target not in clips:
            raise ValueError('Missing production handoff: ' + source + ' -> ' + target)
        for si in indices(edge['source_frame'], len(clips[source]['frames'])):
            for ti in indices(edge['target_frame'], len(clips[target]['frames'])):
                value = change(mask(source, si), mask(target, ti))
                rows.append(dict(source=source, source_frame=si, target=target,
                                 target_frame=ti, change=value))
    if not rows:
        raise ValueError('No production handoffs checked')
    return rows


def main():
    spec = json.loads(SPEC.read_text(encoding='utf-8'))
    if spec['schema'] != 1 or not spec['kinds']:
        raise ValueError('Missing reviewed handoff specification')
    failures, checks = [], 0
    pages = fit.Atlases()
    for kind, edges in spec['kinds'].items():
        path = fit.active_manifest(fit.CREATURES / kind)
        manifest = json.loads(path.read_text(encoding='utf-8'))
        rows = measure(manifest, production_edges(manifest, edges), pages.alpha)
        bad = [r for r in rows if r['change'] > MAX_CHANGE]
        failures.extend(dict(kind=kind, **r) for r in bad)
        checks += len(rows)
        print(f'HANDOFF {kind} checks={len(rows)} max_change={max(r["change"] for r in rows):.4f}')
    for row in failures:
        print('HANDOFF_FAIL ' + json.dumps(row))
    print(f'CREATURE_HANDOFFS checks={checks} failures={len(failures)}')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
