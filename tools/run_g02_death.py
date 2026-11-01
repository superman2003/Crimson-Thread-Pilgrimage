"""Earned death/recovery continuation, five independent engine processes, no grants."""
from pathlib import Path
import subprocess,os,argparse,json,hashlib,gzip,time,re,shutil
from run_damage_route import freeze
r=Path(__file__).resolve().parents[1]
def sources():
 out=freeze()
 for name in ['godot/scripts/world_g02_death_playback.gd','tools/run_g02_death.py','tools/verify_g02_proofs.py','tools/build_chapter_terrain.py','tools/build_cave_world.py','tools/run_godot_regressions.py','tools/run_g02_respawn_fixture.py','godot/scripts/g02_respawn_validation.gd','artifacts/t04_greenhouse_west/earned_west_seed.json']:
  out[name]=hashlib.sha256((r/name).read_bytes()).hexdigest()
 return out
p=argparse.ArgumentParser();p.add_argument('--log-dir',type=Path,required=True);p.add_argument('--native-gl',action='store_true');a=p.parse_args();d=a.log_dir;d.mkdir(parents=True,exist_ok=True)
before=sources();assert before['artifacts/t04_greenhouse_west/earned_west_seed.json']=='4f9a624b6c55a656e711053397511e3388fd1a16e45b9d40fbf0c952d38f2cc1'
for name in ['godot/scripts/world_g02_death_playback.gd','tools/run_g02_death.py']:(d/(Path(name).name+'.txt')).write_bytes((r/name).read_bytes())
c=[str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe'),*(['--position','-32000,-32000'] if a.native_gl else ['--headless']),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/world_g02_death_playback.gd')]
started=time.monotonic();proof=None;results=[]
for phase in range(5):
 command=c+['--','--g02-phase='+str(phase)]
 if proof:command+=['--g02-proof='+json.dumps(proof,separators=(',',':'))]
 t=time.monotonic()
 with (d/f'phase_{phase}.log').open('wb') as f:
  try:code=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
  except subprocess.TimeoutExpired:code=-1
 text=(d/f'phase_{phase}.log').read_text(encoding='utf-8',errors='replace');errors=re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$',text,re.M);m=re.findall(r'^G02_PHASE_PROOF (.+)$',text,re.M);marker=f'WORLD_G02_DEATH failures=0 deaths={1 if phase<3 else 0} damage_suppression=false';passed=code==0 and not errors and marker in text and bool(m)
 results.append(dict(phase=phase,exit=code,seconds=round(time.monotonic()-t,2),timeout=180,errors=errors,warnings=text.count('ObjectDB instances leaked'),passed=passed,command=command))
 if not passed:break
 proof=json.loads(m[-1]);(d/f'phase_{phase}_proof.json').write_text(json.dumps(proof,indent=2)+'\n');snap=re.findall(r'^G02_SNAPSHOT (.+)$',text,re.M)[-1].strip();shutil.copyfile(snap,d/f'phase_{phase}_save.json')
after=sources()
for name,value in [('before',before),('after',after)]:(d/f'source-{name}.json.gz').write_bytes(gzip.compress((json.dumps(value,indent=2)+'\n').encode(),mtime=0))
result=dict(phases=results,seconds=round(time.monotonic()-started,2),source_files=len(before),source_unchanged=before==after,passed=len(results)==5 and all(v['passed'] for v in results) and before==after)
(d/'verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));raise SystemExit(0 if result['passed'] else 1)
