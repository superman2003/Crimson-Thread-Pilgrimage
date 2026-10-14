#!/usr/bin/env python3
"""Build the audio-category review catalog from checked, local asset packs."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / 'docs/proposals/audio_category'
PACKS = ['reverse_music_v2', 'audio_category_music', 'audio_category_sfx', 'audio_category_ambience']
REGIONS = {'ch06': '无声王冠', 'ch05': '黑曜巡礼道', 'ch04': '断弦温室', 'ch03': '盐白书库', 'ch02': '铸雨渠', 'ch01': '苔钟庭', 'global': '全局 / 人物 / 事件'}


def local_file(root: Path, path: str) -> Path:
    relative = Path(path)
    if relative.is_absolute() or '..' in relative.parts or '\\' in path:
        raise ValueError(f'Invalid relative path: {path}')
    target = root / relative
    if not target.resolve().is_relative_to(root.resolve()) or not target.is_file():
        raise ValueError(f'Missing or escaping file: {path}')
    if any(p.is_symlink() for p in [target, *target.parents] if p != root.parent):
        raise ValueError(f'Symlink not accepted: {path}')
    return target


def inspect_audio(path: Path) -> dict:
    blob = path.read_bytes()
    if blob.startswith(b'version https://git-lfs.github.com/spec'):
        raise ValueError(f'Unhydrated audio: {path.name}')
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(path)], capture_output=True, check=True)
    streams = json.loads(probe.stdout)['streams']
    if len(streams) != 1 or streams[0]['codec_type'] != 'audio':
        raise ValueError(f'Expected one audio stream: {path.name}')
    stream = streams[0]
    if int(stream['sample_rate']) != 48000 or stream['channels'] not in (1, 2):
        raise ValueError(f'Unexpected audio format: {path.name}')
    return {'bytes': len(blob), 'sha256': hashlib.sha256(blob).hexdigest(), 'channels': stream['channels'], 'sample_rate': 48000, 'probed_duration_seconds': float(stream['duration'])}


def normalize_item(root: Path, pack: str, kind: str, source: dict) -> dict:
    item = dict(source)
    item['pack'] = pack
    item['kind'] = kind
    item['key'] = pack + ':' + str(item['id'])
    item['region_id'] = item.get('region_id', 'global')[:4] if item.get('region_id', '').startswith('ch0') else 'global'
    if item['region_id'] not in REGIONS:
        raise ValueError(f'Invalid region: {item["key"]}')
    path = local_file(root, 'assets/proposals/' + pack + '/' + item['file'])
    details = inspect_audio(path)
    for field in ['channels', 'sample_rate']:
        if field in item and item[field] != details[field]:
            raise ValueError(f'Declared {field} differs from stream: {item["key"]}')
    item.update(details)
    duration = float(item['duration_seconds'])
    if not math.isfinite(duration) or not 0 < duration <= 300:
        raise ValueError(f'Invalid duration: {item["key"]}')
    if abs(duration - details['probed_duration_seconds']) > 0.01:
        raise ValueError(f'Declared duration differs from stream: {item["key"]}')
    gain = float(item.get('recommended_playback_gain_db', -6))
    if not math.isfinite(gain) or not -60 <= gain <= 0:
        raise ValueError(f'Invalid playback gain: {item["key"]}')
    item['recommended_playback_gain_db'] = gain
    if not isinstance(item.get('loop'), bool):
        raise ValueError(f'Loop must be boolean: {item["key"]}')
    if item['loop']:
        start = item.get('loop_start_sample', 0)
        end = item.get('loop_end_sample_exclusive', item.get('loop_end_sample', round(duration * 48000)))
        if not isinstance(start, int) or not isinstance(end, int) or not 0 <= start < end <= round(duration * 48000) + 2:
            raise ValueError(f'Invalid loop samples: {item["key"]}')
        item['loop_start_sample'], item['loop_end_sample_exclusive'] = start, end
    item['url'] = '../../../' + path.relative_to(root).as_posix()
    item['source_path'] = path.relative_to(root).as_posix()
    item['human_listening_review'] = 'pending'
    return item


def collect(root: Path = ROOT, partial: bool = False) -> dict:
    items = []
    for pack in PACKS:
        manifest_path = root / 'assets/proposals' / pack / 'manifest.json'
        if partial and not manifest_path.exists():
            continue
        manifest = json.loads(local_file(root, str(manifest_path.relative_to(root))).read_text())
        for source in manifest['items']:
            items.append(normalize_item(root, pack, manifest['kind'], source))
    legacy = json.loads(local_file(root, 'docs/proposals/reverse_audio/manifest.json').read_text())
    for source in legacy['assets']:
        path = local_file(root, source['path'])
        with wave.open(str(path)) as w:
            duration = w.getnframes() / w.getframerate()
        item = dict(source, title=REGIONS[source['region_id'][:4]] + ' · ' + {'warning': '攻击预警', 'attack_body': '攻击主体', 'attack_detail': '攻击细节', 'hurt': '受击'}[source['role']], file=path.relative_to(root / 'assets/proposals/reverse_audio').as_posix(), duration_seconds=duration, recommended_playback_gain_db=-6, description=source['texture'])
        items.append(normalize_item(root, 'reverse_audio', 'sfx', item))
    keys = [x['key'] for x in items]
    if len(keys) != len(set(keys)):
        raise ValueError('Duplicate catalog key')
    profile_path = root / 'assets/proposals/audio_category_ambience/mix_profiles.json'
    profiles = {} if partial and not profile_path.exists() else json.loads(local_file(root, str(profile_path.relative_to(root))).read_text())
    if profiles:
        validate_profiles(profiles, items)
    return {'schema_version': 1, 'scope': 'independent resource and mix review; not runtime wiring or human listening acceptance', 'regions': REGIONS, 'items': items, 'mix_profiles': profiles}


def validate_profiles(document: dict, items: list[dict]) -> None:
    profiles = document['profiles']
    if sorted(x['region_id'] for x in profiles) != sorted(k for k in REGIONS if k != 'global'):
        raise ValueError('Mix profiles must cover six distinct regions')
    lookup = {x['id']: x for x in items if x['pack'] == 'audio_category_ambience'}
    for profile in profiles:
        for key, role in [('bed_cue_id', 'bed'), ('landmark_cue_id', 'landmark')]:
            cue = lookup.get(profile[key])
            if not cue or cue['region_id'] != profile['region_id'] or cue['role'] != role or not cue['loop']:
                raise ValueError(f'Invalid regional mix cue: {profile[key]}')
        spatial = profile['landmark_spatial']
        near, far = spatial['near_distance_m'], spatial['far_distance_m']
        if not all(math.isfinite(x) for x in [near, far]) or not 0 <= near < far <= 100:
            raise ValueError('Invalid attenuation distances')
        if not 20 <= spatial['occluded']['lowpass_hz'] <= 20000 or not -60 <= spatial['occluded']['gain_db'] <= 0:
            raise ValueError('Invalid occlusion settings')
        if not 0 <= profile['reverb']['wet'] <= 1 or not 0 < profile['reverb']['decay_seconds'] <= 6:
            raise ValueError('Invalid reflection settings')
        if not -30 <= profile['warning_duck']['gain_db'] <= 0:
            raise ValueError('Invalid warning duck gain')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--partial', action='store_true', help='Development only; omit unfinished new packs')
    args = parser.parse_args()
    catalog = collect(partial=args.partial)
    DOC.mkdir(parents=True, exist_ok=True)
    (DOC / 'catalog.js').write_text('window.AUDIO_CATALOG = ' + json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + ';\n')
    report = {'asset_count': len(catalog['items']), 'partial': args.partial, 'total_bytes': sum(x['bytes'] for x in catalog['items']), 'files': [{k: x[k] for k in ['key', 'source_path', 'sha256', 'bytes', 'sample_rate', 'channels']} for x in catalog['items']]}
    (DOC / 'catalog_validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'files'}))


if __name__ == '__main__':
    main()
