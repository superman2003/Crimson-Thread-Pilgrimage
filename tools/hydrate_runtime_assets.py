#!/usr/bin/env python3
"""Hydrate the exact checkout's runtime assets, with bounded LFS retries."""
from __future__ import annotations

import argparse
import os
import signal
import subprocess
import time


DEFAULT_INCLUDE = 'godot/assets/**,godot/addons/MetroidvaniaSystem/**'
ATTEMPTS = 3
ATTEMPT_TIMEOUT = 300


def run_pull(command: list[str]) -> int:
    process = subprocess.Popen(command, start_new_session=os.name == 'posix')
    try:
        return process.wait(timeout=ATTEMPT_TIMEOUT)
    except subprocess.TimeoutExpired:
        # git starts git-lfs and transfer helpers; stop the entire attempt
        # before retrying, so a timed-out download cannot keep running behind it.
        if os.name == 'posix':
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        else:
            process.kill()
        process.wait()
        raise


def hydrate(include: str) -> int:
    # A batch endpoint can return HTTP 502 before LFS's per-object transfer
    # retries apply. Retrying pull reuses objects already downloaded; it never
    # changes the checked-out commit or substitutes an older resource set.
    command = ['git', '-c', 'lfs.concurrenttransfers=3', 'lfs', 'pull',
               '--include=' + include]
    for attempt in range(1, ATTEMPTS + 1):
        print(f'LFS hydration attempt {attempt}/{ATTEMPTS}', flush=True)
        try:
            status = run_pull(command)
        except subprocess.TimeoutExpired:
            print(f'LFS hydration exceeded {ATTEMPT_TIMEOUT}s', flush=True)
            status = 124
        except OSError as error:
            print(f'Cannot launch git LFS: {error}', flush=True)
            return 127
        if status == 0:
            print('LFS hydration completed', flush=True)
            return 0
        if attempt < ATTEMPTS:
            delay = 5 * attempt
            print(f'LFS hydration failed (exit {status}); retrying in {delay}s', flush=True)
            time.sleep(delay)
    print(f'LFS hydration failed after {ATTEMPTS} attempts (exit {status})', flush=True)
    return status if status > 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--include', default=DEFAULT_INCLUDE,
                        help='Git LFS include patterns for this validation job.')
    args = parser.parse_args()
    if not args.include.strip():
        parser.error('--include must name the required assets')
    return hydrate(args.include)


if __name__ == '__main__':
    raise SystemExit(main())
