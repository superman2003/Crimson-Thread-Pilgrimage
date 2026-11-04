"""Keep transient download recovery bounded and permanent failures fatal."""
import subprocess
import signal
import unittest
from unittest.mock import call, patch

import hydrate_runtime_assets as hydration


class HydrationTests(unittest.TestCase):
    @patch.object(hydration.time, 'sleep')
    @patch.object(hydration, 'run_pull')
    def test_batch_failure_recovers_without_changing_required_assets(self, run, sleep):
        run.side_effect = [2, 0]
        self.assertEqual(hydration.hydrate('godot/assets/**'), 0)
        self.assertEqual(run.call_count, 2)
        first, second = run.call_args_list
        self.assertEqual(first, second)
        self.assertIn('--include=godot/assets/**', first.args[0])
        self.assertIn('lfs.concurrenttransfers=3', first.args[0])
        sleep.assert_called_once_with(5)

    @patch.object(hydration.time, 'sleep')
    @patch.object(hydration, 'run_pull')
    def test_persistent_failure_stops_and_keeps_nonzero_exit(self, run, sleep):
        run.return_value = 2
        self.assertEqual(hydration.hydrate(hydration.DEFAULT_INCLUDE), 2)
        self.assertEqual(run.call_count, 3)
        self.assertEqual(sleep.call_args_list, [call(5), call(10)])

    @patch.object(hydration.time, 'sleep')
    @patch.object(hydration, 'run_pull')
    def test_hung_downloads_are_bounded_and_cannot_pass(self, run, sleep):
        run.side_effect = subprocess.TimeoutExpired('git', 300)
        self.assertEqual(hydration.hydrate(hydration.DEFAULT_INCLUDE), 124)
        self.assertEqual(run.call_count, 3)
        self.assertEqual(sleep.call_count, 2)

    @patch.object(hydration.time, 'sleep')
    @patch.object(hydration, 'run_pull')
    def test_success_needs_no_retry(self, run, sleep):
        run.return_value = 0
        self.assertEqual(hydration.hydrate(hydration.DEFAULT_INCLUDE), 0)
        run.assert_called_once()
        sleep.assert_not_called()

    @patch.object(hydration.time, 'sleep')
    @patch.object(hydration, 'run_pull')
    def test_missing_git_is_fatal_without_pointless_retries(self, run, sleep):
        run.side_effect = FileNotFoundError('git')
        self.assertEqual(hydration.hydrate(hydration.DEFAULT_INCLUDE), 127)
        run.assert_called_once()
        sleep.assert_not_called()

    @unittest.skipUnless(hydration.os.name == 'posix', 'CI runs on Ubuntu')
    @patch.object(hydration.os, 'killpg')
    @patch.object(hydration.subprocess, 'Popen')
    def test_timeout_reaps_the_download_group_before_retry(self, popen, killpg):
        process = popen.return_value
        process.pid = 1234
        process.wait.side_effect = [subprocess.TimeoutExpired('git', 300), -9]
        with self.assertRaises(subprocess.TimeoutExpired):
            hydration.run_pull(['git', 'lfs', 'pull'])
        popen.assert_called_once_with(['git', 'lfs', 'pull'], start_new_session=True)
        killpg.assert_called_once_with(1234, signal.SIGKILL)
        self.assertEqual(process.wait.call_args_list, [call(timeout=300), call()])


if __name__ == '__main__':
    unittest.main()
