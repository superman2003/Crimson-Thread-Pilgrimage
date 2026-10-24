#!/usr/bin/env python3
"""Negative fixtures for tools/audit_export_contents.py on a throwaway project."""
from __future__ import annotations
import sys
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_export_contents import audit

PRESET = '''[preset.0]

name="Linux x86_64"
export_filter="all_resources"
exclude_filter="{excludes}"

[preset.0.options]
'''


def project(root: Path, excludes: str, files: dict[str, str]) -> None:
    godot = root / 'godot'
    (godot / 'scripts').mkdir(parents=True)
    (godot / 'scenes').mkdir()
    (godot / 'shaders').mkdir()
    (godot / 'project.godot').write_text('[application]\nrun/main_scene="res://scenes/World.tscn"\n\n[autoload]\n\nKit="*res://scripts/kit.gd"\n')
    (godot / 'export_presets.cfg').write_text(PRESET.format(excludes=excludes))
    base = {
        'scenes/World.tscn': '[ext_resource type="Script" path="res://scripts/world.gd" id="1"]\n',
        'scripts/world.gd': 'extends Node\nconst S := preload("res://shaders/glow.gdshader")\nvar d := Director.new()\n',
        'scripts/director.gd': 'class_name Director\nextends RefCounted\n',
        'scripts/kit.gd': 'extends Node\n',
        'shaders/glow.gdshader': 'shader_type canvas_item;\n',
        'scripts/route_playback.gd': 'extends SceneTree\nconst W := preload("res://scripts/world.gd")\n',
    }
    base.update(files)
    for name, text in base.items():
        (godot / name).parent.mkdir(parents=True, exist_ok=True)
        (godot / name).write_text(text)


class ExportAuditTests(unittest.TestCase):
    def run_audit(self, excludes: str, files: dict[str, str] | None = None) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            project(Path(directory), excludes, files or {})
            return audit(Path(directory))

    def test_clean_project_passes_with_class_name_and_shader(self):
        report = self.run_audit('scripts/*_playback.gd')
        self.assertEqual(report['errors'], [])
        self.assertIn('res://scripts/director.gd', report['reachable'])

    def test_shipped_replay_is_rejected(self):
        report = self.run_audit('')
        self.assertIn('Linux x86_64: development-only file shipped: res://scripts/route_playback.gd', report['errors'])

    def test_excluding_runtime_code_is_rejected(self):
        report = self.run_audit('scripts/*_playback.gd,scripts/director.gd')
        self.assertIn('Linux x86_64: runtime file excluded from export: res://scripts/director.gd', report['errors'])

    def test_missing_reference_and_dynamic_script_path_are_rejected(self):
        report = self.run_audit('scripts/*_playback.gd', {
            'scripts/kit.gd': 'extends Node\nconst G := preload("res://scripts/gone.gd")\nfunc f(n): return load("res://scripts/%s.gd" % n)\n'})
        self.assertIn('missing runtime reference: res://scripts/gone.gd', report['errors'])
        self.assertTrue(any('built dynamically' in error and 'kit.gd' in error for error in report['errors']))

    def test_all_reachable_resource_types_are_checked_for_exclusion(self):
        for path, contents in {
            'data/runtime.json': '{}', 'materials/main.tres': '[gd_resource]',
            'images/hero.png': 'binary leaf', 'audio/alarm.ogg': 'binary leaf',
            'fonts/hero.otf': 'binary leaf', 'shaders/include.gdshaderinc': '// include',
        }.items():
            with self.subTest(path=path):
                report = self.run_audit('scripts/*_playback.gd,' + path, {
                    'scripts/kit.gd': f'extends Node\nconst ASSET = "res://{path}"\n', path: contents})
                self.assertIn(f'Linux x86_64: runtime file excluded from export: res://{path}', report['errors'])
                self.assertIn('res://' + path, report['reachable_resources'])

    def test_shader_is_not_omitted_from_exclusion_check(self):
        report = self.run_audit('scripts/*_playback.gd,shaders/*')
        self.assertIn('Linux x86_64: runtime file excluded from export: res://shaders/glow.gdshader', report['errors'])

    def test_shader_includes_are_followed(self):
        report = self.run_audit('scripts/*_playback.gd', {
            'shaders/glow.gdshader': '#include "res://shaders/missing.gdshaderinc"\n'})
        self.assertIn('missing runtime reference: res://shaders/missing.gdshaderinc', report['errors'])

    def test_missing_asset_is_rejected(self):
        report = self.run_audit('scripts/*_playback.gd', {
            'scripts/kit.gd': 'extends Node\nconst ICON = "res://images/missing.png"\n'})
        self.assertIn('missing runtime reference: res://images/missing.png', report['errors'])

    def test_binary_asset_bytes_are_not_scanned_as_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project(root, 'scripts/*_playback.gd', {'scripts/kit.gd': 'const ICON = "res://images/icon.png"'})
            icon = root / 'godot/images/icon.png'
            icon.parent.mkdir()
            icon.write_bytes(b'\x89PNG\xffres://scripts/not_a_dependency.gd')
            self.assertEqual(audit(root)['errors'], [])

    def test_filters_match_godot_case_prefix_and_whitespace(self):
        for pattern in ['  scripts/*_playback.gd  ', 'res://scripts/*_playback.gd', 'SCRIPTS/*_PLAYBACK.GD']:
            with self.subTest(pattern=pattern):
                self.assertEqual(self.run_audit(pattern)['errors'], [])

    def test_filter_question_mark_does_not_match_dot(self):
        report = self.run_audit('scripts/*_playback.gd,shaders/glow?gdshader')
        self.assertEqual(report['errors'], [])
        report = self.run_audit('scripts/route?playback.gd')
        self.assertEqual(report['errors'], [])

    def test_filter_brackets_are_literal_not_python_character_classes(self):
        report = self.run_audit('scripts/[r]*_playback.gd')
        self.assertIn('Linux x86_64: development-only file shipped: res://scripts/route_playback.gd', report['errors'])

    def test_invalid_presets_never_pass_silently(self):
        clean = PRESET.format(excludes='scripts/*_playback.gd')
        cases = {
            'empty': '', 'options_only': '[preset.0.options]\n',
            'missing_name': clean.replace('name="Linux x86_64"', ''),
            'missing_excludes': clean.replace('exclude_filter="scripts/*_playback.gd"', ''),
            'missing_mode': clean.replace('export_filter="all_resources"', ''),
            'empty_name': clean.replace('Linux x86_64', ''),
            'unquoted_name': clean.replace('"Linux x86_64"', 'Linux'),
            'non_string_filter': clean.replace('"scripts/*_playback.gd"', '123'),
            'duplicate_name': clean + clean.replace('preset.0', 'preset.1'),
            'duplicate_section': clean + clean,
            'bad_header': '[preset.0\nname="Linux"\n',
            'unknown_section': clean + '\n[preset.wrong]\n',
            'bad_second_preset': clean + '\n[preset.1]\nname="Windows"\n',
        }
        for mode in ['selected_scenes', 'selected_resources', 'exclude_selected_resources', 'customized']:
            cases[mode] = clean.replace('all_resources', mode)
        for label, text in cases.items():
            with self.subTest(case=label), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                project(root, 'scripts/*_playback.gd', {})
                (root / 'godot/export_presets.cfg').write_text(text)
                report = audit(root)
                self.assertTrue(report['errors'], label)
                self.assertIn('invalid audit configuration:', report['errors'][0])

    def test_valid_multiple_presets_are_all_audited(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project(root, 'scripts/*_playback.gd', {})
            cfg = root / 'godot/export_presets.cfg'
            second = PRESET.format(excludes='scripts/*_playback.gd,shaders/*').replace('preset.0', 'preset.1').replace('Linux x86_64', 'Windows x86_64')
            cfg.write_text(cfg.read_text() + second)
            report = audit(root)
            self.assertEqual(len(report['presets']), 2)
            self.assertEqual(report['presets']['Linux x86_64']['excluded_runtime'], [])
            self.assertIn('res://shaders/glow.gdshader', report['presets']['Windows x86_64']['excluded_runtime'])

    def test_explicit_empty_excludes_still_audits_the_preset(self):
        report = self.run_audit('')
        self.assertEqual(len(report['presets']), 1)
        self.assertTrue(report['errors'])

    def test_missing_configuration_and_main_scene_are_reported(self):
        for name in ['export_presets.cfg', 'project.godot']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                project(root, 'scripts/*_playback.gd', {})
                (root / 'godot' / name).unlink()
                self.assertTrue(audit(root)['errors'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project(root, 'scripts/*_playback.gd', {})
            (root / 'godot/project.godot').write_text('[application]\n')
            self.assertIn('main scene', audit(root)['errors'][0])

    def test_cli_returns_failure_and_writes_report_for_empty_presets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project(root, 'scripts/*_playback.gd', {})
            (root / 'godot/export_presets.cfg').write_text('')
            target = root / 'audit.json'
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('audit_export_contents.py')),
                                     '--root', str(root), '--report', str(target)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('EXPORT_AUDIT_FAIL presets=0', result.stdout)
            self.assertTrue(json.loads(target.read_text())['errors'])
            self.assertNotIn('Traceback', result.stderr)


if __name__ == '__main__':
    unittest.main()
