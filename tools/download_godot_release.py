#!/usr/bin/env python3
"""Install the pinned release editor/templates with bounded, verified downloads."""
from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import shutil
import ssl
import tempfile
import subprocess
import time
import urllib.error
import urllib.request
import zipfile

VERSION = '4.6.1'
BASE = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/'
EDITORS = {
    'Godot_v4.6.1-stable_linux.x86_64': 'linux_release.x86_64',
    'Godot_v4.6.1-stable_win64.exe': 'windows_release_x86_64.exe',
}
TEMPLATES = f'Godot_v{VERSION}-stable_export_templates.tpz'
RETRY_HTTP = {408, 429, 500, 502, 503, 504}


class DownloadIntegrityError(RuntimeError):
    pass


def sha512(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha512').hexdigest()


def parse_checksums(text):
    hashes = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'([0-9a-fA-F]{128})\s+\*?([^\s/\\]+)', line.strip())
        if match is None:
            raise ValueError('Invalid official SHA512 manifest line')
        digest, name = match.groups()
        digest = digest.lower()
        if name in hashes:
            raise ValueError('Duplicate official SHA512 entry: '+name)
        hashes[name] = digest
    if not hashes:
        raise ValueError('Empty official SHA512 manifest')
    return hashes


RELEASE_URL = re.compile(r'https://github\.com/([\w.-]+/[\w.-]+)/releases/download/([^/]+)/([^/]+)')


def fetch_with_gh(url, pending):
    """Authenticated GitHub API download when CI provides GH_TOKEN; anonymous
    release downloads time out during GitHub surges. Returns False to fall back."""
    match = RELEASE_URL.fullmatch(url)
    if match is None or not os.environ.get('GH_TOKEN') or shutil.which('gh') is None:
        return False
    repo, tag, asset = match.groups()
    try:
        result = subprocess.run(['gh', 'release', 'download', tag, '-R', repo, '-p', asset, '-O', str(pending), '--clobber'],
                                capture_output=True, text=True, timeout=600)
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f'gh release download failed, falling back: {error}', flush=True)
        return False
    if result.returncode != 0:
        print(f'gh release download failed, falling back: {result.stderr.strip()[:200]}', flush=True)
        return False
    return True


def download(url, target, expected=None, *, attempts=5, timeout=45, sleep=time.sleep):
    """A partial or unverified response never replaces the destination."""
    if type(attempts) is not int or attempts < 1 or timeout <= 0:
        raise ValueError('Positive download attempts and timeout required')
    if expected is not None and re.fullmatch(r'[0-9a-f]{128}', expected) is None:
        raise ValueError('A full lowercase SHA512 digest is required')
    target.parent.mkdir(parents=True, exist_ok=True)
    if expected is not None and target.is_file() and sha512(target) == expected:
        return target
    for attempt in range(1, attempts+1):
        with tempfile.NamedTemporaryFile(prefix=target.name+'.', suffix='.part', dir=target.parent, delete=False) as handle:
            pending = Path(handle.name)
        try:
            if attempt == 1 and fetch_with_gh(url, pending):
                if expected is not None and sha512(pending) != expected:
                    raise DownloadIntegrityError('Official SHA512 mismatch: '+target.name)
                pending.replace(target)
                return target
            with urllib.request.urlopen(url, timeout=timeout) as response, pending.open('wb') as output:
                length = response.headers.get('Content-Length')
                count = 0
                while chunk := response.read(1024*1024):
                    output.write(chunk)
                    count += len(chunk)
                if length is not None and (not length.isdecimal() or count != int(length)):
                    raise DownloadIntegrityError('Incomplete response: '+target.name)
            if expected is not None and sha512(pending) != expected:
                raise DownloadIntegrityError('Official SHA512 mismatch: '+target.name)
            pending.replace(target)
            return target
        except urllib.error.HTTPError as error:
            error.close()
            if error.code not in RETRY_HTTP:
                raise
            failure = error
        except urllib.error.URLError as error:
            if isinstance(error.reason, ssl.SSLCertVerificationError):
                raise
            failure = error
        except (ssl.SSLEOFError, TimeoutError, ConnectionError, http.client.IncompleteRead, DownloadIntegrityError) as error:
            failure = error
        finally:
            pending.unlink(missing_ok=True)
        if attempt == attempts:
            raise RuntimeError(f'Download failed after {attempts} attempts: {target.name}: {failure}') from failure
        delay = min(5*2**(attempt-1), 40)
        print(f'Retrying {target.name}: attempt {attempt}/{attempts}, wait {delay}s: {failure}', flush=True)
        sleep(delay)


def extract_member(archive, member, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(prefix=target.name+'.', suffix='.part', dir=target.parent, delete=False) as handle:
        pending = Path(handle.name)
    try:
        with zipfile.ZipFile(archive) as source, source.open(member) as binary, pending.open('wb') as output:
            shutil.copyfileobj(binary, output)
        pending.chmod(0o755)
        pending.replace(target)
    finally:
        pending.unlink(missing_ok=True)


def install(editor, template, root, templates, env_file=None, *, base=BASE, **download_options):
    if EDITORS.get(editor) != template:
        raise ValueError('Editor and release template must be a pinned matching pair')
    root = root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    (root/'install-receipt.json').unlink(missing_ok=True)
    sums = download(base+'SHA512-SUMS.txt', root/'SHA512-SUMS.txt', **download_options)
    hashes = parse_checksums(sums.read_text(encoding='utf-8'))
    archive_name = editor+'.zip'
    for name in [archive_name, TEMPLATES]:
        if name not in hashes:
            raise ValueError('Official SHA512 entry is missing: '+name)
    archive = download(base+archive_name, root/archive_name, hashes[archive_name], **download_options)
    template_archive = download(base+TEMPLATES, root/TEMPLATES, hashes[TEMPLATES], **download_options)
    binary = root/editor
    template_binary = templates/template
    extract_member(archive, editor, binary)
    extract_member(template_archive, 'templates/'+template, template_binary)
    receipt = {'version':VERSION, 'source':base, 'editor':str(binary), 'template':str(template_binary),
               'archive_sha512':{name:hashes[name] for name in [archive_name,TEMPLATES]},
               'binary_sha512':{editor:sha512(binary),template:sha512(template_binary)}}
    (root/'install-receipt.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    # Publish GODOT only after both verified archives and exact members succeeded.
    if env_file is not None:
        with env_file.open('a', encoding='utf-8') as output:
            output.write('GODOT='+str(binary)+'\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor', required=True, choices=EDITORS)
    parser.add_argument('--template', required=True, choices=EDITORS.values())
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--github-env', type=Path, default=os.environ.get('GITHUB_ENV'))
    args = parser.parse_args()
    if os.name == 'nt':
        data = Path(os.environ['APPDATA'])/'Godot'
    else:
        data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))/'godot'
    receipt = install(args.editor, args.template, args.root,
                      data/f'export_templates/{VERSION}.stable', args.github_env)
    print(json.dumps(receipt, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
