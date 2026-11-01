"""Reject wrong independent-restart proofs against the actually earned Bride save."""
import argparse,copy,json,os,re,subprocess
from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--log-dir',type=Path,required=True);p.add_argument('--engine',default=os.environ.get('GODOT',str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe') if os.name=='nt' else 'godot'));a=p.parse_args();a.log_dir.mkdir(parents=True,exist_ok=True);proof=json.loads(a.proof.read_text(encoding='utf-8'));results=[]
for case in ['wallet','inventory','build','story','charted','shortcuts','checkpoint','pid','region','cache','hp','energy','unlocked','defeated','regions','spawn','phase']:
 q=copy.deepcopy(proof)
 if case=='wallet':q[case]+=1
 elif case=='inventory':q[case]['obsidian_splinter']=20.5
 elif case=='build':q[case]['active_skill_slot']=0.5
 elif case=='story':q[case].pop(next(iter(q[case])))
 elif case in ['charted','shortcuts']:q[case]={}
 elif case=='pid':q.pop(case)
 elif case=='cache':q[case]={'currency':1}
 elif case in ['hp','energy']:q[case]+=0.5
 elif case in ['unlocked','defeated']:q[case]=not q[case]
 elif case=='regions':q[case]={}
 elif case=='spawn':q[case][0]+=1
 elif case=='phase':q[case]='death' if q[case]=='retry' else 'retry'
 else:q[case]='wrong'
 command=[a.engine,'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/world_bride_retry_playback.gd'),'--','--bride-restart-proof='+json.dumps(q,separators=(',',':'))]
 v=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);(a.log_dir/(case+'.log')).write_bytes(v.stdout);text=v.stdout.decode(errors='replace');errors=re.findall(r'^ERROR:.*$',text,re.M);ok=v.returncode==1 and len(errors)==1 and 'WORLD_C05_BRIDE_RESTART failures=1 pid_changed=true' in text;results.append({'case':case,'exit':v.returncode,'errors':errors,'passed':ok})
(a.log_dir/'verification.json').write_text(json.dumps(results,indent=2)+'\n');print(results);raise SystemExit(0 if all(x['passed'] for x in results) else 1)
