"""Gate: a pull request may not quietly add hundreds of megabytes of non-LFS binaries.

Every clone, worktree and CI checkout carries each committed blob forever, so a
PR that commits generation sheets, rejected drafts or full atlas sets straight
into Git (as the v8 motion layer did) slows every later checkout. This check
sums the bytes of added or modified binary files in the PR that are stored as
real blobs (an LFS pointer costs nothing) and fails above the budget. A PR that
really needs more must carry the `large-assets` label, which a maintainer adds
on purpose.

    python tools/ci/check_binary_budget.py --files changed.txt [--labels '["large-assets"]']
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
FILE_LIMIT = 8 * 1024 * 1024
TOTAL_LIMIT = 60 * 1024 * 1024
OVERRIDE_LABEL = "large-assets"
LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"
TEXT_SUFFIXES = {".gd", ".py", ".json", ".md", ".txt", ".yml", ".yaml", ".tscn", ".tres", ".godot", ".cfg",
                 ".js", ".mjs", ".css", ".html", ".csv", ".import", ".uid", ".gdshader", ".svg", ".toml", ".ini"}


def measure(paths, root=ROOT):
    rows = []
    for name in paths:
        path = root / name
        if not path.is_file() or path.suffix.lower() in TEXT_SUFFIXES:
            continue
        with path.open("rb") as handle:
            head = handle.read(len(LFS_POINTER))
        if head == LFS_POINTER:
            continue
        rows.append((name, path.stat().st_size))
    return rows


def judge(rows, labels):
    errors = []
    big = [(name, size) for name, size in rows if size > FILE_LIMIT]
    total = sum(size for _, size in rows)
    for name, size in big:
        errors.append(f"{name}: {size / 2**20:.1f} MiB non-LFS binary (limit {FILE_LIMIT / 2**20:.0f} MiB per file)")
    if total > TOTAL_LIMIT:
        errors.append(f"PR adds {total / 2**20:.1f} MiB of non-LFS binaries (limit {TOTAL_LIMIT / 2**20:.0f} MiB)")
    if errors and OVERRIDE_LABEL in labels:
        return [], total
    return errors, total


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--files", type=Path, required=True)
    parser.add_argument("--labels", default="[]")
    args = parser.parse_args()
    names = [line.strip() for line in args.files.read_text(encoding="utf-8").splitlines() if line.strip()]
    labels = set(json.loads(args.labels or "[]") or [])
    rows = measure(names)
    errors, total = judge(rows, labels)
    for name, size in sorted(rows, key=lambda r: -r[1])[:15]:
        print(f"  {size / 2**20:8.2f} MiB  {name}")
    for error in errors:
        print("FAIL:", error)
    if errors:
        print(f"Store large art with Git LFS, keep drafts/rejected sheets out of Git, or ask for the '{OVERRIDE_LABEL}' label.")
    print(f"BINARY_BUDGET files={len(rows)} total_mib={total / 2**20:.1f} override={OVERRIDE_LABEL in labels} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
