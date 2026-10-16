#!/usr/bin/env python3
"""Exercise the pixel runner's final gate without starting Godot or Xvfb."""
from contextlib import ExitStack, redirect_stderr, redirect_stdout
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import run_rock_gpu_validation as runner


MARKER = 'ROCK_SEAMS probes=12 failures=0'


class RockGPUValidationTests(unittest.TestCase):
    def setUp(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        self.logs = Path(stack.enter_context(tempfile.TemporaryDirectory()))
        stack.enter_context(mock.patch.object(runner.shutil, 'which',
                                             side_effect=lambda name: '/fake/' + name))
        stack.enter_context(mock.patch.object(runner.Path, 'exists', return_value=False))
        stack.enter_context(mock.patch.object(runner.socket, 'socket'))
        stack.enter_context(mock.patch.object(runner.socket, 'create_connection'))
        self.server = stack.enter_context(mock.patch.object(runner.subprocess, 'Popen')).return_value
        self.server.poll.return_value = None
        self.engine_run = stack.enter_context(mock.patch.object(runner.subprocess, 'run'))
        self.copyfile = stack.enter_context(mock.patch.object(runner.shutil, 'copyfile'))
        self.stdout = stack.enter_context(redirect_stdout(io.StringIO()))
        self.stderr = stack.enter_context(redirect_stderr(io.StringIO()))

    def run_main(self, output, returncode=0, extra_args=()):
        self.engine_run.return_value = subprocess.CompletedProcess(['fake-godot'], returncode, output)
        args = ['run_rock_gpu_validation.py', '--engine', 'godot',
                '--log-dir', str(self.logs), *extra_args]
        with mock.patch.object(sys, 'argv', args):
            try:
                runner.main()
            except SystemExit as exc:
                return exc.code
        return 0

    def test_colored_script_error_with_marker_fails(self):
        output = '\x1b[31mSCRIPT ERROR: fixture failure\x1b[0m\n' + MARKER + '\n'
        self.assertEqual(self.run_main(output), 1)
        self.copyfile.assert_not_called()
        self.assertEqual((self.logs / 'gpu.log').read_text(), output)
        self.server.terminate.assert_called_once()

    def test_colored_engine_error_with_marker_fails(self):
        output = '\x1b[1;31mERROR: fixture failure\x1b[0m\n' + MARKER + '\n'
        self.assertEqual(self.run_main(output), 1)
        self.copyfile.assert_not_called()

    def test_plain_errors_with_marker_fail(self):
        for diagnostic in ('SCRIPT ERROR: fixture failure', '  ERROR: fixture failure'):
            with self.subTest(diagnostic=diagnostic):
                self.assertEqual(self.run_main(diagnostic + '\n' + MARKER), 1)
        self.copyfile.assert_not_called()

    def test_colored_marker_succeeds(self):
        output = '\x1b[32mROCK_SEAMS\x1b[0m probes=12 failures=0\n'
        self.assertEqual(self.run_main(output), 0)
        self.copyfile.assert_called_once()
        self.assertEqual((self.logs / 'gpu.log').read_text(), output)

    def test_plain_marker_and_warning_succeed(self):
        self.assertEqual(self.run_main('WARNING: fixture warning\n' + MARKER + '\n'), 0)
        self.copyfile.assert_called_once()

    def test_custom_marker_retains_substring_compatibility(self):
        self.assertEqual(self.run_main('prefix CUSTOM_OK suffix\n',
                                       extra_args=('--success-marker', 'CUSTOM_OK')), 0)
        self.copyfile.assert_called_once()

    def test_nonzero_exit_with_marker_fails(self):
        self.assertEqual(self.run_main(MARKER + '\n', returncode=7), 1)
        self.copyfile.assert_not_called()

    def test_missing_marker_fails(self):
        self.assertEqual(self.run_main('Godot startup complete\n'), 1)
        self.copyfile.assert_not_called()

    def test_main_uses_final_output_gate(self):
        with mock.patch.object(runner, 'validation_failed', return_value=True) as gate:
            self.assertEqual(self.run_main(MARKER + '\n'), 1)
        gate.assert_called_once_with(MARKER + '\n', 0, MARKER)
        self.copyfile.assert_not_called()

    def test_real_gl_and_default_timeout_are_preserved(self):
        self.assertEqual(self.run_main(MARKER + '\n'), 0)
        command = self.engine_run.call_args.args[0]
        self.assertEqual(command[command.index('--display-driver') + 1], 'x11')
        self.assertEqual(command[command.index('--rendering-method') + 1], 'gl_compatibility')
        self.assertNotIn('--headless', command)
        self.assertEqual(self.engine_run.call_args.kwargs['env']['LIBGL_ALWAYS_SOFTWARE'], '1')
        self.assertEqual(self.engine_run.call_args.kwargs['timeout'], 120)
        self.assertEqual(self.engine_run.call_args.kwargs['stderr'], subprocess.STDOUT)

    def test_timeout_fails_even_after_marker(self):
        self.engine_run.side_effect = subprocess.TimeoutExpired(['fake-godot'], 0.25,
                                                        output=(MARKER + '\n').encode())
        self.assertEqual(self.run_main('', extra_args=('--timeout', '0.25')), 124)
        self.assertEqual(self.engine_run.call_args.kwargs['timeout'], 0.25)
        log = (self.logs / 'gpu.log').read_text()
        self.assertIn(MARKER, log)
        self.assertIn('ERROR: Godot validation timed out after 0.25 seconds', log)
        self.copyfile.assert_not_called()
        self.server.terminate.assert_called_once()


if __name__ == '__main__':
    unittest.main()
