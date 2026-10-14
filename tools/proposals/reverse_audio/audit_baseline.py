#!/usr/bin/env python3
"""Read-only baseline inspection; decoded temporary files never become candidates."""
import argparse, hashlib, json, subprocess, tempfile
from pathlib import Path
from build_pack import DOC, SR, meter, read
p=argparse.ArgumentParser()
p.add_argument('audio_root',type=Path,help='Hydrated godot/assets/audio directory')
a=p.parse_args()
keys=['boss_windup_light','boss_windup_lethal']+[f'boss_ch{ch:02d}_atk_heavy' for ch in range(6,0,-1)]
rows=[]
with tempfile.TemporaryDirectory() as tmp:
    for key in keys:
        source=a.audio_root/'sfx/generated'/f'{key}.ogg'
        decoded=Path(tmp)/f'{key}.wav'
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ar',str(SR),'-ac','1','-c:a','pcm_s16le',str(decoded)],check=True)
        m=meter(decoded,read(decoded)); m.pop('sha256')
        rows.append({'path':f'godot/assets/audio/sfx/generated/{key}.ogg','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'decoded_pcm_measurements':m})
report={'baseline_commit':'3bd62d199662','purpose':'Verify existing real audio and characterize timing/levels; not a judgment of subjective quality. OGG decoded to mono 48k PCM16 for comparable measurement. No baseline sample reused in synthesis.','assets':rows}
(DOC/'baseline_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'Inspected {len(rows)} hydrated baseline OGG files.')
