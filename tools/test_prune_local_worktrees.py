"""Protect actual Git worktrees and unpublished work during optional cleanup."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import prune_local_worktrees as prune


class WorktreeProtection(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="ctp-prune-test-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name).resolve()
        self.repo = self.root / "repo"
        self.extra = self.root / "extra"
        self.repo.mkdir()
        self.run_git("init", "-b", "main")
        self.run_git("config", "user.name", "Fixture")
        self.run_git("config", "user.email", "fixture@example.invalid")
        self.run_git("remote", "add", "origin", str(self.repo))
        (self.repo / "source.txt").write_text("committed\n", encoding="utf-8")
        self.run_git("add", "source.txt")
        self.run_git("commit", "-qm", "fixture")
        self.run_git("update-ref", "refs/remotes/origin/main", self.run_git("rev-parse", "HEAD"))
        self.run_git("worktree", "add", "-b", "extra", str(self.extra))
        self.run_git("branch", "--set-upstream-to=origin/main", "extra")

    def run_git(self, *args, cwd=None):
        result = subprocess.run(["git", *args], cwd=cwd or self.repo,
                                capture_output=True, text=True, encoding="utf-8")
        result.check_returncode()
        return result.stdout.strip()

    def inspect(self, state="MERGED"):
        with patch.object(prune, "pr_state", return_value=state):
            return prune.inspect({"path": str(self.extra), "branch": "extra"}, self.repo)

    def safe_remove(self):
        # Every recursive Git removal in this fixture is confined to its own
        # resolved temporary root, never the user's repository or worktrees.
        self.assertTrue(self.extra.resolve().is_relative_to(self.root))
        with patch.object(prune, "git", side_effect=lambda *a, **kw: subprocess.run(
                ["git", *a], cwd=self.repo, capture_output=True, text=True)):
            return prune.remove_worktree(self.extra)

    def test_clean_merged_worktree_can_be_removed(self):
        self.assertTrue(self.inspect()["removable"])
        self.assertEqual(self.safe_remove().returncode, 0)
        self.assertFalse(self.extra.exists())

    def test_untracked_authored_file_is_preserved(self):
        draft = self.extra / "new-level.gd"
        draft.write_text("extends Node\n", encoding="utf-8")
        result = self.inspect()
        self.assertFalse(result["removable"])
        self.assertEqual(result["untracked_changes"], 1)
        self.assertNotEqual(self.safe_remove().returncode, 0)
        self.assertEqual(draft.read_text(encoding="utf-8"), "extends Node\n")

    def test_new_file_after_inspection_blocks_removal(self):
        self.assertTrue(self.inspect()["removable"])
        draft = self.extra / "late-draft.json"
        draft.write_text("{}\n", encoding="utf-8")
        self.assertNotEqual(self.safe_remove().returncode, 0)
        self.assertTrue(draft.exists())

    def test_closed_unmerged_branch_is_retained(self):
        (self.extra / "source.txt").write_text("unmerged\n", encoding="utf-8")
        self.run_git("commit", "-qam", "local change", cwd=self.extra)
        self.run_git("update-ref", "refs/remotes/origin/extra", self.run_git("rev-parse", "HEAD", cwd=self.extra))
        self.run_git("branch", "--set-upstream-to=origin/extra", "extra")
        self.assertFalse(self.inspect("CLOSED")["removable"])

    def test_missing_upstream_does_not_prove_unpublished_commits_are_safe(self):
        (self.extra / "source.txt").write_text("unpublished\n", encoding="utf-8")
        self.run_git("commit", "-qam", "unpublished", cwd=self.extra)
        self.run_git("branch", "--unset-upstream", "extra")
        self.assertFalse(self.inspect()["removable"])

    def test_unavailable_process_inventory_keeps_stale_files(self):
        with patch.object(prune.subprocess, "run", side_effect=FileNotFoundError):
            self.assertTrue(prune.git_running())


if __name__ == "__main__":
    unittest.main()
