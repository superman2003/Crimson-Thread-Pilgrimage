#!/usr/bin/env python3
"""Run the rock shader pixel probe under real software GL, never dummy rendering."""
import argparse
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def validation_failed(output, returncode, success_marker):
    """Check diagnostics and the completion marker without terminal formatting."""
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
    return (returncode != 0
            or re.search(r'^\s*(SCRIPT ERROR:|ERROR:)', plain, re.MULTILINE) is not None
            or success_marker not in plain)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--log-dir', type=Path, required=True)
    parser.add_argument('--script', default='../tools/validate_rock_seams.gd')
    parser.add_argument('--success-marker', default='ROCK_SEAMS probes=12 failures=0')
    parser.add_argument('--summary-path', default='artifacts/hero_rock_upgrade/checkpoint4/gpu_seams.json')
    parser.add_argument('--timeout', type=float, default=120,
                        help='maximum Godot runtime in seconds (default: 120)')
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine or not shutil.which('Xvfb'):
        parser.error('Godot and Xvfb are required')
    args.log_dir.mkdir(parents=True, exist_ok=True)
    # Separate process trees cannot use unix display sockets in some workspaces.
    # Choose an unused TCP display and keep Xvfb and Godot in one process tree.
    display = None
    for candidate in range(90, 110):
        # TCP namespaces may differ while parallel workers share X lockfiles.
        if Path(f"/tmp/.X{candidate}-lock").exists():
            continue
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
                try:
                    result = subprocess.run([engine, '--display-driver', 'x11', '--audio-driver', 'Dummy', '--fixed-fps', '60', '--path', str(ROOT / 'godot'), '--rendering-method', 'gl_compatibility', '--script', args.script], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=args.timeout)
                except subprocess.TimeoutExpired as exc:
                    output = exc.stdout or exc.output or ''
                    if isinstance(output, bytes):
                        output = output.decode(errors='replace')
                    timeout_message = f'ERROR: Godot validation timed out after {args.timeout:g} seconds'
                    log_output = output + ('' if output.endswith('\n') or not output else '\n') + timeout_message + '\n'
                    (args.log_dir / 'gpu.log').write_text(log_output)
                    print(output, end='')
                    print(timeout_message, file=sys.stderr)
                    raise SystemExit(124) from exc
                (args.log_dir / 'gpu.log').write_text(result.stdout)
                print(result.stdout, end='')
                if validation_failed(result.stdout, result.returncode, args.success_marker):
                    raise SystemExit(1)
                shutil.copyfile(ROOT / args.summary_path, args.log_dir / Path(args.summary_path).name)
            finally:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()

if __name__ == '__main__':
    main()
