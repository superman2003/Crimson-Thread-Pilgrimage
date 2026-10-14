#!/usr/bin/env python3
"""Decode actual Vorbis output, measure it, and prove a second full build is identical."""
import hashlib,json,pathlib,subprocess,tempfile
import numpy as np
from scipy.signal import resample_poly
ROOT=pathlib.Path(__file__).resolve().parents[3]
ASSETS=ROOT/'assets/proposals/audio_category_ambience'
DOCS=ROOT/'docs/proposals/audio_category_ambience'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def db(v):return round(float(20*np.log10(max(float(v),1e-12))),3)
def main():
 manifest=json.loads((ASSETS/'manifest.json').read_text());rows=[]
 assert manifest['schema_version']==1 and manifest['pack_id']=='audio_category_ambience'
 assert manifest['kind']=='ambience' and len(manifest['items'])==24
 assert len({i['id'] for i in manifest['items']})==24
 for region in range(1,7):
  group=[i for i in manifest['items'] if i['region_id']==f'ch{region:02}']
  assert {i['role'] for i in group}=={'bed','landmark','event_a','event_b'}
 for i in manifest['items']:
  assert i['human_listening_review']=='pending' and i['license']=='CC0-1.0'
  assert not i['loop'] or (i['loop_start_sample']==0 and i['loop_end_sample']==round(i['duration_seconds']*48000))
 profiles=json.loads((ASSETS/'mix_profiles.json').read_text())['profiles']
 assert len(profiles)==6
 cue_ids={i['id'] for i in manifest['items']}
 for p in profiles:
  assert {p['bed_cue_id'],p['landmark_cue_id'],*p['events']['cue_ids']}<=cue_ids
  assert p['landmark_spatial']['near_distance_m']<p['landmark_spatial']['far_distance_m']
 assert sum(p.stat().st_size for p in ASSETS.glob('*.ogg'))<5_000_000
 for item in manifest['items']:
  p=ASSETS/item['file'];c=item['channels']
  raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-acodec','pcm_f32le','pipe:1'])
  x=np.frombuffer(raw,dtype='<f4').reshape(-1,c);n=len(x)
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(p)]))['streams'][0]
  peak=float(np.max(abs(x)));rms=float(np.sqrt(np.mean(x*x)));truepeak=float(np.max(abs(resample_poly(x,4,1,axis=0))))
  ff=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(p),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True,check=True).stderr
  import re
  integ=float(re.findall(r'I:\s+(-?[\d.]+) LUFS',ff)[-1]);boundary=float(np.max(abs(x[0]-x[-1])))
  step=np.abs(np.diff(x,axis=0));q99=float(np.quantile(step,.99));edge=max(float(abs(x[:240]).max()),float(abs(x[-240:]).max()))
  checks={'finite':bool(np.isfinite(x).all()),'sample_rate':int(probe['sample_rate'])==48000,'channels':int(probe['channels'])==c,'exact_frames':n==int(item['duration_seconds']*48000),'peak_below_minus_8_dbtp':truepeak<10**(-8/20),'loop_seam_below_minus_55_dbfs':not item['loop'] or boundary<10**(-55/20),'loop_edge_below_minus_35_dbfs':not item['loop'] or edge<10**(-35/20)}
  rows.append(dict(id=item['id'],sha256=sha(p),bytes=p.stat().st_size,frames=n,sample_peak_dbfs=db(peak),true_peak_4x_dbtp=db(truepeak),rms_dbfs=db(rms),integrated_lufs=integ,loop_seam_jump_dbfs=db(boundary) if item['loop'] else None,loop_edge_5ms_peak_dbfs=db(edge) if item['loop'] else None,interior_step_p99_dbfs=db(q99),checks=checks))
 with tempfile.TemporaryDirectory(prefix='ambience-rebuild-') as td:
  second=pathlib.Path(td);subprocess.run(['python',str(ROOT/'tools/proposals/audio_category_ambience/build.py'),'--out',td],check=True)
  proof=[dict(file=p.name,build_a_sha256=sha(p),build_b_sha256=sha(second/p.name),identical=sha(p)==sha(second/p.name)) for p in sorted(ASSETS.iterdir()) if p.suffix in ['.ogg','.json']]
 report=dict(schema_version=1,status='machine_validation_only_human_listening_pending',measurement='decoded ffmpeg float32; sample peak, scipy resample_poly 4x estimated true peak; ffmpeg EBU R128 integrated LUFS; seam compares last sample to first; edge maximum first/last 5ms',encoder=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],numpy_version=np.__version__,items=rows,total_ogg_bytes=sum(r['bytes'] for r in rows),reproducibility=proof,all_checks_pass=all(all(r['checks'].values()) for r in rows) and all(p['identical'] for p in proof))
 DOCS.mkdir(parents=True,exist_ok=True);(DOCS/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'pass':report['all_checks_pass'],'bytes':report['total_ogg_bytes'],'failed':[{r['id']:r['checks']} for r in rows if not all(r['checks'].values())],'reproducible':all(p['identical'] for p in proof)},indent=2))
 assert report['all_checks_pass']
if __name__=='__main__':main()
