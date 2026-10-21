#!/usr/bin/env python3
"""Negative fixtures for tools/audit_export_contents.py on a throwaway project."""
from __future__ import annotations
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_export_contents import audit

PRESET = '''[preset.0]

name="Linux x86_64"
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


if __name__ == '__main__':
    unittest.main()
