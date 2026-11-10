import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
import validate_runtime_asset_dependencies as check
import audit_character_animation_assets as production


class DependencyRegression(unittest.TestCase):
    def test_missing_png_and_lfs_pointer_cannot_count_as_loaded_art(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/"godot/assets").mkdir(parents=True)
            pointer=root/"godot/assets/pointer.png"
            pointer.write_bytes(check.POINTER+b"\noid sha256:0000\nsize 100\n")
            tree=check.WorkingAssets(root)
            self.assertIsNone(tree.png_size("godot/assets/missing.png"))
            self.assertIsNone(tree.png_size("godot/assets/pointer.png"))
            self.assertIn("godot/assets/missing.png",tree.missing)
            self.assertIn("godot/assets/pointer.png",tree.unresolved_lfs)

    def test_atlas_crop_and_logical_canvas_are_independent_checks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);folder=root/"godot/assets";folder.mkdir(parents=True)
            Image.new("RGBA",(8,8),(255,255,255,255)).save(folder/"atlas.png")
            spec={"canvas":[8,8],"animations":[{"name":"idle","frames":[{"atlas":"res://assets/atlas.png","region":[6,0,4,8],"margin":[0,0,0,0]}]}]}
            (folder/"manifest.json").write_text(json.dumps(spec),encoding="utf-8")
            errors=[];production.inspect_manifest(check.WorkingAssets(root),"godot/assets/manifest.json",errors)
            check.check_canvas(spec,"manifest",errors)
            self.assertTrue(any("region outside" in e for e in errors))
            self.assertTrue(any("logical frame size" in e for e in errors))

    def test_current_multi_attack_commands_resolve_their_own_phases(self):
        clips={name:{"frame_refs":12} for name in ["jab","jab_windup","jab_recover","sweep","sweep_windup","sweep_recover"]}
        for attack in ["jab","sweep"]:
            row=production.resolve_attack({"id":attack,"windup":.2,"active":.3,"recover":.4},clips)
            self.assertEqual(row["clips"],[attack+"_windup",attack,attack+"_recover"])
            self.assertEqual(row["frame_refs"],[12,12,12])

    def test_templates_and_method_documentation_are_not_literal_filenames(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name in ["godot/project.godot","godot/scenes/World.tscn","godot/scenes/Main.tscn"]:
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text("",encoding="utf-8")
            p=root/"godot/data/paths.json";p.parent.mkdir(parents=True)
            p.write_text(json.dumps({"template":"res://data/%s.json", "method":"res://scripts/example.gd::run", "actual":"res://assets/missing.png"}),encoding="utf-8")
            report=check.resource_closure(root)
            self.assertEqual(report["missing"],["godot/assets/missing.png"])
            self.assertEqual(report["dynamic_templates"],["res://data/%s.json"])


if __name__ == "__main__":
    unittest.main()
