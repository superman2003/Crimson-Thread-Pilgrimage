from pathlib import Path
import os,subprocess
p=Path('godot/scripts/wish_confirmation.gd');raw=p.read_bytes()
try:
 s=raw.decode();needle='if String(fresh.fingerprint)!=fingerprint:';assert s.count(needle)==1;p.write_text(s.replace(needle,'if false:'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 r=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','wish_reward_atomic','--timeout','60','--log-dir','artifacts/upgrade_20261025_07/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025_07/negative.log').write_text(r.stdout)
 log=Path('artifacts/upgrade_20261025_07/negative/wish_reward_atomic.log').read_text()
 assert r.returncode!=0 and 'CHECK FAIL changed source requires another explicit confirmation' in log and 'SCRIPT ERROR:' not in log
 print('WISH_FRESHNESS_NEGATIVE_PASS')
finally:p.write_bytes(raw)
