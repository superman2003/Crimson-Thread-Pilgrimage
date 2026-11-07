#!/usr/bin/env python3
"""Build the three approved local MP3s into normalized, wrapped Ogg loops.

No network or generation calls. Sources and the generation receipt are retained
under art_requests/ai_music_v1. Requires ffmpeg/ffprobe on PATH.
"""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_requests/ai_music_v1"
OUTPUT = ROOT / "godot/assets/audio/bgm/ai_generated"
OVERLAP = 3.0


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, encoding="utf-8")


def probe(path):
    return json.loads(run("ffprobe", "-v", "error", "-show_format", "-show_streams",
                          "-of", "json", str(path)).stdout)


def main():
    receipt = json.loads((SOURCE / "trial_batch_20261107.json").read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for entry in receipt["entries"]:
        source = SOURCE / entry["local_file"]
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        assert digest == entry["local_verification"]["sha256"], source
        duration = float(probe(source)["format"]["duration"])
        # Start at t=3s, play the body, then blend the tail into the first 3s.
        # The boundary after the blend continues at t=3s with no silent gap.
        wrap = (
            f"[0:a]asplit=3[body][tail][head];"
            f"[body]atrim=start={OVERLAP}:end={duration-OVERLAP},asetpts=PTS-STARTPTS[b];"
            f"[tail]atrim=start={duration-OVERLAP},asetpts=PTS-STARTPTS[t];"
            f"[head]atrim=end={OVERLAP},asetpts=PTS-STARTPTS[h];"
            f"[t][h]acrossfade=d={OVERLAP}:c1=qsin:c2=qsin[join];"
            "[b][join]concat=n=2:v=0:a=1[loop];"
        )
        measure = run("ffmpeg", "-hide_banner", "-i", str(source), "-filter_complex",
                      wrap + "[loop]loudnorm=I=-18:TP=-2:LRA=11:print_format=json[out]",
                      "-map", "[out]", "-f", "null", "-")
        stats, _ = json.JSONDecoder().raw_decode(measure.stderr[measure.stderr.rfind("{"):])
        # Use constant gain after measurement so normalization cannot change
        # the seam envelope or insert the dynamic loudnorm filter's EOF pad.
        gain_db = min(-18 - float(stats['input_i']), -2 - float(stats['input_tp']))
        normalizer = f"[loop]volume={gain_db:.6f}dB[out]"
        target = OUTPUT / (entry["id"] + "_loop.ogg")
        run("ffmpeg", "-hide_banner", "-y", "-i", str(source), "-filter_complex",
            wrap + normalizer, "-map", "[out]", "-ar", "48000", "-ac", "2",
            "-c:a", "libvorbis", "-q:a", "6", "-metadata", "title=" + entry["title"], str(target))
        info = probe(target)
        verification = run("ffmpeg", "-hide_banner", "-i", str(target), "-af",
                           "loudnorm=I=-18:TP=-2:LRA=11:print_format=json", "-f", "null", "-")
        actual, _ = json.JSONDecoder().raw_decode(verification.stderr[verification.stderr.rfind("{"):])
        stream = next(s for s in info["streams"] if s["codec_type"] == "audio")
        assert stream["codec_name"] == "vorbis" and stream["channels"] == 2
        assert abs(float(info["format"]["duration"]) - (duration - OVERLAP)) < .1
        assert -22 < float(actual["input_i"]) < -17
        assert float(actual["input_tp"]) < -.5
        report = dict(id=entry["id"], title=entry["title"], role=entry["role"],
                      source=source.relative_to(ROOT).as_posix(), source_sha256=digest,
                      runtime="res://" + target.relative_to(ROOT / "godot").as_posix(),
                      sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                      duration_seconds=float(info["format"]["duration"]),
                      gain_db=gain_db,
                      integrated_lufs=float(actual["input_i"]), true_peak_dbtp=float(actual["input_tp"]))
        entries.append(report)
        print(json.dumps(report, ensure_ascii=False), flush=True)
    (OUTPUT / "manifest.json").write_text(json.dumps(dict(
        schema=1, date="2026-11-07", status="approved_and_wired", provider="elevenlabs/music/v2.5 via fal.ai",
        generation_receipt="art_requests/ai_music_v1/trial_batch_20261107.json",
        loop_edit=dict(overlap_seconds=OVERLAP, curve="equal-power", target_lufs=-18, target_dbtp=-2),
        mix_policy="CH01/CH04 full mixes continue through ordinary combat without the unrelated old stems. Boss and shrine transitions retain their existing envelopes.",
        entries=entries), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
