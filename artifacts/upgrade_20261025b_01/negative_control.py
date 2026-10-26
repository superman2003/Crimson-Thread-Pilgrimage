from pathlib import Path
import os,subprocess
p=Path('godot/scripts/main_level.gd');raw=p.read_bytes()
try:
 s=raw.decode();needle='_persist_world_change({"currency":currency_count+int(cache.currency),"death_cache":{}})';assert s.count(needle)==1;p.write_text(s.replace(needle,'_persist_world_change({"currency":currency_count+int(cache.currency),"death_cache":cache})'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 r=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','return_knot_transaction','--timeout','120','--log-dir','artifacts/upgrade_20261025b_01/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025b_01/negative.log').write_text(r.stdout)
 log=Path('artifacts/upgrade_20261025b_01/negative/return_knot_transaction.log').read_text()
 assert r.returncode!=0 and 'CHECK FAIL field claim reload cannot duplicate currency' in log and 'SCRIPT ERROR:' not in log
 print('KNOT_CLEAR_NEGATIVE_PASS')
finally:p.write_bytes(raw)
