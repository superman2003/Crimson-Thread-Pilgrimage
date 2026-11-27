#!/usr/bin/env python3
"""Safely list (default dry-run) or untrack unreferenced diagnostic logs/archives in artifacts/.

Protects:
  1. Every top-level artifacts/<dir> directory referenced by CI workflows/contracts (.github/)
     or verifier/test/check scripts (tools/verify_*.py, tools/test_*.py, tools/check_*.py).
  2. Every exact artifacts/... file path or directory prefix referenced in README.md, docs/,
     tools/, godot/, or .github/.
  3. Every .gz / .log basename referenced in tools/.

Usage:
    python3 tools/ci/prune_unreferenced_artifact_logs.py           # Dry-run summary
    python3 tools/ci/prune_unreferenced_artifact_logs.py --execute # git rm unreferenced logs/gz
"""
from __future__ import annotations

import argparse
import fnmatch
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_EXTS = (
    ".log.gz", ".json.gz", ".txt.gz", ".diff.gz", ".gd.gz", ".bak.gz",
    ".py.gz", ".patch.gz", ".tar.gz", ".pre_sync.gz", ".import.gz", ".log",
)
TEXT_SUFFIXES = {".md", ".json", ".py", ".gd", ".yml", ".yaml", ".mjs", ".js", ".txt"}
VERIFIER_PREFIXES = ("verify_", "test_", "check_")


def _is_ci_or_verifier(path: Path, root: Path = ROOT) -> bool:
    rel = path.relative_to(root).as_posix()
    if rel.startswith(".github/"):
        return True
    if rel.startswith("tools/") and path.suffix == ".py" and path.name.startswith(VERIFIER_PREFIXES):
        return True
    return False


def find_unreferenced(root: Path = ROOT, tracked_paths: list[str] | None = None) -> tuple[list[str], set[str]]:
    ref_paths: set[str] = set()
    ref_prefixes: set[str] = set()
    protected_top_dirs: set[str] = set()
    ref_basenames: set[str] = set()
    dynamic_patterns: set[str] = set()

    pat_path = re.compile(r"artifacts/[A-Za-z0-9_./{}$%*:+\-]+")
    pat_dynamic = re.compile(r"\{[^{}]+\}|%[a-zA-Z]|\$[A-Za-z_][A-Za-z_0-9]*")
    pat_base = re.compile(r"[A-Za-z0-9_\-]+\.(?:gz|log)")
    pat_dir_token = re.compile(r"artifacts/([A-Za-z0-9_\-]+)")

    for rel_root in ("README.md", "docs", "tools", "godot", ".github"):
        base = root / rel_root
        paths = [base] if base.is_file() else [
            p for p in base.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES
        ]
        for p in paths:
            try:
                txt = p.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            ci_or_verifier = _is_ci_or_verifier(p, root)
            for m in pat_path.findall(txt):
                cleaned = m.rstrip('.,;:)"\'`')
                if pat_dynamic.search(cleaned):
                    dynamic_patterns.add(pat_dynamic.sub("*", cleaned))
                else:
                    ref_paths.add(cleaned)
                trimmed = cleaned.rstrip("/")
                if trimmed != "artifacts" and (cleaned.endswith("/") or "." not in Path(trimmed).name):
                    ref_prefixes.add(trimmed + "/")
            if ci_or_verifier:
                for top_dir in pat_dir_token.findall(txt):
                    protected_top_dirs.add(top_dir)
            if rel_root == "tools":
                for m in pat_base.findall(txt):
                    ref_basenames.add(m)

    # Protect logs explicitly cited by retained JSON manifests/reports under artifacts/.
    artifacts_dir = root / "artifacts"
    if artifacts_dir.is_dir():
        for manifest in artifacts_dir.rglob("*.json"):
            try:
                txt = manifest.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for m in pat_path.findall(txt):
                cleaned = m.rstrip('.,;:)"\'`')
                if pat_dynamic.search(cleaned):
                    dynamic_patterns.add(pat_dynamic.sub("*", cleaned))
                else:
                    ref_paths.add(cleaned)

    tracked = tracked_paths
    if tracked is None:
        tracked = subprocess.check_output(
            ["git", "ls-files", "artifacts/"], cwd=root, text=True, encoding="utf-8"
        ).splitlines()
    candidates = [f for f in tracked if f.startswith("artifacts/") and f.endswith(TARGET_EXTS)]

    unreferenced: list[str] = []
    for f in candidates:
        parts = f.split("/")
        if len(parts) >= 3 and parts[1] in protected_top_dirs:
            continue
        if f in ref_paths or Path(f).name in ref_basenames:
            continue
        if any(f.startswith(prefix) for prefix in ref_prefixes):
            continue
        if any(fnmatch.fnmatchcase(f, pattern) for pattern in dynamic_patterns):
            continue
        unreferenced.append(f)

    return unreferenced, protected_top_dirs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true", help="Untrack unreferenced files with git rm")
    args = parser.parse_args(argv)

    unreferenced, protected_top_dirs = find_unreferenced(ROOT)
    total_mb = sum((ROOT / f).stat().st_size for f in unreferenced if (ROOT / f).exists()) / (1024 * 1024)
    print(f"Protected CI/verifier artifact directories: {len(protected_top_dirs)}")
    print(f"Unreferenced diagnostic log/gz files in artifacts/: {len(unreferenced)} ({total_mb:.2f} MB)")
    for path in unreferenced:
        print(f"Candidate: {path}")

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
