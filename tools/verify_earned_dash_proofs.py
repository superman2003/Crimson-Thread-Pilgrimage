"""Exercise exact independent-PID proof rejection without changing earned save bytes."""
import argparse,copy,json,os,re,subprocess,tempfile
from pathlib import Path
from run_earned_dash_return import ROOT,freeze,EXTRA_INPUTS
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--engine',required=True)
p.add_argument('--save',type=Path,required=True)
p.add_argument('--proof',type=Path,required=True)
p.add_argument('--log-dir',type=Path,required=True)
a=p.parse_args();a.log_dir.mkdir(parents=True,exist_ok=True)
proof=json.loads(a.proof.read_text(encoding='utf8'));cases={}
for case in ['wallet','inventory_fraction','build_fraction','story','collected','shortcuts','checkpoint','pid','region']:
 q=copy.deepcopy(proof)
 if case=='wallet':q['wallet']+=1
 elif case=='inventory_fraction':q['inventory']['quiet_sole']=1.5
 elif case=='build_fraction':q['build']['active_skill_slot']=0.5
 elif case=='story':q['story']={}
 elif case=='collected':q['collected'].pop('col_quiet_sole')
 elif case=='shortcuts':q['shortcuts']={'forged':True}
 elif case=='pid':q.pop('pid')
 else:q[case]='wrong'
 f=a.log_dir/(case+'-proof.json');f.write_text(json.dumps(q,indent=2)+'\n',encoding='utf8');cases[case]=f
EXTRA_INPUTS.extend(str(x.resolve()) for x in [a.save,a.proof,*cases.values()]);before=freeze();rows=[]
for case,f in cases.items():
 with tempfile.TemporaryDirectory(prefix='ctp-dash-proof-') as scratch:
  command=[a.engine,'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(ROOT/'godot'),'--script','res://scripts/world_earned_dash_return_playback.gd','--','--dash-stage=5','--dash-input='+str(a.save.resolve()),'--dash-proof='+str(f.resolve()),'--dash-export='+str((a.log_dir/(case+'-unexpected-save.json')).resolve())]
  try:
   result=subprocess.run(command,cwd=ROOT,env=dict(os.environ,APPDATA=scratch,XDG_DATA_HOME=scratch),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);code=result.returncode;raw=result.stdout
  except subprocess.TimeoutExpired as e:code=-1;raw=e.stdout or b''
  (a.log_dir/(case+'.log')).write_bytes(raw);text=raw.decode('utf8',errors='replace');errors=re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$',text,re.M);warnings=re.findall(r'^\s*WARNING:.*$',text,re.M)
  passed=code==1 and len(errors)==1 and not warnings and 'WORLD_EARNED_DASH_RETURN stage=5 steps=0 failures=1 deaths=0' in text
  rows.append(dict(case=case,exit=code,errors=errors,warnings=warnings,passed=passed));print(json.dumps(rows[-1]),flush=True)
after=freeze()
for label,data in [('before',before),('after',after)]:(a.log_dir/f'source-{label}.json').write_text(json.dumps(data,indent=2),encoding='utf8')
passed=before==after and all(x['passed'] for x in rows)
(a.log_dir/'verification.json').write_text(json.dumps(dict(passed=passed,source_equal=before==after,cases=rows),indent=2)+'\n',encoding='utf8')
raise SystemExit(0 if passed else 1)
