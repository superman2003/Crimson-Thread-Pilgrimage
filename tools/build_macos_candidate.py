#!/usr/bin/env python3
"""Experimental macOS candidate: export the app, then boot it from its ZIP.

Kept apart from tools/build_release.py so the Windows/Linux release gates stay
exactly as they are while the macOS path is proven on a real macOS runner.
The official macOS template is a universal binary only, and a universal export
requires ETC2/ASTC texture import to be enabled. That project setting is
switched on in the staged copy alone, so Windows/Linux imports are unchanged.
The app is unsigned beyond the built-in ad-hoc signature and not notarised:
Gatekeeper will warn on a downloaded copy.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

import build_release as release
import download_godot_release as engine_release
from release_save_contract import smoke_save_contract

ROOT = Path(__file__).resolve().parents[1]
PRESET = 'macOS'
EDITOR_ARCHIVE = f'Godot_v{engine_release.VERSION}-stable_macos.universal.zip'
TEMPLATE = 'macos.zip'
LEGAL_DIR = 'Contents/Resources/legal'
LEGAL_REQUIRED = (
    LEGAL_DIR + '/licenses/LICENSE',
    LEGAL_DIR + '/licenses/THIRD_PARTY_NOTICES.md',
    LEGAL_DIR + '/licenses/GODOT_ENGINE.txt',
    LEGAL_DIR + '/README.md',
    LEGAL_DIR + '/BUILD_MANIFEST.json',
)


def zip_member_names(archive: Path) -> list[str]:
    """Read ZIP member names as UTF-8 even when macOS ditto omits flag bit 0x800."""
    with zipfile.ZipFile(archive) as bundle:
        names = []
        for info in bundle.infolist():
            name = info.filename
            if not (info.flag_bits & 0x800):
                try:
                    name = name.encode('cp437').decode('utf-8')
                except (UnicodeEncodeError, UnicodeDecodeError):
                    pass
            names.append(name)
        return names


def bundle_name(names: list[str]) -> str:
    """The one top-level .app in a ZIP's member list (named after the project)."""
    tops = sorted({name.split('/', 1)[0] for name in names if name})
    apps = [top for top in tops if top.endswith('.app')]
    if len(apps) != 1 or len(tops) != 1:
        raise ValueError('Expected exactly one app bundle and nothing else at the top of the archive: ' + ', '.join(tops[:4]))
    return apps[0]


def bundle_problems(names: list[str]) -> list[str]:
    """What a ZIP's member list is missing to be the exported app bundle."""
    app = bundle_name(names)
    found = []
    files = {name for name in names if not name.endswith('/')}
    if not any(name.startswith(app + '/Contents/MacOS/') for name in files):
        found.append('no executable under Contents/MacOS')
    if app + '/Contents/Info.plist' not in files:
        found.append('no Info.plist')
    if not any(name.startswith(app + '/Contents/Resources/') and name.endswith('.pck') for name in files):
        found.append('no game data (.pck) under Contents/Resources')
    for required in LEGAL_REQUIRED:
        if app + '/' + required not in files:
            found.append(f'missing legal/release metadata under {required}')
    return found


def populate_legal_bundle(app: Path, root: Path, engine_licenses: Path, manifest: dict) -> Path:
    """Attach license notices, player guide and manifest inside <app>/Contents/Resources/legal."""
    if not engine_licenses.is_file() or not engine_licenses.stat().st_size:
        raise ValueError('Missing Godot engine and bundled-library license notices')
    legal_root = app / LEGAL_DIR
    licenses_root = legal_root / 'licenses'
    licenses_root.mkdir(parents=True, exist_ok=True)
    for path in release.notice_files(root):
        target = licenses_root / path.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    shutil.copy2(engine_licenses, licenses_root / 'GODOT_ENGINE.txt')
    shutil.copy2(root / 'docs/RELEASE_PLAYER_GUIDE.md', legal_root / 'README.md')
    legal_manifest = dict(manifest)
    legal_manifest['legal_files'] = {
        p.relative_to(legal_root).as_posix(): {'bytes': p.stat().st_size, 'sha256': release.sha256(p)}
        for p in sorted(legal_root.rglob('*')) if p.is_file()
    }
    manifest_path = legal_root / 'BUILD_MANIFEST.json'
    manifest_path.write_text(json.dumps(legal_manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return legal_root


def enable_universal_textures(project_file: Path) -> None:
    """Turn on ETC2/ASTC import in a staged project.godot (never the checkout's)."""
    if ROOT in project_file.resolve().parents:
        raise ValueError('Refusing to change the import settings of the source checkout')
    setting = 'textures/vram_compression/import_etc2_astc=true'
    lines = project_file.read_text(encoding='utf-8').splitlines()
    lines = [line for line in lines if not line.startswith('textures/vram_compression/import_etc2_astc=')]
    if '[rendering]' in lines:
        lines.insert(lines.index('[rendering]') + 1, setting)
    else:
        lines += ['', '[rendering]', '', setting]
    project_file.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def executable_in(app: Path) -> Path:
    binaries = [p for p in sorted((app / 'Contents/MacOS').iterdir()) if p.is_file()]
    if len(binaries) != 1:
        raise ValueError('Expected exactly one executable in Contents/MacOS')
    return binaries[0]


def install_engine(root: Path) -> Path:
    """Verified editor app and macOS template; returns the editor executable."""
    root.mkdir(parents=True, exist_ok=True)
    sums = engine_release.download(engine_release.BASE + 'SHA512-SUMS.txt', root / 'SHA512-SUMS.txt')
    hashes = engine_release.parse_checksums(sums.read_text(encoding='utf-8'))
    for name in [EDITOR_ARCHIVE, engine_release.TEMPLATES]:
        if name not in hashes:
            raise ValueError('Official SHA512 entry is missing: ' + name)
    editor = engine_release.download(engine_release.BASE + EDITOR_ARCHIVE, root / EDITOR_ARCHIVE, hashes[EDITOR_ARCHIVE])
    templates = engine_release.download(engine_release.BASE + engine_release.TEMPLATES,
                                        root / engine_release.TEMPLATES, hashes[engine_release.TEMPLATES])
    # ditto keeps the bundle's permissions and signature; zipfile would not.
    subprocess.run(['ditto', '-x', '-k', str(editor), str(root)], check=True)
    target = (Path.home() / 'Library/Application Support/Godot/export_templates'
              / f'{engine_release.VERSION}.stable' / TEMPLATE)
    engine_release.extract_member(templates, 'templates/' + TEMPLATE, target)
    return root / 'Godot.app/Contents/MacOS/Godot'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/releases')
    parser.add_argument('--timeout', type=float, default=900)
    args = parser.parse_args()
    try:
        if sys.platform != 'darwin':
            raise ValueError('Build on macOS so the exported app can actually be started')
        files = release.validate_source(ROOT)
        engine = str(install_engine(args.engine_root.resolve()))
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=True)
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        dirty = bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=ROOT, text=True).strip())
        name = f'CrimsonThreadPilgrimage-macos-{commit[:12]}'
        logs = output / f'{name}-logs'
        version = release.run_checked([engine, '--version'], logs / 'version.log', timeout=60, cwd=ROOT).strip()
        if not version.startswith(engine_release.VERSION + '.stable.'):
            raise ValueError(f'Expected Godot {engine_release.VERSION} stable, got {version}')
        with tempfile.TemporaryDirectory(prefix='pilgrimage-macos-') as temporary:
            work = Path(temporary)
            project = work / 'project'
            release.stage_project(ROOT, project, files)
            enable_universal_textures(project / 'project.godot')
            release.run_checked([engine, '--headless', '--path', str(project), '--editor', '--import', '--quit'],
                                logs / 'import.log', timeout=args.timeout, cwd=work)
            raw_archive = work / f'{name}-raw.zip'
            release.run_checked([engine, '--headless', '--path', str(project), '--export-release', PRESET, str(raw_archive)],
                                logs / 'export.log', timeout=args.timeout, cwd=work)
            if not raw_archive.is_file():
                raise ValueError('Exporter did not produce the app archive')
            app = bundle_name(zip_member_names(raw_archive))
            license_project = work / 'engine-licenses'
            license_project.mkdir()
            (license_project / 'project.godot').write_text('config_version=5\n', encoding='utf-8')
            engine_licenses = work / 'GODOT_ENGINE.txt'
            release.run_checked([engine, '--headless', '--path', str(license_project), '--script',
                                 str(ROOT / 'tools/release_engine_licenses.gd'), '--', str(engine_licenses)],
                                logs / 'engine-licenses.log', timeout=args.timeout, cwd=work)
            staged_bundle = work / 'bundle'
            subprocess.run(['ditto', '-x', '-k', str(raw_archive), str(staged_bundle)], check=True)
            manifest = {
                'schema_version': 1, 'source_commit': commit, 'source_dirty': dirty,
                'target': 'macos', 'engine': version,
                'validation': ['source-inputs', 'isolated-import', 'release-export', 'bundle-legal-notices',
                               'unpacked-first-start', 'unpacked-resume-writeback',
                               'unpacked-three-slot-isolation', 'unpacked-damaged-save-preservation'],
                'qualification': 'candidate; ad-hoc signed, not notarised; headless startup is not full gameplay, visual, audio or ending acceptance',
            }
            populate_legal_bundle(staged_bundle / app, ROOT, engine_licenses, manifest)
            subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(staged_bundle / app)], check=True)
            archive = work / f'{name}.zip'
            subprocess.run(['ditto', '-c', '-k', '--keepParent', str(staged_bundle / app), str(archive)], check=True)
            names = zip_member_names(archive)
            app = bundle_name(names)
            problems = bundle_problems(names)
            if problems:
                raise ValueError('Exported archive is not a complete app: ' + '; '.join(problems))
            # Only the archive survives: the staged project and raw bundle cannot stand in for missing data.
            shutil.rmtree(project)
            shutil.rmtree(staged_bundle)
            raw_archive.unlink()
            unpacked = work / 'unpacked'
            subprocess.run(['ditto', '-x', '-k', str(archive), str(unpacked)], check=True)
            binary = executable_in(unpacked / app)
            release.smoke_package(binary, logs, args.timeout)
            smoke_save_contract(binary, logs, args.timeout, release.run_checked)
            shutil.copy2(archive, output / archive.name)
            (output / f'{archive.name}.sha256').write_text(f'{release.sha256(archive)}  {archive.name}\n', encoding='ascii')
        print(f'MACOS_CANDIDATE_PASS {output / archive.name}', flush=True)
        return 0
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f'MACOS_CANDIDATE_FAILED: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
