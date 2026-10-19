"""Check the merged economy, including both elite and challenge rewards."""
import copy
import unittest
from unittest.mock import patch
import audit_economy

class EconomyAuditTests(unittest.TestCase):
    def test_merged_rewards_keep_late_spending_meaningful(self):
        report, errors = audit_economy.audit()
        self.assertEqual(errors, [])
        self.assertGreater(sum(r["elite_first"] for r in report["regions"].values()), 0)
        self.assertGreater(sum(r["optional_challenges"] for r in report["regions"].values()), 0)
        self.assertGreaterEqual(report["one_time_sinks"], audit_economy.MIN_SINK_SHARE * report["one_time_income"])
        self.assertGreaterEqual(report["one_time_income"], audit_economy.INCOME_HEADROOM * report["one_time_sinks"])

    def test_old_upgrade_prices_fail_after_elite_rewards(self):
        original_load = audit_economy.load
        def old_prices(name):
            data = original_load(name)
            if name == "build_catalog.json":
                data = copy.deepcopy(data)
                for recipe in data["recipes"].values():
                    if recipe["kind"] == "skill": recipe["currency_per_level"] = 30
            return data
        with patch.object(audit_economy, "load", side_effect=old_prices):
            _, errors = audit_economy.audit()
        self.assertTrue(any("late currency has nothing to buy" in error for error in errors), errors)

if __name__ == "__main__":
    unittest.main()
