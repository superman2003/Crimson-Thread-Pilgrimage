#!/usr/bin/env python3
"""Headroom tests of the documented preview mix; never a listening verdict."""
import json
import math
import subprocess
from pathlib import Path
import numpy as np
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / 'docs/proposals/audio_category'
SR = 48000


def db(value):
    return 20 * math.log10(max(float(value), 1e-12))


def decode(item):
    output = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(ROOT / item['source_path']), '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], capture_output=True, check=True)
    return np.frombuffer(output.stdout, dtype='<f4').reshape(-1, 2).astype(float)


def repeated(item, count):
    pcm = decode(item)
    if item['loop']:
        pcm = np.tile(pcm, (math.ceil(count / len(pcm)), 1))[:count]
    else:
        pcm = np.pad(pcm[:count], ((0, max(0, count - len(pcm))), (0, 0)))
    return pcm * 10 ** (item['recommended_playback_gain_db'] / 20)


def main():
    text = (DOC / 'catalog.js').read_text()
    data = json.loads(text.removeprefix('window.AUDIO_CATALOG = ').rstrip(';\n'))
    items = data['items']; results = []; count = SR * 8
    for profile in data['mix_profiles']['profiles']:
        region = profile['region_id']
        lookup = {x['id']: x for x in items if x['region_id'] == region}
        bed = repeated(lookup[profile['bed_cue_id']], count)
        landmark = repeated(lookup[profile['landmark_cue_id']], count)
        warning = next(x for x in items if x['pack'] == 'reverse_audio' and x['region_id'] == region and x['role'] == 'warning')
        alert = repeated(warning, count)
        alert = np.roll(alert, SR * 2, axis=0)
        for role in ['exploration', 'combat_layer', 'boss', 'lullaby']:
            item = next(x for x in items if x['kind'] == 'music' and x['region_id'] == region and x['role'] == role)
            music = repeated(item, count)
            # Conservative upper-gain scenario: closest dry landmark, wet-bound
            # allowance, equal-power music-overlap allowance, warning at unity
            # cue level, and no ducking benefit. Master is the UI maximum 70%.
            mix = (bed + landmark * (1 + profile['reverb']['wet']) + music * math.sqrt(2) + alert) * 0.7
            tp = np.max(np.abs(resample_poly(mix, 4, 1, axis=0)))
            mono = mix.mean(axis=1)
            stereo_rms = np.sqrt(np.mean(mix * mix)); mono_rms = np.sqrt(np.mean(mono * mono))
            record = {'region': region, 'music_role': role, 'sample_peak_dbfs': round(db(np.max(np.abs(mix))), 3), 'estimated_4x_true_peak_dbtp': round(db(tp), 3), 'mono_to_stereo_rms_db': round(db(mono_rms / max(stereo_rms, 1e-12)), 3), 'finite': bool(np.isfinite(mix).all()), 'not_clipped': bool(tp < 10 ** (-1 / 20))}
            results.append(record)
            assert record['finite'] and record['not_clipped'], record
    report = {'scope': '24 deterministic 8-second preview mix scenarios; conservative gain allowances, not the WebAudio convolution waveform, perceptual masking, human listening, or Godot mixing acceptance', 'sample_rate': SR, 'master_gain': 0.7, 'scenario_count': len(results), 'all_pass': True, 'cases': results}
    (DOC / 'mix_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'scenarios': len(results), 'worst_true_peak_dbtp': max(x['estimated_4x_true_peak_dbtp'] for x in results), 'pass': True}))


if __name__ == '__main__':
    main()
