"""Round-trip tests for the onion-skin in-between pipeline with a fake image generator.

The fake generator draws a midpoint where the onion skins say it belongs, then
moves and resizes the whole sheet the way a model re-lays out its output. The
pipeline must recover the runtime placement exactly, reject the failure modes
the v8 layer shipped with, and build a layer the scale gate accepts.
"""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

import numpy as np
from PIL import Image, ImageDraw

import audit_motion_scale_consistency as gate
import motion_onion as onion

KIND = "wax_bee"
SOURCE = onion.CREATURES


def fake_generation(job, path, offset=(6, 0), swell=None, drop_marker=False, cross=None, copy_slot=None,
                    sheet_size=(1600, 1066), shift=(14, -9)):
    """A generated sheet: one midpoint per cell, then the whole image moved and resized."""
    k, canvas = job["scale"], job["canvas"]
    sheet = Image.new("RGBA", onion.SHEET, (0, 0, 0, 0))
    if not drop_marker:
        onion.draw_markers(sheet)
    for slot, edge in enumerate(job["edges"]):
        image, x, y = onion.placed(edge["left"])
        dx = 0 if slot == copy_slot else offset[0]
        factor = swell if swell and slot == 0 else 1.0
        size = (round(image.width * k * factor), round(image.height * k * factor))
        scaled = image.resize(size, Image.Resampling.LANCZOS)
        ox, oy = onion.canvas_origin(slot, canvas, k)
        # A swollen pose keeps its feet where they were, as the v8 frames did.
        px = ox + (x + dx) * k - (size[0] - image.width * k) / 2
        py = oy + y * k - (size[1] - image.height * k)
        if slot == cross:
            px = (slot % onion.GRID[0]) * onion.CELL - 20
        sheet.alpha_composite(scaled, (round(px), round(py)))
    sx, sy = sheet_size[0] / onion.SHEET[0], sheet_size[1] / onion.SHEET[1]
    moved = sheet.transform(sheet_size, Image.Transform.AFFINE, (1 / sx, 0, -shift[0] / sx, 0, 1 / sy, -shift[1] / sy),
                            resample=Image.Resampling.BICUBIC)
    moved.save(path)
    return path


class OnionPipeline(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.creatures = self.tmp / "creatures"
        shutil.copytree(SOURCE / KIND, self.creatures / KIND)
        self.saved = onion.REQUEST, onion.CREATURES, gate.CREATURES
        onion.REQUEST = self.tmp / "request"
        onion.CREATURES = gate.CREATURES = self.creatures
        onion._atlases.clear()

    def tearDown(self):
        onion.REQUEST, onion.CREATURES, gate.CREATURES = self.saved
        onion._atlases.clear()
        shutil.rmtree(self.tmp)

    def job(self, animation="idle", batch=None):
        return onion.prepare(KIND, animation, batch)

    def spec(self):
        return onion.load_spec(KIND)

    def test_onion_sheet_keeps_one_scale_and_real_positions(self):
        jobs = self.job()
        self.assertTrue(all(j["scale"] == onion.scale_for(j["canvas"]) for j in jobs))
        with Image.open(onion.ROOT / jobs[0]["onion"]) as sheet:
            self.assertEqual(sheet.size, onion.SHEET)
        more = self.job("walk")
        self.assertEqual({j["scale"] for j in jobs + more}, {jobs[0]["scale"]}, "every sheet of a character shares K")
        with self.assertRaises(ValueError):
            self.job()

    def test_registration_recovers_runtime_placement_after_relayout(self):
        job = self.job()[0]
        path = fake_generation(job, self.tmp / "out.png")
        self.assertEqual(onion.deliver(job["id"], path), 0)
        accepted = self.spec()["accepted"]
        self.assertEqual(len(accepted), len(job["edges"]))
        for edge in job["edges"]:
            row = accepted[f"{edge['animation']}#{edge['after']}"]
            image, x, y = onion.placed(edge["left"])
            ink = Image.fromarray(((np.asarray(image)[:, :, 3] > onion.INK_ALPHA) * 255).astype(np.uint8)).getbbox()
            expected = [x + ink[0] + 6, y + ink[1]]
            self.assertLessEqual(max(abs(a - b) for a, b in zip(row["margin_xy"], expected)), 2, row)
            self.assertLess(abs(row["metrics"]["area_ratio"] - 1), 0.25)

    def test_swollen_pose_is_rejected_and_replanned(self):
        job = self.job()[0]
        onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png", swell=1.4))
        attempt = self.spec()["jobs"][0]["attempts"][-1]
        first = attempt["cells"][0]
        self.assertFalse(first["accepted"])
        self.assertTrue(any("body area" in r for r in first["reasons"]), first["reasons"])
        self.assertTrue(all(c["accepted"] for c in attempt["cells"][1:]))
        retried = onion.retry(KIND)
        self.assertEqual([(e["animation"], e["after"]) for e in retried[0]["edges"]],
                         [(first["animation"], first["after"])], "only the failed transition is redrawn")
        onion.deliver(retried[0]["id"], fake_generation(retried[0], self.tmp / "again.png"))
        self.assertEqual(onion.pending(KIND), [])

    def test_missing_marker_rejects_the_whole_sheet(self):
        job = self.job()[0]
        self.assertEqual(onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png", drop_marker=True)), 1)
        self.assertIn("marker", self.spec()["jobs"][0]["attempts"][-1]["error"])
        self.assertNotIn("accepted", self.spec())

    def test_border_crossing_and_copied_poses_are_rejected(self):
        job = self.job()[0]
        onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png", cross=1, copy_slot=2))
        cells = self.spec()["jobs"][0]["attempts"][-1]["cells"]
        self.assertIn("figure crosses the cell border", cells[1]["reasons"])
        self.assertTrue(any("copies the earlier pose" in r for r in cells[2]["reasons"]), cells[2]["reasons"])

    def test_distorted_sheet_is_rejected(self):
        job = self.job()[0]
        path = fake_generation(job, self.tmp / "out.png", sheet_size=(1700, 1024))
        self.assertEqual(onion.deliver(job["id"], path), 1)
        self.assertIn("distorted", self.spec()["jobs"][0]["attempts"][-1]["error"])

    def test_build_inserts_a_pose_after_each_old_one_and_passes_the_gate(self):
        jobs = self.job()
        for i, job in enumerate(jobs):
            onion.deliver(job["id"], fake_generation(job, self.tmp / f"out{i}.png"))
        base = onion.read(onion.first_layer(KIND, onion.BASELINE_LAYERS))
        built = onion.build(KIND)
        old, new = onion.clips_of(base), onion.clips_of(built)
        self.assertEqual(len(new["idle"]["frames"]), 2 * len(old["idle"]["frames"]))
        self.assertEqual(new["idle"]["fps"], 2 * old["idle"]["fps"])
        self.assertEqual(new["idle"]["frames"][0::2], old["idle"]["frames"], "every original pose is kept in order")
        self.assertEqual(new["walk"], old["walk"], "clips without a full set stay untouched")
        onion.build(KIND, check=True)
        checked, findings = gate.audit(kinds=[KIND])
        self.assertEqual([f for f in findings if f["gated"]], [])
        self.assertTrue(onion.preview(KIND, "idle", out=self.tmp / "idle.gif").exists())

    def test_build_over_a_doubled_layer_replaces_only_redrawn_midpoints(self):
        base = onion.read(onion.first_layer(KIND, onion.BASELINE_LAYERS))
        doubled = json.loads(json.dumps(base))
        for clip in onion.clips_of(doubled).values():
            clip["frames"] = [f for frame in clip["frames"] for f in (frame, frame)]
            clip["fps"] *= 2
        onion.write(self.creatures / KIND / "motion_v8_manifest.json", doubled)
        job = self.job()[0]
        onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png"))
        built = onion.clips_of(onion.build(KIND, over="motion_v8_manifest.json"))
        frames = built["idle"]["frames"]
        for edge in job["edges"]:
            self.assertIn("motion_onion_", frames[2 * edge["after"] + 1]["atlas"])
            self.assertEqual(frames[2 * edge["after"]], onion.clips_of(doubled)["idle"]["frames"][2 * edge["after"]])
        self.assertEqual(built["walk"], onion.clips_of(doubled)["walk"])

    def test_changed_accepted_drawing_breaks_the_build(self):
        job = self.job()[0]
        onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png"))
        row = next(iter(self.spec()["accepted"].values()))
        path = onion.ROOT / row["drawing"]
        image = Image.open(path).convert("RGBA")
        ImageDraw.Draw(image).point((1, 1), fill=(255, 0, 0, 255))
        image.save(path)
        with self.assertRaises(ValueError):
            onion.build(KIND)

    def test_replacement_keeps_world_position_when_v8_canvas_is_padded(self):
        base = onion.read(onion.first_layer(KIND, onion.BASELINE_LAYERS))
        doubled = json.loads(json.dumps(base))
        padding = [12, 20]
        doubled["canvas"] = [size + 2 * pad for size, pad in zip(base["canvas"], padding)]
        for clip in onion.clips_of(doubled).values():
            for frame in clip["frames"]:
                frame["margin"] = [frame["margin"][0] + padding[0], frame["margin"][1] + padding[1],
                                   frame["margin"][2] + 2 * padding[0], frame["margin"][3] + 2 * padding[1]]
            clip["frames"] = [frame for frame in clip["frames"] for _ in range(2)]
            clip["fps"] *= 2
        onion.write(self.creatures / KIND / "motion_v8_manifest.json", doubled)
        job = self.job()[0]
        onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png"))
        accepted = self.spec()["accepted"]
        built = onion.build(KIND, over="motion_v8_manifest.json")
        frames = onion.clips_of(built)["idle"]["frames"]
        for edge in job["edges"]:
            after = edge["after"]
            margin = accepted[f"idle#{after}"]["margin_xy"]
            for facing in [-1, 1]:
                before = [(margin[0] - base["canvas"][0] / 2) * facing, margin[1] - base["canvas"][1] / 2]
                replacement = frames[2 * after + 1]["margin"]
                actual = [(replacement[0] - built["canvas"][0] / 2) * facing, replacement[1] - built["canvas"][1] / 2]
                self.assertEqual(actual, before, "transparent canvas padding must not move the new pose")
            self.assertEqual(frames[2 * after], onion.clips_of(doubled)["idle"]["frames"][2 * after])
        self.assertEqual(onion.clips_of(built)["walk"], onion.clips_of(doubled)["walk"])
        onion.build(KIND, over="motion_v8_manifest.json", check=True)

    def test_replacement_rejects_a_different_original_pose(self):
        base = onion.read(onion.first_layer(KIND, onion.BASELINE_LAYERS))
        doubled = json.loads(json.dumps(base))
        for clip in onion.clips_of(doubled).values():
            clip["frames"] = [frame for frame in clip["frames"] for _ in range(2)]
            clip["fps"] *= 2
        frames = onion.clips_of(doubled)["idle"]["frames"]
        frames[0] = json.loads(json.dumps(frames[0]))
        frames[0]["margin"][0] += 5
        onion.write(self.creatures / KIND / "motion_v8_manifest.json", doubled)
        job = self.job()[0]
        onion.deliver(job["id"], fake_generation(job, self.tmp / "out.png"))
        with self.assertRaisesRegex(ValueError, "original pose"):
            onion.build(KIND, over="motion_v8_manifest.json")


class ScaleGate(unittest.TestCase):
    def test_gate_self_test(self):
        self.assertEqual(gate.self_test(), 0)

    def test_gated_layers_cover_onion_and_v8(self):
        self.assertIn("motion_onion_", gate.GATED_ATLAS_MARKERS)
        self.assertEqual(gate.ACTIVE_LAYERS[:2], ["motion_transition_manifest.json", onion.LAYER])
        self.assertIn("motion_transition_", gate.GATED_ATLAS_MARKERS)
        self.assertEqual(gate.ACTIVE_LAYERS[3:], onion.BASELINE_LAYERS)


if __name__ == "__main__":
    unittest.main()
