#!/usr/bin/env python3
"""Use real child processes to check CI error/timeout propagation."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import run_godot_regressions as runner
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

    def test_colored_script_error_with_success_marker_fails(self):
        result = self.run_engine('print("\\x1b[31mSCRIPT ERROR: colored failure\\x1b[0m")\nprint("ENEMY_VISIBILITY_VALIDATION checks=1 failures=0")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('engine_errors=1 completion_marker=True', result.stdout)

    def test_colored_engine_error_with_success_marker_fails(self):
        result = self.run_engine('print("\\x1b[1;31mERROR: colored resource failure\\x1b[0m")\nprint("ENEMY_VISIBILITY_VALIDATION checks=1 failures=0")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('engine_errors=1 completion_marker=True', result.stdout)

    def test_colored_success_marker_is_success(self):
        result = self.run_engine('print("\\x1b[32mENEMY_VISIBILITY_VALIDATION checks=1 failures=0\\x1b[0m")\n')
        self.assertEqual(result.returncode, 0)

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
        self.assertEqual(len(all_suites), 101)
        self.assertIn("world_catalog_background", DEFAULT_SUITES)
        self.assertIn("world_startup_config_background", DEFAULT_SUITES)
        self.assertIn("input_prompt", DEFAULT_SUITES)
        self.assertIn("combat_resource_cycle", DEFAULT_SUITES)
        self.assertIn("world_gameplay_plan", DEFAULT_SUITES)
        for suite in ["world_route_manifest_walk_lower", "world_route_manifest_walk_upper", "world_route_manifest_integration"]:
            self.assertIn(suite, DEFAULT_SUITES)
        self.assertEqual(len(all_suites), len(set(all_suites)))
        self.assertEqual(set(all_suites), set(SUCCESS_MARKERS))
        for marker in SUCCESS_MARKERS.values():
            self.assertTrue(marker.startswith('^') and marker.endswith('$'))
            re.compile(marker)

    def test_manifest_walk_completion_requires_every_crossing(self):
        for suite, marker, incomplete in [
            ('world_route_manifest_walk_lower', 'WORLD_ROUTE_MANIFEST_WALK_LOWER', 5),
            ('world_route_manifest_walk_upper', 'WORLD_ROUTE_MANIFEST_WALK_UPPER', 3),
        ]:
            with self.subTest(suite=suite):
                result = self.run_engine(
                    f'print("{marker} checks=1 failures=0 physical_crossings={incomplete}")\n',
                    suite=suite,
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn('completion_marker=False', result.stdout)

    def test_manifest_walks_keep_drawing_and_fixed_simulation_clock(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            captured = root / 'args'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + 'print("WORLD_ROUTE_MANIFEST_WALK_LOWER checks=1 failures=0 physical_crossings=6")\n'
                + 'print("WORLD_ROUTE_MANIFEST_WALK_UPPER checks=1 failures=0 physical_crossings=4")\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            for suite in ['world_route_manifest_walk_lower', 'world_route_manifest_walk_upper']:
                with self.subTest(suite=suite):
                    failures = run_suites(str(engine), [suite], 2, logs, root / 'scratch', True,
                                          {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'})
                    self.assertEqual(failures, [])
                    arguments = captured.read_text().splitlines()
                    self.assertNotIn('--disable-render-loop', arguments)
                    self.assertIn('--fixed-fps', arguments)
                    self.assertEqual(arguments[arguments.index('--fixed-fps') + 1], '60')

    def test_only_lifecycle_pressure_suites_skip_real_gl_drawing(self):
        self.assertEqual(render_loop_args(True, 'world_neighbor_gameplay_stress'), ['--disable-render-loop'])
        self.assertEqual(render_loop_args(True, 'world_upgrade'), ['--disable-render-loop'])
        self.assertEqual(render_loop_args(True, 'world_neighbor_gameplay_live'), [])
        self.assertEqual(render_loop_args(True, 'world_neighbor_gameplay'), [])
        self.assertEqual(render_loop_args(True, 'world_route_manifest_walk_lower'), [])
        self.assertEqual(render_loop_args(True, 'world_route_manifest_walk_upper'), [])
        self.assertEqual(render_loop_args(True, 'world_route_manifest_integration'), [])
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

    def test_catalog_fault_fixture_restores_source_for_all_process_outcomes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'godot/data/world_routes.json'
            source.parent.mkdir(parents=True)
            original = b'{"fixture": "original"}'
            script = root / 'godot/scripts/world_catalog_background_validation.gd'
            script.parent.mkdir(parents=True)
            script.write_text('fixture')
            logs = root / 'logs'
            logs.mkdir()
            engine = root / 'fake-godot'
            cases = [
                ('print("WORLD CATALOG BACKGROUND PASS checks=1")', 2, 0),
                ('print("SCRIPT ERROR: fixture failure"); print("WORLD CATALOG BACKGROUND PASS checks=1")', 2, 1),
                ('raise RuntimeError("fixture failure")', 2, 1),
                ('import time; time.sleep(2)', 0.05, 1),
            ]
            for body, timeout, failure_count in cases:
                with self.subTest(body=body):
                    source.write_bytes(original)
                    stamps = (123000000001, 456000000002)
                    os.utime(source, ns=stamps)
                    engine.write_text('#!' + sys.executable + '\n'
                                      + f'open({str(source)!r}, "wb").write(b"changed")\n'
                                      + body + '\n')
                    engine.chmod(0o755)
                    with patch.object(runner, 'ROOT', root):
                        failures = runner.run_suites(str(engine), ['world_catalog_background'],
                                                     timeout, logs, root / 'scratch', False, {})
                    self.assertEqual(len(failures), failure_count)
                    restored = source.stat()  # Inspect atime before reading again.
                    self.assertEqual((restored.st_atime_ns, restored.st_mtime_ns), stamps)
                    self.assertEqual(source.read_bytes(), original)
            source.write_bytes(original)
            os.utime(source, ns=stamps)
            def failed_launch(*args, **kwargs):
                source.write_bytes(b'changed before launch failure')
                raise OSError('fixture launch failure')
            with patch.object(runner, 'ROOT', root), patch.object(runner.subprocess, 'run', side_effect=failed_launch):
                with self.assertRaises(OSError):
                    runner.run_suites(str(engine), ['world_catalog_background'], 2, logs, root / 'scratch', False, {})
            restored = source.stat()
            self.assertEqual((restored.st_atime_ns, restored.st_mtime_ns), stamps)
            self.assertEqual(source.read_bytes(), original)

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
