#!/usr/bin/env python3
"""Execute a second full synthesis and compare generated deliverables byte for byte."""
import hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
PACK=ROOT/'assets/proposals/audio_category_music'
DOC=ROOT/'docs/proposals/audio_category_music'
def snapshot():
 paths=sorted(PACK.rglob('*.ogg'))+[PACK/'manifest.json',DOC/'score_events.json',DOC/'validation.json']
 return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
before=snapshot()
subprocess.run([sys.executable,str(Path(__file__).with_name('build.py'))],check=True)
after=snapshot()
changed=[p for p in set(before)|set(after) if before.get(p)!=after.get(p)]
report={'schema_version':1,'pack_id':'audio_category_music','method':'Second full synthesis and encoding on same toolchain; compare all 29 OGG, manifest, score events and technical report SHA-256','files_compared':len(after),'all_hashes_identical':not changed,'changed_files':sorted(changed),'sha256':after}
(DOC/'reproducibility.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
assert not changed,changed
print('PASS: deterministic full rebuild',len(after),'files')
