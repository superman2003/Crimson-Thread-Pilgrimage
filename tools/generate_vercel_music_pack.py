#!/usr/bin/env python3
"""Generate the authored BGM pack once per cue; receipts prevent paid retries.

Uses the existing ignored credential and the configured Vercel Music v2.5 route.
Generated masters are candidates, never replacements for approved game assets.
"""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import http.client
import json
from pathlib import Path
import subprocess
import threading
import urllib.error
import urllib.request

from generate_vercel_music import CONFIG, ROOT, load_key

PACK = ROOT / "art_requests/ai_music_v1/vercel_pack_20261107"
PLAN = PACK / "plan.json"
PRINT_LOCK = threading.Lock()

SLUGS = ["moss_bell_court", "rain_foundry_canal", "saltwhite_archive",
         "broken_string_greenhouse", "obsidian_pilgrim_road", "silent_crown_core"]
NAMES = ["苔钟庭", "铸雨渠", "盐白书库", "断弦温室", "黑曜巡礼道", "无声王冠"]
BASE = (
    "Compose original music for Crimson Thread Pilgrimage, a dark fairytale underground "
    "action-adventure. Natural acoustic instruments, expressive phrasing, clear voicing, "
    "transparent mix with space for gameplay sound effects. No imitation of existing music "
    "or named artists, no chiptune, EDM drops, trailer braams or mastering distortion. "
    "Shared original Silent Toll motif: D4 down to A3 then up to B-flat3, then a rest; "
    "leave it unresolved except in endings A and C. Crimson Thread countertheme: "
    "D4 leap to B-flat4, then A4 G4 F4 E4, in plucked timbres. "
)
EXPLORE = {
    2: (104, "92 BPM, G minor, 4/4 with a subtle 2+3+3 eighth-note forge rhythm. "
        "Pitched soft anvil and found metal on D and A, pizzicato double bass, a weary "
        "lyrical solo cello bringing B-flat in a gentle slide. Eternal rain and names "
        "lost in water; melancholy labour rather than action. Keep rain outside the "
        "music: no literal environmental rain recording. Develop a quiet A-B-A-prime "
        "shape, introduce a memorable cello phrase early, generous breathing room."),
    3: (112, "66 BPM, A minor with Lydian raised-fourth colour, precise 4/4. Celesta "
        "and glass harmonica in two transparent contrapuntal voices, the second "
        "entering two beats later with retrograde imitation. A very soft harpsichord "
        "suggests a copying machine. No drums, no heavy bass. Crystal, salt, paper, "
        "pristine dishonest archives. Gradually align the voices, then separate again."),
    5: (96, "100 BPM, D Phrygian, 4/4. Muted low horns and bass trombone, cloth-muted "
        "field snare ghost notes, distant wordless low male choir. A solemn exhausted "
        "pilgrimage of the dead, lanterns in wind. Augment the motif into a slow horn "
        "ostinato, use E-flat as a dark Phrygian neighbour. Quiet march, never a "
        "bombastic military anthem; no literal wind effects. Sparse lyrical middle."),
    6: (128, "Senza misura, no fixed beat. Near-silence and spacious air-like acoustic "
        "resonance. One very distant innocent wordless treble voice only on D and "
        "B-flat; omit A, the pendulum has stopped. Extremely distant D2 bronze bell "
        "every 20 to 30 seconds, long decay. Organised silence should occupy most "
        "of the cue. Brief delicate echoes of celesta, harp and a muted horn, "
        "never all at once. White-gold vacuum before judgement. No percussion."),
}
COMBAT = {
    1: "72 BPM D Dorian 6/8, hand drum and staccato low strings, D-A tension tremolo; warm bronze courtyard.",
    2: "92 BPM G minor 4/4, double-density soft found-metal percussion and bowed bass semitone friction.",
    3: "66 BPM A minor, absolutely NO drums; fast harpsichord sixteenths and high glass tremolo create urgency through density.",
    4: "58 BPM E minor, alternate 5/4 and 6/4; Bartok pizzicato accents, muted woodblock, low E string resonance.",
    5: "100 BPM D Phrygian 4/4; controlled full field snare, short low horn stabs and dark low male wordless pedal.",
}
BOSSES = {
    2: ("绯线执剪者 · 双剪断誓", "138 BPM G minor, then a semitone lift to A-flat minor. "
        "A tiny pitched scissor-like orchestral click introduces an urgent anvil and "
        "string allegro. Two-beat cutting against three-beat sewing hemiola. The cello "
        "motif is interrupted at A; in the second half spinning string figures and "
        "the complete plucked Crimson Thread countertheme challenge the scissors."),
    3: ("灰冠螳将 · 复写的军役", "120 BPM A minor with Lydian colour. Harpsichord motif "
        "followed by a self-copying canon, one new voice every four bars up to four "
        "voices. Bright glass harmonica scythe figures. The second half turns the "
        "phrases backwards in written retrograde, not reversed audio; a plucked "
        "Crimson Thread countertheme remains distinct. Precise, martial, crystalline."),
    4: ("铜根主教 · 根上帕萨卡利亚", "69 BPM E minor passacaglia. Eight-bar pipe-organ "
        "ground bass feels like unstoppable roots. Above it, successive variations "
        "of interrupted bowed strings, bowed glass, col legno and snap pizzicato. "
        "Second half adds solemn wordless choir and a fragile distant wordless "
        "female hum resisting above it; plucked Crimson Thread countertheme. "
        "Sacred pressure, a living greenhouse cathedral, no lyrics or language."),
    5: ("镜池新娘 · 破镜圆舞曲", "A 3/4 waltz, 60 bars per minute (180 quarter-note BPM), "
        "D Phrygian. Brief subtly detuned music-box wedding phrase, then elegant "
        "dangerous chamber strings and triangle on beat one. Ghost field-snare "
        "notes reveal the bride's military past. Second half mirrors the melody "
        "by inversion, then presents original and inverted Crimson Thread figures "
        "a half-beat apart. Graceful tragic dance, lucid orchestration, no circus."),
    6: ("百钥看门人 · 六城点名", "116 BPM, D-centred polytonal quodlibet. Clearly separated "
        "short episodes of bronze bell and harp, forged metal and cello, celesta "
        "canon, broken pizzicato and organ, low horn and muted snare. Tiny bells "
        "and celesta suggest falling keys. Later force the Silent Toll into an "
        "oppressive orchestral unison, challenged by plucked Crimson Thread, "
        "then thin back to a single distant wordless treble voice. No lyrics."),
}
LULLABIES = {
    1: (20, "One warm soft bronze handbell with delicate harp harmonics; moss absorbs the resonance."),
    2: (18, "One worn rusty music-box timbre, softened high frequencies and the faintest tired clockwork; no literal rain."),
    3: (22, "Solo celesta, two honest forward-moving voices following each other, no retrograde, no percussion."),
    4: (24, "An intimate gentle wordless female hum and only a few plucked string harmonics; a singer keeping watch over a sleeping pilgrim."),
    5: (16, "A single muted low horn, soft breath-shaped phrasing like a camp lights-out call, almost no accompaniment."),
    6: (20, "A single distant innocent wordless treble hum that finally reaches B-natural, with a very quiet echo answering."),
}


def now():
    return datetime.now(timezone.utc).isoformat()


def dump(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    temporary.replace(path)


def plan():
    entries = []

    def cue(key, title, role, seconds, detail, *, voices=False, loop=True):
        ending = ("Finish with texture and harmony compatible with the opening, no big final "
                  "cadence, leaving a three-second editable overlap for a smooth game loop. "
                  if loop else "This is a complete one-shot cue: finish deliberately and let the last resonance decay within the duration. ")
        vocal = ("Only wordless humming or vowel choir as specified; NO intelligible words, lyrics, speech or narration. "
                 if voices else "Strictly instrumental; NO vocals, humming, choir, lyrics, speech or narration. ")
        entries.append(dict(key=key, title=title, category=role, status="planned",
            target_duration_seconds=seconds, request_duration_seconds=seconds + (3 if loop else 0),
            loop=loop, force_instrumental=not voices, prompt=BASE + detail + " " + vocal + ending,
            synchronization="unverified_independent_stem_do_not_layer" if role == "combat" else "standalone_mix",
            source_file=f"incoming/{key}.mp3", candidate_file=f"candidates/{key}.ogg"))

    for chapter, (seconds, detail) in EXPLORE.items():
        cue(f"ch{chapter:02}_{SLUGS[chapter-1]}_explore_loop", NAMES[chapter-1] + " · 探索", "explore", seconds, detail, voices=chapter in [5, 6])
    for chapter, (title, detail) in BOSSES.items():
        cue(f"ch{chapter:02}_{SLUGS[chapter-1]}_boss_loop", title, "boss", 120, detail, voices=chapter in [4, 6])
    finals = [
        (1, 60, "无声", "Movement I: extremely sparse near-silence. A muted low heartbeat-like acoustic drum and breath-like bowed air, one swallowed D bell every fifteen seconds, no active melody, no action ostinato. Make the absent ringing palpable.", False),
        (2, 120, "万声", "Movement II: 148 BPM. Bronze bells, forge metal, celesta, broken strings, low horns, snare and wordless treble choir enter in clear stages. Present original, augmented and diminished Silent Toll motifs simultaneously in transparent counterpoint; whole-tone tide clusters rise beneath. Highest plucked strings carry Crimson Thread. Immense emotional pressure, controlled headroom, no wall of noise.", True),
        (3, 60, "抉择", "Movement III: suspended A dominant harmony, unresolved. Low pipe-organ octave, very high flickering glass and a soft timpani swell, long held space rather than a melody. Hold the question of three doors without answering, no tonic resolution.", False),
    ]
    for movement, seconds, title, detail, voices in finals:
        cue(f"boss_final_silent_crown_mvt{movement}", "缄鸣三章 · " + title, "boss_final", seconds, detail, voices=voices)
    for chapter, (seconds, detail) in LULLABIES.items():
        cue(f"ch{chapter:02}_{SLUGS[chapter-1]}_shrine_lullaby", NAMES[chapter-1] + " · 龛中眠", "lullaby", seconds,
            "A tiny safe-rest lullaby. Slow augmented D-A-B-NATURAL motif, its minor second becomes a major second, comforting but never a triumphant cadence. " + detail, voices=chapter in [4, 6])
    for key, title, seconds, detail in [
        ("ending_a_rebell", "结局 A · 重鸣", 60, "At last allow B-flat down to A then home to D, authentic V-I resolution. Real bronze bells together, D major organ and restrained wordless choir; solemn earned renewal. At the very end one faint wordless treble B-flat leaves a tiny shadow within victory."),
        ("ending_b_severance", "结局 B · 断冠", 55, "Build toward a cadence, then interrupt at E-flat with one snapped plucked string. A deceptive V to flat-VI, reversed bronze envelopes and whole-tone tide clusters flood in. Many tiny separate wordless voices finally sound independently, freedom resembling a flood, then retreat to a deep slow pulse. No tonic resolution."),
        ("ending_c_reweave", "结局 C · 绯线重织", 60, "The Silent Toll and Crimson Thread themes finally sound fully at the same time as an intelligible double counterpoint. Add harp, bronze bell, cello, celesta, broken strings and low horn one by one; every lost voice can answer. Begin D minor, earn a Picardy D major ending and allow the motif its full resolution. Tender luminous chamber ensemble, restrained wordless choir, no trailer climax."),
    ]:
        cue(key, title, "ending", seconds, detail, voices=True, loop=False)
    cue("bellway_transit_loop", "钟骨长梯 · 轻铃行旅", "bellway", 60,
        "A friendly quick 3/8 miniature dance, light small handbells and harp plucks, playful diminished Silent Toll variation. Intimate handmade clockwork motion, a warm brief respite, no bombast and no final resolution.")
    cue("bellway_depart_jingle", "钟骨长梯 · 出发", "bellway", 4,
        "A single short ascending bright bell-and-harp departure gesture D5-A5-B5 with a tiny rising mechanical swell. Compact clean game jingle, no introduction and no extra repeat.", loop=False)
    cue("bellway_arrive_jingle", "钟骨长梯 · 到站", "bellway", 4,
        "A single short descending warm bell-and-harp arrival gesture B5-A5-D5 then one delicate D6 bell. Soft falling mechanical motion, compact clean game jingle, no introduction and no extra repeat.", loop=False)
    cue("hidden_black_tide_drone", "深井黑潮 · 水下低语", "drone", 120,
        "Submerged D1 drone in three slowly interfering layers, reversed bronze swells separated by irregular eight-to-thirteen-second breaths, whole-tone C-D-E-F-sharp clusters and falling microtones. Almost nonmusical, no fixed beat. One fleeting very low-pass plucked Crimson Thread phrase beneath the surface, reverse the Silent Toll order. No cheap horror stingers or literal water effects.")
    for chapter, detail in COMBAT.items():
        seconds = {1:117, 2:104, 3:112, 4:117, 5:96}[chapter]
        cue(f"ch{chapter:02}_{SLUGS[chapter-1]}_combat_layer", NAMES[chapter-1] + " · 战斗层候选", "combat", seconds,
            "A sparse isolated accompaniment stem, NOT a full song. No lead melody, long intro or ending, keep fixed tempo and tonal centre. Leave room for a separate exploration melody. " + detail, voices=chapter == 5)
    preserved = [dict(key=key, status="preserved_existing_approved", source_file=file) for key, file in [
        ("ch01_cave_loop", "../incoming/ch01_moss_explore_trial01.mp3"),
        ("boss_rust_crown_loop", "../incoming/ch01_moss_boss_trial01.mp3"),
        ("ch04_broken_string_greenhouse_explore_loop", "../incoming/ch04_greenhouse_explore_trial01.mp3")]]
    entries += preserved
    entries.append(dict(key="ch06_silent_crown_core_combat_layer", status="intentional_silence_no_generation",
                        reason="Spec section 2.7: ordinary encounters remove music entirely."))
    return dict(schema=1, created_at=now(), model="elevenlabs/music-v2.5", provider="vercel_ai_gateway",
        spec="docs/spec/20260726160400000_音效与音乐设计规格.md", entries=entries,
        rate_usd_per_minute=0.07, pricing_source="https://vercel.com/ai-gateway/models/music-v2.5",
        estimated_generation_usd=round(sum(e.get("request_duration_seconds",0) for e in entries)/60*.07,4),
        policy="One paid POST per new receipt. Never retry ambiguous, failed or already recorded submissions. Candidate audio requires listening and musical verification; independent combat stems are not phase aligned.")


def probe(path):
    result = subprocess.run(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)],
                            check=True, capture_output=True, text=True, encoding="utf-8")
    data = json.loads(result.stdout)
    stream = next(s for s in data["streams"] if s["codec_type"] == "audio")
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], check=True, capture_output=True)
    return dict(duration_seconds=float(data["format"]["duration"]), codec=stream["codec_name"],
                sample_rate=int(stream["sample_rate"]), channels=stream["channels"], decoded=True)


def say(*args):
    with PRINT_LOCK:
        print(*args, flush=True)


def generate(entry, config, key, stop):
    target = PACK / entry["source_file"]
    receipt_path = target.with_suffix(".mp3.receipt.json")
    if stop.is_set():
        return dict(key=entry["key"], status="not_submitted_after_failure")
    if target.exists() or receipt_path.exists():
        say("SKIP recorded submission", entry["key"])
        return dict(key=entry["key"], status="recorded_submission_skipped")
    body = dict(text=entry["prompt"], outputFormat="mp3", providerOptions=dict(elevenlabs=dict(
        musicLengthMs=entry["request_duration_seconds"]*1000, forceInstrumental=entry["force_instrumental"])))
    receipt = dict(schema=1, key=entry["key"], model=config["model"], provider=config["preferred_provider"],
                   submitted_at=now(), status="submitted_result_pending", request=body)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation is the guard against concurrent billing for one cue.
    try:
        with receipt_path.open("x", encoding="utf-8", newline="\n") as f:
            json.dump(receipt, f, ensure_ascii=False, indent=2)
    except FileExistsError:
        return dict(key=entry["key"], status="recorded_submission_skipped")
    say("SUBMIT", entry["key"], entry["request_duration_seconds"], "seconds")
    try:
        request = urllib.request.Request(config["endpoint"], data=json.dumps(body).encode("utf-8"), headers={
            "Authorization":"Bearer "+key, "Content-Type":"application/json",
            "ai-gateway-protocol-version":"0.0.1", "ai-speech-model-specification-version":"4", "ai-model-id":config["model"]})
        with urllib.request.urlopen(request, timeout=600) as response:
            receipt["response_ids"] = {name:response.headers[name] for name in ["x-request-id","x-vercel-id"] if response.headers.get(name)}
            result = json.load(response)
        audio = base64.b64decode(result["audio"], validate=True)
        if not audio:
            raise ValueError("Empty audio result")
        with target.open("xb") as f:
            f.write(audio)
        receipt.update(status="generated_pending_probe", sha256=hashlib.sha256(audio).hexdigest(),
                       bytes=len(audio), completed_at=now(), warnings=result.get("warnings",[]))
        dump(receipt_path, receipt)
        verification = probe(target)
        receipt["verification"] = verification
        if abs(verification["duration_seconds"]-entry["request_duration_seconds"]) > 2:
            if entry["key"].endswith("_jingle") and verification["duration_seconds"] >= entry["target_duration_seconds"]:
                receipt["duration_edit_required"] = True
            else:
                raise ValueError("Decoded duration differs from request by more than two seconds")
        receipt.update(status="generated_pending_listening", verification=verification)
        say("GENERATED", entry["key"], round(verification["duration_seconds"],3), "seconds")
    except urllib.error.HTTPError as error:
        receipt.update(status="http_error_no_retry", http_status=error.code,
                       error=error.read(12000).decode("utf-8",errors="replace").replace(key,"[REDACTED]"))
        stop.set()
        say("HTTP_ERROR", entry["key"], error.code)
    except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.RemoteDisconnected) as error:
        receipt.update(status="ambiguous_network_failure_no_retry", error=type(error).__name__)
        stop.set()
        say("NETWORK_ERROR_RECONCILE_BEFORE_RETRY", entry["key"])
    except Exception as error:
        receipt.update(status="result_needs_inspection_no_retry", error=str(error).replace(key,"[REDACTED]"))
        stop.set()
        say("INSPECT_RESULT", entry["key"], type(error).__name__)
    dump(receipt_path, receipt)
    return dict(key=entry["key"], status=receipt["status"])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan-only",action="store_true")
    parser.add_argument("--generate",action="store_true")
    parser.add_argument("--only",action="append")
    parser.add_argument("--workers",type=int,choices=[1,2,3],default=2)
    args=parser.parse_args()
    if not PLAN.exists():dump(PLAN,plan())
    data=json.loads(PLAN.read_text(encoding="utf-8"))
    keys=[e["key"] for e in data["entries"]]
    if len(keys)!=34 or len(set(keys))!=34:raise SystemExit("Expected 34 unique inventory roles")
    if args.only and any(k not in keys for k in args.only):parser.error("Unknown --only cue key")
    eligible=[e for e in data["entries"] if e["status"]=="planned" and (not args.only or e["key"] in args.only)]
    say("PLAN",len(eligible),"new candidates",data["estimated_generation_usd"],"USD estimated for entire pack")
    if args.plan_only or not args.generate:return
    config=json.loads(CONFIG.read_text(encoding="utf-8"))
    if config["model"]!="elevenlabs/music-v2.5" or config["endpoint"]!="https://ai-gateway.vercel.sh/v4/ai/speech-model":
        raise SystemExit("Unexpected provider configuration")
    key=load_key()
    stop=threading.Event()
    results=[]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures=[pool.submit(generate,e,config,key,stop) for e in eligible]
        for future in as_completed(futures):results.append(future.result())
    report=dict(schema=1,updated_at=now(),results=results)
    dump(PACK/"last_run.json",report)
    if stop.is_set():raise SystemExit("Stopped new submissions after a failure; inspect saved receipts. No automatic retries.")


if __name__=="__main__":main()
