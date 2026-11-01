"""Native shortcut success must include process, diagnostics and completion."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
import unittest

from run_build_shortcut_contract import invoke, MARKER


class BuildShortcutRunnerTests(unittest.TestCase):
    def test_complete_native_result_is_required(self):
        good = 'BUILD_SHORTCUT_CONTRACT checks=24 failures=0'
        cases = [(good, '', 0, True), (good, '', 2, False), ('', '', 0, False),
                 ('BUILD_SHORTCUT_CONTRACT checks=0 failures=0', '', 0, False),
                 ('BUILD_SHORTCUT_CONTRACT checks=24 failures=1', '', 0, False),
                 (good, 'SCRIPT ERROR: failed dependency', 0, False),
                 (good, '\x1b[31mERROR: native exit leak\x1b[0m', 0, False)]
        with tempfile.TemporaryDirectory() as temporary:
            log = Path(temporary) / 'native.log'
            for stdout, stderr, code, expected in cases:
                with self.subTest(stdout=stdout, stderr=stderr, code=code), redirect_stdout(StringIO()):
                    command = [sys.executable, '-c',
                               'import sys; print(sys.argv[1]); print(sys.argv[2],file=sys.stderr); sys.exit(int(sys.argv[3]))',
                               stdout, stderr, str(code)]
                    self.assertEqual(expected, invoke(command, None, log, MARKER))
                    self.assertIn(stdout, log.read_text(encoding='utf-8'))
                    self.assertIn(stderr, log.read_text(encoding='utf-8'))

    def test_timeout_retains_stderr_and_never_passes(self):
        with tempfile.TemporaryDirectory() as temporary, redirect_stdout(StringIO()):
            log = Path(temporary) / 'timeout.log'
            command = [sys.executable, '-c',
                       'import sys,time; print("SCRIPT ERROR: before wait",file=sys.stderr,flush=True); time.sleep(5)']
            self.assertFalse(invoke(command, None, log, MARKER, timeout=1))
            self.assertIn('SCRIPT ERROR: before wait', log.read_text())
            self.assertIn('exceeded', log.read_text())

    def test_workflow_watches_its_own_entry_points(self):
        workflow = Path(__file__).resolve().parents[1] / '.github/workflows/ledger-u06-build-shortcut.yml'
        text = workflow.read_text()
        for path in ('tools/run_build_shortcut_contract.py', 'tools/test_build_shortcut_runner.py',
                     '.github/workflows/ledger-u06-build-shortcut.yml'):
            self.assertIn("      - '" + path + "'", text)


if __name__ == '__main__':
    unittest.main()
