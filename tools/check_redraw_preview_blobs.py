"""Validate non-LFS redraw previews in the Git index, not hydrated worktree files."""
import io
from pathlib import Path
import re
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = re.compile(r'artifacts/creature_redraw_batch[0-9]+/[^/]+\.(?:jpg|webp)$')


def validate_image(raw, path):
    if raw.startswith(b'version https://git-lfs.github.com/spec/v1'):
        raise ValueError('Non-LFS preview is still a pointer in Git: ' + path)
    try:
        with Image.open(io.BytesIO(raw)) as image:
            image.verify()
    except Exception as error:
        raise ValueError('Preview is not a decodable image in Git: ' + path) from error


def git(*args, data=None):
    return subprocess.check_output(['git', *args], input=data, cwd=ROOT)


def main():
    entries = {}
    for record in git('ls-files', '--stage', '-z').split(b'\0'):
        if not record:
            continue
        header, path = record.split(b'\t', 1)
        name = path.decode('utf-8')
        if PREVIEW.fullmatch(name):
            mode, oid, stage = header.split()
            if stage != b'0':
                raise ValueError('Unmerged preview: ' + name)
            entries[name] = oid.decode('ascii')
    if not entries:
        raise ValueError('No tracked redraw previews')
    attrs = git('check-attr', '--cached', '-z', '--stdin', 'filter',
                data=b''.join(p.encode('utf-8') + b'\0' for p in entries)).split(b'\0')
    selected = []
    for index in range(0, len(attrs) - 1, 3):
        path, attribute, value = attrs[index:index + 3]
        if value == b'lfs':
            continue
        name = path.decode('utf-8')
        selected.append(name)
    if not selected:
        raise ValueError('No ordinary Git preview images checked')
    # Keep one cat-file process: spawning Git separately for hundreds of small
    # previews is particularly slow on Windows.
    process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=ROOT,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for name in selected:
            process.stdin.write((entries[name] + '\n').encode('ascii'))
            process.stdin.flush()
            oid, kind, size = process.stdout.readline().split()
            if oid.decode('ascii') != entries[name] or kind != b'blob':
                raise ValueError('Missing preview blob: ' + name)
            raw = process.stdout.read(int(size))
            if len(raw) != int(size) or process.stdout.read(1) != b'\n':
                raise ValueError('Truncated preview blob: ' + name)
            validate_image(raw, name)
    finally:
        process.stdin.close()
        process.stdout.close()
        process.wait(timeout=30)
    checked = len(selected)
    print(f'REDRAW_PREVIEW_BLOBS PASS images={checked}')


if __name__ == '__main__':
    main()
