"""Reproduce S03 production-hook negative controls and native GL playback checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "8f3048c0c4d8b9456b488173c8ae4700c8f0ec29"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", required=True)
args = parser.parse_args()
out = Path(__file__).resolve().parent / "controls"
out.mkdir(exist_ok=True)
director = ROOT / "godot/scripts/audio_director.gd"
landmark = ROOT / "godot/scripts/npc_sound_landmark.gd"
originals = {path: path.read_bytes() for path in (director, landmark)}
results = []


def invoke(label, negative=False, native=False):
    with tempfile.TemporaryDirectory(prefix="s03-landmark-") as private:
        env = dict(os.environ, APPDATA=private, XDG_DATA_HOME=private)
        display = (["--rendering-method", "gl_compatibility", "--position", "-32000,-32000"]
                   if native else ["--headless"])
        command = [args.engine, *display, "--audio-driver", "Dummy", "--path", str(ROOT / "godot"),
                   "--script", "res://scripts/audio_landmarks_validation.gd"]
        result = subprocess.run(command, env=env, capture_output=True, timeout=180)
        raw = result.stdout + result.stderr
        (out / (label + ".log")).write_bytes(raw)
        plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", raw.decode("utf-8", errors="replace")).replace("\r", "")
        marker = re.search(r"^AUDIO_LANDMARKS checks=(\d+) failures=(\d+)$", plain, re.M)
        passed = marker is not None and "SCRIPT ERROR" not in plain
        if negative:
            passed = passed and result.returncode == 1 and int(marker[2]) > 0
        else:
            passed = passed and result.returncode == 0 and int(marker[2]) == 0
            passed = passed and re.search(r"^\s*(?:ERROR:|WARNING:)", plain, re.M) is None
        record = dict(label=label, exit=result.returncode, negative=negative, passed=bool(passed),
                      marker=marker[0] if marker else None)
        results.append(record)
        print(json.dumps(record), flush=True)
        if not passed:
            print(plain[-4000:], flush=True)
            raise RuntimeError(label + " did not satisfy its expected contract")


try:
    invoke("positive_headless")
    director.write_bytes(subprocess.check_output(["git", "show", BASE + ":godot/scripts/audio_director.gd"], cwd=ROOT))
    try:
        invoke("negative_old_npc_hook", negative=True)
    finally:
        director.write_bytes(originals[director])
    source = originals[landmark].decode("utf-8")
    before = ' if occluded else FILTER.fallback("SFXWorld", FILTER_BUS)'
    assert source.count(before) == 1
    landmark.write_text(source.replace(before, ""), encoding="utf-8")
    try:
        invoke("negative_always_filtered", negative=True)
    finally:
        landmark.write_bytes(originals[landmark])
    invoke("positive_native_gl", native=True)
finally:
    for path, raw in originals.items():
        path.write_bytes(raw)
    restored = all(path.read_bytes() == raw for path, raw in originals.items())
    summary = dict(base=BASE, restored=restored, results=results,
                   source_sha256={path.relative_to(ROOT).as_posix(): hashlib.sha256(raw).hexdigest()
                                  for path, raw in originals.items()})
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    assert restored
