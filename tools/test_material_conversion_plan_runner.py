"""A completed-looking transaction receipt report cannot hide process/engine failure."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from subprocess import CompletedProcess, TimeoutExpired
from unittest.mock import patch
import tempfile
import unittest
import re
from run_material_conversion_plan_contract import invoke, MARKER
from run_godot_regressions import suite_path, SUCCESS_MARKERS
class MaterialConversionPlanRunnerTests(unittest.TestCase):
    def test_completion_requires_process_marker_and_clean_diagnostics(self):
        good='MATERIAL_CONVERSION_PLAN checks=29 failures=0\n'
        cases=[(0,good,'',True),(1,good,'',False),(0,'','',False),
               (0,'MATERIAL_CONVERSION_PLAN checks=0 failures=0\n','',False),
               (0,'MATERIAL_CONVERSION_PLAN checks=29 failures=1\n','',False),
               (0,good,'SCRIPT ERROR: unresolved dependency\n',False),
               (0,good,'\x1b[31mERROR: lifecycle failure\x1b[0m\n',False),
               (0,good,'ObjectDB instances leaked\n',False)]
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/'result.log'
            for code,out,err,expected in cases:
                with self.subTest(code=code,out=out,err=err),redirect_stdout(StringIO()),patch('run_material_conversion_plan_contract.subprocess.run',return_value=CompletedProcess([],code,out,err)):
                    self.assertEqual(invoke(['fixture'],{},path,MARKER),expected)
                    self.assertEqual(path.read_text(),out+err)
    def test_timeout_preserves_both_streams_and_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temporary,redirect_stdout(StringIO()):
            path=Path(temporary)/'timeout.log'
            with patch('run_material_conversion_plan_contract.subprocess.run',side_effect=TimeoutExpired(['fixture'],120,output=b'partial report\n',stderr=b'SCRIPT ERROR: before wait\n')):
                self.assertFalse(invoke(['fixture'],{},path,MARKER))
            self.assertIn('partial report',path.read_text());self.assertIn('before wait',path.read_text());self.assertIn('timeout',path.read_text())
    def test_workflow_declares_real_existing_regressions(self):
        root=Path(__file__).resolve().parents[1]
        text=(root/'.github/workflows/material-conversion-plan-wip.yml').read_text()
        names=set(re.findall(r'--suite\s+([a-z0-9_/]+)',text))
        self.assertEqual(names,{'material_exchange','field_contracts','ui_world_integration'})
        for name in names:
            self.assertTrue((root/'godot'/suite_path(name).removeprefix('res://')).is_file())
            self.assertIn(name,SUCCESS_MARKERS)
        self.assertIn("      - 'tools/test_material_conversion_plan_runner.py'",text)
        self.assertIn('--world',text)
if __name__=='__main__':unittest.main()
