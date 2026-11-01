"""Failure propagation must survive a native process that prints a success marker."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
import unittest
from run_heal_hud_contract import invoke

class StrictHealHudRunner(unittest.TestCase):
    def test_workflow_watches_its_real_path(self):
        workflow = Path(__file__).resolve().parents[1] / '.github/workflows/ledger-u03-heal-hud.yml'
        self.assertIn("      - '.github/workflows/ledger-u03-heal-hud.yml'", workflow.read_text())

    def test_native_result_and_diagnostics_are_all_required(self):
        marker = r'^HEAL_RESOURCE_READOUT checks=[1-9][0-9]* failures=0$'
        good = 'HEAL_RESOURCE_READOUT checks=214 failures=0'
        cases = [
            (good, 0, True),
            (good, 1, False),
            ('', 0, False),
            ('HEAL_RESOURCE_READOUT checks=0 failures=0', 0, False),
            ('HEAL_RESOURCE_READOUT checks=214 failures=1', 0, False),
            (good + '\nERROR: decoder failed', 0, False),
            (good + '\nSCRIPT ERROR: invalid call', 0, False),
            (good + '\nUSER ERROR: retirement timed out', 0, False),
            (good + '\n\x1b[31mERROR: hidden by ANSI\x1b[0m', 0, False),
        ]
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'native.log'
            for output, code, expected in cases:
                with self.subTest(output=output, code=code), redirect_stdout(StringIO()):
                    actual = invoke([sys.executable, '-c',
                        'import sys; print(sys.argv[1]); sys.exit(int(sys.argv[2]))',
                        output, str(code)], None, log, marker)
                    self.assertEqual(actual, expected)
                    self.assertIn(output, log.read_text())

if __name__ == '__main__':
    unittest.main()
