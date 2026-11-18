"""Pure checks of the experimental macOS candidate builder (runs on any OS)."""
import configparser
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_macos_candidate as mac

ROOT = Path(__file__).resolve().parents[1]
APP = '绯线巡礼 - 互联世界.app'
GOOD = [APP + '/', APP + '/Contents/Info.plist', APP + '/Contents/MacOS/绯线巡礼 - 互联世界',
        APP + '/Contents/Resources/绯线巡礼 - 互联世界.pck']


class Bundle(unittest.TestCase):
    def test_complete_bundle_has_no_problems(self):
        self.assertEqual(mac.bundle_problems(GOOD), [])

    def test_each_missing_part_is_named(self):
        self.assertIn('no executable under Contents/MacOS', mac.bundle_problems([n for n in GOOD if '/MacOS/' not in n]))
        self.assertIn('no Info.plist', mac.bundle_problems([n for n in GOOD if not n.endswith('Info.plist')]))
        self.assertIn('no game data (.pck) under Contents/Resources', mac.bundle_problems([n for n in GOOD if not n.endswith('.pck')]))

    def test_the_bundle_takes_the_project_name_and_must_stand_alone(self):
        self.assertEqual(mac.bundle_name(GOOD), APP)
        for bad in [GOOD + ['readme.txt'], GOOD + ['Other.app/Contents/Info.plist'], ['game/data.pck'], []]:
            with self.assertRaisesRegex(ValueError, 'exactly one app bundle'):
                mac.bundle_name(bad)

    def test_exactly_one_executable_is_required(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder) / APP
            (app / 'Contents/MacOS').mkdir(parents=True)
            with self.assertRaisesRegex(ValueError, 'exactly one executable'):
                mac.executable_in(app)
            (app / 'Contents/MacOS/Game').write_bytes(b'x')
            self.assertEqual(mac.executable_in(app).name, 'Game')
            (app / 'Contents/MacOS/Other').write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'exactly one executable'):
                mac.executable_in(app)

    def test_universal_texture_import_is_enabled_only_in_a_staged_copy(self):
        with tempfile.TemporaryDirectory() as folder:
            staged = Path(folder) / 'project.godot'
            staged.write_text('[application]\nconfig/name="x"\n\n[rendering]\n\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
            mac.enable_universal_textures(staged)
            mac.enable_universal_textures(staged)
            text = staged.read_text(encoding='utf-8')
            self.assertEqual(text.count('import_etc2_astc=true'), 1)
            self.assertEqual(text.count('[rendering]'), 1)
            self.assertLess(text.index('[rendering]'), text.index('import_etc2_astc'))
            bare = Path(folder) / 'bare.godot'
            bare.write_text('[application]\n', encoding='utf-8')
            mac.enable_universal_textures(bare)
            self.assertIn('[rendering]\n\ntextures/vram_compression/import_etc2_astc=true', bare.read_text(encoding='utf-8'))
        with self.assertRaisesRegex(ValueError, 'source checkout'):
            mac.enable_universal_textures(ROOT / 'godot/project.godot')
        self.assertNotIn('import_etc2_astc', (ROOT / 'godot/project.godot').read_text(encoding='utf-8'))

    def test_only_macos_may_build_it(self):
        with patch.object(mac.sys, 'platform', 'linux'), patch.object(mac.sys, 'argv', ['x', '--engine-root', 'unused']):
            self.assertEqual(mac.main(), 1)


class Preset(unittest.TestCase):
    def setUp(self):
        config = configparser.ConfigParser(interpolation=None, strict=False)
        config.optionxform = str
        config.read_string((ROOT / 'godot/export_presets.cfg').read_text(encoding='utf-8'))
        self.config = config
        self.section = next(s for s in config.sections() if not s.endswith('.options')
                            and config[s].get('name') == f'"{mac.PRESET}"')

    def test_macos_preset_ships_the_same_files_as_linux(self):
        linux = next(s for s in self.config.sections() if self.config[s].get('name') == '"Linux x86_64"')
        for key in ['export_filter', 'include_filter', 'exclude_filter', 'script_export_mode']:
            self.assertEqual(self.config[self.section][key], self.config[linux][key], key)

    def test_architecture_matches_the_shipped_texture_format(self):
        options = self.config[self.section + '.options']
        # The official template ships a universal binary only; it needs both formats.
        self.assertEqual(options['binary_format/architecture'], '"universal"')
        self.assertEqual(options['texture_format/s3tc_bptc'], 'true')
        self.assertEqual(options['texture_format/etc2_astc'], 'true')
        self.assertTrue(options['application/bundle_identifier'].strip('"').count('.') >= 2)


if __name__ == '__main__':
    unittest.main()
