"""Key an LFS object cache from selected content IDs, without reading blobs."""
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--include', required=True)
    args = parser.parse_args()
    if not args.include.strip():
        parser.error('--include must name the required assets')
    result = subprocess.run(['git', 'lfs', 'ls-files', '--long', '--json',
                             '--include=' + args.include], check=True, capture_output=True)
    key, count = cache_key(result.stdout)
    print(f'LFS_CACHE objects={count} key={key}')
    if output := os.environ.get('GITHUB_OUTPUT'):
        with Path(output).open('a', encoding='utf-8', newline='\n') as handle:
            handle.write(f'key={key}\ncount={count}\n')


if __name__ == '__main__':
    main()
