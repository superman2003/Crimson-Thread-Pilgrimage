#!/usr/bin/env python3
"""Use real child processes to check CI error/timeout propagation."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipIf(os.name == 'nt', 'executable shebang fixtures run on Linux/macOS CI')
class RunnerTests(unittest.TestCase):
    def run_engine(self, body, suite='enemy_visibility', timeout='2', missing_display=False):
        with tempfile.TemporaryDirectory() as directory:
            engine = Path(directory) / 'fake-godot'
            engine.write_text('#!' + sys.executable + '\n' + body)
            engine.chmod(0o755)
            renderer = ['--software-gl'] if missing_display else []
            env = dict(os.environ, PATH=directory) if missing_display else None
            return subprocess.run([sys.executable, str(ROOT / 'tools/run_godot_regressions.py'), '--engine', str(engine), '--suite', suite, '--timeout', timeout, *renderer], env=env, text=True, capture_output=True, timeout=10)

    def test_nonzero_exit_propagates(self):
        result = self.run_engine('raise SystemExit(7)\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('exit=7', result.stdout)

    def test_script_error_with_zero_exit_propagates(self):
        result = self.run_engine('print("SCRIPT ERROR: fixture parse failure")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('engine_errors=1', result.stdout)

    def test_missing_suite_never_reports_success(self):
        result = self.run_engine('print("PASS")\n', suite='missing_fixture')
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing validation script', result.stdout)

    def test_timeout_propagates(self):
        result = self.run_engine('import time\ntime.sleep(2)\n', timeout='0.05')
        self.assertEqual(result.returncode, 1)
        self.assertIn('timeout after', result.stdout)

    def test_success_is_success(self):
        result = self.run_engine('print("FIXTURE_PASS checks=1")\n')
        self.assertEqual(result.returncode, 0)

    def test_missing_gl_display_never_falls_back(self):
        result = self.run_engine('print("FIXTURE_ENGINE_RAN")\n', missing_display=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires Xvfb', result.stderr)
        self.assertNotIn('FIXTURE_ENGINE_RAN', result.stdout)

    def test_python_tool_signal_is_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / 'terminated.py'
            script.write_text('import os, signal\nos.kill(os.getpid(), signal.SIGTERM)\n')
            result = subprocess.run(['node', str(ROOT / 'tools/run_python_tool.mjs'), str(script)], text=True, capture_output=True, env=dict(os.environ, PYTHON=sys.executable), timeout=10)
            self.assertEqual(result.returncode, 1)
            self.assertIn('terminated by signal', result.stderr)

if __name__ == '__main__':
    unittest.main()
