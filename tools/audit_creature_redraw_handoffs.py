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


def unchanged_entry_edges(manifest, baseline, edges):
    """Audit a changed phase boundary whose windup entry was left untouched.

    Keep every loop interruption mandatory for a newly drawn entry. Partial
    tail repairs may retain an older entry that was never in this redraw's
    scope; validate that fact against both provenance and the frozen baseline
    before measuring only the newly changed phase boundary.
    """
    clips = {c['name']: c for c in fit.animations_of(manifest)}
    originals = {c['name']: c for c in fit.animations_of(baseline)}
    reviewed = manifest.get('redraw_record', {}).get('clips', {})
    for edge in edges:
        name = edge['source']
        target = 'attack' if name == 'windup' else name.removesuffix('_windup')
        frames = reviewed.get(name, {}).get('target_frames')
        count = len(clips.get(name, {}).get('frames', []))
        next_record = reviewed.get(target, {})
        next_targets = next_record.get('target_frames')
        next_changed = (0 in next_targets if isinstance(next_targets, list) else
                        next_record.get('frames') == len(clips.get(target, {}).get('frames', [])) and bool(next_record))
        if (not (name == 'windup' or name.endswith('_windup')) or
                edge['source_frame'] != -1 or edge['target_frame'] != 0 or edge['target'] != target or
                not isinstance(frames, list) or not frames or 0 in frames or
                not (count - 1 in frames or next_changed)):
            raise ValueError('Exact handoff requires a partial windup tail with an unchanged entry')
        if name not in originals or clips[name]['frames'][0] != originals[name]['frames'][0]:
            raise ValueError('Exact handoff entry differs from the frozen baseline')
    return list(edges)


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
    exact = spec.get('unchanged_entry_kinds', {})
    for kind in dict.fromkeys([*spec['kinds'], *exact]):
        path = fit.active_manifest(fit.CREATURES / kind)
        manifest = json.loads(path.read_text(encoding='utf-8'))
        edges = production_edges(manifest, spec['kinds'].get(kind, []))
        if kind in exact:
            filename = manifest.get('redraw_record', {}).get('baseline', '')
            if not filename or Path(filename).name != filename:
                raise ValueError('Exact handoff requires a local frozen baseline')
            baseline = json.loads((path.parent / filename).read_text(encoding='utf-8'))
            edges += unchanged_entry_edges(manifest, baseline, exact[kind])
        rows = measure(manifest, edges, pages.alpha)
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
