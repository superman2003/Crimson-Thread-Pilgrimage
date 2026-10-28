#!/usr/bin/env python3
"""Isolated Godot checks of production modules and unmodified UI sources."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
ENTRY = ['material_exchange_desk', 'exchange_stock_plan']
TEST = "scripts/ledger_20261028_05_validation.gd"
MARKER = re.compile(r"^LEDGER_20261028_05 checks=([1-9][0-9]*) failures=0$", re.M)
RESOURCE = re.compile(r"(?:preload|load)\(\s*['\"]res://([^'\"]+)['\"]\s*\)")
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--log-dir", type=Path, required=True)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:parser.error("Godot executable missing")
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ledger-05-") as temporary:
        project = Path(temporary) / "project"
        project.mkdir()
        todo = [Path("scripts/" + name + ".gd") for name in ENTRY] + [Path(TEST)]
        seen = set()
        while todo:
            relative = todo.pop()
            if relative in seen:continue
            seen.add(relative)
            source = ROOT / "godot" / relative
            if not source.is_file():raise FileNotFoundError(source)
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            if source.suffix == ".gd":
                content = source.read_text(encoding="utf-8")
                todo.extend(Path(value) for value in RESOURCE.findall(content))
                todo.extend(Path(value) for value in re.findall(r"^\s*extends\s+['\"]res://([^'\"]+)['\"]", content, re.M))
        shutil.copytree(ROOT / "godot/data", project / "data", dirs_exist_ok=True)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Ledger 05"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        user = str(Path(temporary) / "userdata")
        env = dict(os.environ, APPDATA=user, XDG_DATA_HOME=user, GODOT_SILENCE_ROOT_WARNING="1")
        base = [engine, "--headless", "--audio-driver", "Dummy", "--path", str(project)]
        commands = [("import", base + ["--editor", "--recovery-mode", "--import", "--quit"])]
        commands += [("compile_" + name, base + ["--check-only", "--script", "res://scripts/" + name + ".gd"]) for name in ENTRY]
        commands.append(("behavior", base + ["--script", "res://" + TEST]))
        for name, command in commands:
            try:
                result = subprocess.run(command, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
                output = result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                print("FAIL " + name + ": exceeded 90 seconds")
                return 1
            (args.log_dir / (name + ".log")).write_text(output, encoding="utf-8")
            plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
            invalid = re.search(r"^\s*(?:ERROR:|SCRIPT ERROR:|USER ERROR:|WARNING: ObjectDB)", plain, re.M)
            if result.returncode or invalid:
                print("FAIL " + name + "\n" + output)
                return 1
            if name == "behavior":
                marker = MARKER.search(plain)
                if not marker or int(marker.group(1)) < 12:
                    print("FAIL missing completion contract\n" + output)
                    return 1
                print(marker.group(0))
        print("LEDGER_NATIVE_05 production sources compiled; behavior passed")
    return 0
if __name__ == "__main__":raise SystemExit(main())
