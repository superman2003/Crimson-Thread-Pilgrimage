#!/usr/bin/env python3
"""Build measured Ogg listening candidates from saved Vercel music masters.

No network. Originals, generation receipts and the approved runtime are untouched.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess

from generate_vercel_music_pack import PACK, PLAN, ROOT, dump, now, probe

TARGETS = {"explore":-22, "combat":-20, "boss":-18, "boss_final":-18,
           "lullaby":-26, "ending":-17, "bellway":-24, "drone":-30}


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, encoding="utf-8")


def loudness(path):
    result=run("ffmpeg","-hide_banner","-i",str(path),"-af",
               "loudnorm=I=-18:TP=-2:LRA=11:print_format=json","-f","null","-")
    stats,_=json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind("{"):])
    return {"integrated_lufs":float(stats["input_i"]), "true_peak_dbtp":float(stats["input_tp"])}


def graph(entry, duration):
    if entry["key"].endswith("_jingle"):
        length=min(duration,entry["target_duration_seconds"])
        return f"[0:a]atrim=duration={length},afade=t=out:st={max(0,length-.25)}:d=0.25[loop];"
    if not entry["loop"]:return "[0:a]anull[loop];"
    overlap=3.0
    if duration<=overlap*2:raise ValueError("Loop master is too short for the crossfade")
    return (
        "[0:a]asplit=3[body][tail][head];"
        f"[body]atrim=start={overlap}:end={duration-overlap},asetpts=PTS-STARTPTS[b];"
        f"[tail]atrim=start={duration-overlap},asetpts=PTS-STARTPTS[t];"
        f"[head]atrim=end={overlap},asetpts=PTS-STARTPTS[h];"
        f"[t][h]acrossfade=d={overlap}:c1=qsin:c2=qsin[join];"
        "[b][join]concat=n=2:v=0:a=1[loop];"
    )


def prepare(entry):
    source=PACK/entry["source_file"]
    receipt_path=source.with_suffix(".mp3.receipt.json")
    if not receipt_path.exists():return dict(key=entry["key"],status="not_generated")
    receipt=json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt["status"]!="generated_pending_listening":
        return dict(key=entry["key"],status=receipt["status"])
    source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
    if source_sha!=receipt["sha256"]:raise ValueError("Master hash changed: "+entry["key"])
    target=PACK/entry["candidate_file"]
    report_path=target.with_suffix(".ogg.probe.json")
    if target.exists() and report_path.exists():
        previous=json.loads(report_path.read_text(encoding="utf-8"))
        if previous.get("source_sha256")==source_sha and previous.get("sha256")==hashlib.sha256(target.read_bytes()).hexdigest():
            return previous
        raise ValueError("Existing candidate differs; refusing to overwrite: "+entry["key"])
    if target.exists():raise ValueError("Candidate without a receipt: "+entry["key"])
    target.parent.mkdir(parents=True,exist_ok=True)
    duration=receipt["verification"]["duration_seconds"]
    filters=graph(entry,duration)
    measured=run("ffmpeg","-hide_banner","-i",str(source),"-filter_complex",
        filters+"[loop]loudnorm=I=-18:TP=-2:LRA=11:print_format=json[out]",
        "-map","[out]","-f","null","-")
    stats,_=json.JSONDecoder().raw_decode(measured.stderr[measured.stderr.rfind("{"):])
    desired=TARGETS[entry["category"]]
    if entry["key"]=="boss_final_silent_crown_mvt1":desired=-32
    if entry["key"]=="boss_final_silent_crown_mvt3":desired=-26
    if entry["key"]=="ch06_silent_crown_core_explore_loop":desired=-30
    if entry["key"].endswith("_jingle"):desired=-20
    gain=min(desired-float(stats["input_i"]), -2.0-float(stats["input_tp"]))
    if not math.isfinite(gain):raise ValueError("Silent/invalid source measurement: "+entry["key"])
    partial=target.with_suffix(".partial.ogg")
    run("ffmpeg","-hide_banner","-y","-i",str(source),"-filter_complex",
        filters+f"[loop]volume={gain:.6f}dB[out]","-map","[out]","-ar","48000","-ac","2",
        "-c:a","libvorbis","-q:a","6","-metadata","title="+entry["title"],str(partial))
    info=probe(partial)
    info.update(loudness(partial))
    expected=min(duration,entry["target_duration_seconds"]) if entry["key"].endswith("_jingle") else duration-(3 if entry["loop"] else 0)
    if abs(info["duration_seconds"]-expected)>.2:raise ValueError("Unexpected Ogg duration")
    if info["true_peak_dbtp"]>-.5:raise ValueError("Encoded true peak exceeds headroom")
    if not math.isfinite(info["integrated_lufs"]):raise ValueError("Encoded audio is silent")
    partial.replace(target)
    report=dict(key=entry["key"],title=entry["title"],category=entry["category"],
        status="prepared_pending_listening",source=entry["source_file"],source_sha256=source_sha,
        file=entry["candidate_file"],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        loop=entry["loop"],loop_overlap_seconds=3 if entry["loop"] else 0,
        target_duration_seconds=entry["target_duration_seconds"],
        target_duration_met=abs(info["duration_seconds"]-entry["target_duration_seconds"])<=.2,
        requested_target_lufs=desired,gain_db=gain,synchronization=entry["synchronization"],
        musical_conformance="not_verified_by_listening",verification=info,prepared_at=now())
    dump(report_path,report)
    print("PREPARED",entry["key"],round(info["duration_seconds"],3),"seconds",info["integrated_lufs"],"LUFS",flush=True)
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only",action="append")
    args=parser.parse_args()
    data=json.loads(PLAN.read_text(encoding="utf-8"))
    reports=[]
    for entry in data["entries"]:
        if entry["status"]!="planned" or (args.only and entry["key"] not in args.only):continue
        reports.append(prepare(entry))
    manifest_path=PACK/"manifest.json"
    if args.only and manifest_path.exists():
        previous=json.loads(manifest_path.read_text(encoding="utf-8"))
        merged={e["key"]:e for e in previous["entries"]}
        merged.update({e["key"]:e for e in reports})
        reports=[merged.get(e["key"],dict(key=e["key"],status="not_generated"))
                 for e in data["entries"] if e["status"]=="planned"]
    result=dict(schema=1,updated_at=now(),model=data["model"],provider=data["provider"],
        status="candidates_pending_listening",entries=reports,
        coverage=dict(inventory_roles=34,new_candidates=sum(e["status"]=="prepared_pending_listening" for e in reports),
                      existing_approved=3,intentional_silence=1,
                      pending=[e["key"] for e in reports if e["status"]!="prepared_pending_listening"]),
        runtime_installed=False,existing_approved_tracks_preserved=3,
        limitations=["Musical notes, BPM, voice/lyric compliance and expressive quality require listening.",
                     "The five independently generated combat stems are not sample/phrase aligned; do not layer them with exploration mixes.",
                     "Loop crossfades remove hard discontinuities but musical phrasing still requires listening.",
                     "CH06 ordinary combat is intentionally silent per the specification; no generation request was made for it."])
    dump(manifest_path,result)
    by_key={e["key"]:e for e in reports if e["status"]=="prepared_pending_listening"}
    for e in data["entries"]:
        if e["status"]=="preserved_existing_approved":
            source=(PACK/e["source_file"]).resolve()
            runtime=ROOT/"godot/assets/audio/bgm/ai_generated"/(source.stem+"_loop.ogg")
            by_key[e["key"]]=dict(file=os.path.relpath(runtime,PACK).replace("\\","/"),title=source.stem,
                                  verification={"duration_seconds":117.024})
    inventory=json.loads((ROOT/"output/audio_preview/music_pack_inventory.json").read_text(encoding="utf-8"))
    playlist=["#EXTM3U"]
    for key in inventory["tracks"]:
        if key not in by_key:continue
        e=by_key[key]
        playlist += [f'#EXTINF:{round(e["verification"]["duration_seconds"])},{e.get("title",key)}',e["file"]]
    (PACK/"listen_all.m3u8").write_text("\n".join(playlist)+"\n",encoding="utf-8",newline="\n")
    print("CANDIDATES",sum(e["status"]=="prepared_pending_listening" for e in reports),"of",len(reports),flush=True)


if __name__=="__main__":main()
