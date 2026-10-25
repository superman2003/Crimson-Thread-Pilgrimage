import copy
import json
import unittest
from audit_material_exchange import ROOT, validate

class ExchangeAuditTests(unittest.TestCase):
    def setUp(self):
        data = ROOT / 'godot/data'
        self.configs = {r: json.loads((data / f'{r}.json').read_text()) for r in json.loads((data / 'world_routes.json').read_text())['chapters']}
        self.data = json.loads((data / 'material_exchange.json').read_text())
    def test_canonical(self):
        self.assertEqual(validate(self.data, self.configs), [])
    def test_bad_rates_proofs_and_duplicates_fail(self):
        for field, value in [('output_amount', 3), ('currency', 0), ('output', 'pilgrim_permit_01'), ('requires_item', 'pilgrim_permit_06')]:
            fixture = copy.deepcopy(self.data); fixture['recipes'][0][field] = value
            self.assertTrue(validate(fixture, self.configs), field)
        fixture = copy.deepcopy(self.data); fixture['recipes'][1] = fixture['recipes'][0]
        self.assertTrue(validate(fixture, self.configs))
    def test_cycles_strictly_lose_both_resources(self):
        for region in self.configs:
            candidates = [r for r in self.data['recipes'] if r['region'] == region]
            for outbound in candidates:
                reverse = next(r for r in self.data['recipes'] if r['region'] == outbound['target_region'] and r['target_region'] == region)
                self.assertLess(outbound['output_amount'] * reverse['output_amount'], outbound['input_amount'] * reverse['input_amount'])
                self.assertGreater(outbound['currency'] + reverse['currency'], 0)

if __name__ == '__main__': unittest.main()
