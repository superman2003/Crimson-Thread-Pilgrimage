#!/usr/bin/env python3
"""Local browser listening list; only an explicit click launches one game."""
from __future__ import annotations
import argparse
import http.server
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import threading
import urllib.error
import urllib.request
import webbrowser

from music_library import ROOT, OUTPUT, READY, NAMES, catalog, engine_path, import_game, write_catalog

HOST="127.0.0.1"
PORT=18767
ORIGIN=f"http://{HOST}:{PORT}"
TOKEN=secrets.token_hex(24)
LOCK=threading.Lock()
GAME=None
GAME_KEY=""
GAME_REGION=""
ENGINE=""
DATA={}
ROWS={}
SFX={}
SFX_LABELS={"blade":"刀刃挥击","heavy":"重武器挥击","claw":"甲壳与撕咬","wing":"振翅与俯冲",
    "seed":"种荚与投射","root":"根木释放","bell":"钟壳与术式","impact":"真实接触",
    "prep_light":"轻型蓄力","prep_heavy":"重型蓄力","prep_cast":"术式蓄力"}

class LocalServer(http.server.ThreadingHTTPServer):
    allow_reuse_address=False
    def server_bind(self):
        if hasattr(socket,"SO_EXCLUSIVEADDRUSE"):
            self.socket.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
        super().server_bind()


def status():
    ready=False
    try:ready=bool(json.loads(READY.read_text(encoding="utf-8")).get("ready"))
    except (OSError,ValueError):pass
    ready=ready and (ROOT/"godot/.godot/global_script_class_cache.cfg").exists()
    return dict(app="crimson-music-library",ready=ready,
                game_running=GAME is not None and GAME.poll() is None,
                game_key=GAME_KEY,game_region=GAME_REGION,tracks=33,combat_sfx=len(SFX))


def start_game(key,invulnerable=False):
    global GAME,GAME_KEY,GAME_REGION
    with LOCK:
        if GAME is not None and GAME.poll() is None:
            return 409,dict(ok=False,message="已有一个试玩窗口，请先结束当前试玩再切换。",**status())
        if key not in ROWS:return 400,dict(ok=False,message="找不到这首音乐。")
        if not status()["ready"]:return 409,dict(ok=False,message="游戏资源尚在准备，可以先试听。")
        profile=OUTPUT/"browser_preview_userdata";profile.mkdir(exist_ok=True)
        # The console launcher creates a GUI child on Windows. Track the real
        # game process so closing/stopping it cannot leave an unowned window.
        executable=Path(ENGINE)
        if os.name=="nt" and executable.name.endswith("_console.exe"):
            native=executable.with_name(executable.name.replace("_console.exe",".exe"))
            if native.is_file():executable=native
        command=[str(executable),"--path",str(ROOT/"godot"),"--windowed","--resolution","1280x720",
            "--script","res://scripts/music_scene_preview.gd","--","--music-key="+key,
            "--music-lock=false","--music-invulnerable="+str(bool(invulnerable)).lower()]
        log=(OUTPUT/("browser_play_"+key+".log")).open("w",encoding="utf-8")
        try:
            GAME=subprocess.Popen(command,cwd=ROOT,env=dict(os.environ,APPDATA=str(profile),XDG_DATA_HOME=str(profile)),
                stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
        finally:log.close()
        GAME_KEY=key
        GAME_REGION=ROWS[key]["region"]
        return 200,dict(ok=True,message="区域试玩已启动："+GAME_REGION+"，音乐随探索、战斗和钟龛自动切换。",**status())


def regions():
    result=[]
    styles=json.loads((ROOT/"godot/data/boss_combat_styles.json").read_text(encoding="utf-8"))["bosses"]
    for chapter,name in enumerate(NAMES,1):
        rows=[r for r in DATA["tracks"] if r["chapter"]==chapter]
        boss=next(r for r in rows if r["category"]=="boss")
        config=json.loads((ROOT/"godot"/boss["config"].removeprefix("res://")).read_text(encoding="utf-8"))
        result.append(dict(id=f"ch{chapter:02}",name=name,boss=boss["title"].split(" · ")[0],
            combat=styles[config["boss"]["kind"]]["identity"],
            description="探索 → 遇敌 → 脱战 → 钟龛 → Boss" if chapter<6 else "探索 → 遇敌静默 → 钟龛 → 终战三乐章"))
    return result


def start_region(region,entry="explore",invulnerable=False):
    if region not in [f"ch{i:02}" for i in range(1,7)]:return 400,dict(ok=False,message="找不到这个区域。")
    if entry not in ["explore","shrine","boss"]:return 400,dict(ok=False,message="这个试玩入口不存在。")
    category={"explore":"explore","shrine":"lullaby","boss":"boss"}[entry]
    row=next(r for r in DATA["tracks"] if r["chapter"]==int(region[2:]) and r["category"]==category)
    return start_game(row["key"],invulnerable)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args):pass

    def send_json(self,value,code=200):
        raw=json.dumps(value,ensure_ascii=False).encode("utf-8")
        self.send_response(code);self.send_header("Content-Type","application/json; charset=utf-8")
        self.send_header("Content-Length",str(len(raw)));self.send_header("Cache-Control","no-store")
        self.end_headers();self.wfile.write(raw)

    def do_GET(self):
        path=self.path.split("?",1)[0]
        if path=="/api/status":self.send_json(status());return
        if path=="/api/catalog":
            self.send_json(dict(regions=regions(),tracks=[{k:r[k] for k in ["key","title","group","category","region","time","number","description","duration_seconds"]} for r in DATA["tracks"]],
                sfx=[dict(id=r["id"],family=r["family"],title=SFX_LABELS[r["family"]],duration_seconds=r["duration_seconds"]) for r in SFX.values()]));return
        if path=="/":
            raw=(ROOT/"tools/music_library_browser.html").read_text(encoding="utf-8").replace("__LOCAL_TOKEN__",json.dumps(TOKEN)).encode("utf-8")
            self.send_response(200);self.send_header("Content-Type","text/html; charset=utf-8")
            self.send_header("Content-Length",str(len(raw)));self.send_header("Cache-Control","no-store")
            self.end_headers();self.wfile.write(raw);return
        match=re.fullmatch(r"/audio/([a-z0-9_]+)\.ogg",path)
        effect=re.fullmatch(r"/sfx/([a-z0-9_]+)\.ogg",path)
        file=None
        if match and match.group(1) in ROWS:file=Path(ROWS[match.group(1)]["audio_path"])
        elif effect and effect.group(1) in SFX:file=ROOT/"godot"/SFX[effect.group(1)]["path"].removeprefix("res://")
        if file is not None:
            length=file.stat().st_size
            start,end=0,length-1;code=200
            requested=self.headers.get("Range")
            if requested:
                part=re.fullmatch(r"bytes=(\d*)-(\d*)",requested)
                if not part:self.send_error(416);return
                if part.group(1):start=int(part.group(1));end=min(end,int(part.group(2))) if part.group(2) else end
                elif part.group(2):start=max(0,length-int(part.group(2)))
                if start>end or start>=length:self.send_error(416);return
                code=206
            self.send_response(code);self.send_header("Content-Type","audio/ogg")
            self.send_header("Accept-Ranges","bytes");self.send_header("Content-Length",str(end-start+1))
            if code==206:self.send_header("Content-Range",f"bytes {start}-{end}/{length}")
            self.end_headers()
            try:
                with file.open("rb") as f:
                    f.seek(start);remaining=end-start+1
                    while remaining:
                        block=f.read(min(65536,remaining))
                        if not block:break
                        self.wfile.write(block);remaining-=len(block)
            except (BrokenPipeError,ConnectionResetError):pass
            return
        self.send_error(404)

    def do_POST(self):
        global GAME,GAME_KEY,GAME_REGION
        if self.headers.get("Origin") not in [None,ORIGIN] or self.headers.get("X-Music-Token")!=TOKEN:
            self.send_error(403);return
        size=int(self.headers.get("Content-Length","0"))
        if size>2048:self.send_error(413);return
        try:body=json.loads(self.rfile.read(size) or b"{}")
        except ValueError:self.send_error(400);return
        if self.path=="/api/play":
            code,result=start_game(str(body.get("key","")),body.get("invulnerable",False));self.send_json(result,code);return
        if self.path=="/api/play_region":
            code,result=start_region(str(body.get("region","")),str(body.get("entry","explore")),body.get("invulnerable",False));self.send_json(result,code);return
        if self.path=="/api/stop":
            with LOCK:
                if GAME is not None and GAME.poll() is None:
                    if os.name=="nt":
                        subprocess.run(["taskkill","/PID",str(GAME.pid),"/T","/F"],capture_output=True,timeout=10)
                    else:GAME.terminate()
                    GAME.wait(timeout=10)
                GAME=None;GAME_KEY="";GAME_REGION=""
            self.send_json(dict(ok=True,message="试玩已结束。",**status()));return
        self.send_error(404)


def main(argv=None):
    global ENGINE,DATA,ROWS,SFX
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine")
    parser.add_argument("--no-open",action="store_true")
    args=parser.parse_args(argv)
    ENGINE=engine_path(args.engine)
    DATA=catalog();ROWS={r["key"]:r for r in DATA["tracks"]};write_catalog(DATA)
    manifest=ROOT/"godot/assets/audio/sfx/ai_combat/manifest.json"
    if manifest.is_file():SFX={r["id"]:r for r in json.loads(manifest.read_text(encoding="utf-8"))["entries"]}
    try:server=LocalServer((HOST,PORT),Handler)
    except OSError:
        try:
            with urllib.request.urlopen(ORIGIN+"/api/status",timeout=3) as response:existing=json.load(response)
            if existing.get("app")=="crimson-music-library":
                print("Music library is already running: "+ORIGIN,flush=True)
                if not args.no_open:webbrowser.open(ORIGIN,new=0)
                return
        except (OSError,ValueError):pass
        raise RuntimeError("The local music-library port is occupied") from None
    if not status()["ready"]:
        READY.write_text(json.dumps(dict(ready=False)),encoding="utf-8")
        threading.Thread(target=import_game,args=(ENGINE,),daemon=True).start()
    print("MUSIC_BROWSER_READY "+ORIGIN,flush=True)
    if not args.no_open:webbrowser.open(ORIGIN,new=0)
    server.serve_forever()


if __name__=="__main__":main()
