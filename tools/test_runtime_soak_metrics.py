import copy
import unittest
from runtime_soak_metrics import evaluate, MIB


def evidence():
    rows = [{'cycle': 2, 'measured': False, 'orphans': 0}]
    for index, elapsed in enumerate([60, 600, 1200, 1800]):
        rows.append({'cycle': index+3, 'measured': True, 'elapsed_seconds': elapsed,
                     'region': 'demo_ch01_moss_bell_court', 'memory_bytes': 300*MIB,
                     'nodes': 600, 'resources': 1500, 'orphans': 0, 'voices': 2,
                     'music_bookmarks': 6, 'reading_bookmarks': 15})
    return {'measured_seconds': 1800, 'warmup_cycles': 2, 'cycles': 6, 'transitions': 42,
            'deaths': 6, 'ui_opens': 126, 'dialogue_opens': 42, 'observed_defeats': 42,
            'audio_drained': True, 'remaining_voices': 0, 'initial_orphans': 0, 'final_orphans': 0, 'samples': rows, 'failures': []}


class SoakMetrics(unittest.TestCase):
    def test_stable_long_session(self):
        result = evaluate(evidence(), 1800)
        self.assertTrue(result['passed'])
        self.assertTrue(result['long_session'])

    def test_short_smoke_cannot_be_long_acceptance(self):
        result = evidence()
        result['measured_seconds'] = 60
        self.assertTrue(evaluate(result, 60)['passed'])
        self.assertFalse(evaluate(result, 60)['long_session'])
        self.assertFalse(evaluate(result, 1800)['passed'])

    def test_missing_engine_evidence_fails(self):
        self.assertFalse(evaluate({}, 1800)['passed'])

    def test_drift_fails_even_below_net_budget(self):
        result = evidence()
        for index,row in enumerate(result['samples'][1:]): row['memory_bytes'] += index*12*MIB
        self.assertFalse(evaluate(result, 1800)['passed'])

    def test_large_net_growth_fails(self):
        result = evidence()
        result['samples'][-1]['memory_bytes'] += 65*MIB
        self.assertFalse(evaluate(result, 1800)['passed'])

    def test_cache_and_voice_limits_fail(self):
        for field, value in [('music_bookmarks', 9), ('reading_bookmarks', 65), ('voices', 25)]:
            with self.subTest(field=field):
                result = evidence()
                result['samples'][-1][field] = value
                self.assertFalse(evaluate(result, 1800)['passed'])

    def test_orphans_and_audio_retirement_fail(self):
        for field, value in [('audio_drained', False), ('remaining_voices', 1)]:
            result = evidence()
            result[field] = value
            self.assertFalse(evaluate(result, 1800)['passed'])
        result = evidence()
        result['samples'][-1]['orphans'] = 1
        self.assertFalse(evaluate(result, 1800)['passed'])

    def test_missing_actions_cannot_pass(self):
        for field in ['transitions','deaths','ui_opens','dialogue_opens','observed_defeats']:
            result = evidence()
            result[field] = 0
            self.assertFalse(evaluate(result, 1800)['passed'])

    def test_invalid_or_reordered_counters_fail(self):
        for value in [float('nan'), float('inf'), -1, None]:
            result = evidence()
            result['samples'][-1]['memory_bytes'] = value
            self.assertFalse(evaluate(result, 1800)['passed'])
        result = evidence()
        result['samples'][-1]['elapsed_seconds'] = 10
        self.assertFalse(evaluate(result, 1800)['passed'])

    def test_engine_assertion_failure_is_preserved(self):
        result = evidence()
        result['failures'] = ['prior region actor retained']
        original = copy.deepcopy(result)
        self.assertFalse(evaluate(result, 1800)['passed'])
        self.assertEqual(result, original)


if __name__ == '__main__':
    unittest.main()
