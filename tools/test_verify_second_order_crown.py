"""Reject hash-valid but semantically incomplete or contradictory crown records."""
import gzip
import json
import re
import unittest

import verify_second_order_crown as checker


class CrownProofTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        index = json.loads((checker.ROOT / "evidence_index.json").read_text(encoding="utf-8"))
        cls.original = {row["path"]: gzip.decompress((checker.ROOT / row["archive"]).read_bytes()) for row in index}

    def setUp(self):
        self.files = dict(self.original)

    def change_json(self, path, update):
        value = json.loads(self.files[path])
        update(value)
        self.files[path] = json.dumps(value, ensure_ascii=False).encode("utf-8")

    def rejected(self):
        with self.assertRaises((AssertionError, KeyError)):
            checker.verify_files(self.files)

    def test_current_complete_evidence_passes(self):
        self.assertEqual(checker.verify_files(self.files), [9676, 33704, 5932, 39684])

    def test_missing_initial_formal_restore_is_rejected(self):
        self.files = {name: raw for name, raw in self.files.items() if not name.startswith("native_G_restore02/")}
        self.rejected()

    def test_failed_initial_restore_is_rejected(self):
        self.change_json("native_G_restore02/result.json", lambda x: x.update(passed=False))
        self.rejected()

    def test_restore_nonzero_exit_is_rejected_despite_passed_flag(self):
        self.change_json("native_crown_restore01/result.json", lambda x: x.update(exit=1))
        self.rejected()

    def test_restore_runtime_diagnostics_are_rejected(self):
        for diagnostic in (b"ERROR: injected engine failure\n", b"WARNING: injected exit leak\n"):
            with self.subTest(diagnostic=diagnostic):
                self.files = dict(self.original)
                self.files["native_crown_restore01/runtime.log"] += diagnostic
                self.rejected()

    def test_restore_wrong_lineage_is_rejected(self):
        self.change_json("native_crown_restore01/lineage.json", lambda x: x.update(source_pid=x["source_pid"] + 1))
        self.rejected()

    def test_restore_wrong_command_is_rejected(self):
        self.change_json("native_crown_restore01/command.json", lambda x: x["command"].append("--headless"))
        self.rejected()

    def test_restore_changed_inputs_are_rejected(self):
        self.change_json("native_crown_restore01/source_after.json", lambda x: x.update(injected="changed"))
        self.rejected()

    def test_consistently_rewritten_frame_metric_is_rejected(self):
        folder = "native_crown_west01/"
        old = json.loads(self.files[folder + "result.json"])["completion"]
        new = old.replace("physics_frames=1392", "physics_frames=1393")
        self.change_json(folder + "result.json", lambda x: x.update(completion=new))
        self.files[folder + "runtime.log"] = self.files[folder + "runtime.log"].replace(old.encode(), new.encode())
        self.rejected()

    def test_consistently_rewritten_damage_metric_is_rejected(self):
        folder = "native_crown_west01/"
        self.change_json(folder + "checkpoint_proof.json", lambda x: x.update(damage_events=2))
        proof = json.loads(self.files[folder + "checkpoint_proof.json"])
        log = self.files[folder + "runtime.log"].decode("utf-8")
        log = re.sub(r"^SECOND_ORDER_EARNED .+$", lambda _: "SECOND_ORDER_EARNED " + json.dumps(proof, ensure_ascii=False), log, flags=re.M)
        old = json.loads(self.files[folder + "result.json"])["completion"]
        new = old.replace("damage_events=1", "damage_events=2")
        self.change_json(folder + "result.json", lambda x: x.update(completion=new))
        self.files[folder + "runtime.log"] = log.replace(old, new).encode("utf-8")
        self.rejected()

    def test_missing_calibration_attempt_is_rejected(self):
        self.files = {name: raw for name, raw in self.files.items() if not name.startswith("calibration_west05/")}
        self.rejected()

    def test_changed_calibration_outcome_is_rejected(self):
        self.change_json("calibration_map01/result.json", lambda x: x.update(passed=True, exit=0, errors=[]))
        self.rejected()


if __name__ == "__main__":
    unittest.main()
