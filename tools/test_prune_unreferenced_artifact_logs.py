#!/usr/bin/env python3
"""Test artifact pruning references, dry-run output, and deletion scope."""
from __future__ import annotations

from contextlib import redirect_stdout
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.ci import prune_unreferenced_artifact_logs as pruner


class ArtifactPrunerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for directory in ("docs", "tools", "godot", ".github/contracts"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        (self.root / "README.md").write_text(
            "See artifacts/exact/keep.log for the retained report.\n", encoding="utf-8"
        )
        (self.root / ".github/contracts/used.yml").write_text(
            "path: artifacts/ci_used/\n", encoding="utf-8"
        )
        (self.root / "tools/verify_routes.py").write_text(
            'path = f"artifacts/{chapter}/dynamic.log"\n', encoding="utf-8"
        )
        (self.root / "tools/read_legacy.py").write_text(
            'open("shared.log")\n', encoding="utf-8"
        )
        (self.root / "artifacts/retained").mkdir(parents=True, exist_ok=True)
        (self.root / "artifacts/retained/verification.json").write_text(
            '{"log": "artifacts/retained/diagnostics/run.log.gz"}\n', encoding="utf-8"
        )

        self.tracked = [
            "artifacts/exact/keep.log",
            "artifacts/ci_used/contract.log",
            "artifacts/ch01/dynamic.log",
            "artifacts/archive/shared.log",
            "artifacts/retained/diagnostics/run.log.gz",
            "artifacts/unreferenced/run.log",
            "artifacts/unreferenced/image.png",
            "docs/unrelated.log",
        ]
        for path in self.tracked:
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"fixture")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_reference_rules_keep_exact_ci_dynamic_and_basename_paths(self) -> None:
        candidates, protected = pruner.find_unreferenced(self.root, self.tracked)

        self.assertEqual(candidates, ["artifacts/unreferenced/run.log"])
        self.assertIn("ci_used", protected)

    def test_default_mode_lists_exact_candidates_without_removing_them(self) -> None:
        output = io.StringIO()
        with (
            patch.object(pruner, "ROOT", self.root),
            patch.object(subprocess, "check_output", return_value="\n".join(self.tracked)),
            patch.object(subprocess, "run") as run,
            redirect_stdout(output),
        ):
            result = pruner.main([])

        self.assertEqual(result, 0)
        self.assertIn("Candidate: artifacts/unreferenced/run.log", output.getvalue())
        self.assertIn("Dry-run only", output.getvalue())
        self.assertTrue((self.root / "artifacts/unreferenced/run.log").exists())
        run.assert_not_called()

    def test_execute_only_passes_unreferenced_artifact_candidates_to_git_rm(self) -> None:
        with (
            patch.object(pruner, "ROOT", self.root),
            patch.object(subprocess, "check_output", return_value="\n".join(self.tracked)),
            patch.object(subprocess, "run") as run,
            redirect_stdout(io.StringIO()),
        ):
            result = pruner.main(["--execute"])

        self.assertEqual(result, 0)
        run.assert_called_once_with(
            ["git", "rm", "-q", "--", "artifacts/unreferenced/run.log"],
            cwd=self.root,
            check=True,
        )


if __name__ == "__main__":
    unittest.main()
