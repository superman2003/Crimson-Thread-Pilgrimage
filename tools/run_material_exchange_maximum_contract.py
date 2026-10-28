#!/usr/bin/env python3
"""Isolated native contracts with strict completion and diagnostic gates."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ["material_conversion_plan.gd", "material_conversion_plan_source.gd", "material_conversion_plan_dialog.gd", "world_routes.gd", "exchange_stock_plan.gd", "build_system.gd", "field_contracts.gd", "field_transaction.gd", "journey_desk_window.gd", "journey_window_layout.gd", "material_exchange.gd", "material_exchange_desk.gd", "material_exchange_maximum_validation.gd", "resupply_budget.gd", "world_coordinates.gd", "world_state.gd"]
MARKER = re.compile("^MATERIAL_EXCHANGE_MAXIMUM checks=[1-9][0-9]* failures=0$", re.M)


def invoke(command, env, log):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=120)
        output = result.stdout + result.stderr
        passed = result.returncode == 0
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or b""
        output = raw.decode(errors="replace") if isinstance(raw, bytes) else raw
        stderr = error.stderr or b""
        output += stderr.decode(errors="replace") if isinstance(stderr, bytes) else stderr
        output += "\nERROR: contract exceeded 120 seconds\n"
        passed = False
    log.write_text(output, encoding="utf-8")
    plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
    passed = passed and not re.search(r"^\s*(?:ERROR:|SCRIPT ERROR:|USER ERROR:|WARNING: ObjectDB)", plain, re.M)
    print(output, end="")
    return bool(passed)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--log-dir", type=Path, required=True)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if engine is None:
        parser.error("Godot executable missing")
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="material_exchange_maximum-") as scratch:
        project = Path(scratch) / "godot"
        scripts = project / "scripts"
        scripts.mkdir(parents=True)
        for name in SCRIPTS:
            shutil.copy2(ROOT / "godot/scripts" / name, scripts / name)

        shutil.copytree(ROOT / "godot/data", project / "data")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="material exchange maximum"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        user = str(Path(scratch) / "userdata")
        env = dict(os.environ, APPDATA=user, XDG_DATA_HOME=user)
        base = [engine, "--headless", "--audio-driver", "Dummy", "--path", str(project)]
        if not invoke(base + ["--editor", "--recovery-mode", "--import", "--quit"], env, args.log_dir / "import.log"):
            return 1
        command = base + ["--script", "res://scripts/material_exchange_maximum_validation.gd"]
        passed = invoke(command, env, args.log_dir / "contracts.log")
        output = (args.log_dir / "contracts.log").read_text(encoding="utf-8")
        return 0 if passed and MARKER.search(output) else 1


if __name__ == "__main__":
    raise SystemExit(main())

