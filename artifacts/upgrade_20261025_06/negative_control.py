from pathlib import Path
import os,subprocess
p=Path('godot/scripts/duck_mix.gd');raw=p.read_bytes()
try:
 text=raw.decode();needle='result = minf(result,float(layer.db))';assert text.count(needle)==1
 p.write_text(text.replace(needle,'result = float(layer.db)'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 result=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','audio_landmarks','--log-dir','artifacts/upgrade_20261025_06/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025_06/negative.log').write_text(result.stdout)
 detail=Path('artifacts/upgrade_20261025_06/negative/audio_landmarks.log').read_text()
 assert result.returncode!=0 and 'weaker cue cannot replace the stronger active attenuation' in detail and 'SCRIPT ERROR:' not in detail
 print('DUCK_OVERLAP_NEGATIVE_PASS exit='+str(result.returncode))
finally:p.write_bytes(raw)
