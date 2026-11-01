from pathlib import Path
import os,subprocess
p=Path('godot/scripts/journal_catalog.gd');raw=p.read_bytes()
try:
 text=raw.decode();needle='var public_text := (String(doc.title) + "\\n" + String(doc.text)).to_lower()';assert text.count(needle)==1
 p.write_text(text.replace(needle,'var public_text := JSON.stringify(doc).to_lower()'))
 env=dict(os.environ,PATH='/tmp/ctp-engine/display/usr/bin:'+os.environ['PATH'],LD_LIBRARY_PATH='/tmp/ctp-engine/display/usr/lib/x86_64-linux-gnu')
 result=subprocess.run(['python','tools/run_godot_regressions.py','--engine','/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64','--software-gl','--suite','journal_desk','--log-dir','artifacts/upgrade_20261025_03/negative'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 Path('artifacts/upgrade_20261025_03/negative.log').write_text(result.stdout)
 detail=Path('artifacts/upgrade_20261025_03/negative/journal_desk.log').read_text()
 assert result.returncode!=0 and 'backing hidden fields never participate in search' in detail and 'SCRIPT ERROR:' not in detail
 print('HIDDEN_SEARCH_NEGATIVE_PASS exit='+str(result.returncode))
finally:p.write_bytes(raw)
