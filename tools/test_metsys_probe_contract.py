"""A zero exit or a marker by itself must never pass editor lifecycle QA."""
import unittest
from test_metsys_cold_import import evaluate_output


class ProbeContractTests(unittest.TestCase):
    def test_clean_ready_editor_passes(self):
        self.assertTrue(evaluate_output('cold', 'WARNING: V-Sync unavailable\nMETSYS_EDITOR_READY\n', 0)['passed'])

    def test_zero_exit_with_engine_error_fails(self):
        for output in ['ERROR: bad uid\n', 'SCRIPT ERROR: bad script\n', '\x1b[31mERROR: bad uid\x1b[0m\n']:
            with self.subTest(output=output):
                result = evaluate_output('cold', output + 'METSYS_EDITOR_READY\n', 0)
                self.assertFalse(result['passed'])
                self.assertTrue(result['engine_errors'])

    def test_missing_duplicate_or_non_line_marker_fails(self):
        for output in ['', 'METSYS_EDITOR_READY\nMETSYS_EDITOR_READY\n', 'not ready: METSYS_EDITOR_READY\n']:
            with self.subTest(output=output):
                self.assertFalse(evaluate_output('cold', output, 0)['passed'])

    def test_ready_does_not_hide_failure_exit_or_timeout(self):
        for status in [1, -9, 'timeout']:
            self.assertFalse(evaluate_output('cold', 'METSYS_EDITOR_READY\n', status)['passed'])

    def test_lifetime_warning_is_not_accepted(self):
        for warning in ['ObjectDB instances leaked at exit', '1 RID of type CanvasItem was leaked', 'resources still in use']:
            result = evaluate_output('cold', 'METSYS_EDITOR_READY\nWARNING: ' + warning + '\n', 0)
            self.assertFalse(result['passed'])
            self.assertTrue(result['lifetime_warnings'])

    def test_explicit_early_exit_does_not_require_initialization(self):
        self.assertTrue(evaluate_output('early_exit', '', 0)['passed'])
        self.assertFalse(evaluate_output('cold', '', 0)['passed'])
        self.assertFalse(evaluate_output('early_exit', 'METSYS_EDITOR_READY\nMETSYS_EDITOR_READY\n', 0)['passed'])


if __name__ == '__main__':
    unittest.main()
