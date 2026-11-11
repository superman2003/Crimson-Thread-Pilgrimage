"""Author additional movement gestures using the reviewed onion-sheet geometry.

image_gen supplies all new drawings. This tool prepares references, registers
whole sheets and packs accepted drawings; it never synthesizes a new pose.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import tempfile
from PIL import Image, ImageOps
import motion_onion as onion

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / "art_requests/enemy_transitions_v1"
LAYER = "motion_transition_manifest.json"
BASES = ["motion_onion_manifest.json", "motion_v8_manifest.json", "boss_behavior_manifest.json",
         "combat_motion_v7_manifest.json", "motion_manifest.json", "manifest.json"]
DURATIONS = {"turn": .18, "brake": .16}

def read(path): return json.loads(Path(path).read_text(encoding="utf-8"))
def write(path, value):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
def rel(path): return Path(path).resolve().relative_to(ROOT.resolve()).as_posix()
def spec_path(kind): return REQUEST/"jobs"/(kind+".json")
def baseline(kind):
    folder=onion.CREATURES/kind
    path=next((folder/name for name in BASES if (folder/name).is_file()),None)
    if path is None:raise ValueError("No original character: "+kind)
    return path,read(path)

def prepare(kind, action, indices=None):
    path,base=baseline(kind)
    if action not in DURATIONS:raise ValueError("Unknown movement gesture")
    spec=read(spec_path(kind)) if spec_path(kind).exists() else {
        "schema":1,"kind":kind,"baseline":rel(path),"baseline_sha256":sha256(path.read_bytes()).hexdigest(),
        "canvas":base["canvas"],"scale":onion.scale_for(base["canvas"]),"jobs":[],"accepted":{}}
    if sha256(path.read_bytes()).hexdigest()!=spec["baseline_sha256"]:
        raise ValueError("Original motion changed; replan the drawing references")
    clips=onion.clips_of(base);left=deepcopy(clips["idle" if action=="turn" else "walk"]["frames"][0])
    right=deepcopy(clips["idle"]["frames"][0])
    if action=="turn":
        # This mirrored endpoint is a planning guide only, never a delivered pose.
        mirror=ImageOps.mirror(onion.cel(right))
        target=REQUEST/"references"/kind/"opposite_idle_guide.png"
        target.parent.mkdir(parents=True,exist_ok=True);mirror.save(target)
        right["atlas"]="res://../"+rel(target)
        right["region"]=[0,0,*mirror.size]
        right["margin"][0]=base["canvas"][0]-right["margin"][0]-mirror.width
    todo=indices if indices is not None else list(range(6))
    if not todo or len(todo)>6:raise ValueError("Choose one to six distinct new drawings")
    if any(i not in range(6) for i in todo) or len(set(todo))!=len(todo):raise ValueError("Invalid drawing indices")
    number=sum(j["action"]==action for j in spec["jobs"])+1
    job_id=f"{kind}__{action}__{number:02}"
    edges=[dict(animation=action,after=i,left=deepcopy(left),right=deepcopy(right)) for i in todo]
    sheet,identity=onion.render_sheets(kind,spec["canvas"],spec["scale"],edges)
    folder=REQUEST/"references"/kind;folder.mkdir(parents=True,exist_ok=True)
    sheet.save(folder/(job_id+".onion.png"));identity.save(folder/(job_id+".identity.png"))
    if action=="turn":
        poses=["anticipatory head/antenna turn, about 25 degrees from the original facing",
               "pivot the short feet, head and shell about 50 degrees toward the viewer",
               "near frontal three-quarter pivot at about 75 degrees; preserve body volume",
               "continue through the front to about 105 degrees, turning toward the opposite side",
               "opposite three-quarter view at about 130 degrees; feet finish their pivot",
               "almost opposite-facing side view at about 155 degrees, settling toward orange idle"]
        intent="An in-place TURN from the blue original-facing idle toward the orange opposite-facing idle."
    else:
        poses=["leading feet reach to plant while the other feet finish a walking push",
               "the planted feet take the weight; the body resists forward momentum without scaling",
               "remaining feet gather under the shell, a restrained natural settling pose",
               "weight comes back to the resting stance; antenna and head follow the stop",
               "almost settled, slight remaining antenna/body motion toward idle",
               "finish settling, very close to the orange idle stance but a distinctly drawn pose"]
        intent="A grounded STOP from the blue walking pose toward the orange stationary idle. Keep the original facing."
    prompt=("Use case: identity-preserve. Asset type: six newly HAND-PAINTED 2D game animation poses.\n"
      "Image 1 is the production onion guide, 1536x1024, exactly THREE columns and TWO rows of 512px cells. "
      "Image 2 shows the existing full-colour identity at exactly the same scale. "
      "The BLUE ghost is the start; the ORANGE ghost is the end. Their position, body size and grey ground line are fixed.\n"
      f"Character: {kind}. {intent}\n"
      +"\n".join(f"Cell {slot+1}, row-major: {poses[index]}." for slot,index in enumerate(todo))+"\n"
      "Output one genuinely transparent 1536x1024 PNG. Keep the FOUR solid GREEN corner squares exactly where they are, unchanged. "
      "Draw exactly ONE new full-colour pose per used cell directly over its ghosts, at the SAME production size and location. "
      "Match the fine textured painted style, anatomical proportions, body mass, shell, ornament, face and palette exactly. "
      "The feet stay at the ground guide and the body stays centred. No body swelling/shrinking, no stretched limbs, no rigid whole-character rotation. "
      "Each pose must be a genuinely new drawing of the requested action; no copied, mirrored, cross-faded or blended endpoint figures. "
      "Remove ghosts, grey ground lines and cell outlines. No text, numbers, shadows, effects, particles, weapons or scenery added. "
      "Keep unused cells empty. Nothing crosses a cell border. This completes an existing character; do not redesign it.")
    job=dict(id=job_id,kind=kind,action=action,baseline=rel(path),canvas=spec["canvas"],scale=spec["scale"],
             onion=rel(folder/(job_id+".onion.png")),identity=rel(folder/(job_id+".identity.png")),
             prompt=prompt,edges=edges)
    spec["jobs"].append(job);write(spec_path(kind),spec)
    print(json.dumps({"job":job_id,"onion":job["onion"],"identity":job["identity"],"canvas":spec["canvas"]}))
    return job

def deliver(kind, job_id, image, prompt_file=None, references=None):
    spec=read(spec_path(kind));job=next(j for j in spec["jobs"] if j["id"]==job_id)
    raw=Path(image).read_bytes();attempt=len(job.get("attempts",[]))+1
    source=REQUEST/"sources"/kind/f"{job_id}__try{attempt:02}.png"
    source.parent.mkdir(parents=True,exist_ok=True);source.write_bytes(raw)
    prompt=Path(prompt_file).read_text(encoding="utf-8").rstrip("\n") if prompt_file else job["prompt"]
    refs=references or [ROOT/job["onion"],ROOT/job["identity"]]
    record={"source":rel(source),"sha256":sha256(raw).hexdigest(),"generator":"built-in image_gen","prompt":prompt,
            "prompt_sha256":sha256(prompt.encode("utf-8")).hexdigest(),
            "references":[{"path":rel(p),"sha256":sha256(Path(p).read_bytes()).hexdigest()} for p in refs]}
    try:results,fit=onion.register(job,source,stable_affine=True)
    except ValueError as error:
        record["error"]=str(error);job.setdefault("attempts",[]).append(record);write(spec_path(kind),spec)
        print("DELIVERY_REJECTED",job_id,str(error));return 1
    rows=[]
    for row in results:
        image=row.pop("image",None)
        if row["accepted"]:
            target=REQUEST/"accepted"/kind/f"{row['animation']}__{row['after']:02}.png"
            target.parent.mkdir(parents=True,exist_ok=True);image.save(target)
            spec["accepted"][f"{row['animation']}#{row['after']}"]={"job":job_id,"attempt":attempt,
              "drawing":rel(target),"sha256":sha256(target.read_bytes()).hexdigest(),"margin_xy":row["margin_xy"],"metrics":row["metrics"]}
        rows.append(row)
    record.update(fit);record["cells"]=rows;job.setdefault("attempts",[]).append(record);write(spec_path(kind),spec)
    print(json.dumps({"job":job_id,"accepted":sum(x["accepted"] for x in rows),"cells":[{"index":r["after"],"accepted":r["accepted"],"reasons":r["reasons"]} for r in rows]}))
    return 0 if all(x["accepted"] for x in rows) else 1

def build(kind, check=False):
    spec=read(spec_path(kind));path,base=baseline(kind)
    if sha256(path.read_bytes()).hexdigest()!=spec["baseline_sha256"]:raise ValueError("Baseline changed; drawings need review")
    drawings={}
    for action in DURATIONS:
        for index in range(6):
            row=spec["accepted"].get(f"{action}#{index}")
            if not row:raise ValueError(f"Missing {action} drawing {index}")
            p=ROOT/row["drawing"]
            if sha256(p.read_bytes()).hexdigest()!=row["sha256"]:raise ValueError("Accepted drawing changed")
            with Image.open(p) as image:drawings[(action,index)]=(image.convert("RGBA"),row["margin_xy"])
    pages,packed=onion.pack(kind,drawings,base["canvas"])
    for frame in packed.values():frame["atlas"]=frame["atlas"].replace("motion_onion_","motion_transition_")
    result=deepcopy(base);clips=onion.clips_of(base)
    for action,duration in DURATIONS.items():
        frames=[deepcopy(clips["idle" if action=="turn" else "walk"]["frames"][0])]+[packed[(action,i)] for i in range(6)]
        result["animations"].append({"name":action,"fps":len(frames)/duration,"loop":False,"frames":frames})
    result["transition_record"]={"schema":1,"baseline":path.name,"baseline_sha256":spec["baseline_sha256"],
      "spec":rel(spec_path(kind)),"new_drawings":12,"durations":DURATIONS,
      "turn":"Canonical artwork turns from its original-facing side to its opposite; runtime mirrors the entire gesture for the reverse direction."}
    outputs=[(onion.CREATURES/kind/LAYER,result)]+[(onion.CREATURES/kind/f"motion_transition_{i:02}.png",page) for i,page in enumerate(pages)]
    for target,data in outputs:
        if check:
            if isinstance(data,dict):
                if read(target)!=data:raise ValueError("Stale manifest: "+str(target))
            else:
                with Image.open(target) as current:
                    if current.convert("RGBA").tobytes()!=data.tobytes():raise ValueError("Stale atlas: "+str(target))
        elif isinstance(data,dict):write(target,data)
        else:data.save(target)
    print(json.dumps({"kind":kind,"new_drawings":12,"clips":["turn","brake"],"check":check}))
    return result

def audit_sources(kind):
    """Re-register selected raw generations; reject altered provenance/crops.

    Reference boards and rejected drafts are represented by thumbnail receipts.
    The mirrored planning endpoint is reconstructed only for this mechanical
    registration, never used as a delivered new drawing.
    """
    spec=read(spec_path(kind));path,base=baseline(kind)
    if sha256(path.read_bytes()).hexdigest()!=spec["baseline_sha256"]:raise ValueError("Baseline changed")
    receipts=read(REQUEST/"receipts.json")
    archived={row["path"]:row for row in receipts["omitted"]}
    selected={(row["job"],row["attempt"]) for row in spec["accepted"].values()}
    checked=0
    with tempfile.TemporaryDirectory(prefix="enemy-transition-references-") as scratch:
        for job in spec["jobs"]:
            job_copy=deepcopy(job)
            if job["action"]=="turn":
                guide=Path(scratch)/"opposite_idle_guide.png"
                ImageOps.mirror(onion.cel(onion.clips_of(base)["idle"]["frames"][0])).save(guide)
                for edge in job_copy["edges"]:edge["right"]["atlas"]="res://"+guide.as_posix()
            for number,attempt in enumerate(job["attempts"],1):
                if sha256(attempt["prompt"].encode("utf-8")).hexdigest()!=attempt["prompt_sha256"]:
                    raise ValueError("Generation prompt changed")
                for reference in attempt["references"]:
                    receipt=archived.get(reference["path"])
                    if receipt:
                        if receipt["sha256"]!=reference["sha256"]:raise ValueError("Archived reference checksum mismatch")
                    elif sha256((ROOT/reference["path"]).read_bytes()).hexdigest()!=reference["sha256"]:
                        raise ValueError("Reference changed")
                if (job["id"],number) not in selected:continue
                source=ROOT/attempt["source"]
                if sha256(source.read_bytes()).hexdigest()!=attempt["sha256"]:raise ValueError("Selected generation changed")
                rows,fit=onion.register(job_copy,source,stable_affine=True)
                if fit["registration"]!=attempt.get("registration"):
                    raise ValueError("Source registration algorithm changed")
                if fit["affine"]!=attempt["affine"]:raise ValueError("Source registration changed")
                for row in rows:
                    key=f"{row['animation']}#{row['after']}"
                    accepted=spec["accepted"][key]
                    if (accepted["job"],accepted["attempt"])!=(job["id"],number):continue
                    if not row["accepted"]:raise ValueError("Selected drawing rejected: "+str(row["reasons"]))
                    with Image.open(ROOT/accepted["drawing"]) as current:
                        if current.convert("RGBA").tobytes()!=row["image"].tobytes() or row["margin_xy"]!=accepted["margin_xy"]:
                            raise ValueError("Registered drawing was modified")
                    checked+=1
    if checked!=12:raise ValueError("Incomplete selected source audit")
    build(kind,check=True)
    print(f"ENEMY_TRANSITION_SOURCES kind={kind} drawings={checked}")

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("command",choices=["prepare","deliver","build","audit"])
    p.add_argument("--kind",required=True);p.add_argument("--action",choices=list(DURATIONS));p.add_argument("--indices",nargs="*",type=int)
    p.add_argument("--job");p.add_argument("--image",type=Path);p.add_argument("--prompt-file",type=Path)
    p.add_argument("--reference",type=Path,action="append");p.add_argument("--check",action="store_true");args=p.parse_args()
    if args.command=="prepare":prepare(args.kind,args.action,args.indices)
    elif args.command=="deliver":raise SystemExit(deliver(args.kind,args.job,args.image,args.prompt_file,args.reference))
    elif args.command=="audit":audit_sources(args.kind)
    else:build(args.kind,args.check)
