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
SCRIPTS = ["audio_director.gd","audio_volume_preferences.gd","audio_volume_preferences_validation.gd","audio_user_volume_validation.gd","duck_mix.gd","npc_landmark_schedule.gd","audio_retirement.gd","music_layer_phase.gd","spatial_enemy_alert.gd", "landmark_spatial_refresh.gd"]
MARKER = re.compile("^AUDIO_VOLUME_SAVE checks=[1-9][0-9]* failures=0$", re.M)


def invoke(command, env, log):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=120)
        output = result.stdout + result.stderr
        passed = result.returncode == 0
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or b""
        output = raw.decode(errors="replace") if isinstance(raw, bytes) else raw
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
    with tempfile.TemporaryDirectory(prefix="audio-save-") as scratch:
        project = Path(scratch) / "godot"
        scripts = project / "scripts"
        scripts.mkdir(parents=True)
        for name in SCRIPTS:
            shutil.copy2(ROOT / "godot/scripts" / name, scripts / name)
        # S03 may be merged independently before or after this change.
        room_mix = ROOT / "godot/scripts/room_reverb_mix.gd"
        if room_mix.is_file():
            shutil.copy2(room_mix, scripts / room_mix.name)
        source = (ROOT / "godot/scripts/pilgrimage_interface.gd").read_text(encoding="utf-8")
        feedback = re.search(r"^func _audio_save_feedback\(.*?(?=^func |\Z)", source, re.M | re.S)
        if feedback is None:
            raise ValueError("production audio persistence feedback method missing")
        (scripts / "audio_volume_feedback_contract.gd").write_text(
            'extends Node\nvar toast: Label\nvar toast_age := 0.0\nvar last_toast := ""\nvar audio_save_toast := ""\n'
            + feedback.group(),encoding="utf-8")

        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Audio preferences persistence"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        user = str(Path(scratch) / "userdata")
        env = dict(os.environ, APPDATA=user, XDG_DATA_HOME=user)
        base = [engine, "--headless", "--audio-driver", "Dummy", "--path", str(project)]
        if not invoke(base + ["--editor", "--recovery-mode", "--import", "--quit"], env, args.log_dir / "import.log"):
            return 1
        command = base + ["--script", "res://scripts/audio_volume_preferences_validation.gd"]
        passed = invoke(command, env, args.log_dir / "contracts.log")
        output = (args.log_dir / "contracts.log").read_text(encoding="utf-8")
        return 0 if passed and MARKER.search(output) else 1


if __name__ == "__main__":
    raise SystemExit(main())

