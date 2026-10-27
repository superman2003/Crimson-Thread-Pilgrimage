"""A success marker must not conceal a native failure or shutdown leak."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from run_room_reverb_contract import invoke, MARKER, chapter_fixture_source


class RoomReverbRunner(unittest.TestCase):
    def test_result_marker_and_diagnostics(self):
        success = "ROOM_REVERB checks=182 failures=0"
        cases = [
            (success, 0, True),
            (success, 1, False),
            ("", 0, False),
            ("ROOM_REVERB checks=0 failures=0", 0, False),
            ("ROOM_REVERB checks=182 failures=1", 0, False),
            (success + "\nERROR: failed effect", 0, False),
            (success + "\nSCRIPT ERROR: invalid receiver", 0, False),
            (success + "\nUSER ERROR: incomplete retirement", 0, False),
            (success + "\nWARNING: ObjectDB instances leaked at exit", 0, False),
            (success + "\n\x1b[31mERROR: ANSI must not hide this\x1b[0m", 0, False),
        ]
        with tempfile.TemporaryDirectory() as scratch:
            log = Path(scratch) / "native.log"
            for output, code, expected in cases:
                with self.subTest(output=output, code=code), redirect_stdout(StringIO()):
                    command = [sys.executable, "-c",
                               "import sys; print(sys.argv[1]); sys.exit(int(sys.argv[2]))",
                               output, str(code)]
                    self.assertEqual(invoke(command, None, log, MARKER), expected)
                    self.assertIn(output, log.read_text(encoding="utf-8"))

    def test_stderr_is_not_ignored(self):
        with tempfile.TemporaryDirectory() as scratch, redirect_stdout(StringIO()):
            log = Path(scratch) / "native.log"
            command = [sys.executable, "-c",
                       "import sys; print('ROOM_REVERB checks=1 failures=0'); "
                       "print('SCRIPT ERROR: on stderr', file=sys.stderr)"]
            self.assertFalse(invoke(command, None, log, MARKER))
            self.assertIn("SCRIPT ERROR:", log.read_text(encoding="utf-8"))

    def test_timeout_cannot_pass_with_a_partial_success_marker(self):
        with tempfile.TemporaryDirectory() as scratch, redirect_stdout(StringIO()):
            log = Path(scratch) / "native.log"
            error = subprocess.TimeoutExpired("godot", 120, output=b"ROOM_REVERB checks=1 failures=0\n")
            with patch("run_room_reverb_contract.subprocess.run", side_effect=error):
                self.assertFalse(invoke(["godot"], None, log, MARKER))
            self.assertIn("exceeded 120 seconds", log.read_text(encoding="utf-8"))

    def test_main_fixture_uses_complete_production_methods(self):
        generated = chapter_fixture_source()
        self.assertIn("const REVERB_TIERS", generated)
        self.assertIn("const CHAPTER_REVERB_TIER", generated)
        self.assertIn("func _find_bus_effect(", generated)
        self.assertIn("func _apply_chapter_reverb(", generated)
        self.assertNotIn("func duck_bgm(", generated)
        self.assertNotIn("func _build_audio(", generated)

    def test_missing_production_method_is_a_hard_error(self):
        with patch("run_room_reverb_contract.Path.read_text", return_value="extends Node\n"):
            with self.assertRaises(ValueError):
                chapter_fixture_source()


if __name__ == "__main__":
    unittest.main()

