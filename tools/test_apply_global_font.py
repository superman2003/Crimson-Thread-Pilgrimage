import importlib.util
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('font_switch',Path(__file__).with_name('apply_global_font.py'))
switch=importlib.util.module_from_spec(spec)
spec.loader.exec_module(switch)

class FontSwitchTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)
        self.write('godot/project.godot','config_version=5\n\n[gui]\n\ntheme/default_font_multichannel_signed_distance_field=true\n\n[rendering]\n')
        self.write('godot/scripts/ui.gd','const FONT=preload("res://assets/fonts/NotoSansSC.ttf")\nvar sign=ThemeDB.fallback_font\n')
        self.write('src/styles.css',':root { font-family: sans-serif; }\n')
        self.write('src/main.js','ctx.font = "800 22px Microsoft YaHei, sans-serif";\n')
        self.font=self.root/'source.otf'
        self.font.write_bytes(b'OTTO' + b'fixture-font')
    def tearDown(self):self.temp.cleanup()
    def write(self,path,text):
        target=self.root/path
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(text,encoding='utf-8')
    def test_apply_and_repeated_apply_are_idempotent(self):
        self.assertEqual(switch.apply(self.root,self.font),0)
        backup=(self.root/'tmp/font_switch_backups/latest.json').read_bytes()
        self.assertEqual(switch.apply(self.root,self.font),0)
        self.assertEqual((self.root/'tmp/font_switch_backups/latest.json').read_bytes(),backup)
        project=(self.root/'godot/project.godot').read_text()
        self.assertEqual(project.count('[gui]'),1)
        self.assertIn('theme/default_font_multichannel_signed_distance_field=true',project)
        self.assertEqual(project.count('GlobalTypography='),1)
        self.assertNotIn('theme/custom_font=',project)
    def test_restore_reproduces_exact_original_bytes(self):
        original={p.relative_to(self.root):p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        switch.apply(self.root,self.font)
        self.assertEqual(switch.restore(self.root),0)
        for name,data in original.items():self.assertEqual((self.root/name).read_bytes(),data)
        self.assertFalse((self.root/'godot/assets/fonts/GlobalTypeface.otf').exists())
        self.assertFalse((self.root/'godot/assets/ui/global_typeface.tres').exists())
        self.assertFalse((self.root/'godot/scripts/global_typography.gd').exists())
    def test_restore_does_not_overwrite_later_edits_or_partially_restore(self):
        switch.apply(self.root,self.font)
        edited=self.root/'godot/scripts/ui.gd'
        edited.write_text(edited.read_text()+'# later gameplay edit\n')
        self.assertEqual(switch.restore(self.root),1)
        self.assertIn('# later gameplay edit',edited.read_text())
        self.assertTrue((self.root/'godot/assets/fonts/GlobalTypeface.otf').exists())
        self.assertEqual(switch.check(self.root),0)
    def test_check_finds_new_font_bypasses(self):
        switch.apply(self.root,self.font)
        self.write('godot/scripts/new_label.gd','var font=preload("res://assets/fonts/OtherFont.ttf")\n')
        self.assertEqual(switch.check(self.root),1)
        self.assertEqual(switch.apply(self.root,self.font),0)
        self.assertIn(switch.GLOBAL,(self.root/'godot/scripts/new_label.gd').read_text())
    def test_png_is_not_accepted_as_a_font(self):
        self.font.write_bytes(b'\x89PNG\r\n')
        with self.assertRaises(ValueError):switch.apply(self.root,self.font)
        self.assertFalse((self.root/'tmp/font_switch_backups').exists())
    def test_backup_path_cannot_escape_workspace(self):
        with self.assertRaises(ValueError):switch.local(self.root,'../outside.gd')

if __name__=='__main__':unittest.main()
