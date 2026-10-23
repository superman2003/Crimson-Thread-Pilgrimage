"""Normal earned camp -> ash winch -> tower/grave circuit -> mirror shrine, exact new PID restart."""
from pathlib import Path
import argparse,hashlib,json,gzip,os,subprocess,time,re,shutil
from run_damage_route import freeze
r=Path(__file__).resolve().parents[1]
def sources():
 d=freeze()
 for name in ['godot/scripts/world_obsidian_tower_playback.gd','tools/run_obsidian_tower.py','tools/verify_obsidian_tower_proofs.py','artifacts/t04_obsidian_route/earned_camp_seed.json','tools/build_chapter_terrain.py','tools/build_cave_world.py']:
  d[name]=hashlib.sha256((r/name).read_bytes()).hexdigest()
 return d
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--log-dir',type=Path,required=True);p.add_argument('--native-gl',action='store_true');p.add_argument('--engine',default=os.environ.get('GODOT',str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe') if os.name=='nt' else 'godot'));a=p.parse_args();engine=shutil.which(a.engine)
if not engine:p.error('Godot executable not found')
a.log_dir.mkdir(parents=True,exist_ok=True);before=sources();assert before['artifacts/t04_obsidian_route/earned_camp_seed.json']=='91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b'
for n in ['godot/scripts/world_obsidian_tower_playback.gd','tools/run_obsidian_tower.py']:(a.log_dir/(Path(n).name+'.txt')).write_bytes((r/n).read_bytes())
(a.log_dir/'source.diff').write_bytes(subprocess.check_output(['git','diff','HEAD','--','godot/scripts/world_obsidian_tower_playback.gd','tools/run_obsidian_tower.py']))
c=[engine,*(['--position','-32000,-32000'] if a.native_gl else ['--headless']),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/world_obsidian_tower_playback.gd')]
def run(command,name,marker):
 t=time.monotonic()
 with (a.log_dir/name).open('wb') as f:
  try:code=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
  except subprocess.TimeoutExpired:code=-1
 text=(a.log_dir/name).read_text(encoding='utf-8',errors='replace');text=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',text);errors=re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$',text,re.M);m=re.search(marker,text,re.M)
 return {'exit':code,'seconds':round(time.monotonic()-t,2),'timeout':180,'errors':errors,'warnings':text.count('ObjectDB instances leaked'),'passed':code==0 and not errors and bool(m),'completion':m[0] if m else None,'command':command},text
started=time.monotonic();primary,text=run(c,'runtime.log',r'^WORLD_C05_TOWER steps=\d+ failures=0 damage_events=\d+ heals=\d+ deaths=0 damage_suppression=false$');restart=None
if primary['passed']:
 matches=re.findall(r'^TOWER_RESTART_PROOF (.+)$',text,re.M)
 if matches:
  proof=json.loads(matches[-1]);(a.log_dir/'restart-proof.json').write_text(json.dumps(proof,indent=2)+'\n');restart,_=run(c+['--','--tower-restart-proof='+json.dumps(proof,separators=(',',':'))],'restart.log',r'^WORLD_C05_TOWER_RESTART failures=0 pid_changed=true$')
  if restart['passed']:
   path=re.findall(r'^TOWER_EARNED_SEED (.+)$',text,re.M)[-1].strip();shutil.copyfile(path,a.log_dir/'earned_mirror_seed.json')
after=sources()
for label,data in [('before',before),('after',after)]:(a.log_dir/f'source-{label}.json.gz').write_bytes(gzip.compress(json.dumps(data,indent=2).encode(),mtime=0))
v={'primary':primary,'restart':restart,'seconds':round(time.monotonic()-started,2),'source_files':len(before),'source_unchanged':before==after,'seed_sha256':before['artifacts/t04_obsidian_route/earned_camp_seed.json'],'passed':primary['passed'] and bool(restart and restart['passed']) and before==after};(a.log_dir/'verification.json').write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v,indent=2));raise SystemExit(0 if v['passed'] else 1)
