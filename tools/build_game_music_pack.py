#!/usr/bin/env python3
"""Install the 33 Music v2.5 cues from retained, verified offline sources."""
from pathlib import Path
import hashlib
import json
import os
import shutil

from generate_vercel_music_pack import PACK, PLAN, ROOT, dump
from prepare_vercel_music_pack import main as prepare


def build():
    plan=json.loads(PLAN.read_text(encoding="utf-8"))
    candidates=json.loads((PACK/"manifest.json").read_text(encoding="utf-8"))
    by_key={e["key"]:e for e in candidates["entries"]}
    old=json.loads((ROOT/"godot/assets/audio/bgm/ai_generated/manifest.json").read_text(encoding="utf-8"))
    trial=json.loads((ROOT/"art_requests/ai_music_v1/trial_batch_20261107.json").read_text(encoding="utf-8"))
    approved_keys={"ch01_cave_loop":0,"ch04_broken_string_greenhouse_explore_loop":1,"boss_rust_crown_loop":2}
    output=ROOT/"godot/assets/audio/bgm/ai_generated"
    entries=[]
    for item in plan["entries"]:
        key=item["key"]
        if item["status"]=="intentional_silence_no_generation":
            entries.append(dict(key=key,status="intentional_silence",runtime="",loop=False,
                                reason=item["reason"]))
            continue
        if item["status"]=="preserved_existing_approved":
            index=approved_keys[key]
            source=ROOT/"art_requests/ai_music_v1"/trial["entries"][index]["local_file"]
            metadata=old["entries"][index]
            if hashlib.sha256(source.read_bytes()).hexdigest()!=metadata["source_sha256"]:
                raise ValueError("Approved source hash mismatch: "+key)
            runtime=metadata["runtime"]
            path=ROOT/"godot"/runtime.removeprefix("res://")
            if hashlib.sha256(path.read_bytes()).hexdigest()!=metadata["sha256"]:
                raise ValueError("Approved loop hash mismatch: "+key)
            entry=dict(key=key,title=metadata["title"],runtime=runtime,loop=True,
                duration_seconds=metadata["duration_seconds"],sha256=metadata["sha256"],
                source=str(source.relative_to(ROOT)).replace("\\","/"),source_sha256=metadata["source_sha256"],
                provider="elevenlabs/music/v2.5 via fal.ai",
                receipt="art_requests/ai_music_v1/trial_batch_20261107.json")
        else:
            metadata=by_key[key]
            if metadata["status"]!="prepared_pending_listening":raise ValueError("Missing prepared cue: "+key)
            source=PACK/item["source_file"]
            candidate=PACK/metadata["file"]
            for path,expected in [(source,metadata["source_sha256"]),(candidate,metadata["sha256"])]:
                if hashlib.sha256(path.read_bytes()).hexdigest()!=expected:raise ValueError("Hash mismatch: "+str(path))
            target=output/(key+".ogg")
            shutil.copy2(candidate,target)
            entry=dict(key=key,title=item["title"],category=item["category"],
                runtime="res://"+str(target.relative_to(ROOT/"godot")).replace("\\","/"),loop=item["loop"],
                duration_seconds=metadata["verification"]["duration_seconds"],sha256=metadata["sha256"],
                source=str(source.relative_to(ROOT)).replace("\\","/"),source_sha256=metadata["source_sha256"],
                provider="elevenlabs/music-v2.5 via Vercel AI Gateway",
                receipt=str(source.relative_to(ROOT)).replace("\\","/")+".receipt.json",
                verification=metadata["verification"],
                requested_duration_seconds=item["target_duration_seconds"],
                musical_conformance="Not independently verified by listening; integration explicitly requested by user.")
        entry["status"]="installed"
        if key.endswith("_combat_layer"):
            entry["mix_policy"]="Standalone encounter cue; exploration pauses. Independent compositions are not layered or phase-locked."
        entries.append(entry)
    dump(output/"music_pack.json",dict(schema=1,status="integrated_by_user_request",roles=34,tracks=33,
        user_authorization="2026-11-08: regenerate missing Boss cue, integrate all music and submit a PR.",
        generator="tools/build_game_music_pack.py",entries=entries))
    candidates.update(runtime_installed=True,status="installed_by_user_request_pending_listening",
                      runtime_manifest="res://assets/audio/bgm/ai_generated/music_pack.json")
    dump(PACK/"manifest.json",candidates)
    playlist=["#EXTM3U"]
    for entry in entries:
        if entry["status"]!="installed":continue
        path=ROOT/"godot"/entry["runtime"].removeprefix("res://")
        playlist += [f'#EXTINF:{round(entry["duration_seconds"])},{entry["title"]}',
                     os.path.relpath(path,PACK).replace("\\","/")]
    (PACK/"listen_all.m3u8").write_text("\n".join(playlist)+"\n",encoding="utf-8",newline="\n")
    print("GAME_MUSIC_PACK roles=34 tracks=33 intentional_silence=1")


if __name__=="__main__":
    prepare()
    build()
