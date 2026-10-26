"""Prove the CI matrix executes each registered suite exactly once."""
import unittest
import run_godot_regressions as runner

class ShardCoverageTests(unittest.TestCase):
    def test_all_registered_suites_are_covered_once(self):
        suites = runner.DEFAULT_SUITES + runner.NARRATIVE_SUITES
        parts = [runner.select_shard(suites, index, 3) for index in range(1, 4)]
        flattened = [suite for part in parts for suite in part]
        self.assertCountEqual(flattened, suites)
        self.assertEqual(len(flattened), len(set(flattened)))
        self.assertTrue(all(parts))
        self.assertLessEqual(max(map(len, parts)) - min(map(len, parts)), 1)
        for suite in suites:
            self.assertIn(suite, runner.SUCCESS_MARKERS)

    def test_default_invocation_preserves_full_order(self):
        suites = runner.DEFAULT_SUITES + runner.NARRATIVE_SUITES
        self.assertEqual(runner.select_shard(suites, 1, 1), suites)

    def test_invalid_or_empty_shards_cannot_report_success(self):
        for index, count in [(0, 3), (4, 3), (1, 0), (-1, 3), (1, -2), (1, 4)]:
            with self.subTest(index=index, count=count), self.assertRaises(ValueError):
                runner.select_shard(['a', 'b', 'c'], index, count)

if __name__ == '__main__':
    unittest.main()
