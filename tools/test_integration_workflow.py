#!/usr/bin/env python3
"""Keep both independent CI jobs mandatory without dropping existing gates."""
from pathlib import Path
import re
import unittest

WORKFLOW = Path(__file__).resolve().parents[1] / '.github/workflows/godot-integration.yml'
EXPECTED_PIXEL_COMMANDS = (
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/rock-gpu"',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/streaming-gpu" --script ../tools/validate_streaming_pixels.gd --success-marker "STREAMING_PIXELS probes=12 failures=0" --summary-path artifacts/world_streaming/gpu_pixels.json',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/passage-gpu" --script ../tools/validate_passage_pixels.gd --success-marker \'PASSAGE_PIXELS probes=5 failures=0\' --summary-path artifacts/world_passage/gpu_pipe.json',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/room-rims-gpu" --script ../tools/validate_room_rim_pixels.gd --success-marker \'ROOM_RIM_PIXELS probes=12 failures=0\' --summary-path artifacts/world_rims/gpu_rims.json',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/atlas-gpu" --script ../tools/validate_world_atlas_pixels.gd --success-marker \'WORLD_ATLAS_PIXELS probes=5 failures=0\' --summary-path artifacts/world_atlas/gpu_atlas.json',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/neighbor-gameplay-gpu" --script ../tools/validate_neighbor_gameplay_pixels.gd --success-marker \'NEIGHBOR_GAMEPLAY_PIXELS probes=6 failures=0\' --summary-path artifacts/neighbor_gameplay/gpu_gameplay.json',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/neighbor-gameplay-live-gpu" --script res://scripts/world_neighbor_gameplay_live_validation.gd --success-marker \'WORLD_NEIGHBOR_GAMEPLAY_LIVE checks=48 failures=0\' --summary-path artifacts/neighbor_gameplay/gpu_live.json --timeout 300',
    'python3 tools/run_rock_gpu_validation.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/region-commit-gpu" --script ../tools/validate_region_commit_pixels.gd --success-marker \'REGION_COMMIT_PIXELS probes=10 failures=0\' --summary-path artifacts/region_commit/gpu_ui.json',
)


class IntegrationWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.source = WORKFLOW.read_text(encoding='utf-8')
        self.runtime, self.visual = self.source.split('  runtime:\n', 1)[1].split('  visual:\n', 1)

    def test_original_pixel_commands_preserved_exactly_once(self):
        commands = tuple(line.strip() for line in self.visual.splitlines()
                         if line.strip().startswith('python3 tools/run_rock_gpu_validation.py '))
        self.assertEqual(commands, EXPECTED_PIXEL_COMMANDS)
        self.assertNotIn('tools/run_rock_gpu_validation.py', self.runtime)

    def test_complete_runtime_suite_remains_unfiltered_and_drawn(self):
        command = 'npm run test:godot -- --engine "$engine" --software-gl --log-dir "$RUNNER_TEMP/regression-logs"'
        self.assertEqual(self.runtime.count(command), 1)
        self.assertNotIn('npm run test:godot', self.visual)
        self.assertNotIn('--suites', self.runtime)

    def test_jobs_keep_original_bounds_and_strict_failure_behavior(self):
        for job, minutes in ((self.runtime, 60), (self.visual, 45)):
            with self.subTest(job=job[:40]):
                self.assertIn('    timeout-minutes: %d\n' % minutes, job)
                self.assertNotIn('continue-on-error', job)
                self.assertNotIn('|| true', job)
                self.assertNotIn('needs:', job)
                self.assertIn('VALIDATION_SHA: ${{ github.sha }}', job)
                self.assertIn('Godot_v4.6.1-stable_linux.x86_64.zip', job)
                self.assertIn('--recovery-mode --timeout 600', job)
                self.assertIn('sudo apt-get install -y xvfb libgl1-mesa-dri', job)

    def test_distinct_logs_are_preserved_even_on_failure(self):
        for kind, job in (('runtime', self.runtime), ('visual', self.visual)):
            with self.subTest(kind=kind):
                self.assertIn('if: always()', job)
                self.assertIn(f'name: godot-regression-{kind}-logs', job)

    def test_workflow_self_test_runs_in_runtime_job(self):
        self.assertIn('python3 tools/test_integration_workflow.py', self.runtime)

    def test_actual_editor_plugin_gate_is_separate_from_recovery_import(self):
        command = 'python3 tools/test_metsys_cold_import.py --engine "$engine" --log-dir "$RUNNER_TEMP/regression-logs/metsys-editor"'
        self.assertEqual(self.runtime.count(command), 1)
        self.assertNotIn(command, self.visual)
        self.assertIn('python3 tools/test_metsys_probe_contract.py', self.runtime)
        self.assertIn("godot/addons/MetroidvaniaSystem/**", self.runtime)
        self.assertNotIn('--recovery-mode', command)


if __name__ == '__main__':
    unittest.main()
