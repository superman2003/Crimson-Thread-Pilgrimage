"""Release receipt completion may never mask stderr, timeout or a failed process."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from subprocess import CompletedProcess, TimeoutExpired
from unittest.mock import patch
import tempfile
import unittest
from run_build_receipt_contract import invoke, MARKER

class ReceiptRunnerTests(unittest.TestCase):
    def test_process_marker_and_diagnostics_are_jointly_required(self):
        good='BUILD_RECEIPT checks=40 failures=0\n'
        cases=[(0,good,'',True),(1,good,'',False),(0,'','',False),
               (0,'BUILD_RECEIPT checks=0 failures=0\n','',False),
               (0,'BUILD_RECEIPT checks=40 failures=1\n','',False),
               (0,good,'SCRIPT ERROR: dependency failed\n',False),
               (0,good,'\x1b[31mERROR: resource leaked\x1b[0m\n',False),
               (0,good,'ObjectDB instances leaked\n',False)]
        with tempfile.TemporaryDirectory() as temporary:
            log=Path(temporary)/'native.log'
            for code,out,err,expected in cases:
                with self.subTest(code=code,out=out,err=err), redirect_stdout(StringIO()), patch('run_build_receipt_contract.subprocess.run',return_value=CompletedProcess([],code,out,err)):
                    self.assertEqual(invoke(['fixture'],{},log,MARKER),expected)
                    self.assertEqual(log.read_text(),out+err)
    def test_timeout_preserves_both_streams_without_passing(self):
        with tempfile.TemporaryDirectory() as temporary, redirect_stdout(StringIO()):
            log=Path(temporary)/'native.log'
            with patch('run_build_receipt_contract.subprocess.run',side_effect=TimeoutExpired(['fixture'],120,output=b'partial stdout\n',stderr=b'SCRIPT ERROR: partial stderr\n')):
                self.assertFalse(invoke(['fixture'],{},log,MARKER))
            self.assertIn('partial stdout',log.read_text())
            self.assertIn('partial stderr',log.read_text())
            self.assertIn('timeout',log.read_text())
    def test_workflow_runs_native_world_and_old_reader(self):
        workflow=(Path(__file__).resolve().parents[1]/'.github/workflows/build-receipt.yml').read_text()
        for path in ['tools/run_build_receipt_contract.py','tools/test_build_receipt_runner.py','.github/workflows/build-receipt.yml']:
            self.assertIn("      - '"+path+"'",workflow)
        self.assertIn('tools/run_build_receipt_contract.py --engine',workflow)
        self.assertIn('tools/run_credits_reader_contract.py --engine',workflow)
        self.assertIn('--world',workflow)
if __name__=='__main__':unittest.main()
