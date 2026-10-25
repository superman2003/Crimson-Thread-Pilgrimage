from pathlib import Path
import os,subprocess
p=Path('godot/scripts/controller_preferences.gd');raw=p.read_bytes()
try:
 text=raw.decode();needle='if not stick or trigger:continue';assert text.count(needle)==1
 p.write_text(text.replace(needle,'if not stick:continue'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 result=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','controller_comfort','--log-dir','artifacts/upgrade_20261025_04/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025_04/negative.log').write_text(result.stdout)
 detail=Path('artifacts/upgrade_20261025_04/negative/controller_comfort.log').read_text()
 assert result.returncode!=0 and 'trigger mixed and keyboard actions preserve their thresholds: cal_mixed' in detail and 'SCRIPT ERROR:' not in detail
 print('MIXED_TRIGGER_NEGATIVE_PASS exit='+str(result.returncode))
finally:p.write_bytes(raw)
