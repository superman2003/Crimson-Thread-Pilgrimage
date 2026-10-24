#!/usr/bin/env python3
"""Check portable completion contracts and CI error/timeout propagation."""
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

class CompletionContractTests(unittest.TestCase):
    """Static suite contracts apply on every host, including Windows."""
    def test_default_suites_all_have_compilable_completion_contracts(self):
        all_suites = DEFAULT_SUITES + NARRATIVE_SUITES
        self.assertEqual(len(all_suites), 145)
        self.assertIn("permanent_capacity", DEFAULT_SUITES)
        self.assertIn("boss_skill_art", DEFAULT_SUITES)
        self.assertIn("player_movement_art", DEFAULT_SUITES)
        self.assertIn("player_heal_art", DEFAULT_SUITES)
        self.assertIn("player_guard_art", DEFAULT_SUITES)
        self.assertIn("combat_visual_budget", DEFAULT_SUITES)
        self.assertIn("minor_enemy_skill_art", DEFAULT_SUITES)
        self.assertIn("skill_branches", DEFAULT_SUITES)
        self.assertIn("artisan_crafts", DEFAULT_SUITES)
        self.assertIn("survey_room_segments", DEFAULT_SUITES)
        self.assertIn("save_recovery", DEFAULT_SUITES)
        self.assertIn("death_cache_placement", DEFAULT_SUITES)
        self.assertIn("g02_respawn", DEFAULT_SUITES)
        self.assertIn("obsidian_road_clearance", DEFAULT_SUITES)
        self.assertIn("obsidian_dock_clearance", DEFAULT_SUITES)
        self.assertIn("ending_aftermath", DEFAULT_SUITES)
        self.assertIn("settings_remap", DEFAULT_SUITES)
        self.assertIn("tool_practice", DEFAULT_SUITES)
        self.assertIn("shrine_exit_probe", DEFAULT_SUITES)
        self.assertIn("shrine_exit_routes", DEFAULT_SUITES)
        self.assertIn("hidden_routes", DEFAULT_SUITES)
        self.assertIn("expanded_character_motion", DEFAULT_SUITES)
        self.assertIn("enemy_ai_behavior", DEFAULT_SUITES)
        self.assertIn("enemy_tactical_roles", DEFAULT_SUITES)
        self.assertIn("character_art_prewarm", DEFAULT_SUITES)
        self.assertIn("texture_request_exit", DEFAULT_SUITES)
        self.assertIn("background_texture_contention", DEFAULT_SUITES)
        self.assertIn("enemy_atlas_integrity", DEFAULT_SUITES)
        self.assertIn("world_save_candidate", DEFAULT_SUITES)
        self.assertIn("map_player_pins", DEFAULT_SUITES)
        self.assertIn("world_startup_config_background", DEFAULT_SUITES)
        self.assertIn("world_catalog_background", DEFAULT_SUITES)
        self.assertIn("room_camera_stability", DEFAULT_SUITES)
        self.assertIn("player_layered_idle", DEFAULT_SUITES)
        self.assertIn("input_prompt", DEFAULT_SUITES)
        self.assertIn("ui_text_order", DEFAULT_SUITES)
        self.assertIn("combat_resource_cycle", DEFAULT_SUITES)
        self.assertIn("world_gameplay_plan", DEFAULT_SUITES)
        self.assertIn("player_motion_continuity", DEFAULT_SUITES)
        self.assertIn("player_melee_feedback", DEFAULT_SUITES)
        self.assertIn("spike_pogo", DEFAULT_SUITES)
        for suite in ["world_route_manifest_walk_lower", "world_route_manifest_walk_upper", "world_route_manifest_integration"]:
            self.assertIn(suite, DEFAULT_SUITES)
        self.assertEqual(len(all_suites), len(set(all_suites)))
        self.assertEqual(set(all_suites), set(SUCCESS_MARKERS))
        for marker in SUCCESS_MARKERS.values():
            self.assertTrue(marker.startswith('^') and marker.endswith('$'))
            re.compile(marker)


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

    def test_audio_retirement_uses_wall_clock_with_both_renderers(self):
        # Real audio mixing and reservation expiry do not follow the accelerated
        # simulation clock. Check the actual child command used by both paths.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + 'assert "--fixed-fps" not in sys.argv, "audio needs wall-clock timing"\n'
                + 'print("AUDIO RETIREMENT PASS: fixture, failures=0")\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            for real_gl in [False, True]:
                with self.subTest(real_gl=real_gl):
                    failures = run_suites(str(engine), ['audio_retirement'], 2,
                                          logs, root / 'scratch', real_gl, {})
                    self.assertEqual(failures, [])

    def test_zero_exit_without_completion_is_failure(self):
        result = self.run_engine('print("PASS: first assertion only")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('completion_marker=False', result.stdout)

    def test_different_suite_marker_is_not_completion(self):
        result = self.run_engine('print("WORLD_MAP checks=1 failures=0")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('completion_marker=False', result.stdout)

    def test_workshop_groups_require_full_room_and_restart_counts(self):
        for suffix, count in [('one', 10), ('two', 9)]:
            suite = 'world_workshop_group_' + suffix
            prefix = 'WORLD_WORKSHOP_GROUP_' + suffix.upper()
            marker = f'{prefix} checks=400 failures=0 rooms={count} disk_restarts={count} enemy_removal=true fixture_positioning=true elapsed_ms=1234'
            with self.subTest(suite=suite, terminal='complete'):
                self.assertEqual(self.run_engine(f'print({marker!r})\n', suite=suite).returncode, 0)
            for partial in [
                'WORKSHOP_ACTION_PASS upgrade_thread_dash_1_action_gate',
                marker.replace(f'rooms={count}', f'rooms={count-1}'),
                marker.replace(f'disk_restarts={count}', f'disk_restarts={count-1}'),
                marker.replace('failures=0', 'failures=1'),
            ]:
                with self.subTest(suite=suite, terminal=partial):
                    result = self.run_engine(f'print({partial!r})\n', suite=suite)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('completion_marker=False', result.stdout)

    def test_workshop_group_success_never_masks_engine_errors(self):
        for suffix, count in [('one', 10), ('two', 9)]:
            marker = f'WORLD_WORKSHOP_GROUP_{suffix.upper()} checks=400 failures=0 rooms={count} disk_restarts={count} enemy_removal=true fixture_positioning=true elapsed_ms=1234'
            result = self.run_engine(f'print({marker!r})\nprint("\\x1b[31mERROR: workshop fixture failure\\x1b[0m")\n', suite='world_workshop_group_' + suffix)
            self.assertEqual(result.returncode, 1)
            self.assertIn('engine_errors=1 completion_marker=True', result.stdout)

    def test_workshop_groups_keep_real_gl_fixed_clock_and_explicit_capture_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            captured = root / 'args'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + 'print("WORLD_WORKSHOP_GROUP_ONE checks=400 failures=0 rooms=10 disk_restarts=10 enemy_removal=true fixture_positioning=true elapsed_ms=1234")\n'
                + 'print("WORLD_WORKSHOP_GROUP_TWO checks=400 failures=0 rooms=9 disk_restarts=9 enemy_removal=true fixture_positioning=true elapsed_ms=1234")\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            for suite in ['world_workshop_group_one', 'world_workshop_group_two']:
                self.assertIn(suite, DEFAULT_SUITES)
                failures = run_suites(str(engine), [suite], 2, logs, root / 'scratch', True, {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'})
                self.assertEqual(failures, [])
                args = captured.read_text().splitlines()
                self.assertIn('--disable-render-loop', args)
                self.assertEqual(args[args.index('--fixed-fps') + 1], '60')
                self.assertEqual(args[args.index('--rendering-method') + 1], 'gl_compatibility')
                self.assertIn('--verbose', args)
                self.assertNotIn('--headless', args)

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
                + 'print("PLAYER_MOTION_CONTINUITY checks=1 failures=0")\n'
                + 'print("PLAYER_MELEE_FEEDBACK_PASS checks=1 hardware=simulated physical_feel=unverified")\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            for suite in ['world_route_manifest_walk_lower', 'world_route_manifest_walk_upper', 'player_motion_continuity', 'player_melee_feedback']:
                with self.subTest(suite=suite):
                    failures = run_suites(str(engine), [suite], 2, logs, root / 'scratch', True,
                                          {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'})
                    self.assertEqual(failures, [])
                    arguments = captured.read_text().splitlines()
                    self.assertNotIn('--disable-render-loop', arguments)
                    self.assertIn('--fixed-fps', arguments)
                    self.assertEqual(arguments[arguments.index('--fixed-fps') + 1], '60')

    def test_motion_and_feedback_markers_do_not_overclaim_acceptance(self):
        for suite, marker in [
            ('player_motion_continuity', 'PLAYER_MOTION_CONTINUITY checks=1 failures=1'),
            ('player_melee_feedback', 'PLAYER_MELEE_FEEDBACK_PASS checks=1 hardware=physical physical_feel=verified'),
        ]:
            with self.subTest(suite=suite):
                result = self.run_engine(f'print({marker!r})\n', suite=suite)
                self.assertEqual(result.returncode, 1)
                self.assertIn('completion_marker=False', result.stdout)

    def test_room_camera_requires_complete_real_player_integration(self):
        for marker in [
            'ROOM_CAMERA_STABILITY checks=63 failures=0 player_integration=false metrics={}',
            'ROOM_CAMERA_STABILITY checks=78 failures=0 player_integration=false metrics={}',
            'ROOM_CAMERA_STABILITY checks=77 failures=0 player_integration=true metrics={}',
            'ROOM_CAMERA_STABILITY checks=78 failures=1 player_integration=true metrics={}',
        ]:
            with self.subTest(marker=marker):
                result = self.run_engine(f'print({marker!r})\n', suite='room_camera_stability')
                self.assertEqual(result.returncode, 1)
                self.assertIn('completion_marker=False', result.stdout)

    def test_room_camera_keeps_drawing_fixed_clock_and_player_flag(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            captured = root / 'args'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + 'print("ROOM_CAMERA_STABILITY checks=78 failures=0 player_integration=true metrics={}")\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            failures = run_suites(str(engine), ['room_camera_stability'], 2, logs, root / 'scratch', True,
                                  {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'})
            self.assertEqual(failures, [])
            arguments = captured.read_text().splitlines()
            self.assertEqual(arguments[-2:], ['--', '--player'])
            self.assertNotIn('--disable-render-loop', arguments)
            self.assertEqual(arguments[arguments.index('--fixed-fps') + 1], '60')
            self.assertEqual(arguments[arguments.index('--rendering-method') + 1], 'gl_compatibility')

    def test_layered_idle_rejects_headless_partial_or_missing_pixels(self):
        for marker in [
            'PLAYER_LAYERED_IDLE_VALIDATION checks=200 failures=0 real_gl=true pixels_complete=true',
            'PLAYER_LAYERED_IDLE_VALIDATION checks=212 failures=0 real_gl=false pixels_complete=true',
            'PLAYER_LAYERED_IDLE_VALIDATION checks=211 failures=0 real_gl=true pixels_complete=true',
            'PLAYER_LAYERED_IDLE_VALIDATION checks=212 failures=1 real_gl=true pixels_complete=true',
            'PLAYER_LAYERED_IDLE_VALIDATION checks=212 failures=0 real_gl=true pixels_complete=false',
            'PLAYER_LAYERED_IDLE_VALIDATION checks=212 failures=0 real_gl=true',
        ]:
            with self.subTest(marker=marker):
                result = self.run_engine(f'print({marker!r})\n', suite='player_layered_idle')
                self.assertEqual(result.returncode, 1)
                self.assertIn('completion_marker=False', result.stdout)

    def test_layered_idle_keeps_real_gl_drawing_and_fixed_clock(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            captured = root / 'args'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + 'print("PLAYER_LAYERED_IDLE_VALIDATION checks=212 failures=0 real_gl=true pixels_complete=true")\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            failures = run_suites(str(engine), ['player_layered_idle'], 2, logs, root / 'scratch', True,
                                  {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'})
            self.assertEqual(failures, [])
            arguments = captured.read_text().splitlines()
            self.assertNotIn('--disable-render-loop', arguments)
            self.assertNotIn('--headless', arguments)
            self.assertEqual(arguments[arguments.index('--fixed-fps') + 1], '60')
            self.assertEqual(arguments[arguments.index('--rendering-method') + 1], 'gl_compatibility')

    def test_enemy_atlas_keeps_real_gl_drawing_fixed_clock_and_full_coverage(self):
        marker = 'ENEMY_ATLAS_INTEGRITY checks=3315 failures=0 static_frames=48 playbacks=8'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'fake-godot'
            captured = root / 'args'
            engine.write_text(
                '#!' + sys.executable + '\nimport sys\n'
                + f'print({marker!r})\n'
                + f'open({str(captured)!r}, "w").write("\\n".join(sys.argv[1:]))\n'
            )
            engine.chmod(0o755)
            logs = root / 'logs'
            logs.mkdir()
            failures = run_suites(str(engine), ['enemy_atlas_integrity'], 2, logs, root / 'scratch', True,
                                  {'DISPLAY': 'test-display', 'LIBGL_ALWAYS_SOFTWARE': '1'})
            self.assertEqual(failures, [])
            arguments = captured.read_text().splitlines()
            self.assertNotIn('--disable-render-loop', arguments)
            self.assertNotIn('--headless', arguments)
            self.assertEqual(arguments[arguments.index('--fixed-fps') + 1], '60')
            self.assertEqual(arguments[arguments.index('--rendering-method') + 1], 'gl_compatibility')
        for incomplete in [marker.replace('failures=0', 'failures=1'),
                           marker.replace('static_frames=48', 'static_frames=47'),
                           marker.replace('playbacks=8', 'playbacks=7'),
                           marker.replace('checks=3315', 'checks=0')]:
            with self.subTest(marker=incomplete):
                result = self.run_engine(f'print({incomplete!r})\n', suite='enemy_atlas_integrity')
                self.assertEqual(result.returncode, 1)
                self.assertIn('completion_marker=False', result.stdout)

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
