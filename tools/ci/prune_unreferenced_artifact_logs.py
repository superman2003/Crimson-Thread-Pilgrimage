#!/usr/bin/env python3
"""Safely list (default dry-run) or untrack unreferenced diagnostic logs/archives in artifacts/.

Usage:
    python3 tools/ci/prune_unreferenced_artifact_logs.py           # Dry-run summary
    python3 tools/ci/prune_unreferenced_artifact_logs.py --execute # git rm unreferenced logs/gz
"""
from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_EXTS = (
    ".log.gz", ".json.gz", ".txt.gz", ".diff.gz", ".gd.gz", ".bak.gz",
    ".py.gz", ".patch.gz", ".tar.gz", ".pre_sync.gz", ".import.gz", ".log",
)
TEXT_SUFFIXES = {".md", ".json", ".py", ".gd", ".yml", ".yaml", ".mjs", ".js", ".txt"}


def find_unreferenced() -> list[str]:
    ref_paths: set[str] = set()
    ref_basenames: set[str] = set()
    pat_path = re.compile(r"artifacts/[A-Za-z0-9_./\-]+")
    pat_base = re.compile(r"[A-Za-z0-9_\-]+\.(?:gz|log)")

    for rel_root in ("README.md", "docs", "tools", "godot", ".github"):
        base = ROOT / rel_root
        paths = [base] if base.is_file() else [p for p in base.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES]
        for p in paths:
            try:
                txt = p.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for m in pat_path.findall(txt):
                ref_paths.add(m.rstrip('.,;:)"\'`'))
            if rel_root == "tools":
                for m in pat_base.findall(txt):
                    ref_basenames.add(m)

    tracked = subprocess.check_output(["git", "ls-files", "artifacts/"], cwd=ROOT, text=True).splitlines()
    candidates = [f for f in tracked if f.endswith(TARGET_EXTS)]
    return [f for f in candidates if f not in ref_paths and Path(f).name not in ref_basenames]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true", help="Untrack unreferenced files with git rm")
    args = parser.parse_args()

    unreferenced = find_unreferenced()
    total_mb = sum((ROOT / f).stat().st_size for f in unreferenced if (ROOT / f).exists()) / (1024 * 1024)
    print(f"Unreferenced diagnostic log/gz files in artifacts/: {len(unreferenced)} ({total_mb:.2f} MB)")

    if not args.execute or not unreferenced:
        if unreferenced:
            print("Dry-run only. Re-run with --execute to remove them via git rm.")
        return 0

    batch_size = 200
    for i in range(0, len(unreferenced), batch_size):
        subprocess.run(["git", "rm", "-q", "--", *unreferenced[i:i + batch_size]], cwd=ROOT, check=True)
    print(f"Removed {len(unreferenced)} unreferenced files from Git index.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
