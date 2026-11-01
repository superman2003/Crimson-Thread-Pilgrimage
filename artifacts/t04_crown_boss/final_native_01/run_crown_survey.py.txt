"""Normal earned C6 map, west ring, testimony and final-door shrine continuation."""
from pathlib import Path
import argparse,hashlib,json,gzip,os,subprocess,time,re,shutil
from run_damage_route import freeze
r=Path(__file__).resolve().parents[1]
def sources():
 d=freeze()
 for n in ['godot/scripts/world_crown_survey_playback.gd','tools/run_crown_survey.py','tools/build_chapter_terrain.py','tools/build_cave_world.py','tools/run_godot_regressions.py','tools/godot_suite_success_markers.json','tools/test_regression_runner.py','godot/scripts/crown_vault_door_validation.gd','tools/run_crown_vault.py','godot/scripts/crown_rain_slot_validation.gd','tools/run_crown_slot.py','tools/verify_crown_survey_proofs.py','artifacts/t04_crown_entry/earned_lower_seed.json']:
  d[n]=hashlib.sha256((r/n).read_bytes()).hexdigest()
 return d
p=argparse.ArgumentParser();p.add_argument('--log-dir',type=Path,required=True);p.add_argument('--native-gl',action='store_true');a=p.parse_args();a.log_dir.mkdir(parents=True,exist_ok=True);before=sources();assert before['artifacts/t04_crown_entry/earned_lower_seed.json']=='991da3aee7e085764c400b51792a48a28f9cf226cea89b50794d2c0610c03dae'
for n in ['godot/scripts/world_crown_survey_playback.gd','tools/run_crown_survey.py','tools/verify_crown_survey_proofs.py']:(a.log_dir/(Path(n).name+'.txt')).write_bytes((r/n).read_bytes())
c=[str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe'),*(['--position','-32000,-32000'] if a.native_gl else ['--headless']),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/world_crown_survey_playback.gd')]
def run(args,name,marker):
 t=time.monotonic()
 with (a.log_dir/name).open('wb') as f:
  try:code=subprocess.run(c+['--']+args,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
  except subprocess.TimeoutExpired:code=-1
 text=(a.log_dir/name).read_text(encoding='utf-8',errors='replace');text=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',text);errors=re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$',text,re.M);m=re.search(marker,text,re.M)
 return {'exit':code,'seconds':round(time.monotonic()-t,2),'timeout':180,'errors':errors,'warnings':text.count('ObjectDB instances leaked'),'completion':m[0] if m else None,'passed':code==0 and not errors and bool(m) and 'ObjectDB instances leaked' not in text},text
started=time.monotonic();entry,text=run([],'runtime.log',r'^WORLD_C06_SURVEY steps=\d+ failures=0 deaths=0 damage_events=\d+ heals=\d+ damage_suppression=false$')
restart=None
if entry['passed']:
 proof=json.loads(re.findall(r'^CROWN_SURVEY_PROOF (.+)$',text,re.M)[-1]);(a.log_dir/'restart-proof.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
 path=re.findall(r'^CROWN_SURVEY_EARNED_SEED (.+)$',text,re.M)[-1].strip();shutil.copyfile(path,a.log_dir/'earned_boss_door_seed.json')
 restart,_=run(['--crown-survey-proof='+json.dumps(proof,separators=(',',':'))],'restart.log',r'^WORLD_C06_SURVEY_RESTART failures=0 pid_changed=true$')
after=sources()
for label,data in [('before',before),('after',after)]:(a.log_dir/f'source-{label}.json.gz').write_bytes(gzip.compress(json.dumps(data,indent=2).encode(),mtime=0))
v={'primary':entry,'restart':restart,'source_files':len(before),'source_unchanged':before==after,'passed':entry['passed'] and bool(restart and restart['passed']) and before==after};(a.log_dir/'verification.json').write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v,indent=2));raise SystemExit(0 if v['passed'] else 1)
