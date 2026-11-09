#!/usr/bin/env python3
"""Open a local 33-track listening library and isolated gameplay previews."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output/music_library"
READY = OUTPUT / "import-ready.json"
GROUPS = {"explore":"区域探索", "combat":"遇敌战斗", "boss":"守门者 / Boss",
          "boss_final":"终战三乐章", "lullaby":"钟龛休息", "ending":"三种结局",
          "bellway":"钟骨长梯", "drone":"隐藏区域"}
REGIONS = ["moss_bell_court", "rain_foundry_canal", "saltwhite_archive",
           "broken_string_greenhouse", "obsidian_pilgrim_road", "silent_crown_core"]
NAMES = ["苔钟庭", "铸雨渠", "盐白书库", "断弦温室", "黑曜巡礼道", "无声王冠"]


def engine_path(override=None):
    choices=[override,os.environ.get("GODOT"),ROOT/"output/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe",shutil.which("godot"),
        Path.home()/"Tools/Godot/Godot_v4.6-stable_win64_console.exe"]
    for choice in choices:
        if choice and Path(choice).is_file():return str(Path(choice).resolve())
    raise RuntimeError("Godot was not found. Pass --engine or set GODOT.")


def catalog():
    original=json.loads((ROOT/"godot/assets/audio/bgm/ai_generated/music_pack.json").read_text(encoding="utf-8"))
    rows=[]
    for entry in original["entries"]:
        if entry["status"]!="installed":continue
        row=dict(entry)
        key=row["key"]
        category=row.get("category") or ("boss" if key=="boss_rust_crown_loop" else "explore")
        chapter=next((n for n in range(1,7) if key.startswith(f"ch{n:02}_")),
                     1 if key=="boss_rust_crown_loop" or key.startswith("bellway") else 6)
        row.update(category=category,group=GROUPS[category],chapter=chapter,region=NAMES[chapter-1],
                   config="res://data/demo_ch%02d_%s.json" % (chapter,REGIONS[chapter-1]),
                   title=row["title"].replace("战斗层候选","遇敌战斗"),
                   audio_path=str((ROOT/"godot"/row["runtime"].removeprefix("res://")).resolve()))
        row["time"]="%d:%02d" % divmod(round(row["duration_seconds"]),60)
        row["description"]={
            "explore":"本区探索配乐；区域试玩会随遇敌、钟龛和 Boss 状态自动选曲。",
            "combat":"本区普通遇敌配乐；区域试玩中脱战后会恢复探索曲。",
            "boss":"本区 Boss 配乐；区域列表的“Boss 起点”可直接进入战斗。",
            "boss_final":"终战三乐章之一；区域试玩中随 Boss 阶段切换。",
            "lullaby":"本区钟龛休息配乐；离开钟龛后恢复探索曲。",
            "ending":"结局配乐，可在这里完整试听。",
            "bellway":"钟骨长梯旅行配乐或出发、到站短提示音。",
            "drone":"隐藏房间的环境低鸣，会随进入、离开房间淡入淡出。",
        }[category]
        if key=="ch06_silent_crown_core_boss_loop":
            row["description"]="完整试听《六城点名》；正常游戏使用其中八秒作为终战入场段。"
        if key=="ch04_broken_string_greenhouse_combat_layer":
            row["description"]+=" 此曲循环约 107 秒，较目标时长短。"
        rows.append(row)
    order=list(GROUPS)
    rows.sort(key=lambda r:(order.index(r["category"]),r["chapter"],r["key"]))
    for n,row in enumerate(rows,1):row["number"]=n
    assert len(rows)==33 and len({r["key"] for r in rows})==33
    assert all(Path(r["audio_path"]).is_file() for r in rows)
    return dict(tracks=rows,groups=GROUPS,game_root=str(ROOT.resolve()),
                ready_file=str(READY.resolve()),log_root=str(OUTPUT.resolve()))


def write_catalog(data):
    OUTPUT.mkdir(parents=True,exist_ok=True)
    (OUTPUT/"catalog.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
    text=["绯线巡礼 · 音乐试听清单", "", "33 首音乐；第六区普通战斗按设计静默。", ""]
    for category,label in GROUPS.items():
        text += [label, ""]
        for row in data["tracks"]:
            if row["category"]==category:text.append(f'{row["number"]:02d}. {row["title"]}  [{row["time"]}]')
        text.append("")
    text += ["试玩操作", "A/D 或方向键移动，空格跳跃，J 攻击，Shift 冲刺，F 互动，V 设置。",
             "F8 结束当前试玩；回到试听窗口可选择另一首。", "试玩在独立临时目录保存，不读取个人正式旅途。"]
    (OUTPUT/"音乐试听清单.txt").write_text("\n".join(text)+"\n",encoding="utf-8-sig",newline="\n")


def import_game(engine):
    env=dict(os.environ,PYTHONUTF8="1")
    log=OUTPUT/"game-import-console.log"
    with log.open("w",encoding="utf-8") as output:
        result=subprocess.run([sys.executable,str(ROOT/"tools/run_godot_import.py"),"--engine",engine,
            "--recovery-mode","--timeout","900","--log-dir",str(OUTPUT/"import")],
            cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,env=env)
    READY.write_text(json.dumps(dict(ready=result.returncode==0,error="" if result.returncode==0 else str(log))),encoding="utf-8")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine")
    parser.add_argument("--open",action="store_true")
    parser.add_argument("--no-open",action="store_true")
    parser.add_argument("--prepare-only",action="store_true")
    parser.add_argument("--smoke",action="store_true")
    args=parser.parse_args()
    data=catalog();write_catalog(data)
    if args.smoke:
        print("MUSIC_LIBRARY_CATALOG_PASS tracks=33 regions=6")
        return
    engine=engine_path(args.engine)
    if args.prepare_only:
        import_game(engine)
        return
    from music_library_server import main as browser_main
    browser_main(["--engine",engine]+(["--no-open"] if args.no_open else []))


if __name__=="__main__":main()
