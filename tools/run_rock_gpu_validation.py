#!/usr/bin/env python3
"""Run the rock shader pixel probe under real software GL, never dummy rendering."""
import argparse
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine or not shutil.which('Xvfb'):
        parser.error('Godot and Xvfb are required')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    # Separate process trees cannot use unix display sockets in some workspaces.
    # Choose an unused TCP display and keep Xvfb and Godot in one process tree.
    display = None
    for candidate in range(90, 110):
        with socket.socket() as probe:
            try:
                probe.bind(('127.0.0.1', 6000 + candidate))
                display = candidate
                break
            except OSError:
                continue
    if display is None:
        raise RuntimeError('No free X display port')
    with tempfile.TemporaryDirectory(prefix='rock-gpu-') as scratch:
        with (args.log_dir / 'xvfb.log').open('w') as log:
            server = subprocess.Popen(['Xvfb', f':{display}', '-screen', '0', '1280x720x24', '-ac', '-nolisten', 'unix', '-nolisten', 'local', '-listen', 'tcp'], stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 10
                while True:
                    if server.poll() is not None:
                        raise RuntimeError('Xvfb exited during startup')
                    try:
                        with socket.create_connection(('127.0.0.1', 6000 + display), timeout=0.2):
                            break
                    except OSError:
                        if time.monotonic() > deadline:
                            raise RuntimeError('Xvfb startup timed out')
                        time.sleep(0.1)
                env = dict(os.environ, DISPLAY=f'127.0.0.1:{display}', LIBGL_ALWAYS_SOFTWARE='1', XDG_DATA_HOME=scratch)
                result = subprocess.run([engine, '--display-driver', 'x11', '--audio-driver', 'Dummy', '--fixed-fps', '60', '--path', str(ROOT / 'godot'), '--rendering-method', 'gl_compatibility', '--script', '../tools/validate_rock_seams.gd'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
                (args.log_dir / 'gpu.log').write_text(result.stdout)
                print(result.stdout, end='')
                failed = result.returncode != 0 or re.search(r'^\s*(SCRIPT ERROR:|ERROR:)', result.stdout, re.MULTILINE) or 'ROCK_SEAMS probes=12 failures=0' not in result.stdout
                if failed:
                    raise SystemExit(1)
                shutil.copyfile(ROOT / 'artifacts/hero_rock_upgrade/checkpoint4/gpu_seams.json', args.log_dir / 'gpu_seams.json')
            finally:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()

if __name__ == '__main__':
    main()
