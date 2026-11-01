from pathlib import Path
import sys
sys.path.insert(0,'tools')
from test_metsys_cold_import import run
path=Path('godot/addons/MetroidvaniaSystem/EditorExtension/MetSysEditorExtension.gd')
raw=path.read_bytes()
try:
 text=raw.decode();assert '\t\tbutton.free()' in text
 path.write_text(text.replace('\t\tbutton.free()','\t\tpass # negative control: retain the detached button',1))
 result=run('/tmp/ctp-engine/Godot_v4.6.1-stable_linux.x86_64',Path('artifacts/t03_editor_cold_start/no_button_free'))
 case=result['cases'][0]
 assert not result['passed'] and case['ready_count']==1
 assert case['engine_errors'] or case['lifetime_warnings']
 print('BUTTON_RETIREMENT_NEGATIVE_PASS errors='+str(len(case['engine_errors'])))
finally:path.write_bytes(raw)
