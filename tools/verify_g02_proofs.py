"""Reject wrong G02 phase proofs against the actual private continuation save."""
import argparse,copy,json,os,re,subprocess
from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--log-dir',type=Path,required=True);a=p.parse_args();a.log_dir.mkdir(parents=True,exist_ok=True);proof=json.loads(a.proof.read_text());results=[]
for case in ['wallet','cache','inventory','build','pid','charted','checkpoint']:
 q=copy.deepcopy(proof)
 if case=='wallet':q[case]+=1
 elif case=='cache':q[case]={'currency':129,'region_id':q['region'],'position':[1897,1562]}
 elif case=='inventory':q[case]['pollen_wax']=23.5
 elif case=='build':q[case]['active_skill_slot']=0.5
 elif case=='pid':q[case]=0.5
 elif case=='charted':q[case]={}
 else:q[case]='wrong'
 command=[str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe'),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/world_g02_death_playback.gd'),'--','--g02-phase=4','--g02-proof='+json.dumps(q,separators=(',',':'))]
 v=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);(a.log_dir/(case+'.log')).write_bytes(v.stdout);text=v.stdout.decode(errors='replace');errors=re.findall(r'^ERROR:.*$',text,re.M);ok=v.returncode==1 and len(errors)==1 and 'WORLD_G02_DEATH failures=1 deaths=0' in text;results.append(dict(case=case,exit=v.returncode,errors=errors,passed=ok))
(a.log_dir/'verification.json').write_text(json.dumps(results,indent=2)+'\n');print(results);raise SystemExit(0 if all(x['passed'] for x in results) else 1)
