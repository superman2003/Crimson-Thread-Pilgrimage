#!/usr/bin/env python3
"""Bounded input-only fresh second-order route stages; preserve every attempt."""
from __future__ import annotations
import argparse,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCRIPT="godot/scripts/world_second_order_playback.gd"
def freeze():
    paths=subprocess.check_output(["git","ls-files","-z","godot","tools",".gitattributes"],cwd=ROOT).decode("utf-8").split("\0")
    paths += [SCRIPT,"tools/run_second_order.py"]
    return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(set(paths)) if p and (ROOT/p).is_file()}
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine",required=True)
    parser.add_argument("--stage",choices=["probe","first_lamp"],required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--native-gl",action="store_true")
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    if (out/"runtime.log").exists():parser.error("attempt already exists; choose a new output path")
    scratch=Path(tempfile.mkdtemp(prefix="ctp-order2-"));appdata=scratch/"Roaming";local=scratch/"Local";appdata.mkdir();local.mkdir()
    env=dict(os.environ,APPDATA=str(appdata),LOCALAPPDATA=str(local))
    renderer=["--display-driver","windows","--rendering-method","gl_compatibility"] if args.native_gl else ["--headless"]
    command=[args.engine,*renderer,"--audio-driver","Dummy","--fixed-fps","60","--path",str(ROOT/"godot"),"--script","res://scripts/world_second_order_playback.gd","--","--order-stage="+args.stage,"--output="+str(out)]
    before=freeze();(out/"source_before.json").write_text(json.dumps(before,indent=2)+"\n",encoding="utf-8")
    (out/"playback.gd.txt").write_bytes((ROOT/SCRIPT).read_bytes());(out/"runner.py.txt").write_bytes(Path(__file__).read_bytes())
    (out/"command.json").write_text(json.dumps({"command":command,"timeout":180,"private_appdata":str(appdata),"type":"native final attempt" if args.native_gl else "bounded CPU calibration"},indent=2)+"\n",encoding="utf-8")
    code=None;timed_out=False
    try:
        with (out/"runtime.log").open("wb") as log:code=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180,env=env).returncode
    except subprocess.TimeoutExpired:timed_out=True
    after=freeze();(out/"source_after.json").write_text(json.dumps(after,indent=2)+"\n",encoding="utf-8")
    log=(out/"runtime.log").read_text(encoding="utf-8",errors="replace")
    errors=re.findall(r"^(?:SCRIPT ERROR:|ERROR:).*",log,re.M);warnings=re.findall(r"^WARNING:.*",log,re.M)
    marker=re.search(r"^SECOND_ORDER_STAGE stage="+args.stage+r" .* failures=0$",log,re.M)
    checkpoint=out/"earned_checkpoint.json"
    result={"head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT).decode().strip(),"stage":args.stage,"exit":code,"timed_out":timed_out,"errors":errors,"warnings":warnings,"source_unchanged":before==after,"source_files":len(before),"completion":marker.group(0) if marker else None,"checkpoint_sha256":hashlib.sha256(checkpoint.read_bytes()).hexdigest() if checkpoint.exists() else None}
    result["passed"]=code==0 and not timed_out and not errors and not warnings and before==after and bool(marker)
    (out/"result.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8");print(json.dumps(result,indent=2));return 0 if result["passed"] else 1
if __name__=="__main__":raise SystemExit(main())
