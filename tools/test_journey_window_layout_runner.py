"""The owned window contract keeps strict native completion and diagnostics."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import run_journey_window_layout_contract as runner


class LayoutRunnerTests(unittest.TestCase):
    def invoke(self, native):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(StringIO()):
            log = Path(directory) / 'native.log'
            with patch.object(runner.subprocess, 'run', side_effect=native if isinstance(native, Exception) else [native]):
                result = runner.invoke(['godot'], None, log, runner.MARKER)
            return 0 if result else 1, log.read_text(encoding='utf-8')

    def test_only_complete_native_success_passes(self):
        marker = 'JOURNEY_WINDOW_LAYOUT checks=42 failures=0\n'
        cases = [
            (marker, '', 0, 0),
            ('', '', 0, 1),
            ('JOURNEY_WINDOW_LAYOUT checks=0 failures=0', '', 0, 1),
            ('JOURNEY_WINDOW_LAYOUT checks=42 failures=1', '', 0, 1),
            (marker, '', 1, 1),
            (marker, 'SCRIPT ERROR: failed native callback', 0, 1),
            (marker, 'WARNING: ObjectDB instances leaked', 0, 1),
            (marker, 'Unicode parsing error: invalid text', 0, 1),
            (marker, '\x1b[31mERROR: colored native failure\x1b[0m', 0, 1),
        ]
        for stdout, stderr, code, expected in cases:
            with self.subTest(code=code, stderr=stderr):
                result, text = self.invoke(subprocess.CompletedProcess([], code, stdout, stderr))
                self.assertEqual(result, expected)
                self.assertIn(stderr, text)

    def test_missing_dependency_is_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(StringIO()):
            args = ['runner', '--engine', 'pinned-godot', '--log-dir', directory]
            with patch('sys.argv', args), patch.object(runner.shutil, 'copy2', side_effect=FileNotFoundError('production script missing')), patch.object(runner.subprocess, 'run') as native:
                with self.assertRaises(FileNotFoundError):runner.main()
                native.assert_not_called()

    def test_timeout_preserves_both_streams_and_never_passes_partial_marker(self):
        error = subprocess.TimeoutExpired('godot', 120, output=b'JOURNEY_WINDOW_LAYOUT checks=42 failures=0\n', stderr=b'SCRIPT ERROR: blocked reader\n')
        result, text = self.invoke(error)
        self.assertEqual(result, 1)
        self.assertIn('blocked reader', text)
        self.assertIn('native fixture timeout', text)

    def test_timeout_accepts_text_and_byte_diagnostics_without_dropping_either(self):
        error = subprocess.TimeoutExpired('godot', 120, output='before native exit\n', stderr=b'failure on stderr\n')
        result, text = self.invoke(error)
        self.assertEqual(result, 1)
        self.assertIn('before native exit', text)
        self.assertIn('failure on stderr', text)


if __name__ == '__main__':unittest.main()
