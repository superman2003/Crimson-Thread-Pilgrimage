from pathlib import Path
import os,subprocess
p=Path('godot/scripts/build_system.gd');raw=p.read_bytes()
try:
 text=raw.decode();needle='    if state.loadouts.has(name):return _fail("新名称已存在，不会覆盖其它方案")';assert text.count(needle)==1
 p.write_text(text.replace(needle,'    # negative: collision guard removed'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 result=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','loadout_workbench','--log-dir','artifacts/upgrade_20261025_02/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025_02/negative.log').write_text(result.stdout)
 detail=Path('artifacts/upgrade_20261025_02/negative/loadout_workbench.log').read_text()
 assert result.returncode!=0 and 'collisions never overwrite' in detail and 'SCRIPT ERROR:' not in detail
 print('COLLISION_NEGATIVE_PASS exit='+str(result.returncode))
finally:p.write_bytes(raw)
