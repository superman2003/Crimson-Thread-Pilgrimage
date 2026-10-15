"""Keep a real software OpenGL display alive for isolated regression processes."""
from contextlib import contextmanager
from pathlib import Path
import shutil
import socket
import subprocess
import time


@contextmanager
def software_gl(log_dir: Path):
    if not shutil.which('Xvfb'):
        raise RuntimeError('--software-gl requires Xvfb; no headless fallback')
    log_dir.mkdir(parents=True, exist_ok=True)
    display = None
    for candidate in range(90, 110):
        # Parallel containers may isolate TCP while sharing X server lockfiles.
        # Respect the lock without removing or terminating another display.
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
    with (log_dir / 'xvfb.log').open('w') as log:
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
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Xvfb startup timed out')
                    time.sleep(0.1)
            yield {'DISPLAY': f'127.0.0.1:{display}', 'LIBGL_ALWAYS_SOFTWARE': '1'}
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
