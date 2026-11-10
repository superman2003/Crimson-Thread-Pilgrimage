"""List (and with --apply, remove) local clutter that slowly fills the disk.

* extra worktrees whose branch's PR is merged or closed, with no tracked changes
  and no unpushed commits (untracked Godot .import/.uid files do not count);
* temporary packs left by interrupted fetches (tmp_pack_*, .tmp-*-pack-*),
  older than an hour and only while no git process is running;
* empty stale ref locks (refs/**/*.lock).

Branches and commits are never deleted; a removed worktree can be re-created
with `git worktree add`. Worktrees with any local work are only reported.

    python3 tools/prune_local_worktrees.py            # report
    python3 tools/prune_local_worktrees.py --apply    # remove what is safe
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def common_dir():
    return Path(git("rev-parse", "--git-common-dir").stdout.strip()).resolve()


def worktrees():
    rows, current = [], {}
    for line in git("worktree", "list", "--porcelain").stdout.splitlines() + [""]:
        if not line:
            if current:
                rows.append(current)
            current = {}
        elif line.startswith("worktree "):
            current["path"] = line.split(" ", 1)[1]
        elif line.startswith("branch "):
            current["branch"] = line.split(" ", 1)[1].removeprefix("refs/heads/")
        elif line == "detached":
            current["branch"] = None
    return rows


def pr_state(branch):
    if not branch:
        return None
    result = subprocess.run(["gh", "pr", "list", "--head", branch, "--state", "all", "--json", "state", "-q", ".[0].state"],
                            cwd=ROOT, capture_output=True, text=True)
    return result.stdout.strip() or None


def inspect(row, main_path):
    path = Path(row["path"])
    if path.resolve() == main_path:
        return None
    tracked = [l for l in git("status", "--porcelain", "-uno", cwd=path).stdout.splitlines() if l.strip()]
    upstream = git("rev-list", "--count", "@{u}..HEAD", cwd=path)
    unpushed = int(upstream.stdout.strip()) if upstream.returncode == 0 else None
    merged_into_main = git("merge-base", "--is-ancestor", "HEAD", "origin/main", cwd=path).returncode == 0
    state = pr_state(row.get("branch"))
    done = state in ("MERGED", "CLOSED") or merged_into_main
    safe = done and not tracked and (unpushed in (0, None) or merged_into_main)
    return dict(path=str(path), branch=row.get("branch"), pr=state, tracked_changes=len(tracked),
                unpushed=unpushed, merged_into_main=merged_into_main, removable=safe)


def git_running():
    return subprocess.run(["pgrep", "-x", "git"], capture_output=True).returncode == 0


def stale_files(git_dir):
    now = time.time()
    packs = [p for pattern in ("tmp_pack_*", ".tmp-*-pack-*") for p in (git_dir / "objects/pack").glob(pattern)]
    locks = [p for p in (git_dir / "refs").rglob("*.lock") if p.stat().st_size == 0]
    return [p for p in packs + locks if now - p.stat().st_mtime > 3600]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    git("fetch", "-q", "origin", "main")
    main_path = Path(git("rev-parse", "--show-toplevel", cwd=common_dir().parent).stdout.strip()).resolve()
    rows = [r for r in (inspect(row, main_path) for row in worktrees()) if r]
    for row in rows:
        flag = "REMOVE" if row["removable"] else "keep  "
        print(f"{flag} {row['path']} [{row['branch']}] pr={row['pr']} tracked={row['tracked_changes']} unpushed={row['unpushed']}")
    junk = stale_files(common_dir())
    for path in junk:
        print(f"STALE  {path} ({path.stat().st_size / 2**20:.0f} MiB)")
    if not args.apply:
        print(json.dumps(dict(removable=sum(r["removable"] for r in rows), stale_files=len(junk), applied=False)))
        return 0
    for row in rows:
        if row["removable"]:
            result = git("worktree", "remove", "--force", row["path"])
            print(("removed " if result.returncode == 0 else "FAILED ") + row["path"] + " " + result.stderr.strip())
    if junk and git_running():
        print("git is running; leaving temporary packs alone")
    else:
        for path in junk:
            path.unlink()
            print("deleted", path)
    git("worktree", "prune")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
