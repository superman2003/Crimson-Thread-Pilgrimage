#!/usr/bin/env python3
"""Strict music phase/transition fixtures with actual chapter music assets."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def invoke(command, env, log, marker=None):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        good = result.returncode == 0
    except subprocess.TimeoutExpired as exc:
        value = exc.stdout or b''
        output = value.decode(errors='replace') if isinstance(value, bytes) else value
        output += '\nERROR: native music contract exceeded 120 seconds\n'
        good = False
    log.write_text(output)
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
    good = good and not re.search(r'^\s*(?:ERROR|SCRIPT ERROR|USER ERROR):', plain, re.M)
    if marker is not None:
        good = good and re.search(marker, plain, re.M) is not None
    print(output, end='')
    return bool(good)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if engine is None:
        parser.error('Godot executable missing')
    # A successful marker with absent optional sound cues is not sufficient.
    # Reject missing/LFS pointer dependencies before constructing the fixture.
    required = [
        ('assets/audio/bgm', '*.ogg', b'OggS'),
        ('assets/audio/seals', '*.wav', b'RIFF'),
    ]
    for folder, pattern, signature in required:
        files = list((ROOT / 'godot' / folder).rglob(pattern))
        if not files:
            parser.error('missing actual native audio dependency: ' + folder)
        for asset in files:
            with asset.open('rb') as content:
                header = content.read(4)
            if header != signature:
                parser.error('hydrate actual audio resource: ' + str(asset))
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='crimson-s01-music-') as scratch:
        project = Path(scratch) / 'godot'
        project.mkdir()
        for directory in ('scripts', 'data', 'shaders', 'scenes', 'assets/vfx', 'assets/fonts', 'assets/ui', 'assets/audio/bgm', 'assets/audio/seals'):
            shutil.copytree(ROOT / 'godot' / directory, project / directory)
        anchors = Path('assets/sprites/player/generated_hero_motion_v4/runtime_supplement/blade_anchors.json')
        (project / anchors).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'godot' / anchors, project / anchors)
        shutil.copy2(ROOT / 'godot/default_bus_layout.tres', project / 'default_bus_layout.tres')
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Music layer transition contracts"\n'
            '[audio]\nbuses/default_bus_layout="res://default_bus_layout.tres"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = dict(os.environ, XDG_DATA_HOME=str(Path(scratch) / 'userdata'))
        base = [engine, '--headless', '--audio-driver', 'Dummy', '--path', str(project)]
        if not invoke(base + ['--editor', '--recovery-mode', '--import', '--quit'], env,
                      args.log_dir / 'import.log'):
            return 1
        marker = r'^MUSIC_LAYER_TRANSITIONS checks=[1-9][0-9]* failures=0$'
        good = invoke(base + ['--script', 'res://scripts/music_layer_transition_validation.gd'], env,
                      args.log_dir / 'contracts.log', marker)
        return 0 if good else 1

if __name__ == '__main__':
    raise SystemExit(main())
