#!/usr/bin/env python3
"""Use real child processes to check CI error/timeout propagation."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from run_godot_regressions import suite_path, render_loop_args, DEFAULT_SUITES, NARRATIVE_SUITES, SUCCESS_MARKERS
import re
from run_godot_regressions import run_suites

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
        result = self.run_engine('print("ENEMY_VISIBILITY_VALIDATION checks=1 failures=0")\n')
        self.assertEqual(result.returncode, 0)

    def test_zero_exit_without_completion_is_failure(self):
        result = self.run_engine('print("PASS: first assertion only")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('completion_marker=False', result.stdout)

    def test_different_suite_marker_is_not_completion(self):
        result = self.run_engine('print("WORLD_MAP checks=1 failures=0")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('completion_marker=False', result.stdout)

    def test_default_suites_all_have_compilable_completion_contracts(self):
        all_suites = DEFAULT_SUITES + NARRATIVE_SUITES
        self.assertEqual(len(all_suites), 96)
        self.assertIn("input_prompt", DEFAULT_SUITES)
        self.assertEqual(len(all_suites), len(set(all_suites)))
        self.assertEqual(set(all_suites), set(SUCCESS_MARKERS))
        for marker in SUCCESS_MARKERS.values():
            self.assertTrue(marker.startswith('^') and marker.endswith('$'))
            re.compile(marker)

    def test_only_lifecycle_pressure_suites_skip_real_gl_drawing(self):
        self.assertEqual(render_loop_args(True, 'world_neighbor_gameplay_stress'), ['--disable-render-loop'])
        self.assertEqual(render_loop_args(True, 'world_upgrade'), ['--disable-render-loop'])
        self.assertEqual(render_loop_args(True, 'world_neighbor_gameplay_live'), [])
        self.assertEqual(render_loop_args(True, 'world_neighbor_gameplay'), [])
        self.assertEqual(render_loop_args(False, 'world_neighbor_gameplay_stress'), [])

    def test_only_non_visual_neighbor_stress_disables_render_loop(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            captured = root / 'args'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + 'print("WORLD_NEIGHBOR_GAMEPLAY_STRESS checks=1 failures=0")\n'
                + 'print("WORLD_NEIGHBOR_GAMEPLAY_LIVE checks=1 failures=0")\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            for suite, should_disable in [
                ('world_neighbor_gameplay_stress', True),
                ('world_neighbor_gameplay_live', False),
            ]:
                with self.subTest(suite=suite):
                    captured.unlink(missing_ok=True)
                    failures = run_suites(
                        str(engine), [suite], 2, logs, root / 'scratch', True,
                        {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'},
                    )
                    self.assertEqual(failures, [])
                    args = captured.read_text().splitlines()
                    self.assertIn('--rendering-method', args)
                    self.assertIn('gl_compatibility', args)
                    self.assertEqual('--disable-render-loop' in args, should_disable)

    def test_invalid_timeout_never_launches_engine(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'ran'
            engine = Path(directory) / 'fake-godot'
            engine.write_text('#!' + sys.executable + '\n'
                              + f'open({str(marker)!r}, "w").close()\n')
            engine.chmod(0o755)
            for timeout in ('nan', 'inf', '-inf', '0', '-1'):
                with self.subTest(timeout=timeout):
                    result = subprocess.run(
                        [sys.executable, str(ROOT / 'tools/run_godot_regressions.py'),
                         '--engine', str(engine), '--suite', 'enemy_visibility',
                         '--timeout=' + timeout], text=True, capture_output=True, timeout=10)
                    self.assertEqual(result.returncode, 2)
                    self.assertIn('finite and positive', result.stderr)
                    self.assertNotIn('Traceback', result.stderr)
                    self.assertFalse(marker.exists())

    def test_invalid_suite_preflight_never_runs_earlier_valid_suite(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'ran'
            logs = Path(directory) / 'logs'
            engine = Path(directory) / 'fake-godot'
            engine.write_text('#!' + sys.executable + '\n'
                              + f'open({str(marker)!r}, "w").close()\n')
            engine.chmod(0o755)
            for suite in ('../escape', 'tests/../../escape', '/absolute', 'Bad_Name', 'two words'):
                with self.subTest(suite=suite):
                    result = subprocess.run(
                        [sys.executable, str(ROOT / 'tools/run_godot_regressions.py'),
                         '--engine', str(engine), '--suite', 'enemy_visibility',
                         '--suite', suite, '--log-dir', str(logs)],
                        text=True, capture_output=True, timeout=10)
                    self.assertEqual(result.returncode, 2)
                    self.assertIn('invalid suite name', result.stderr)
                    self.assertNotIn('Traceback', result.stderr)
                    self.assertFalse(marker.exists())
                    self.assertFalse(logs.exists())

    def test_valid_narrative_suite_name_is_accepted(self):
        self.assertEqual(suite_path('tests/verify_world_narrative'),
                         'res://tests/verify_world_narrative.gd')

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
