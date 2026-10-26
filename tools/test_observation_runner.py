#!/usr/bin/env python3
"""Failure-propagation contracts for the observation test launcher."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('observed_runner', Path(__file__).with_name('run_observation_challenge.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)
MODULE = 'k01_safe_rooms'
MARKER = 'JOURNEY_K01_SAFE_ROOMS checks=7 failures=0\n'

class RunnerContracts(unittest.TestCase):
    def execute(self, output, code=0, timeout=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('journey', 'scripts', 'data'):
                (root / 'godot' / name).mkdir(parents=True)
            source = root / 'godot/journey/tests' / (MODULE + '.gd')
            source.parent.mkdir(parents=True)
            source.write_text('extends SceneTree\n')
            args = ['runner', '--engine', sys.executable, '--module', MODULE, '--log-dir', str(root / 'logs')]
            with patch.object(RUNNER, 'ROOT', root), patch.object(sys, 'argv', args), contextlib.redirect_stdout(io.StringIO()):
                with patch.object(RUNNER.subprocess, 'run') as launch:
                    if timeout:
                        launch.side_effect = subprocess.TimeoutExpired('godot', 90, output=output.encode())
                    else:
                        launch.return_value = subprocess.CompletedProcess([], code, output, '')
                    result = RUNNER.main()
                    self.assertEqual(launch.call_args.kwargs['timeout'], 90)
                log = (root / 'logs' / (MODULE + '.log')).read_text()
            return result, log

    def test_valid_marker_and_zero_exit(self):
        result, log = self.execute(MARKER)
        self.assertEqual(result, 0)
        self.assertIn(MARKER, log)

    def test_zero_exit_requires_a_completion_marker(self):
        result, _ = self.execute('Godot launched\n')
        self.assertEqual(result, 1)

    def test_nonzero_exit_cannot_be_masked_by_marker(self):
        result, _ = self.execute(MARKER, 1)
        self.assertEqual(result, 1)

    def test_engine_errors_cannot_be_masked_by_marker(self):
        for prefix in ('SCRIPT ERROR:', 'ERROR:', 'USER ERROR:'):
            with self.subTest(prefix=prefix):
                result, log = self.execute(MARKER + prefix + ' injected negative fixture\n')
                self.assertEqual(result, 1)
                self.assertIn('injected negative fixture', log)

    def test_wrong_module_marker_is_rejected(self):
        result, _ = self.execute(MARKER.replace('K01_SAFE_ROOMS', 'K02_WALKING'))
        self.assertEqual(result, 1)

    def test_nonzero_failure_count_is_rejected(self):
        result, _ = self.execute(MARKER.replace('failures=0', 'failures=1'))
        self.assertEqual(result, 1)

    def test_zero_check_count_is_rejected(self):
        result, _ = self.execute(MARKER.replace('checks=7', 'checks=0'))
        self.assertEqual(result, 1)

    def test_timeout_retains_diagnostics_and_fails(self):
        result, log = self.execute('partial output\n', timeout=True)
        self.assertEqual(result, 1)
        self.assertIn('partial output', log)
        self.assertIn('90 second budget', log)

    def test_colored_diagnostics_are_detected(self):
        result, _ = self.execute(MARKER + '\x1b[31mSCRIPT ERROR: injected\x1b[0m\n')
        self.assertEqual(result, 1)

if __name__ == '__main__':
    unittest.main()
