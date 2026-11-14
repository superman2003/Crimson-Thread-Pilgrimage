"""Key selected LFS pointers without traversing a sparse clone's other blobs."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def cache_key(listing: bytes) -> tuple[str, int]:
    objects = set()
    for record in json.loads(listing)['files'] or []:
        oid = record['oid']
        if not re.fullmatch('[0-9a-f]{64}', oid):
            raise ValueError('Unexpected git lfs ls-files record')
        objects.add(oid.encode('ascii'))
    # Paths and the hydrated/pointer marker do not change cached object bytes.
    fingerprint = hashlib.sha256(b'\n'.join(sorted(objects))).hexdigest()
    return 'lfs-v2-' + fingerprint, len(objects)


def selected_objects(include: str, cwd: Path | None = None) -> bytes:
    def git(*args, data=None):
        return subprocess.run(['git', *args], cwd=cwd, input=data,
                              check=True, capture_output=True).stdout

    # git-lfs's index/tree scan can lazily fetch excluded art in a sparse
    # partial clone. Select paths first, then inspect only their declared LFS
    # files; legacy ordinary Git files covered by those attributes are skipped.
    entries = git('ls-files', '--stage', '-z', '--', *include.split(','))
    blobs = {}
    for entry in entries.split(b'\0'):
        if not entry:
            continue
        header, name = entry.split(b'\t', 1)
        mode, oid, stage = header.split()
        if stage != b'0':
            raise ValueError('Unmerged LFS selection')
        blobs[name] = oid
    attributes = git('check-attr', '--cached', '-z', '--stdin', 'filter',
                     data=b''.join(name + b'\0' for name in blobs)).split(b'\0')
    selected = {blobs[attributes[i]] for i in range(0, len(attributes) - 1, 3)
                if attributes[i + 2] == b'lfs'}
    objects = []
    if selected:
        process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=cwd,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        try:
            for blob in sorted(selected):
                process.stdin.write(blob + b'\n')
                process.stdin.flush()
                oid, kind, size = process.stdout.readline().split()
                if oid != blob or kind != b'blob':
                    raise ValueError('Expected a selected LFS blob')
                size = int(size)
                if size > 1024:
                    # Attributes can also cover legacy ordinary Git files. Do
                    # not buffer their data or confuse it with an LFS pointer.
                    remaining = size
                    while remaining:
                        chunk = process.stdout.read(min(remaining, 65536))
                        if not chunk:
                            raise ValueError('Truncated selected Git blob')
                        remaining -= len(chunk)
                    if process.stdout.read(1) != b'\n':
                        raise ValueError('Truncated selected Git blob')
                    continue
                pointer = process.stdout.read(size)
                if process.stdout.read(1) != b'\n':
                    raise ValueError('Truncated LFS pointer')
                if not pointer.splitlines() or pointer.splitlines()[0] != b'version https://git-lfs.github.com/spec/v1':
                    continue
                match = re.search(rb'^oid sha256:([0-9a-f]{64})\r?$', pointer, re.MULTILINE)
                if not match:
                    raise ValueError('Malformed selected LFS pointer')
                objects.append(dict(oid=match.group(1).decode('ascii')))
        finally:
            process.stdin.close()
            process.stdout.close()
            if process.wait(timeout=30):
                raise ValueError('Cannot read selected LFS pointers')
    return json.dumps(dict(files=objects)).encode('utf-8')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--include', required=True)
    args = parser.parse_args()
    if not args.include.strip():
        parser.error('--include must name the required assets')
    key, count = cache_key(selected_objects(args.include))
    print(f'LFS_CACHE objects={count} key={key}')
    if output := os.environ.get('GITHUB_OUTPUT'):
        with Path(output).open('a', encoding='utf-8', newline='\n') as handle:
            handle.write(f'key={key}\ncount={count}\n')


if __name__ == '__main__':
    main()
