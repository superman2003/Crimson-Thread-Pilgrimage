"""Tests for the non-LFS binary budget gate."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_binary_budget as budget  # noqa: E402


class BinaryBudget(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())

    def file(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return name

    def test_pointers_text_and_missing_files_cost_nothing(self):
        names = [self.file("a.png", budget.LFS_POINTER + b"\noid sha256:x\nsize 99999999\n"),
                 self.file("b.json", b"{}" * 10_000_000), "gone.png"]
        self.assertEqual(budget.measure(names, self.root), [])

    def test_large_file_and_total_fail_unless_labelled(self):
        rows = [("huge.png", budget.FILE_LIMIT + 1)]
        self.assertEqual(len(budget.judge(rows, set())[0]), 1)
        many = [(f"f{i}.png", budget.FILE_LIMIT) for i in range(8)]
        errors, total = budget.judge(many, set())
        self.assertTrue(any("non-LFS binaries" in e for e in errors))
        self.assertEqual(budget.judge(many, {budget.OVERRIDE_LABEL})[0], [])

    def test_small_art_passes(self):
        names = [self.file(f"art/{i}.png", b"\x89PNG" + b"0" * 200_000) for i in range(5)]
        rows = budget.measure(names, self.root)
        self.assertEqual(len(rows), 5)
        self.assertEqual(budget.judge(rows, set())[0], [])


if __name__ == "__main__":
    unittest.main()
