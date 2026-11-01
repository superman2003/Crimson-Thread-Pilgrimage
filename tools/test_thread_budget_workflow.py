"""Reject nonexistent regression suite declarations before costly native CI work."""
from pathlib import Path
import re
import unittest
from run_godot_regressions import suite_path, SUCCESS_MARKERS
ROOT=Path(__file__).resolve().parents[1]
class ThreadWorkflowTests(unittest.TestCase):
    def test_every_declared_suite_exists_and_has_a_strict_marker(self):
        text=(ROOT/'.github/workflows/thread-budget.yml').read_text()
        suites=re.findall(r'--suite\s+([a-z0-9_/]+)',text)
        self.assertEqual(set(suites),{'build_slots_ui','ui_world_integration'})
        for name in suites:
            with self.subTest(suite=name):
                path=ROOT/'godot'/suite_path(name).removeprefix('res://')
                self.assertTrue(path.is_file(),str(path))
                self.assertIn(name,SUCCESS_MARKERS)
                self.assertTrue(SUCCESS_MARKERS[name].startswith('^'))
                self.assertTrue(SUCCESS_MARKERS[name].endswith('$'))
    def test_workflow_checks_its_own_declarations(self):
        text=(ROOT/'.github/workflows/thread-budget.yml').read_text()
        self.assertIn("      - 'tools/test_thread_budget_workflow.py'",text)
        self.assertIn('run: python3 tools/test_thread_budget_workflow.py',text)
if __name__=='__main__':unittest.main()
