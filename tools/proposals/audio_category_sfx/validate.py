#!/usr/bin/env python3
"""Decode every committed WAV with ffmpeg; deterministic rebuild into temp storage."""
import array, hashlib, json, math, subprocess, sys, tempfile, wave
from pathlib import Path
from generate import ROOT, generate
PACK=ROOT/'assets/proposals/audio_category_sfx'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rms(v):return math.sqrt(sum(x*x for x in v)/len(v))
def main():
    m=json.loads((PACK/'manifest.json').read_text()); results=[]; ids=set()
    for item in m['items']:
        assert item['loop'] is False and item['license']=='CC0-1.0' and item['human_listening_review']=='pending'
        assert item['region_id'] in ['global','ch01','ch02','ch03','ch04','ch05','ch06']
        assert 0<=item['priority']<=2 and item['max_voices']>0 and item['min_interval_seconds']>0
        p=PACK/item['file']; assert item['id'] not in ids; ids.add(item['id'])
        with wave.open(str(p),'rb') as w:
            assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,48000)
            pcm=w.readframes(w.getnframes()); assert len(pcm)==round(item['duration_seconds']*48000)*2
        decoded=subprocess.run(['ffmpeg','-v','error','-i',str(p),'-f','s16le','-acodec','pcm_s16le','-'],capture_output=True,check=True).stdout
        assert decoded==pcm, 'ffmpeg decoded PCM mismatch'
        v=array.array('h',pcm)
        if sys.byteorder!='little':v.byteswap()
        peak=max(abs(x) for x in v); full=rms(v); lead=rms(v[:48]); tail=rms(v[-48:]); nonzero=sum(x!=0 for x in v)
        assert 100<peak<30000 and full>100 and nonzero/len(v)>.9
        assert v[0]==v[-1]==0 and lead<full*.6 and tail<full*.2
        results.append(dict(id=item['id'],sha256=digest(p),frames=len(v),peak_dbfs=round(20*math.log10(peak/32768),3),rms_dbfs=round(20*math.log10(full/32768),3),head_1ms_rms=round(lead,3),tail_1ms_rms=round(tail,3),first_sample=v[0],last_sample=v[-1],nonzero_fraction=round(nonzero/len(v),5),ffmpeg_decoded_pcm_identical=True))
    with tempfile.TemporaryDirectory() as d:
        output=Path(d); generate(output)
        paths=[Path('manifest.json')]+[Path(i['file']) for i in m['items']]
        assert all(digest(PACK/p)==digest(output/p) for p in paths)
    report=dict(schema_version=1,pack_id=m['pack_id'],item_count=len(results),wav_bytes=sum((PACK/i['file']).stat().st_size for i in m['items']),checks='PCM WAV headers, independent ffmpeg decode exact match, peak/head-tail RMS/non-silence, unique IDs and content hashes, temporary deterministic full rebuild',deterministic_rebuild_files=len(results)+1,deterministic_rebuild_identical=True,human_listening_review='pending',runtime_integration='not performed',python_version=sys.version.split()[0],ffmpeg_version=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],items=results)
    assert len({r['sha256'] for r in results})==len(results)
    (ROOT/'docs/proposals/audio_category_sfx/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='items'},ensure_ascii=False))
if __name__=='__main__':main()
