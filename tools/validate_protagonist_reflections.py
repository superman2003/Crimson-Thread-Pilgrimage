import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def validate(data):
    errors=[]
    entries=data.get("entries",[])
    abilities={x.get("ability") for x in entries if isinstance(x,dict)}
    if len(entries)!=8 or len(abilities)!=8:errors.append("eight unique abilities required")
    ids=set()
    for row in data.get("combinations",[]):
        identity=row.get("id")
        if not isinstance(identity,str) or not identity or identity in ids:errors.append("invalid identity")
        ids.add(identity)
        required=row.get("requires")
        if not isinstance(required,list) or not 2<=len(required)<=4 or not all(isinstance(x,str) and x in abilities for x in required) or len(set(required))!=len(required):errors.append("invalid earned conditions")
        for key,minimum in [("title",3),("text",35)]:
            text=row.get(key)
            if not isinstance(text,str) or len(text.strip())<minimum or not any("一"<=c<="鿿" for c in text):errors.append("incomplete Chinese text")
    return errors
if __name__=="__main__":
    data=json.loads((ROOT/"godot/data/protagonist_voice.json").read_text())
    errors=validate(data)
    print("PROTAGONIST_REFLECTIONS errors="+str(len(errors)))
    raise SystemExit(bool(errors))
