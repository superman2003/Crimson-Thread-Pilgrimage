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
SCRIPTS = ["danger_caption_groups.gd", "danger_caption_groups_validation.gd", "controller_preferences.gd"]
MARKER = re.compile("^DANGER_CAPTION_GROUPS checks=[1-9][0-9]* failures=0$", re.M)


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
    with tempfile.TemporaryDirectory(prefix="danger_caption_groups-") as scratch:
        project = Path(scratch) / "godot"
        scripts = project / "scripts"
        scripts.mkdir(parents=True)
        for name in SCRIPTS:
            shutil.copy2(ROOT / "godot/scripts" / name, scripts / name)

        source = (ROOT / "godot/scripts/danger_captions.gd").read_text(encoding="utf-8")
        refresh = re.search(r"^func refresh\(.*?(?=^func |\Z)", source, re.M | re.S)
        if refresh is None:raise ValueError("production danger refresh missing")
        host = 'extends Node\nconst MAX_SCAN := 128\nconst GROUPS := preload("res://scripts/danger_caption_groups.gd")\nvar level: Node\nvar ui: Control\nvar panel: PanelContainer\nvar labels: Array[Label]=[]\nvar rows: Array=[]\nvar cursor:=0\nvar scanned:=0\nfunc observe(actor: Node) -> Dictionary:return actor.get_meta("tell",{}).duplicate(true)\n'
        (scripts / "danger_caption_refresh_contract.gd").write_text(host + refresh.group(),encoding="utf-8")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="danger caption groups"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        user = str(Path(scratch) / "userdata")
        env = dict(os.environ, APPDATA=user, XDG_DATA_HOME=user)
        base = [engine, "--headless", "--audio-driver", "Dummy", "--path", str(project)]
        if not invoke(base + ["--editor", "--recovery-mode", "--import", "--quit"], env, args.log_dir / "import.log"):
            return 1
        command = base + ["--script", "res://scripts/danger_caption_groups_validation.gd"]
        passed = invoke(command, env, args.log_dir / "contracts.log")
        output = (args.log_dir / "contracts.log").read_text(encoding="utf-8")
        return 0 if passed and MARKER.search(output) else 1


if __name__ == "__main__":
    raise SystemExit(main())

