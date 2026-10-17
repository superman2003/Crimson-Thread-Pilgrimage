#!/usr/bin/env python3
"""Release gates must fail closed even when the engine returns zero."""
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build_release as release


class ReleaseBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / 'godot'
        self.project.mkdir()

    def write(self, name, data='content'):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data, encoding='utf-8')
        return path

    def command(self, script, timeout=5):
        return release.run_checked([sys.executable, '-c', script], self.root / 'command.log',
                                   timeout=timeout, cwd=self.root)

    def test_zero_exit_engine_errors_fail(self):
        for error in ['ERROR:', 'SCRIPT ERROR:', 'Parse Error:', 'USER ERROR:']:
            with self.subTest(error=error), self.assertRaises(RuntimeError):
                self.command(f'print("  {error} missing resource")')

    def test_nonzero_exit_fails(self):
        with self.assertRaises(RuntimeError):
            self.command('raise SystemExit(9)')

    def test_ansi_colored_error_cannot_bypass_gate(self):
        with self.assertRaises(RuntimeError):
            self.command('print("\\x1b[31mERROR: missing resource\\x1b[0m")')

    def test_timeout_fails_and_preserves_log(self):
        with self.assertRaisesRegex(RuntimeError, 'Timeout'):
            self.command('import time; print("started", flush=True); time.sleep(2)', timeout=0.2)
        self.assertIn('started', (self.root / 'command.log').read_text())

    def test_clean_output_passes(self):
        self.assertIn('ready', self.command('print("ready")'))

    def test_lfs_pointer_rejected(self):
        self.write('assets/image.png', release.LFS_POINTER.decode() + '\noid sha256:123\n')
        with self.assertRaisesRegex(ValueError, 'Unhydrated'):
            release.runtime_files(self.project)

    def test_restricted_asset_rejected(self):
        for directory in release.RESTRICTED:
            with self.subTest(directory=directory):
                path = self.write(directory + '/image.png')
                with self.assertRaisesRegex(ValueError, 'Restricted'):
                    release.runtime_files(self.project)
                path.unlink()
                # Empty restricted directories also block packaging.
                with self.assertRaisesRegex(ValueError, 'Restricted'):
                    release.runtime_files(self.project)
                path.parent.rmdir()

    def test_symlink_rejected(self):
        target = self.write('assets/a.txt')
        try:
            (self.project / 'assets/link.txt').symlink_to(target)
        except OSError:
            self.skipTest('symlinks unavailable without privileges on this OS')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            release.runtime_files(self.project)

    def test_development_files_excluded_but_dynamic_resources_kept(self):
        kept = ['scripts/main_level.gd', 'data/world_routes.json', 'assets/actor/manifest.json',
                'MapData.txt', 'addons/MetroidvaniaSystem/Scripts/MetSys.gd']
        excluded = ['scripts/world_validation.gd', 'scripts/world_capture.gd.uid',
                    'scripts/capture_world.gd', 'scripts/preview_world.gd.uid',
                    'tests/verify_world.gd', '.godot/imported/image.ctex', 'tools/debug.gd']
        for path in kept + excluded:
            self.write(path)
        files = [p.relative_to(self.project).as_posix() for p in release.runtime_files(self.project)]
        self.assertEqual(sorted(kept), sorted(files))

    def test_staging_preserves_autoload_and_disables_only_editor_plugins(self):
        original = '[autoload]\nRuntime="*res://runtime.gd"\n[editor_plugins]\nenabled=PackedStringArray("plugin.cfg")\n[rendering]\nrenderer="gl_compatibility"\n'
        path = self.write('project.godot', original)
        stage = self.root / 'stage'
        release.stage_project(self.root, stage, [path])
        self.assertEqual(original, path.read_text())
        staged = (stage / 'project.godot').read_text()
        self.assertNotIn('editor_plugins', staged)
        self.assertIn('Runtime=', staged)
        self.assertIn('[rendering]', staged)

    def test_missing_or_incomplete_save_is_not_a_success(self):
        with self.assertRaises(ValueError):
            release.verify_save(self.root)
        save = self.root / 'pilgrimage_world.json'
        save.write_text('{}')
        with self.assertRaises(ValueError):
            release.verify_save(self.root)
        save.write_text(json.dumps({'current_region': 'ch01', 'regions': {'ch01': {}}}))
        self.assertEqual(save, release.verify_save(self.root))

    def test_smoke_requires_real_resume_and_isolated_user_data(self):
        def fake_engine(command, log, *, timeout, cwd, env):
            self.assertEqual([str(self.root / 'game'), '--headless', '--verbose', '--max-fps', '60', '--quit-after', '1200'], command)
            self.assertEqual(5, timeout)
            self.assertNotIn('--path', command)
            self.assertNotIn('--script', command)
            user_data = Path(env['XDG_DATA_HOME'])
            self.assertEqual(str(user_data), env['APPDATA'])
            user_data.mkdir(exist_ok=True)
            save = user_data / 'pilgrimage_world.json'
            if not save.exists():
                save.write_text(json.dumps({'current_region': 'ch01', 'regions': {'ch01': {}}, 'story_flags': {}}))
            else:
                # Match production's atomic save writeback after loading World.
                contents = save.read_text()
                save.with_name(save.name + '.bak').write_text(contents)
                save.write_text(json.dumps(json.loads(contents)))
            return ''
        with patch.object(release, 'run_checked', side_effect=fake_engine) as runner:
            release.smoke_package(self.root / 'game', self.root, 5)
            self.assertEqual(2, runner.call_count)

    def test_verbose_exit_resource_error_still_fails_without_retry(self):
        checked = release.run_checked
        diagnostics = ('WARNING: ObjectDB instances leaked at exit.\n'
                       'Leaked instance: RefCounted:1234\n'
                       'ERROR: 1 resources still in use at exit.\n'
                       'Resource still in use: res://scripts/fixture.gd (GDScript)\n')
        for failing_attempt, calls in [('first-start', 1), ('resume', 2)]:
            with self.subTest(attempt=failing_attempt):
                def fake_engine(command, log, *, timeout, cwd, env):
                    self.assertEqual([str(self.root / 'game'), '--headless', '--verbose', '--max-fps', '60', '--quit-after', '1200'], command)
                    self.assertEqual(5, timeout)
                    if log.stem == failing_attempt:
                        # Use the real strict gate with a successful OS exit.
                        return checked([sys.executable, '-c', f'print({diagnostics!r}, end="")'],
                                       log, timeout=timeout, cwd=cwd, env=env)
                    user_data = Path(env['XDG_DATA_HOME'])
                    user_data.mkdir(exist_ok=True)
                    (user_data / 'pilgrimage_world.json').write_text(json.dumps(
                        {'current_region': 'ch01', 'regions': {'ch01': {}}, 'story_flags': {}}))
                    return ''
                with patch.object(release, 'run_checked', side_effect=fake_engine) as runner:
                    with self.assertRaisesRegex(RuntimeError, r'exit=0, engine_errors=1'):
                        release.smoke_package(self.root / 'game', self.root, 5)
                    self.assertEqual(calls, runner.call_count)
                self.assertEqual(diagnostics, (self.root / f'{failing_attempt}.log').read_text())

    def test_passive_second_boot_cannot_claim_resume(self):
        def passive_boot(command, log, *, timeout, cwd, env):
            user_data = Path(env['XDG_DATA_HOME'])
            user_data.mkdir(exist_ok=True)
            save = user_data / 'pilgrimage_world.json'
            if not save.exists():
                save.write_text(json.dumps({'current_region': 'ch01', 'regions': {'ch01': {}}, 'story_flags': {}}))
                # A leftover first-start backup must not count as resume evidence.
                save.with_name(save.name + '.bak').write_text(save.read_text())
        with patch.object(release, 'run_checked', side_effect=passive_boot):
            with self.assertRaisesRegex(ValueError, 'write back'):
                release.smoke_package(self.root / 'game', self.root, 5)

    def test_unrelated_backup_cannot_claim_resume(self):
        def wrong_backup(command, log, *, timeout, cwd, env):
            user_data = Path(env['XDG_DATA_HOME'])
            user_data.mkdir(exist_ok=True)
            save = user_data / 'pilgrimage_world.json'
            if not save.exists():
                save.write_text(json.dumps({'current_region': 'ch01', 'regions': {'ch01': {}}, 'story_flags': {}}))
            else:
                save.with_name(save.name + '.bak').write_text(json.dumps({'story_flags': {}}))
        with patch.object(release, 'run_checked', side_effect=wrong_backup):
            with self.assertRaisesRegex(ValueError, 'back up'):
                release.smoke_package(self.root / 'game', self.root, 5)

    def test_false_resume_rejected(self):
        def reset_save(command, log, *, timeout, cwd, env):
            user_data = Path(env['XDG_DATA_HOME'])
            user_data.mkdir(exist_ok=True)
            (user_data / 'pilgrimage_world.json').write_text(json.dumps({'current_region': 'ch01', 'regions': {'ch01': {}}, 'story_flags': {}}))
        with patch.object(release, 'run_checked', side_effect=reset_save):
            with self.assertRaisesRegex(ValueError, 'resume probe'):
                release.smoke_package(self.root / 'game', self.root, 5)

    def test_license_tree_and_checksums_travel_with_binary(self):
        (self.root / 'LICENSE').write_text('project license')
        (self.root / 'THIRD_PARTY_NOTICES.md').write_text('attribution')
        self.write('assets/fonts/OFL.txt', 'font license')
        self.write('assets/audio/sfx/kenney/License.txt', 'CC0')
        self.write('addons/MetroidvaniaSystem/LICENSE.txt', 'plugin license')
        self.assertEqual(5, len(release.notice_files(self.root)))
        payload = self.root / 'candidate'
        payload.mkdir()
        binary = payload / 'game'
        binary.write_bytes(b'candidate-binary')
        binary.chmod(0o755)
        archive = self.root / 'candidate.zip'
        release.package_directory(payload, archive, {'source_commit': 'test'})
        with zipfile.ZipFile(archive) as z:
            manifest = json.loads(z.read('candidate/BUILD_MANIFEST.json'))
            self.assertEqual(hashlib.sha256(binary.read_bytes()).hexdigest(), manifest['files']['game']['sha256'])
            self.assertEqual(b'candidate-binary', z.read('candidate/game'))
            if sys.platform != 'win32':
                self.assertTrue((z.getinfo('candidate/game').external_attr >> 16) & 0o111)
        self.assertEqual(release.sha256(archive), (self.root / 'candidate.zip.sha256').read_text().split()[0])
        unpacked = release.unpack_verified_package(archive, self.root / 'unpacked')
        self.assertEqual(b'candidate-binary', (unpacked / 'game').read_bytes())
        if sys.platform != 'win32':
            self.assertTrue((unpacked / 'game').stat().st_mode & 0o111)

    def candidate(self):
        payload = self.root / 'candidate'
        payload.mkdir()
        (payload / 'game').write_bytes(b'candidate-binary')
        archive = self.root / 'candidate.zip'
        release.package_directory(payload, archive, {'source_commit': 'test'})
        return archive

    def refresh_checksum(self, archive):
        archive.with_name(archive.name + '.sha256').write_text(f'{release.sha256(archive)}  {archive.name}\n')

    def test_corrupted_archive_rejected_before_unpacking(self):
        archive = self.candidate()
        with archive.open('ab') as file:
            file.write(b'corrupted')
        with self.assertRaisesRegex(ValueError, 'ZIP checksum'):
            release.unpack_verified_package(archive, self.root / 'unpacked')
        self.assertFalse((self.root / 'unpacked').exists())

    def test_corrupted_payload_rejected_even_with_matching_zip_checksum(self):
        archive = self.candidate()
        with zipfile.ZipFile(archive) as file:
            members = {name: file.read(name) for name in file.namelist()}
        members['candidate/game'] = b'corrupted-binary'
        with zipfile.ZipFile(archive, 'w') as file:
            for name, data in members.items():
                file.writestr(name, data)
        self.refresh_checksum(archive)
        with self.assertRaisesRegex(ValueError, 'payload checksum'):
            release.unpack_verified_package(archive, self.root / 'unpacked')
        self.assertFalse((self.root / 'unpacked').exists())

    def test_unlisted_or_escaping_archive_member_rejected(self):
        archive = self.candidate()
        original = archive.read_bytes()
        for name in ['candidate/extra', 'candidate/../escaped', 'candidate/\\escaped']:
            with self.subTest(name=name):
                archive.write_bytes(original)
                with zipfile.ZipFile(archive, 'a') as file:
                    file.writestr(name, b'not-in-manifest')
                self.refresh_checksum(archive)
                with self.assertRaises(ValueError):
                    release.unpack_verified_package(archive, self.root / 'unpacked')
                self.assertFalse((self.root / 'unpacked').exists())

    def test_invalid_timeout_rejected_before_source_scan(self):
        for value in ['nan', 'inf', '0', '-1']:
            with self.subTest(value=value), patch.object(sys, 'argv', ['build_release.py', '--timeout', value]):
                with self.assertRaises(SystemExit) as error:
                    release.main()
                self.assertEqual(2, error.exception.code)


class ReleaseWorkflowTests(unittest.TestCase):
    def branches(self, event):
        workflow = (Path(__file__).resolve().parents[1] /
                    '.github/workflows/release-candidate.yml').read_text(encoding='utf-8')
        section = workflow.split(f'  {event}:\n', 1)[1].split('\n  push:', 1)[0].split('\n\n', 1)[0]
        # Branch filters are kept inline; tolerate explanatory comments above them.
        match = re.search(r'branches: \[([^\]]+)\]', section)
        self.assertIsNotNone(match)
        return [value.strip().strip("'\"") for value in match.group(1).split(',')]

    def test_pull_requests_cover_main_and_stacked_upgrade_bases(self):
        patterns = self.branches('pull_request')
        for branch in ('main', 'codex/w00-catalog-modern-integration',
                       'codex/w00-startup-config-modern-integration',
                       'codex/w00-private-save-modern-integration',
                       'codex/u04-map-pins-modern-integration',
                       'codex/death-respawn-presentation'):
            with self.subTest(branch=branch):
                self.assertTrue(any(fnmatch.fnmatchcase(branch, pattern) for pattern in patterns))
        for branch in ('feature/unrelated', 'codex/w00-catalog-experiment', 'codex/death-unrelated', 'release'):
            with self.subTest(branch=branch):
                self.assertFalse(any(fnmatch.fnmatchcase(branch, pattern) for pattern in patterns))

    def test_push_filter_remains_main_only(self):
        self.assertEqual(self.branches('push'), ['main'])


if __name__ == '__main__':
    unittest.main()
