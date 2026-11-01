import importlib.util
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('coverage_check',Path(__file__).with_name('check_font_coverage.py'))
coverage=importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)

class FontCoverageTests(unittest.TestCase):
    def test_committed_font_contains_ui_symbols_and_rare_chinese(self):
        supported=coverage.unicode_cmap(coverage.ROOT/'godot/assets/fonts/GlobalTypeface.otf')
        self.assertTrue(set(map(ord,'创墟迥旌沫笛龘靐齉麤爨灪籲鸞繁體简体↩⊣🔒'))<=supported)
        self.assertGreaterEqual(len(supported),44780)
    def test_new_godot_characters_fail_with_locations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/'godot/data').mkdir(parents=True)
            (root/'godot/data/names.json').write_text('{"name":"笛"}\n',encoding='utf-8')
            (root/'godot/data/title.json').write_text('{"title":"创"}',encoding='utf-8')
            (root/'godot/data/story.json').write_text('{"name":"龘"}',encoding='utf-8')
            # Simulate removal of real glyphs; no system fallback can hide it.
            supported=set(range(32,127))
            missing=coverage.missing_runtime_characters(root,supported)
            self.assertEqual({entry['character'] for entry in missing},{'笛','创','龘'})
            self.assertEqual({entry['path'] for entry in missing},{'godot/data/names.json','godot/data/title.json','godot/data/story.json'})
            self.assertTrue(all(entry['line']==1 for entry in missing))
    def test_unicode_escapes_in_godot_data_are_checked(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/'godot/data').mkdir(parents=True)
            (root/'godot/data/escaped.json').write_text(r'{"title":"\u9f98\ud83e\udea1"}',encoding='utf-8')
            missing=coverage.missing_runtime_characters(root,set(range(32,127)))
            self.assertEqual([entry['codepoint'] for entry in missing],['U+9F98','U+1FAA1'])

if __name__=='__main__':unittest.main()
