"""Mutation coverage for real challenge/material provenance and economy gates."""
import copy
import unittest
from audit_economy import audit, load


class ProofCraftEconomy(unittest.TestCase):
    def setUp(self):
        self.catalog = copy.deepcopy(load("build_catalog.json"))

    def test_complete_campaign_can_fund_every_optional_craft_without_farming(self):
        report, errors = audit(self.catalog)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(report["one_time_income"], 1.5 * report["one_time_sinks"])

    def test_unused_proof_is_rejected(self):
        del self.catalog["recipes"]["craft_tide_reel"]
        self.assertTrue(any("evidence_canal_track" in e and "no growth use" in e for e in audit(self.catalog)[1]))

    def test_sixth_region_material_cannot_be_left_without_a_sink(self):
        self.catalog["recipes"]["craft_crown_pendant"]["materials"] = {"wet_chitin": 3}
        self.assertTrue(any("crown_echo_shard" in e and "no crafting sink" in e for e in audit(self.catalog)[1]))

    def test_fake_proof_does_not_count_as_a_challenge_source(self):
        self.catalog["recipes"]["craft_tide_reel"]["requires_items"].append("invented_proof")
        self.assertTrue(any("invented_proof" in e for e in audit(self.catalog)[1]))

    def test_non_artisan_cannot_be_assigned_a_recipe(self):
        self.catalog["recipes"]["craft_tide_reel"]["artisan"] = "npc_canal_child"
        self.assertTrue(any("not one of the three artisans" in e for e in audit(self.catalog)[1]))


if __name__ == "__main__":
    unittest.main()
