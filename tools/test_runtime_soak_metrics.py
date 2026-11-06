import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from runtime_soak_metrics import evaluate, MIB
from run_runtime_soak import engine_process_id, process_memory_errors, terminate_process_tree


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


class SoakProcessIdentity(unittest.TestCase):
    def test_engine_receipt_is_bound_to_this_run(self):
        with tempfile.TemporaryDirectory() as scratch:
            result = Path(scratch)/'metrics.json'
            receipt = Path(scratch)/'process.json'
            self.assertIsNone(engine_process_id(receipt, result))
            receipt.write_text('{', encoding='utf-8')
            self.assertIsNone(engine_process_id(receipt, result))
            receipt.write_text(json.dumps({'schema':1, 'engine_pid':321, 'output':result.as_posix()}), encoding='utf-8')
            self.assertEqual(engine_process_id(receipt, result), 321)
            self.assertIsNone(engine_process_id(receipt, Path(scratch)/'old.json'))

    def test_invalid_process_receipts_do_not_select_a_pid(self):
        with tempfile.TemporaryDirectory() as scratch:
            result = Path(scratch)/'metrics.json'
            receipt = Path(scratch)/'process.json'
            for value in [None, [], {}, {'schema':True, 'engine_pid':321},
                          *({'schema':1, 'engine_pid':pid} for pid in [None, True, 0, -2, '321', 3.2])]:
                with self.subTest(value=value):
                    if isinstance(value,dict):value['output']=result.as_posix()
                    receipt.write_text(json.dumps(value), encoding='utf-8')
                    self.assertIsNone(engine_process_id(receipt, result))

    def test_actual_child_memory_is_accepted_after_startup(self):
        rows=[{'pid':None,'resident_bytes':None}, {'pid':321,'resident_bytes':400*MIB}]
        self.assertEqual(process_memory_errors(321, {'engine_pid':321}, rows), [])

    def test_console_launcher_cannot_stand_in_for_engine(self):
        rows=[{'pid':123,'resident_bytes':7*MIB}]
        self.assertTrue(process_memory_errors(321, {'engine_pid':321}, rows))
        self.assertTrue(process_memory_errors(123, {'engine_pid':321}, rows))

    def test_missing_or_unreadable_engine_memory_fails(self):
        for rows in [[], [{'pid':None,'resident_bytes':None}],
                     [{'pid':321,'resident_bytes':None}], [{'pid':321,'resident_bytes':0}]]:
            with self.subTest(rows=rows):
                self.assertTrue(process_memory_errors(321, {'engine_pid':321}, rows))

    def test_final_metrics_must_match_engine_identity(self):
        rows=[{'pid':321,'resident_bytes':400*MIB}]
        for result in [{}, {'engine_pid':123}, {'engine_pid':True}, {'engine_pid':'321'}]:
            with self.subTest(result=result):
                self.assertTrue(process_memory_errors(321, result, rows))

    def test_windows_timeout_retires_owned_launcher_tree(self):
        proc=Mock(pid=123)
        proc.poll.return_value=None
        with patch('run_runtime_soak.os.name','nt'), patch('run_runtime_soak.subprocess.run') as run:
            terminate_process_tree(proc)
        self.assertEqual(run.call_args.args[0], ['taskkill','/PID','123','/T','/F'])
        proc.kill.assert_not_called()

    def test_unix_timeout_and_already_exited_process(self):
        proc=Mock(pid=123)
        proc.poll.return_value=None
        with patch('run_runtime_soak.os.name','posix'):
            terminate_process_tree(proc)
        proc.kill.assert_called_once()
        proc.poll.return_value=0
        with patch('run_runtime_soak.subprocess.run') as run:
            terminate_process_tree(proc)
        run.assert_not_called()
        proc.kill.assert_called_once()


if __name__ == '__main__':
    unittest.main()
