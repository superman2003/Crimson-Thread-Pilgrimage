from pathlib import Path
import os,subprocess
p=Path('godot/scripts/cartography_runtime.gd');raw=p.read_bytes()
try:
 s=raw.decode();needle='    if not result.ok:\n        var failed: Dictionary=';assert s.count(needle)==1;p.write_text(s.replace(needle,'    level._publish_inventory_progress(plan,result.candidate) # Negative: publish before checking durability.\n'+needle))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 r=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','cartographer_trade','--timeout','180','--log-dir','artifacts/upgrade_20261025b_04/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025b_04/negative.log').write_text(r.stdout)
 log=Path('artifacts/upgrade_20261025b_04/negative/cartographer_trade.log').read_text()
 assert r.returncode!=0 and 'CHECK FAIL failed map save retains exact wallet knowledge build resources and file' in log and 'SCRIPT ERROR:' not in log
 print('CARTOGRAPHY_EARLY_PUBLISH_NEGATIVE_PASS')
finally:p.write_bytes(raw)
