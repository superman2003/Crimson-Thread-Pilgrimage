"""Diagnostic fixture with explicit placement/damage; fixed and exact old-condition negative."""
from pathlib import Path
import subprocess,os,argparse,json,gzip,hashlib,re
from run_damage_route import freeze
r=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--log-dir',type=Path,required=True);a=p.parse_args();a.log_dir.mkdir(parents=True,exist_ok=True)
main=r/'godot/scripts/main_level.gd';fixed=main.read_bytes();old=fixed.replace(b'if not world_mode and boss_unlocked and not demo_complete and not boss_spawned:',b'if boss_unlocked and not demo_complete and not boss_spawned:');assert old!=fixed
out=[]
try:
 for label,source in [('fixed',fixed),('negative_old',old)]:
  main.write_bytes(source);before=freeze()
  for name in ['godot/scripts/g02_respawn_validation.gd','godot/scripts/world_g02_death_playback.gd','tools/run_g02_respawn_fixture.py']:
   before[name]=hashlib.sha256((r/name).read_bytes()).hexdigest()
  command=[str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe'),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/g02_respawn_validation.gd')]
  v=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);(a.log_dir/(label+'.log')).write_bytes(v.stdout);text=v.stdout.decode(errors='replace');m=re.search(r'WORLD_G02_RESPAWN_FIXTURE failures=(\d+) deaths=4',text);errors=re.findall(r'^ERROR:.*$',text,re.M);unchanged=all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in before.items());passed=unchanged and bool(m) and ((label=='fixed' and v.returncode==0 and int(m[1])==0 and not errors) or (label=='negative_old' and v.returncode==1 and int(m[1])>0 and len(errors)==int(m[1])));out.append(dict(case=label,exit=v.returncode,errors=errors,source_unchanged=unchanged,fixture_sha256=before['godot/scripts/g02_respawn_validation.gd'],passed=passed));(a.log_dir/(label+'-sources.json.gz')).write_bytes(gzip.compress(json.dumps(before,indent=2).encode(),mtime=0))
finally:main.write_bytes(fixed)
(a.log_dir/'verification.json').write_text(json.dumps(out,indent=2)+'\n');print(out);raise SystemExit(0 if all(x['passed'] for x in out) else 1)
