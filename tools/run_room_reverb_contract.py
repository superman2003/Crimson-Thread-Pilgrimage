#!/usr/bin/env python3
"""Run isolated real AudioServer room-mix and user-volume contracts."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = (
    "audio_director.gd", "duck_mix.gd", "npc_landmark_schedule.gd",
    "audio_retirement.gd", "music_layer_phase.gd", "spatial_enemy_alert.gd", "landmark_spatial_refresh.gd",
    "room_reverb_validation.gd", "audio_user_volume_validation.gd",
)
MARKER = re.compile(r"^ROOM_REVERB checks=[1-9][0-9]* failures=0$", re.M)


def chapter_fixture_source():
    """Execute Main's exact methods/constants without unrelated scenes or assets."""
    source = (ROOT / "godot/scripts/main_level.gd").read_text(encoding="utf-8")
    blocks = ["extends Node\n"]
    for name in ("REVERB_TIERS", "CHAPTER_REVERB_TIER"):
        match = re.search(r"^const " + name + r" := \{.*?^\}", source, re.M | re.S)
        if match is None:
            raise ValueError("Missing production reverb constant: " + name)
        blocks.append(match.group())
    for name in ("_find_bus_effect", "_apply_chapter_reverb"):
        match = re.search(r"^func " + name + r"\(.*?(?=^func |\Z)", source, re.M | re.S)
        if match is None:
            raise ValueError("Missing production reverb method: " + name)
        blocks.append(match.group())
    return "\n\n".join(blocks)


def invoke(command, env, log, marker=None):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
        output = result.stdout + result.stderr
        good = result.returncode == 0
    except subprocess.TimeoutExpired as exc:
        content = exc.stdout or b""
        output = content.decode(errors="replace") if isinstance(content, bytes) else content
        errors = exc.stderr or b""
        output += errors.decode(errors="replace") if isinstance(errors, bytes) else errors
        output += "\nERROR: room reverb contract exceeded 120 seconds\n"
        good = False
    log.write_text(output, encoding="utf-8")
    plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
    good = good and not re.search(r"^\s*(?:ERROR:|SCRIPT ERROR:|USER ERROR:|WARNING: ObjectDB)", plain, re.M)
    if marker is not None:
        good = good and marker.search(plain) is not None
    print(output, end="")
    return bool(good)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--log-dir", type=Path, required=True)
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:
        parser.error("Godot executable missing")
    args.log_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="crimson-room-reverb-") as scratch:
        project = Path(scratch) / "godot"
        scripts = project / "scripts"
        scripts.mkdir(parents=True)
        for name in SCRIPTS:
            shutil.copy2(ROOT / "godot/scripts" / name, scripts / name)
        mix = ROOT / "godot/scripts/room_reverb_mix.gd"
        if mix.is_file():
            shutil.copy2(mix, scripts / mix.name)
        preferences = ROOT / "godot/scripts/audio_volume_preferences.gd"
        if preferences.is_file():
            shutil.copy2(preferences, scripts / preferences.name)
        (scripts / "chapter_reverb_contract_host.gd").write_text(chapter_fixture_source(), encoding="utf-8")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Room reverb contracts"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        user = str(Path(scratch) / "userdata")
        env = dict(os.environ, APPDATA=user, XDG_DATA_HOME=user)
        base = [engine, "--headless", "--audio-driver", "Dummy", "--path", str(project)]
        if not invoke(base + ["--editor", "--recovery-mode", "--import", "--quit"], env,
                      args.log_dir / "import.log"):
            return 1
        return 0 if invoke(base + ["--script", "res://scripts/room_reverb_validation.gd"], env,
                           args.log_dir / "contracts.log", MARKER) else 1


if __name__ == "__main__":
    raise SystemExit(main())

