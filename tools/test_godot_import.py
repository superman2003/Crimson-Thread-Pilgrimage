#!/usr/bin/env python3
"""Exercise import failure detection with isolated real child processes."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == 'nt', 'executable shebang fixtures run on Linux/macOS CI')
class ImportTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        self.engine = self.directory / 'fake-godot'
        self.logs = self.directory / 'logs'
        self.marker = self.directory / 'ran'

    def run_engine(self, body, timeout='2', recovery=False):
        self.engine.write_text('#!' + sys.executable + '\n' + body, encoding='utf-8')
        self.engine.chmod(0o755)
        return self.run_import(timeout, recovery)

    def run_import(self, timeout='2', recovery=False):
        return subprocess.run(
            [sys.executable, str(ROOT / 'tools/run_godot_import.py'),
             '--engine', str(self.engine), '--log-dir', str(self.logs),
             '--timeout', timeout, *(['--recovery-mode'] if recovery else [])],
            text=True, capture_output=True, timeout=10)

    def test_success_runs_both_import_passes(self):
        result = self.run_engine(
            'from pathlib import Path\nimport sys\n'
            'assert sys.argv[1:] == ["--headless", "--path", '
            + repr(str(ROOT / 'godot')) + ', "--editor", "--import", "--quit"]\n'
            + f'with Path({str(self.marker)!r}).open("a") as marker: marker.write("x")\n'
            'print("Imported resources")\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.marker.read_text(), 'xx')
        self.assertIn('GODOT_IMPORT passes=2 failures=0', result.stdout)
        for number in (1, 2):
            self.assertIn('Imported resources', (self.logs / f'import-{number}.log').read_text())

    def test_nonzero_exit_fails(self):
        result = self.run_engine('raise SystemExit(7)\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('exit=7', result.stdout)
        self.assertFalse((self.logs / 'import-2.log').exists())

    def test_recovery_mode_is_explicitly_forwarded(self):
        result = self.run_engine(
            'import sys\nassert "--recovery-mode" in sys.argv\n', recovery=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('editor-plugin behavior is not validated', result.stdout)

    def test_recovery_mode_still_rejects_engine_errors(self):
        result = self.run_engine('print("ERROR: broken resource import")\n', recovery=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('exit=0 engine_errors=1', result.stdout)

    def test_zero_exit_engine_errors_fail(self):
        for diagnostic in ('ERROR: missing asset', 'SCRIPT ERROR: parse failure',
                           '\x1b[31mERROR: colored failure\x1b[0m'):
            with self.subTest(diagnostic=diagnostic):
                result = self.run_engine('import sys\nprint(' + repr(diagnostic) + ', file=sys.stderr)\n')
                self.assertEqual(result.returncode, 1)
                self.assertIn('exit=0 engine_errors=1', result.stdout)

    def test_second_pass_errors_are_not_hidden(self):
        result = self.run_engine(
            'from pathlib import Path\n'
            + f'marker = Path({str(self.marker)!r})\n'
            'if marker.exists():\n    print("ERROR: second pass failed")\n'
            'marker.touch()\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('PASS: import pass 1', result.stdout)
        self.assertIn('FAIL: import pass 2', result.stdout)

    def test_timeout_retains_partial_log(self):
        result = self.run_engine('import time\nprint("before timeout", flush=True)\ntime.sleep(2)\n', timeout='0.5')
        self.assertEqual(result.returncode, 1)
        self.assertIn('timeout after', result.stdout)
        self.assertIn('before timeout', (self.logs / 'import-1.log').read_text())

    def test_invalid_timeout_does_not_launch_engine(self):
        for timeout in ('nan', 'inf', '-inf', '0', '-1'):
            with self.subTest(timeout=timeout):
                # Equals syntax allows argparse to recognize negative infinity.
                self.engine.write_text('#!' + sys.executable + '\n'
                                       + f'open({str(self.marker)!r}, "w").close()\n')
                self.engine.chmod(0o755)
                result = subprocess.run(
                    [sys.executable, str(ROOT / 'tools/run_godot_import.py'),
                     '--engine', str(self.engine), '--log-dir', str(self.logs),
                     '--timeout=' + timeout], text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 2)
                self.assertIn('finite and positive', result.stderr)
                self.assertFalse(self.marker.exists())

    def test_warning_is_not_an_engine_error(self):
        result = self.run_engine('print("WARNING: fixture warning")\n')
        self.assertEqual(result.returncode, 0)

    def test_missing_engine_is_cli_error(self):
        result = self.run_import()
        self.assertEqual(result.returncode, 2)
        self.assertIn('Godot executable not found', result.stderr)

    def test_engine_launch_error_fails_without_traceback(self):
        self.engine.write_text('#!/missing-import-fixture-interpreter\n')
        self.engine.chmod(0o755)
        result = self.run_import()
        self.assertEqual(result.returncode, 1)
        self.assertIn('could not launch engine', result.stdout)
        self.assertNotIn('Traceback', result.stderr)


if __name__ == '__main__':
    unittest.main()
