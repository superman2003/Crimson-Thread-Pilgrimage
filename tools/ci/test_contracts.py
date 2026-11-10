"""Unit tests for the shared contract runner (tools/ci/contracts.py)."""
from __future__ import annotations

import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import textwrap
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import contracts as c  # noqa: E402

GODOT_SETUP = """
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha || github.sha }}
          lfs: false
      - name: Install Godot
        run: |
          git lfs pull --include='godot/assets/**,art_requests/x/*.png'
          GH_TOKEN="${{ github.token }}" gh release download 4.6.1-stable -R godotengine/godot -p "Godot_v4.6.1-stable_linux.x86_64.zip" -O "$RUNNER_TEMP/godot.zip" --clobber || curl --fail --location -o "$RUNNER_TEMP/godot.zip" "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64.zip"
          unzip -q "$RUNNER_TEMP/godot.zip" -d "$RUNNER_TEMP/engine"
          sudo apt-get update -qq
          sudo apt-get install -y xvfb libgl1-mesa-dri
"""


def workflow(steps, on="""  pull_request:
    paths:
      - 'godot/scripts/a*.gd'
      - 'tools/**'
      - '!tools/ignored.py'
  push:
    branches: [main]
""", job_extra=""):
    return textwrap.dedent(f"""\
name: Sample contract
"on":
{on}
jobs:
  verify:
    runs-on: ubuntu-24.04
    timeout-minutes: 7
{job_extra}    steps:
""") + GODOT_SETUP + steps


class Parsing(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def write(self, text, name="sample.yml"):
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return path

    def load(self, text):
        saved = c.ROOT
        c.ROOT = self.tmp
        try:
            return c.load(self.write(text))
        finally:
            c.ROOT = saved

    def test_setup_lines_are_shared_and_tests_kept(self):
        contract = self.load(workflow("""      - name: Import and check
        run: |
          python3 tools/run_godot_import.py --engine "$RUNNER_TEMP/engine/Godot_v4.6.1-stable_linux.x86_64" \\
            --recovery-mode --timeout 600 --log-dir "$RUNNER_TEMP/import"
          python3 tools/check_a.py --engine "$RUNNER_TEMP/engine/Godot_v4.6.1-stable_linux.x86_64"
      - name: Keep logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: logs
          path: ${{ runner.temp }}/logs
"""))
        self.assertEqual([s.script for s in contract.steps], ['python3 tools/check_a.py --engine "$RUNNER_TEMP/engine/Godot_v4.6.1-stable_linux.x86_64"'])
        self.assertTrue(contract.imports)
        self.assertEqual(contract.apt, {"xvfb", "libgl1-mesa-dri"})
        self.assertEqual(contract.lfs_includes, {"godot/assets/**", "art_requests/x/*.png"})
        self.assertEqual(contract.engine_dirs, {"$RUNNER_TEMP/engine"})
        self.assertEqual(contract.timeout, 7)
        self.assertTrue(contract.on_push)

    def test_unfaithful_workflows_are_refused(self):
        cases = {
            "job strategy": workflow("      - run: echo hi\n", job_extra="    strategy:\n      matrix:\n        x: [1, 2]\n"),
            "uses actions/setup-node": workflow("      - uses: actions/setup-node@v4\n      - run: echo hi\n"),
            "expression": workflow("      - run: echo ${{ matrix.shard }}\n"),
            "step if": workflow("      - if: github.event_name == 'push'\n        run: echo hi\n"),
            "no test commands": workflow(""),
            "not a pull_request check": workflow("      - run: echo hi\n", on="  push:\n    branches: [main]\n"),
        }
        for reason, text in cases.items():
            with self.subTest(reason=reason):
                with self.assertRaises(c.Unsupported) as caught:
                    self.load(text)
                self.assertIn(reason.split()[0], str(caught.exception))

    def test_exact_head_checkout_lines_are_setup(self):
        contract = self.load(workflow("""      - name: Manual checkout
        env:
          VALIDATION_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          git init .
          git remote add origin "https://github.com/$GITHUB_REPOSITORY.git"
          GIT_LFS_SKIP_SMUDGE=1 git fetch --depth=1 origin "$VALIDATION_SHA"
          GIT_LFS_SKIP_SMUDGE=1 git checkout --detach FETCH_HEAD
          echo "$VALIDATION_SHA" > "$RUNNER_TEMP/sha"
"""))
        self.assertEqual(contract.steps[0].script, 'echo "$VALIDATION_SHA" > "$RUNNER_TEMP/sha"')
        self.assertEqual(contract.steps[0].env, {"VALIDATION_SHA": "$CONTRACT_SHA"})


class Selection(unittest.TestCase):
    def test_github_glob_semantics(self):
        self.assertTrue(c.glob_match("godot/scripts/abc.gd", "godot/scripts/a*.gd"))
        self.assertFalse(c.glob_match("godot/scripts/sub/abc.gd", "godot/scripts/a*.gd"))
        self.assertTrue(c.glob_match("tools/x/y.py", "tools/**"))
        self.assertTrue(c.glob_match("a/b/c.png", "**/*.png"))
        self.assertTrue(c.glob_match("c.png", "**/*.png"))
        self.assertTrue(c.glob_match("tools/run_a_contract.py", "tools/run_*_contract.py"))

    def test_negation_and_ignore(self):
        self.assertFalse(c.filter_hits(["tools/ignored.py"], ["tools/**", "!tools/ignored.py"]))
        self.assertTrue(c.filter_hits(["tools/ignored.py", "tools/b.py"], ["tools/**", "!tools/ignored.py"]))
        self.assertFalse(c.filter_hits(["docs/a.md"], ["docs/**"], ignore=True))
        self.assertTrue(c.filter_hits(["docs/a.md", "godot/x.gd"], ["docs/**"], ignore=True))

    def contract(self, **kw):
        base = dict(id="x", name="x", source="x", pr_paths=["godot/**"], pr_ignore=None, push_paths=None,
                    on_push=False, steps=[c.Step("s", "true")], timeout=5)
        base.update(kw)
        return c.Contract(**base)

    def test_events(self):
        contract = self.contract()
        self.assertTrue(c.selected(contract, ["godot/a.gd"], "pull_request"))
        self.assertFalse(c.selected(contract, ["docs/a.md"], "pull_request"))
        self.assertFalse(c.selected(contract, ["godot/a.gd"], "push"), "push only when the workflow had a push trigger")
        self.assertTrue(c.selected(self.contract(on_push=True), ["godot/a.gd"], "push"))
        self.assertTrue(c.selected(contract, [], "workflow_dispatch"))
        self.assertTrue(c.selected(contract, ["tools/ci/contracts.py"], "pull_request"), "runner changes re-run everything")

    def test_plan_balances_by_minutes(self):
        contracts = [self.contract(id=f"c{i}") for i in range(6)]
        timings = {"c0": 40, "c1": 20, "c2": 10, "c3": 10, "c4": 5, "c5": 5}
        data = c.plan(contracts, ["godot/a.gd"], "pull_request", max_shards=8, per_shard_minutes=30, timings=timings)
        self.assertEqual(len(data["shards"]), 3)
        self.assertEqual(sorted(x for s in data["shards"] for x in s["contracts"]), [f"c{i}" for i in range(6)])
        self.assertLessEqual(max(s["estimate_minutes"] for s in data["shards"]), 40)
        self.assertEqual(c.plan(contracts, ["docs/a.md"], "pull_request", 8, timings=timings)["shards"], [])
        self.assertEqual(len(c.plan(contracts, ["godot/a.gd"], "pull_request", 2, timings=timings)["shards"]), 2)


class Running(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.engine = self.tmp / "engine/Godot_v4.6.1-stable_linux.x86_64"
        self.engine.parent.mkdir(parents=True)
        self.engine.write_text("#!/bin/sh\necho engine $*\n")
        self.engine.chmod(self.engine.stat().st_mode | stat.S_IEXEC)

    def contract(self, steps, **kw):
        base = dict(id=kw.pop("id", "demo"), name="demo", source="demo", pr_paths=None, pr_ignore=None, push_paths=None,
                    on_push=False, steps=steps, timeout=kw.pop("timeout", 5), engine_dirs={"$RUNNER_TEMP/godot"})
        base.update(kw)
        return c.Contract(**base)

    def test_engine_link_env_file_and_isolated_user_dir(self):
        contract = self.contract([
            c.Step("one", 'echo "GREETING=hi" >> "$GITHUB_ENV"\n"$RUNNER_TEMP/godot/Godot_v4.6.1-stable_linux.x86_64" --version'),
            c.Step("two", 'test "$GREETING" = hi\ntest "$XDG_DATA_HOME" = "$RUNNER_TEMP/xdg-data"\necho "$WHO" > "$RUNNER_TEMP/who"',
                   env={"WHO": "$GREETING-there"}),
        ])
        failed, log = c.run_contract(contract, self.engine, self.tmp / "work")
        self.assertIsNone(failed, log.read_text())
        self.assertIn("engine --version", log.read_text())
        self.assertEqual((self.tmp / "work/demo/who").read_text().strip(), "hi-there")

    def test_failure_skips_rest_but_always_steps_run(self):
        contract = self.contract([
            c.Step("breaks", "false"),
            c.Step("skipped", 'touch "$RUNNER_TEMP/should-not-exist"'),
            c.Step("cleanup", 'touch "$RUNNER_TEMP/cleanup-ran"', always=True),
        ])
        failed, _ = c.run_contract(contract, self.engine, self.tmp / "work")
        self.assertIn("breaks", failed)
        self.assertFalse((self.tmp / "work/demo/should-not-exist").exists())
        self.assertTrue((self.tmp / "work/demo/cleanup-ran").exists())

    def test_pipefail_and_timeout(self):
        failed, _ = c.run_contract(self.contract([c.Step("pipe", "false | true")], id="pipe"), self.engine, self.tmp / "work")
        self.assertIsNotNone(failed, "bash runs with -eo pipefail like Actions")
        slow = self.contract([c.Step("slow", "sleep 5")], id="slow", timeout=0.02)
        failed, _ = c.run_contract(slow, self.engine, self.tmp / "work")
        self.assertIn("timeout", failed)

    def test_identical_pure_checks_run_once_per_shard(self):
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        counter = self.tmp / "count"
        fake = bin_dir / "npm"
        fake.write_text(f'#!/bin/sh\necho x >> "{counter}"\n')
        fake.chmod(0o755)
        saved = os.environ["PATH"]
        os.environ["PATH"] = f"{bin_dir}{os.pathsep}{saved}"
        try:
            for name in ("first", "second"):
                failed, log = c.run_contract(self.contract([c.Step("npm", "npm test")], id=name), self.engine, self.tmp / "work")
                self.assertIsNone(failed, log.read_text())
        finally:
            os.environ["PATH"] = saved
        self.assertEqual(len(counter.read_text().split()), 1)
        self.assertIn("[ci_once] reusing exit 0", (self.tmp / "work/second/contract.log").read_text())

    def test_github_env_heredoc(self):
        path = self.tmp / "env"
        path.write_text("A=1\nB<<EOF\nline1\nline2\nEOF\nC=x=y\n")
        self.assertEqual(c.read_github_file(path), {"A": "1", "B": "line1\nline2", "C": "x=y"})


class Repository(unittest.TestCase):
    def test_every_committed_contract_is_runnable_and_lint_passes(self):
        self.assertEqual(c.lint(), 0)
        self.assertGreater(len(c.load_all()), 100)

    def test_timings_cover_most_contracts(self):
        timings = c.default_timings()
        ids = {contract.id for contract in c.load_all()}
        self.assertGreaterEqual(len(ids & set(timings)) / len(ids), 0.5)


if __name__ == "__main__":
    unittest.main()
