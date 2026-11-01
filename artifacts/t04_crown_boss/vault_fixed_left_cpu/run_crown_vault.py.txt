"""Positioned crown slot collision fixture; old/new data, ordinary inputs only."""
from pathlib import Path
import argparse,gzip,hashlib,json,os,re,subprocess,time
from run_damage_route import freeze
r=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--config',type=Path,required=True);p.add_argument('--log-dir',type=Path,required=True);p.add_argument('--expect-old',action='store_true');p.add_argument('--native-gl',action='store_true');p.add_argument('--failure-stage',choices=['left','right'],default='right');a=p.parse_args();a.log_dir.mkdir(parents=True,exist_ok=True)
def sources():
 d=freeze()
 for name in ['godot/scripts/crown_vault_door_validation.gd','tools/run_crown_vault.py','tools/build_chapter_terrain.py','tools/build_cave_world.py','tools/run_godot_regressions.py','tools/godot_suite_success_markers.json','tools/test_regression_runner.py',a.config.as_posix()]:d[name]=hashlib.sha256((r/name).read_bytes()).hexdigest()
 return d
before=sources();command=[str(Path(os.environ['TEMP'])/'ctp-godot-4.6.1/Godot_v4.6.1-stable_win64.exe'),*(['--position','-32000,-32000'] if a.native_gl else ['--headless']),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--fixed-fps','60','--path',str(r/'godot'),'--script',str(r/'godot/scripts/crown_vault_door_validation.gd'),'--','--slot-config=res://../'+a.config.as_posix(),'--vault-side='+a.failure_stage];started=time.monotonic()
with (a.log_dir/'runtime.log').open('wb') as f:
 try:code=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
 except subprocess.TimeoutExpired:code=-1
text=(a.log_dir/'runtime.log').read_text(encoding='utf-8',errors='replace');errors=re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$',text,re.M);after=sources()
for label,data in [('before',before),('after',after)]:(a.log_dir/f'source-{label}.json.gz').write_bytes(gzip.compress(json.dumps(data,indent=2).encode(),mtime=0))
for n in ['godot/scripts/crown_vault_door_validation.gd','tools/run_crown_vault.py']:(a.log_dir/(Path(n).name+'.txt')).write_bytes((r/n).read_bytes())
passed=(code==1 and len(errors)==1 and errors[0].strip().startswith('ERROR: walk-only route blocked '+a.failure_stage+' at') and 'CROWN_VAULT_DOOR failures=1' in text) if a.expect_old else (code==0 and not errors and 'CROWN_VAULT_DOOR failures=0' in text)
v={'exit':code,'seconds':round(time.monotonic()-started,2),'errors':errors,'warnings':text.count('ObjectDB instances leaked'),'source_unchanged':before==after,'passed':passed and before==after and 'ObjectDB instances leaked' not in text,'expected_old_failure':a.expect_old};(a.log_dir/'verification.json').write_text(json.dumps(v,indent=2)+'\n');print(v);raise SystemExit(0 if v['passed'] else 1)
