"""Regression checks for frame-fit input currency and base anchoring."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image
import build_creature_frame_fit as fit


class FrameFitInputs(unittest.TestCase):
    def test_atlas_edit_invalidates_identical_manifest(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(fit, "ROOT", Path(folder)):
            atlas = Path(folder) / "godot/atlas.png"
            atlas.parent.mkdir()
            manifest = {"animations": [{"name": "idle", "frames": [{"atlas": "res://atlas.png"}]}]}
            Image.new("RGBA", (2, 2), (20, 30, 40, 255)).save(atlas)
            before = fit.atlas_digests(manifest)
            Image.new("RGBA", (2, 2), (20, 30, 40, 0)).save(atlas)
            self.assertNotEqual(before, fit.atlas_digests(manifest))

    def test_runtime_and_generator_select_same_layers(self):
        source = (fit.ROOT / "godot/scripts/hand_drawn_assets.gd").read_text(encoding="utf-8")
        offsets = [source.index('"' + name + '"') for name in fit.ACTIVE_LAYERS]
        self.assertEqual(offsets, sorted(offsets))
        with tempfile.TemporaryDirectory() as folder:
            for name in fit.ACTIVE_LAYERS:
                (Path(folder) / name).write_text("{}")
            self.assertEqual(fit.active_manifest(Path(folder)).name, fit.ACTIVE_LAYERS[0])

    def test_stationary_base_does_not_move_when_scaled(self):
        alpha = Image.fromarray(np.full((40, 20), 255, dtype=np.uint8))
        frame = {"margin": [12, 30, 0, 0]}
        for motion in ("ground", "stationary"):
            px, py = fit.pivot_of(alpha, frame, [100, 100], fit.is_grounded({"motion": motion}))
            bottom = 30 + 40 - 50
            self.assertEqual(py, bottom)
            self.assertEqual(py + (bottom - py) * 1.15, bottom)
        self.assertFalse(fit.is_grounded({"motion": "flying"}))


if __name__ == "__main__":
    unittest.main()
