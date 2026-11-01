"""Validate lifecycle-soak evidence without treating a short probe as long acceptance."""
from __future__ import annotations
import math

MIB = 1024 * 1024
MAX_NET_GROWTH = 64 * MIB
MAX_GROWTH_PER_MINUTE = MIB


def evaluate(result: dict, requested_seconds: float) -> dict:
    errors = list(result.get('failures', []))
    elapsed = result.get('measured_seconds', 0)
    if not isinstance(elapsed, (int, float)) or not math.isfinite(elapsed) or elapsed < requested_seconds:
        errors.append('requested wall-clock measurement duration was not completed')
    if result.get('warmup_cycles') != 2 or result.get('cycles', 0) < 3:
        errors.append('two full warmup cycles and a measured cycle are required')
    cycles = result.get('cycles', 0)
    for field, minimum in [('transitions', cycles * 7), ('deaths', cycles), ('ui_opens', cycles * 21), ('dialogue_opens', cycles), ('observed_defeats', cycles)]:
        if result.get(field, 0) < minimum:
            errors.append(f'{field} did not cover the requested lifecycle actions')
    if not result.get('audio_drained') or result.get('remaining_voices', -1) != 0:
        errors.append('audio did not retire completely')
    if result.get('final_orphans', 1) > result.get('initial_orphans', 0):
        errors.append('orphan nodes remain after final teardown')
    samples = [row for row in result.get('samples', []) if row.get('measured')]
    warmup = [row for row in result.get('samples', []) if row.get('cycle') == 2]
    if not warmup:
        errors.append('warmup anchor sample is missing')
    elif any(row.get('orphans', -1) > warmup[-1].get('orphans', -1) for row in samples):
        errors.append('orphan nodes grew after warmup')
    growth = None
    slope = None
    if not samples:
        errors.append('no matched-anchor samples after cache warmup')
    else:
        for row in samples:
            for key in ['elapsed_seconds', 'memory_bytes', 'nodes', 'resources', 'orphans', 'voices', 'music_bookmarks', 'reading_bookmarks']:
                value = row.get(key)
                if not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                    errors.append(f'invalid metric {key}')
            if row.get('region') != 'demo_ch01_moss_bell_court':
                errors.append('memory samples must use the same first-region anchor')
            if row.get('voices', 25) > 24 or not 6 <= row.get('music_bookmarks', 0) <= 8 or row.get('reading_bookmarks', 65) > 64:
                errors.append('a declared live cache or voice bound was exceeded')
        if any(right.get('elapsed_seconds', 0) <= left.get('elapsed_seconds', 0) for left,right in zip(samples, samples[1:])):
            errors.append('measured sample times must increase')
        if not errors:
            growth = samples[-1]['memory_bytes'] - samples[0]['memory_bytes']
            if growth > MAX_NET_GROWTH:
                errors.append('matched-anchor static memory grew by more than 64 MiB')
            if len(samples) >= 3:
                times = [row['elapsed_seconds'] / 60 for row in samples]
                values = [row['memory_bytes'] for row in samples]
                mean_x, mean_y = sum(times)/len(times), sum(values)/len(values)
                variance = sum((x-mean_x)**2 for x in times)
                if variance <= 0:
                    errors.append('memory samples have no positive time span')
                else:
                    slope = sum((x-mean_x)*(y-mean_y) for x,y in zip(times, values))/variance
                    if slope > MAX_GROWTH_PER_MINUTE:
                        errors.append('static memory regression slope exceeds 1 MiB/minute')
    return {'passed': not errors, 'errors': errors, 'long_session': requested_seconds >= 1800 and not errors,
            'net_static_growth_bytes': growth, 'static_growth_bytes_per_minute': slope,
            'budgets': {'net_static_growth_bytes': MAX_NET_GROWTH, 'static_growth_bytes_per_minute': MAX_GROWTH_PER_MINUTE},
            'scope': 'lifecycle fixtures; does not prove natural routes, difficulty, target-hardware FPS or human comfort'}
