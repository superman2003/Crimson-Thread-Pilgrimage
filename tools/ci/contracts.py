"""Run the project's native contract checks from one workflow instead of one workflow each.

Every file in .github/contracts/ is an ordinary single-job GitHub workflow that
GitHub itself does not schedule. `.github/workflows/contracts.yml` asks this tool
which contracts a change touches (their own `paths` filters, GitHub semantics),
installs Godot, LFS assets, packages and the import cache ONCE per shard, then
runs each selected contract's test lines in order with its own RUNNER_TEMP and
Godot user directory. A failing contract never stops the others; the shard
fails at the end with every failure listed.

Setup lines inside a contract (Godot download/unzip, apt, pip, LFS pulls,
project import) are recognised and replaced by the shared setup; everything
else runs verbatim. A workflow this tool cannot run faithfully (matrix, other
actions, unknown expressions, history-dependent checkout) is refused by `lint`,
so it has to stay a real workflow under .github/workflows/ instead.

    python tools/ci/contracts.py lint
    python tools/ci/contracts.py select --files changed.txt --event pull_request --max-shards 8 --out plan.json
    python tools/ci/contracts.py setup --plan plan.json --shard 1          # prints shared needs
    python tools/ci/contracts.py run --plan plan.json --shard 1 --engine ENGINE --work DIR
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import fnmatch
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

import yaml

ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / ".github/contracts"
WORKFLOWS = ROOT / ".github/workflows"
ENGINE_NAME = "Godot_v4.6.1-stable_linux.x86_64"
# Changing the runner itself re-runs every contract.
RUN_ALL_PATHS = ["tools/ci/**", ".github/workflows/contracts.yml", "tools/requirements-hero.txt"]
DEFAULT_TIMEOUT = 30
ALLOWED_ACTIONS = {"actions/checkout", "actions/upload-artifact"}
EXPRESSIONS = {
    # Contracts validate the exact PR head; the shard checks that commit out once.
    "${{ github.event.pull_request.head.sha || github.sha }}": "$CONTRACT_SHA",
    "${{ github.event.pull_request.head.sha }}": "$CONTRACT_SHA",
    "${{ github.token }}": "$GH_TOKEN",
    "${{ runner.temp }}": "$RUNNER_TEMP",
    "${{ github.workspace }}": "$GITHUB_WORKSPACE",
    "${{ github.sha }}": "$GITHUB_SHA",
    "${{ github.repository }}": "$GITHUB_REPOSITORY",
}

SETUP_PATTERNS = [
    re.compile(r"^(GH_TOKEN=\S+\s+)?gh release download .*godot", re.I),
    re.compile(r"^curl .*godotengine/godot/releases", re.I),
    re.compile(r"^unzip .*godot.*\.zip", re.I),
    re.compile(r"^(sudo )?apt-get (update|install)"),
    re.compile(r"^python3? -m pip install"),
    re.compile(r"^pip3? install"),
    re.compile(r"^git lfs (install|pull|checkout|fetch)"),
    re.compile(r"^python3? tools/hydrate_runtime_assets\.py"),
    re.compile(r"^python3? tools/run_godot_import\.py"),
    re.compile(r"^chmod \+x .*Godot", re.I),
    # Manual exact-head checkouts (git init / fetch --depth=1 / checkout FETCH_HEAD).
    re.compile(r"^git init( \.)?$"),
    re.compile(r"^git remote add origin "),
    re.compile(r"^(GIT_LFS_SKIP_SMUDGE=1 )?git fetch --depth[= ]1 origin "),
    re.compile(r"^(GIT_LFS_SKIP_SMUDGE=1 )?git checkout (--detach |-q )*FETCH_HEAD$"),
]


# Argument-free checks that many contracts repeat (npm test, test:campaign, ...).
# Within one shard they run once on the same commit; later contracts reuse the
# recorded exit code instead of spending minutes on an identical run.
PURE = re.compile(r"^(npm test|npm run (check|test:[\w:.-]+)|python3? tools/(test|validate|audit)_\w+\.py)$")
ONCE = r"""ci_once() {
  local key="$CI_ONCE_DIR/$(printf '%s' "$*" | sha1sum | cut -c1-16)"
  if [ -f "$key" ]; then local code; code=$(cat "$key"); echo "[ci_once] reusing exit $code of: $*"; return "$code"; fi
  local code=0; "$@" || code=$?; echo "$code" > "$key"; return "$code"
}
"""
ALWAYS = {"always()", "${{ always() }}", "!cancelled()", "${{ !cancelled() }}", "always() && !cancelled()", "${{ always() && !cancelled() }}"}


def memoised(script: str) -> str:
    return ONCE + "\n".join(("ci_once " + line) if PURE.match(line) else line for line in script.splitlines())


class Unsupported(ValueError):
    pass


@dataclass
class Step:
    name: str
    script: str
    env: dict = field(default_factory=dict)
    directory: str | None = None
    always: bool = False
    real: bool = True


@dataclass
class Contract:
    id: str
    name: str
    source: str
    pr_paths: list | None
    pr_ignore: list | None
    push_paths: list | None
    on_push: bool
    steps: list
    timeout: int
    lfs_includes: set = field(default_factory=set)
    apt: set = field(default_factory=set)
    pip: list = field(default_factory=list)
    imports: bool = False
    engine_dirs: set = field(default_factory=set)
    env: dict = field(default_factory=dict)


# ------------------------------------------------------------------ parsing

def logical_lines(script: str):
    """(raw, bare) per shell line: raw keeps the original physical lines and
    indentation (heredoc bodies depend on it); bare joins backslash
    continuations and trims, for recognising setup commands only."""
    raw_lines, buffer = [], ""
    for raw in script.splitlines():
        raw_lines.append(raw)
        line = raw.rstrip()
        if line.endswith("\\"):
            buffer += line[:-1].strip() + " "
            continue
        yield "\n".join(raw_lines), (buffer + line.strip()).strip()
        raw_lines, buffer = [], ""
    if raw_lines:
        yield "\n".join(raw_lines), buffer.strip()


def substitute(text: str, where: str) -> str:
    for expression, value in EXPRESSIONS.items():
        text = text.replace(expression, value)
    leftover = re.findall(r"\$\{\{[^}]*\}\}", text)
    if leftover:
        raise Unsupported(f"{where}: expression {leftover[0]}")
    return text


def classify(script: str, contract: Contract) -> str:
    """Strip shared-setup lines out of one run script, recording what they needed."""
    kept, real = [], False
    for raw, bare in logical_lines(script):
        if any(p.search(bare) for p in SETUP_PATTERNS):
            # Keep the side effects later lines rely on: the directories an
            # import would have created and the zip a checksum line verifies.
            for directory in re.findall(r"--log-dir[= ]['\"]?([^'\" ]+)", bare):
                kept.append(f'mkdir -p "{directory}"')
            if "godot" in bare.lower() and ("release download" in bare or bare.startswith("curl")):
                for target in dict.fromkeys(re.findall(r"\s-[oO]\s+['\"]?([^'\" ]+)", bare)):
                    kept.append(f'mkdir -p "$(dirname "{target}")" && ln -sf "$CONTRACT_GODOT_ZIP" "{target}"')
            if "apt-get install" in bare:
                contract.apt.update(t for t in bare.split("install", 1)[1].split() if not t.startswith("-"))
            elif "pip" in bare and "install" in bare:
                contract.pip.append(bare)
            elif "lfs" in bare or "hydrate_runtime_assets" in bare:
                for match in re.findall(r"--include[= ]['\"]?([^'\" ]+)", bare):
                    contract.lfs_includes.update(p for p in match.split(",") if p)
                if "--include" not in bare and ("lfs pull" in bare or "hydrate_runtime_assets" in bare):
                    contract.lfs_includes.add("**")
            elif "run_godot_import" in bare:
                contract.imports = True
            elif bare.startswith("unzip"):
                target = re.search(r"-d\s+['\"]?([^'\" ]+)", bare)
                if target:
                    contract.engine_dirs.add(target.group(1))
            continue
        kept.append(raw)
        real = real or bool(bare) and not bare.startswith("#")
    return ("\n".join(kept).strip("\n") if any(line.strip() for line in kept) else ""), real


def triggers(document):
    on = document.get(True, document.get("on"))
    if isinstance(on, str):
        on = {on: None}
    if isinstance(on, list):
        on = {name: None for name in on}
    return on or {}


def load(path: Path) -> Contract:
    text = path.read_text(encoding="utf-8")
    document = yaml.safe_load(text)
    where = path.name
    on = triggers(document)
    if "pull_request" not in on:
        raise Unsupported(f"{where}: not a pull_request check")
    extra = set(on) - {"pull_request", "push", "workflow_dispatch"}
    if extra:
        raise Unsupported(f"{where}: trigger {sorted(extra)}")
    pr = on.get("pull_request") or {}
    push = on.get("push") or {}
    branches = push.get("branches")
    if "push" in on and branches is not None and "main" not in ([branches] if isinstance(branches, str) else branches):
        raise Unsupported(f"{where}: push branches {branches}")
    jobs = document.get("jobs") or {}
    if len(jobs) != 1:
        raise Unsupported(f"{where}: {len(jobs)} jobs")
    (job_id, job), = jobs.items()
    for key in ("strategy", "services", "container", "needs", "if", "outputs"):
        if key in job:
            raise Unsupported(f"{where}: job {key}")
    if not str(job.get("runs-on", "")).startswith("ubuntu"):
        raise Unsupported(f"{where}: runs-on {job.get('runs-on')}")
    contract = Contract(id=path.stem, name=document.get("name", path.stem), source=path.resolve().relative_to(ROOT).as_posix(),
                        pr_paths=pr.get("paths"), pr_ignore=pr.get("paths-ignore"), push_paths=push.get("paths"),
                        on_push="push" in on, steps=[], timeout=int(job.get("timeout-minutes", DEFAULT_TIMEOUT)))
    for scope in (document.get("env") or {}, job.get("env") or {}):
        contract.env.update({k: substitute(str(v), where) for k, v in scope.items()})
    defaults = (job.get("defaults") or {}).get("run") or {}
    if defaults.get("shell") not in (None, "bash"):
        raise Unsupported(f"{where}: shell {defaults.get('shell')}")
    for index, step in enumerate(job.get("steps") or []):
        name = step.get("name") or f"step {index + 1}"
        if "uses" in step:
            action = step["uses"].split("@")[0]
            if action not in ALLOWED_ACTIONS:
                raise Unsupported(f"{where}: uses {action}")
            options = step.get("with") or {}
            if action == "actions/checkout":
                if str(options.get("fetch-depth", 1)) not in ("1",) or options.get("repository") or options.get("submodules"):
                    raise Unsupported(f"{where}: checkout {sorted(options)}")
                if options.get("lfs") in (True, "true"):
                    contract.lfs_includes.add("**")
            continue
        if "run" not in step:
            raise Unsupported(f"{where}: step without run")
        if step.get("shell") not in (None, "bash"):
            raise Unsupported(f"{where}: shell {step.get('shell')}")
        condition = str(step.get("if", "")).strip()
        always = condition in ALWAYS
        if condition and not always:
            raise Unsupported(f"{where}: step if {condition}")
        if step.get("continue-on-error") or step.get("timeout-minutes"):
            raise Unsupported(f"{where}: step continue-on-error/timeout")
        script, real = classify(substitute(step["run"], where), contract)
        env = {k: substitute(str(v), where) for k, v in (step.get("env") or {}).items()}
        if script:
            contract.steps.append(Step(name=name, script=script, env=env, directory=step.get("working-directory"), always=always, real=real))
    if not any(step.real for step in contract.steps):
        raise Unsupported(f"{where}: no test commands left after setup")
    return contract


def load_all(directory: Path = CONTRACTS):
    return [load(path) for path in sorted(directory.glob("*.yml"))]


# ------------------------------------------------------------------ selection

def glob_match(path: str, pattern: str) -> bool:
    """GitHub filter glob: * stays inside a directory, ** crosses directories."""
    regex = ""
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith("**/", i):
            regex += "(?:.*/)?"
            i += 3
            continue
        if pattern.startswith("**", i):
            regex += ".*"
            i += 2
            continue
        if c == "*":
            regex += "[^/]*"
        elif c == "?":
            regex += "[^/]"
        elif c == "[":
            end = pattern.find("]", i)
            if end == -1:
                regex += re.escape(c)
            else:
                regex += pattern[i:end + 1]
                i = end
        else:
            regex += re.escape(c)
        i += 1
    return re.fullmatch(regex, path) is not None


def filter_hits(files, patterns, ignore=False):
    if patterns is None:
        return True
    for path in files:
        decision = None
        for pattern in patterns:
            negate = pattern.startswith("!")
            if glob_match(path, pattern[1:] if negate else pattern):
                decision = not negate
        if ignore:
            if not decision:
                return True
        elif decision:
            return True
    return False


def selected(contract: Contract, files, event: str) -> bool:
    if event == "workflow_dispatch":
        return True
    if any(filter_hits(files, [pattern]) for pattern in RUN_ALL_PATHS):
        return True
    if event == "push":
        if not contract.on_push:
            return False
        return filter_hits(files, contract.push_paths)
    if contract.pr_ignore is not None:
        return filter_hits(files, contract.pr_ignore, ignore=True)
    return filter_hits(files, contract.pr_paths)


def plan(contracts, files, event, max_shards, per_shard_minutes=30, timings=None):
    chosen = [c for c in contracts if selected(c, files, event)]
    timings = timings if timings is not None else default_timings()
    weight = {c.id: float(timings.get(c.id, 3.0)) for c in chosen}
    total = sum(weight.values())
    count = max(1, min(max_shards, math.ceil(total / per_shard_minutes))) if chosen else 0
    shards = [[] for _ in range(count)]
    loads = [0.0] * count
    for contract in sorted(chosen, key=lambda c: (-weight[c.id], c.id)):
        index = loads.index(min(loads))
        shards[index].append(contract.id)
        loads[index] += weight[contract.id]
    return dict(event=event, files=len(files), contracts=len(chosen),
                shards=[dict(index=i + 1, contracts=sorted(s), estimate_minutes=round(loads[i], 1)) for i, s in enumerate(shards)])


# ------------------------------------------------------------------ running

def default_timings():
    path = ROOT / "tools/ci/contract_minutes.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def needs(contracts):
    lfs, apt, pip, imports = set(), set(), [], False
    for contract in contracts:
        lfs |= contract.lfs_includes
        apt |= contract.apt
        imports |= contract.imports
        for line in contract.pip:
            if line not in pip:
                pip.append(line)
    if "**" in lfs:
        lfs = {"**"}
    return dict(lfs=sorted(lfs), apt=sorted(apt), pip=pip, imports=imports)


def read_github_file(path: Path):
    """Parse a $GITHUB_ENV / $GITHUB_PATH style file (KEY=value and KEY<<EOF blocks)."""
    values, lines = {}, path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    i = 0
    while i < len(lines):
        line = lines[i]
        if "<<" in line and "=" not in line.split("<<", 1)[0]:
            key, marker = line.split("<<", 1)
            block = []
            i += 1
            while i < len(lines) and lines[i] != marker:
                block.append(lines[i])
                i += 1
            values[key] = "\n".join(block)
        elif "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
        i += 1
    return values


def run_contract(contract: Contract, engine: Path, work: Path):
    temp = work / contract.id
    temp.mkdir(parents=True, exist_ok=True)
    (work / ".once").mkdir(parents=True, exist_ok=True)
    for directory in contract.engine_dirs or {"$RUNNER_TEMP/godot", "$RUNNER_TEMP/engine"}:
        link = Path(directory.replace("$RUNNER_TEMP", str(temp)).replace("${RUNNER_TEMP}", str(temp)).strip('"'))
        if not link.exists():
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(engine.parent, target_is_directory=True)
    github_env, github_path = temp / "github_env", temp / "github_path"
    env = dict(os.environ, RUNNER_TEMP=str(temp), GITHUB_ENV=str(github_env), GITHUB_PATH=str(github_path),
               CI_ONCE_DIR=str(work / ".once"), XDG_DATA_HOME=str(temp / "xdg-data"), XDG_CONFIG_HOME=str(temp / "xdg-config"), XDG_CACHE_HOME=str(temp / "xdg-cache"))
    env["CONTRACT_SHA"] = env.get("CONTRACT_SHA") or env.get("GITHUB_SHA", "")
    env.update({k: expand(v, env) for k, v in contract.env.items()})
    log = temp / "contract.log"
    deadline = time.monotonic() + contract.timeout * 60
    failed = None
    before = git_status()
    with log.open("w", encoding="utf-8") as out:
        for step in contract.steps:
            if failed and not step.always:
                out.write(f"\n=== SKIPPED {step.name} (an earlier step failed)\n")
                continue
            step_env = dict(env, **read_github_file(github_env))
            step_env.update({k: expand(v, step_env) for k, v in step.env.items()})
            extra_path = github_path.read_text(encoding="utf-8").split() if github_path.exists() else []
            step_env["PATH"] = os.pathsep.join(extra_path + [step_env.get("PATH", "")])
            out.write(f"\n=== {step.name}\n{step.script}\n---\n")
            out.flush()
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                failed = failed or f"timed out before {step.name}"
                break
            try:
                code = subprocess.run(["bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", memoised(step.script)],
                                      cwd=ROOT / (step.directory or "."), env=step_env, stdout=out, stderr=subprocess.STDOUT,
                                      timeout=remaining).returncode
            except subprocess.TimeoutExpired:
                code = "timeout"
            if code != 0 and not failed:
                failed = f"{step.name}: exit {code}"
    changed = sorted(set(git_status()) - set(before))
    if changed:
        # Each original workflow had a fresh checkout; put tracked files back so
        # the next contract in this shard sees the commit, not this one's output.
        subprocess.run(["git", "checkout", "--", *changed], cwd=ROOT, env=dict(os.environ, GIT_LFS_SKIP_SMUDGE="0"),
                       capture_output=True)
        with log.open("a", encoding="utf-8") as out:
            out.write("\nNOTE: restored tracked files the contract modified: " + ", ".join(changed[:20]) + "\n")
    return failed, log


def expand(value: str, env: dict) -> str:
    """$NAME / ${NAME} from the contract environment, as the Actions runner would have."""
    return re.sub(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?", lambda m: env.get(m.group(1), m.group(0)), value)


def git_status():
    result = subprocess.run(["git", "status", "--porcelain", "-uno"], cwd=ROOT, capture_output=True, text=True)
    return [line[3:] for line in result.stdout.splitlines()]


def run_shard(plan_data, shard, engine: Path, work: Path):
    ids = next(s["contracts"] for s in plan_data["shards"] if s["index"] == shard)
    contracts = {c.id: c for c in load_all()}
    results = []
    for contract_id in ids:
        contract = contracts[contract_id]
        start = time.monotonic()
        print(f"::group::{contract.name} ({contract.source})", flush=True)
        failed, log = run_contract(contract, engine, work)
        minutes = (time.monotonic() - start) / 60
        tail = log.read_text(encoding="utf-8", errors="replace").splitlines()
        print("\n".join(tail[-80:] if failed else tail[-15:]), flush=True)
        print("::endgroup::", flush=True)
        status = "FAIL" if failed else "PASS"
        print(f"{status}: {contract.id} {minutes:.1f} min{' - ' + failed if failed else ''}", flush=True)
        if failed:
            print(f"::error title=contract {contract.id}::{failed} (log: {log.name} in artifact)")
        results.append(dict(id=contract.id, name=contract.name, source=contract.source, status=status, minutes=round(minutes, 2), failure=failed))
    (work / f"results-{shard}.json").write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as out:
            out.write(f"### Contracts shard {shard}\n\n| result | contract | minutes | failure |\n| --- | --- | --- | --- |\n")
            for row in sorted(results, key=lambda r: r["status"]):
                out.write(f"| {row['status']} | `{row['id']}` {row['name']} | {row['minutes']} | {row['failure'] or ''} |\n")
    bad = [r for r in results if r["failure"]]
    print(f"CONTRACTS shard={shard} ran={len(results)} failed={len(bad)}")
    return 1 if bad else 0


# ------------------------------------------------------------------ lint

def godot_installer(text: str) -> bool:
    return "godot.zip" in text or ENGINE_NAME in text and "release download" in text


def lint(require_concurrency=True):
    errors = []
    for contract_path in sorted(CONTRACTS.glob("*.yml")):
        try:
            load(contract_path)
        except Unsupported as error:
            errors.append(f"{contract_path.relative_to(ROOT)}: cannot run as a contract ({error}); keep it under .github/workflows")
        if (WORKFLOWS / contract_path.name).exists():
            errors.append(f"{contract_path.name}: exists both as a contract and as a workflow")
    allowed = set(json.loads((ROOT / "tools/ci/workflow_allowlist.json").read_text(encoding="utf-8"))["godot_workflows"])
    for workflow in sorted(WORKFLOWS.glob("*.yml")):
        text = workflow.read_text(encoding="utf-8")
        if godot_installer(text) and workflow.name not in allowed:
            errors.append(f".github/workflows/{workflow.name}: installs Godot itself. Put the check in .github/contracts/{workflow.name} "
                          "(same YAML, run by contracts.yml with shared setup) or justify it in tools/ci/workflow_allowlist.json")
        document = yaml.safe_load(text)
        if require_concurrency and "pull_request" in triggers(document):
            concurrency = document.get("concurrency") or {}
            if not (isinstance(concurrency, dict) and concurrency.get("cancel-in-progress")):
                errors.append(f".github/workflows/{workflow.name}: pull_request workflows need concurrency with cancel-in-progress: true")
    for error in errors:
        print("FAIL:", error)
    print(f"CI_LINT contracts={len(list(CONTRACTS.glob('*.yml')))} workflows={len(list(WORKFLOWS.glob('*.yml')))} errors={len(errors)}")
    return 1 if errors else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("lint")
    p = sub.add_parser("select")
    p.add_argument("--files", type=Path, required=True)
    p.add_argument("--event", default="pull_request")
    p.add_argument("--max-shards", type=int, default=8)
    p.add_argument("--timings", type=Path)
    p.add_argument("--out", type=Path)
    p = sub.add_parser("setup")
    p.add_argument("--plan", type=Path, required=True)
    p.add_argument("--shard", type=int, required=True)
    p = sub.add_parser("run")
    p.add_argument("--plan", type=Path, required=True)
    p.add_argument("--shard", type=int, required=True)
    p.add_argument("--engine", type=Path, required=True)
    p.add_argument("--work", type=Path, required=True)
    p.add_argument("--godot-zip", type=Path)
    args = parser.parse_args()
    if args.command == "lint":
        return lint()
    if args.command == "select":
        files = [line.strip() for line in args.files.read_text(encoding="utf-8").splitlines() if line.strip()]
        timings = json.loads(args.timings.read_text(encoding="utf-8")) if args.timings else None
        data = plan(load_all(), files, args.event, args.max_shards, timings=timings)
        text = json.dumps(data, indent=1)
        if args.out:
            args.out.write_text(text, encoding="utf-8")
        matrix = json.dumps([s["index"] for s in data["shards"]])
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
                out.write(f"shards={matrix}\ncount={len(data['shards'])}\n")
        print(f"CONTRACT_PLAN files={data['files']} contracts={data['contracts']} shards={len(data['shards'])}")
        return 0
    data = json.loads(args.plan.read_text(encoding="utf-8"))
    if args.command == "setup":
        ids = next(s["contracts"] for s in data["shards"] if s["index"] == args.shard)
        contracts = [c for c in load_all() if c.id in ids]
        print(json.dumps(needs(contracts)))
        return 0
    if args.godot_zip:
        os.environ["CONTRACT_GODOT_ZIP"] = str(args.godot_zip.resolve())
    return run_shard(data, args.shard, args.engine, args.work)


if __name__ == "__main__":
    sys.exit(main())
