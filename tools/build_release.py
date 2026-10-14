#!/usr/bin/env python3
"""Build an isolated desktop candidate; never publish or modify the source project."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "linux": ("Linux x86_64", "CrimsonThreadPilgrimage.x86_64"),
    "windows": ("Windows x86_64", "CrimsonThreadPilgrimage.exe"),
}
RESTRICTED = (
    "assets/third_party/mossy_cavern", "assets/sprites/enemies/itch",
    "assets/sprites/player/abyss_hero", "assets/sprites/enemies/distinct",
)
LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"
ENGINE_ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|USER ERROR:).*$", re.MULTILINE)
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
DEV_SCRIPT = re.compile(r"(?:^(?:capture|preview)_.*|.*(?:_validation|_capture|_preview))\.gd(?:\.uid)?$")


def excluded(path: Path) -> bool:
    return (any(part.startswith('.') for part in path.parts)
            or path.parts[0] in {"tests", "tools"}
            or bool(DEV_SCRIPT.search(path.name))
            or path.suffix in {".log", ".tmp", ".bak"})


def runtime_files(project: Path) -> list[Path]:
    files = []
    for path in sorted(project.rglob('*')):
        relative = path.relative_to(project)
        if excluded(relative):
            continue
        if path.is_symlink():
            raise ValueError(f"Release input must not be a symlink: {relative}")
        if any(relative == Path(p) or Path(p) in relative.parents for p in RESTRICTED):
            raise ValueError(f"Restricted/local-only release input: {relative}")
        if path.is_file():
            with path.open('rb') as source:
                if source.read(len(LFS_POINTER)) == LFS_POINTER:
                    raise ValueError(f"Unhydrated Git LFS asset: {relative}; run git lfs pull --include='godot/**'")
            files.append(path)
    return sorted(files)


def notice_files(root: Path) -> list[Path]:
    files = [root / 'LICENSE', root / 'THIRD_PARTY_NOTICES.md']
    for path in sorted((root / 'godot').rglob('*')):
        if path.is_file() and not excluded(path.relative_to(root / 'godot')):
            if path.stem.lower() in {'license', 'notice', 'ofl', 'public-license'}:
                files.append(path)
    return files


def validate_source(root: Path) -> list[Path]:
    project = root / 'godot'
    required = ['project.godot', 'export_presets.cfg', 'scenes/World.tscn',
                'data/world_routes.json', 'data/world_narrative.json', 'data/build_catalog.json',
                'assets/NOTICE.md', 'assets/fonts/OFL.txt', 'addons/MetroidvaniaSystem/LICENSE.txt']
    for name in required:
        if not (project / name).is_file():
            raise ValueError(f"Missing release input: godot/{name}")
    for path in [root / 'LICENSE', root / 'THIRD_PARTY_NOTICES.md', root / 'docs/RELEASE_PLAYER_GUIDE.md']:
        if not path.is_file() or not path.stat().st_size:
            raise ValueError(f"Missing/empty release document: {path.relative_to(root)}")
    settings = (project / 'project.godot').read_text(encoding='utf-8')
    if 'run/main_scene="res://scenes/World.tscn"' not in settings:
        raise ValueError('Release entry must be World.tscn')
    routes = json.loads((project / 'data/world_routes.json').read_text(encoding='utf-8'))
    if not routes.get('chapters'):
        raise ValueError('World routes have no chapters')
    for region in routes['chapters']:
        if not re.fullmatch(r'[a-z0-9_]+', region):
            raise ValueError(f'Invalid chapter identifier: {region}')
        config = project / 'data' / f'{region}.json'
        if json.loads(config.read_text(encoding='utf-8')).get('id') != region:
            raise ValueError(f'Chapter identity mismatch: {region}')
    files = runtime_files(project)
    for path in files:
        if path.suffix == '.json':
            json.loads(path.read_text(encoding='utf-8'))
    return files


def stage_project(root: Path, destination: Path, files: list[Path]) -> None:
    for path in files:
        target = destination / path.relative_to(root / 'godot')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    project = destination / 'project.godot'
    # Editor UI plugins are not part of the player. Preserve all runtime autoloads,
    # addon classes and UIDs; only disable plugin activation in this disposable copy.
    settings = project.read_text(encoding='utf-8')
    settings = re.sub(r'(?ms)^\[editor_plugins\]\s*.*?(?=^\[|\Z)', '', settings)
    project.write_text(settings, encoding='utf-8')


def run_checked(command: list[str], log: Path, *, timeout: float, cwd: Path, env=None) -> str:
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        with log.open('w', encoding='utf-8') as output:
            result = subprocess.run(command, cwd=cwd, env=env, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f'Timeout after {timeout:g}s; see {log}') from error
    output = log.read_text(encoding='utf-8', errors='replace')
    errors = ENGINE_ERROR.findall(ANSI.sub('', output))
    if result.returncode or errors:
        raise RuntimeError(f'Command failed (exit={result.returncode}, engine_errors={len(errors)}); see {log}\n'
                           + '\n'.join(output.splitlines()[-12:]))
    return output


def verify_save(user_data: Path) -> Path:
    saves = list(user_data.rglob('pilgrimage_world.json'))
    if len(saves) != 1:
        raise ValueError('Exported World did not create exactly one isolated journey save')
    data = json.loads(saves[0].read_text(encoding='utf-8'))
    if not isinstance(data, dict) or not data.get('current_region') or not data.get('regions'):
        raise ValueError('Exported World produced an incomplete journey save')
    return saves[0]


def smoke_package(binary: Path, logs: Path, timeout: float) -> None:
    """Run the actual release template, without --path, --script or source resources."""
    with tempfile.TemporaryDirectory(prefix='pilgrimage-player-') as temporary:
        isolated = Path(temporary)
        user_data = isolated / 'user-data'
        env = dict(os.environ, XDG_DATA_HOME=str(user_data), XDG_CONFIG_HOME=str(isolated / 'config'),
                   XDG_CACHE_HOME=str(isolated / 'cache'), APPDATA=str(user_data),
                   LOCALAPPDATA=str(isolated / 'local-data'), GODOT_SILENCE_ROOT_WARNING='1')
        for attempt in ['first-start', 'resume']:
            run_checked([str(binary), '--headless', '--quit-after', '120'],
                        logs / f'{attempt}.log', timeout=timeout, cwd=isolated, env=env)
            save = verify_save(user_data)
            data = json.loads(save.read_text(encoding='utf-8'))
            if attempt == 'first-start':
                # A harmless test-only flag distinguishes a real resume from a
                # second fresh start. This lives only in the temporary profile.
                data.setdefault('story_flags', {})['release_resume_probe'] = True
                save.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
                # World writes atomically, backing up the previous save on startup.
                # Remove the first boot's backup so a passive second boot cannot
                # pass by merely leaving our injected flag untouched on disk.
                save.with_name(save.name + '.bak').unlink(missing_ok=True)
            else:
                if data.get('story_flags', {}).get('release_resume_probe') is not True:
                    raise ValueError('Exported World did not preserve the isolated resume probe')
                backup = save.with_name(save.name + '.bak')
                if not backup.is_file():
                    raise ValueError('Exported World did not write back the resumed save')
                previous = json.loads(backup.read_text(encoding='utf-8'))
                if previous.get('story_flags', {}).get('release_resume_probe') is not True:
                    raise ValueError('Exported World did not back up the resumed save')
        print('RELEASE_PLAYER_PASS first_start=true resume=true resume_writeback=true', flush=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def package_directory(payload: Path, archive: Path, manifest: dict) -> None:
    manifest['files'] = {p.relative_to(payload).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha256(p)}
                         for p in sorted(payload.rglob('*')) if p.is_file()}
    (payload / 'BUILD_MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as output:
        for path in sorted(payload.rglob('*')):
            if path.is_file():
                output.write(path, arcname=f'{payload.name}/{path.relative_to(payload).as_posix()}')
    (archive.parent / f'{archive.name}.sha256').write_text(f'{sha256(archive)}  {archive.name}\n', encoding='ascii')


def unpack_verified_package(archive: Path, destination: Path) -> Path:
    """Verify the delivered ZIP, then unpack it into an empty player directory."""
    checksum = archive.with_name(archive.name + '.sha256').read_text(encoding='ascii').split()
    if checksum != [sha256(archive), archive.name]:
        raise ValueError('Candidate ZIP checksum mismatch')
    if destination.exists():
        raise ValueError('Candidate unpack directory must not already exist')
    with zipfile.ZipFile(archive) as source:
        members = source.infolist()
        names = [member.filename for member in members]
        prefix = archive.stem + '/'
        if len(names) != len(set(names)):
            raise ValueError('Duplicate candidate ZIP member')
        for member in members:
            name = member.filename
            if (not name.startswith(prefix) or '\\' in name or ':' in name
                    or any(part in {'', '.', '..'} for part in name.split('/'))
                    or (member.external_attr >> 16) & 0o170000 == 0o120000):
                raise ValueError(f'Invalid candidate ZIP member: {name}')
        manifest = json.loads(source.read(prefix + 'BUILD_MANIFEST.json'))
        expected = manifest['files']
        if set(names) != {prefix + name for name in expected} | {prefix + 'BUILD_MANIFEST.json'}:
            raise ValueError('Candidate ZIP contents differ from the build manifest')
        for name, record in expected.items():
            digest = hashlib.sha256()
            size = 0
            with source.open(prefix + name) as file:
                for block in iter(lambda: file.read(1024 * 1024), b''):
                    size += len(block)
                    digest.update(block)
            if size != record['bytes'] or digest.hexdigest() != record['sha256']:
                raise ValueError(f'Candidate payload checksum mismatch: {name}')
        source.extractall(destination)
        if os.name != 'nt':
            for member in members:
                (destination / member.filename).chmod((member.external_attr >> 16) & 0o777)
    print(f'RELEASE_ARCHIVE_PASS files={len(expected)}', flush=True)
    return destination / archive.stem


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=TARGETS, default='linux')
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/releases')
    parser.add_argument('--check', action='store_true', help='Check source inputs only; no build or gameplay claim.')
    parser.add_argument('--timeout', type=float, default=600)
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('--timeout must be finite and positive')
    try:
        files = validate_source(ROOT)
        print(f'RELEASE_INPUTS_PASS files={len(files)}', flush=True)
        if args.check:
            return 0
        if (args.target == 'windows') != (sys.platform == 'win32') or (args.target == 'linux' and not sys.platform.startswith('linux')):
            raise ValueError('Build on the target OS so the actual executable can be smoke-tested')
        engine = shutil.which(args.engine)
        if not engine:
            raise ValueError(f'Godot executable not found: {args.engine}')
        output = args.output.resolve()
        if output == ROOT or output in ROOT.parents or output.is_relative_to(ROOT / 'godot'):
            raise ValueError('Output must not contain the source checkout or be inside godot/')
        output.mkdir(parents=True, exist_ok=True)
        preset, executable = TARGETS[args.target]
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        dirty = bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=ROOT, text=True).strip())
        name = f'CrimsonThreadPilgrimage-{args.target}-{commit[:12]}'
        logs = output / f'{name}-logs'
        if logs.exists() or (output / f'{name}.zip').exists() or (output / f'{name}.zip.sha256').exists():
            raise ValueError(f'Refusing to overwrite an earlier candidate; choose a new --output: {name}')
        version = run_checked([engine, '--version'], logs / 'version.log', timeout=30, cwd=ROOT).strip()
        if not version.startswith('4.6.1.stable.'):
            raise ValueError(f'Expected Godot 4.6.1 stable and matching templates, got {version}')
        with tempfile.TemporaryDirectory(prefix='pilgrimage-release-') as temporary:
            work = Path(temporary)
            project = work / 'project'
            stage_project(ROOT, project, files)
            env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
            run_checked([engine, '--headless', '--path', str(project), '--editor', '--import', '--quit'],
                        logs / 'import.log', timeout=args.timeout, cwd=work, env=env)
            payload = work / name
            payload.mkdir()
            binary = payload / executable
            run_checked([engine, '--headless', '--path', str(project), '--export-release', preset, str(binary)],
                        logs / 'export.log', timeout=args.timeout, cwd=work, env=env)
            for required in [binary, binary.with_suffix('.pck')]:
                if not required.is_file() or required.stat().st_size == 0:
                    raise ValueError(f'Exporter did not produce {required.name}')
            for path in notice_files(ROOT):
                target = payload / 'licenses' / path.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
            shutil.copy2(ROOT / 'docs/RELEASE_PLAYER_GUIDE.md', payload / 'README.md')
            license_project = work / 'engine-licenses'
            license_project.mkdir()
            (license_project / 'project.godot').write_text('config_version=5\n', encoding='utf-8')
            engine_licenses = payload / 'licenses/GODOT_ENGINE.txt'
            run_checked([engine, '--headless', '--path', str(license_project), '--script',
                         str(ROOT / 'tools/release_engine_licenses.gd'), '--', str(engine_licenses)],
                        logs / 'engine-licenses.log', timeout=args.timeout, cwd=work, env=env)
            if not engine_licenses.is_file() or not engine_licenses.stat().st_size:
                raise ValueError('Missing Godot engine and bundled-library license notices')
            # The player must work after the entire staged source and import cache disappear.
            shutil.rmtree(project)
            manifest = {'schema_version': 1, 'source_commit': commit, 'source_dirty': dirty,
                        'target': args.target, 'engine': version,
                        'validation': ['source-inputs', 'isolated-import', 'release-export', 'archive-integrity',
                                       'unpacked-first-start', 'unpacked-resume-writeback'],
                        'qualification': 'candidate; headless startup is not full gameplay, visual, audio or ending acceptance'}
            archive = work / f'{name}.zip'
            package_directory(payload, archive, manifest)
            # Only the ZIP survives into the smoke test: no original export or
            # staged project can accidentally satisfy a missing package file.
            shutil.rmtree(payload)
            unpacked = unpack_verified_package(archive, work / 'unpacked')
            smoke_package(unpacked / executable, logs, args.timeout)
            shutil.copy2(archive, output / archive.name)
            shutil.copy2(archive.with_name(archive.name + '.sha256'), output / (archive.name + '.sha256'))
        print(f'RELEASE_CANDIDATE_PASS {output / (name + ".zip")}', flush=True)
        return 0
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f'RELEASE_FAILED: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
