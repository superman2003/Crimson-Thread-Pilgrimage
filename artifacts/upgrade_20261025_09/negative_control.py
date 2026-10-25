from pathlib import Path
import os,subprocess
p=Path('godot/scripts/save_inspector.gd');raw=p.read_bytes()
try:
 s=raw.decode();needle='FileAccess.get_sha256(path) if exists else "missing"';assert s.count(needle)==1;p.write_text(s.replace(needle,'"constant" if exists else "missing"'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 r=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','save_desk','--timeout','120','--log-dir','artifacts/upgrade_20261025_09/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025_09/negative.log').write_text(r.stdout)
 log=Path('artifacts/upgrade_20261025_09/negative/save_desk.log').read_text()
 assert r.returncode!=0 and 'CHECK FAIL valid inspection shows saved state and exact byte identity' in log and 'SCRIPT ERROR:' not in log
 print('SAVE_IDENTITY_NEGATIVE_PASS')
finally:p.write_bytes(raw)
