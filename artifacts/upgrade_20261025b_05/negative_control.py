from pathlib import Path
import os,subprocess
p=Path('godot/scripts/main_level.gd');raw=p.read_bytes()
try:
 s=raw.decode();needle='{"collected_ids":collected,"bell_count":next_bells}';assert s.count(needle)==1;p.write_text(s.replace(needle,'{"collected_ids":world_collected_ids,"bell_count":next_bells}'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 r=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','pickup_ledger','--timeout','180','--log-dir','artifacts/upgrade_20261025b_05/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025b_05/negative.log').write_text(r.stdout)
 log=Path('artifacts/upgrade_20261025b_05/negative/pickup_ledger.log').read_text()
 assert r.returncode!=0 and 'CHECK FAIL actual disk restores ability whisper and collected identity together' in log and 'SCRIPT ERROR:' not in log
 print('PICKUP_REGION_LEDGER_NEGATIVE_PASS')
finally:p.write_bytes(raw)
