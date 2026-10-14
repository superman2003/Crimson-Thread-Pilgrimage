#!/usr/bin/env python3
"""Original, deterministic six-region combat-material proposal. Never touches runtime.
Requires Python 3.10+, numpy, scipy, ffmpeg (only for measurements).
"""
from pathlib import Path
import argparse, hashlib, html, json, subprocess, tempfile, wave
import numpy as np
import scipy
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/proposals/reverse_audio'
DOC = ROOT / 'docs/proposals/reverse_audio'
SR = 48000
REGIONS = {
  1: ('moss_bell_court', '苔钟庭', 'damped bronze / moss friction', 146.83, [1, 2.73, 4.11], 780),
  2: ('rain_foundry_canal', '铸雨渠', 'wet iron / pressure spray', 98., [1, 1.47, 3.62], 1250),
  3: ('saltwhite_archive', '盐白档案馆', 'salt fracture / paper grains', 440., [1, 1.83, 2.71], 2600),
  4: ('broken_string_greenhouse', '断弦温室', 'plucked fiber / snapped wood', 164.81, [1, 2, 3.02], 1700),
  5: ('obsidian_pilgrim_road', '黑曜巡礼路', 'muted marching shell / ash', 73.42, [1, 1.39, 2.07], 520),
  6: ('silent_crown_core', '寂冠核心', 'choked crown / inward pressure', 293.66, [1, 1.05946, 2.012], 950),
}
DUR = {'warning': .60, 'attack_body': .90, 'attack_detail': .90, 'hurt': .46}
PEAK = {'warning': -9., 'attack_body': -10., 'attack_detail': -16., 'hurt': -13.}

def db(x): return float(20*np.log10(max(float(x), 1e-12)))
def t(d): return np.arange(round(SR*d))/SR
def fade(x, start=.004, end=.025):
    x=x.copy(); a=min(round(SR*start),len(x)//2); b=min(round(SR*end),len(x)//2)
    x[:a]*=np.linspace(0,1,a); x[-b:]*=np.linspace(1,0,b); return x

def filt(x, low, high):
    return sosfilt(butter(3, [low,high], btype='bandpass', fs=SR, output='sos'),x)

def material(ch, dur, rng):
    _,_,_,base,ratios,band=REGIONS[ch]; tt=t(dur)
    out=sum((1/(i+1)**1.3)*np.sin(2*np.pi*base*r*tt + .12*np.sin(2*np.pi*(7+ch)*tt))*np.exp(-tt/(.22/(i+1)**.6)) for i,r in enumerate(ratios))
    grit=filt(rng.standard_normal(len(tt)), max(80,band*.45), min(7000,band*2.1))
    if ch==1: out=.75*out+.30*grit*np.exp(-tt/.12)
    elif ch==2: out=.48*out+.8*grit*(.55+.45*np.sin(2*np.pi*29*tt)**2)*np.exp(-tt/.22)
    elif ch==3: out=.65*out+.55*grit*(np.sin(2*np.pi*43*tt)**12)*np.exp(-tt/.14)
    elif ch==4: out=.8*out+.55*grit*np.exp(-tt/.045)
    elif ch==5: out=.95*out+.3*grit*np.exp(-tt/.085)
    else: out=.55*out+.5*grit*np.exp(-tt/.19)*(1-.8*np.exp(-((tt-.095)/.025)**2))
    return fade(out)

def render(ch, role):
    seed=2026101400+ch*10+list(DUR).index(role)
    rng=np.random.default_rng(seed); tt=t(DUR[role]); n=len(tt)
    if role=='warning':
        # Same two dry pulses across regions: urgency is rhythm, identity is timbre.
        x=np.zeros(n)
        for at in (0., .17):
            pulse=material(ch,.13,rng); i=round(at*SR); x[i:i+len(pulse)]+=pulse
        tension=filt(rng.standard_normal(n),450,1800)*np.sin(np.pi*tt/DUR[role])**2
        x+=.22*tension
        x+=.10*np.sin(2*np.pi*(650*tt+180*tt**2))*np.sin(np.pi*tt/.60)**2
    elif role=='attack_body':
        f0=[0,112,95,175,130,78,100][ch]
        phase=2*np.pi*(f0*.032*(1-np.exp(-tt/.032))+48*tt)
        x=np.sin(phase)*np.exp(-tt/.11)
        x+=.22*filt(rng.standard_normal(n),80,600)*np.exp(-tt/.065)
    elif role=='attack_detail':
        x=material(ch,DUR[role],rng)
        # Split chips, water droplets or fiber snaps at region-specific intervals.
        delays={1:(.064,.153),2:(.038,.082,.146,.231),3:(.046,.097,.169),4:(.055,.116),5:(.086,),6:(.072,.182)}[ch]
        for j,at in enumerate(delays):
            p=material(ch,.15,rng); i=round(at*SR); x[i:i+len(p)]+=.24/(j+1)*p
    else:
        x=material(ch,DUR[role],rng)*np.exp(-tt/.065)
        x+=.28*filt(rng.standard_normal(n),650,3400)*np.exp(-tt/.018)
    x=fade(x); x-=np.mean(x); x=fade(x)
    x*=10**(PEAK[role]/20)/np.max(np.abs(x))
    return x,seed

def write(path,x):
    path.parent.mkdir(parents=True,exist_ok=True)
    pcm=np.rint(np.clip(x,-1,1)*32767).astype('<i2')
    with wave.open(str(path),'wb') as w:
        w.setparams((1,2,SR,0,'NONE','not compressed')); w.writeframes(pcm.tobytes())
    return pcm.astype(float)/32768

def write_preview(path,x):
    # Lossless stems are retained; compressed audition saves repository transfer size.
    path.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        raw=Path(tmp)/'preview.wav'; write(raw,x)
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-c:a','libvorbis','-q:a','5',str(path)],check=True)

def read(path):
    if path.suffix=='.ogg':
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','s16le','-ar',str(SR),'-ac','1','-'])
        return np.frombuffer(raw,'<i2').astype(float)/32768
    with wave.open(str(path),'rb') as w:
        assert w.getnchannels()==1 and w.getsampwidth()==2 and w.getframerate()==SR
        return np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768

def meter(path,x):
    run=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-20:TP=-3:LRA=7:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    block=run.stderr[run.stderr.rfind('{'):run.stderr.rfind('}')+1]; loud=json.loads(block)
    active=np.flatnonzero(np.abs(x)>10**(-60/20))
    return {'duration_s':len(x)/SR,'sample_peak_dbfs':round(db(np.max(np.abs(x))),3),
      'true_peak_4x_dbfs_estimate':round(db(np.max(np.abs(resample_poly(x,4,1)))),3),
      'integrated_lufs':float(loud['input_i']),'ffmpeg_true_peak_dbtp':float(loud['input_tp']),
      'rms_dbfs':round(db(np.sqrt(np.mean(x*x))),3),'dc_offset':round(float(np.mean(x)),8),
      'digital_zero_percent':round(float(np.mean(x==0)*100),3),'clipped_samples':int(np.sum(np.abs(x)>=32767/32768)),
      'leading_below_minus60_ms':round(active[0]/SR*1000,3) if len(active) else None,
      'trailing_below_minus60_ms':round((len(x)-1-active[-1])/SR*1000,3) if len(active) else None,
      'first_sample':float(x[0]),'last_sample':float(x[-1]),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def build():
    OUT.mkdir(parents=True,exist_ok=True); DOC.mkdir(parents=True,exist_ok=True)
    (OUT/'.gitattributes').write_text('*.wav -filter -diff -merge -text\n*.ogg -filter -diff -merge -text\n',encoding='utf8')
    rows=[]; reels=[]; cue=[]
    for ch in range(6,0,-1):
        slug,name,texture,base,ratios,band=REGIONS[ch]; clips={}
        for role in DUR:
            x,seed=render(ch,role); key=f'ch{ch:02d}_{role}'; path=OUT/'stems'/f'{key}.wav'; clips[role]=write(path,x)
            rows.append({'id':key,'chapter':ch,'region_id':f'ch{ch:02d}_{slug}','region_name':name,'role':role,'path':str(path.relative_to(ROOT)),
              'source':'Original mathematical synthesis; no sampled or reference-game audio','seed':seed,'sample_rate_hz':SR,'channels':1,'bits':16,'loop':False,
              'base_hz':base,'partial_ratios':ratios,'noise_band_center_hz':band,'texture':texture,'target_sample_peak_dbfs':PEAK[role],
              'playback_gain_db':0,'status':'proposal_not_wired'})
        # Timeline: warning; body solo; detail solo; simultaneous pair; hurt.
        reel=np.zeros(SR*8)
        for role,at in [('warning',.25),('attack_body',1.50),('attack_detail',2.75),('attack_body',4.),('attack_detail',4.),('hurt',5.5)]:
            x=clips[role]; i=round(at*SR); reel[i:i+len(x)]+=x
        preview=OUT/'audition'/f'ch{ch:02d}_layers.ogg'; write_preview(preview,reel)
        cue.append({'chapter':ch,'name':name,'reel_start_s':len(reels)*8,'preview':str(preview.relative_to(ROOT)),
          'local_events_s':{'warning':.25,'body_solo':1.5,'detail_solo':2.75,'body_plus_detail':4.,'hurt':5.5}})
        reels.append(reel)
    write_preview(OUT/'audition/reverse_ch06_to_ch01.ogg',np.concatenate(reels))
    manifest={'version':1,'license':'CC0-1.0 (new synthesized audio only)','sample_rate_hz':SR,'runtime_modified':False,
      'audition_normalization':'none; PCM stems summed at unity before Vorbis q5 encoding; lossy audition codec can change peaks','cue_sheet':cue,'assets':rows}
    (DOC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    cards=[]
    for c in cue:
        ch=c['chapter']; links=' '.join(f'<p>{r} <audio controls preload="none" src="../../../assets/proposals/reverse_audio/stems/ch{ch:02d}_{r}.wav"></audio></p>' for r in DUR)
        cards.append(f'<section><h2>CH{ch:02d} {html.escape(c["name"])}</h2><audio controls preload="none" src="../../../{c["preview"]}"></audio><details><summary>独立分层试听</summary>{links}</details></section>')
    (DOC/'audition.html').write_text('''<!doctype html><meta charset="utf-8"><title>绯线巡礼 · 六章战斗音候选</title><style>body{background:#111821;color:#e6dcc8;font:17px system-ui;max-width:950px;margin:40px auto;padding:24px}h1{color:#dc8170}section{background:#1e2731;padding:20px;border-radius:12px;margin:18px 0}audio{width:100%;margin:12px 0}summary{cursor:pointer;color:#d3b882}</style><h1>从寂冠核心倒推六区 · 原创战斗音候选</h1><p>48 kHz / mono / PCM16 · 24 个独立素材 · 未接运行时</p><p>每章：0.25s 预警 → 1.50s 主体 → 2.75s 材质 → 4.00s 同步叠加 → 5.50s 受击。试听保留原增益，无自动响度统一。先降低播放音量。</p><p>总试听按 CH06→CH01，每章 8 秒。</p><audio controls preload="none" src="../../../assets/proposals/reverse_audio/audition/reverse_ch06_to_ch01.ogg"></audio>'''+''.join(cards)+'<p>客观指标通过不等于混音或玩家识别实听验收。请参阅 README.md。</p>',encoding='utf8')

def verify():
    manifest=json.loads((DOC/'manifest.json').read_text()); results={}; failures=[]
    expected_paths={str(ROOT/r['path']) for r in manifest['assets']}
    expected_paths.update(str(ROOT/c['preview']) for c in manifest['cue_sheet'])
    expected_paths.add(str(OUT/'audition/reverse_ch06_to_ch01.ogg'))
    # Validate the declared delivery inventory; unrelated/stale local files are not delivery assets.
    for path in sorted(Path(p) for p in expected_paths):
        x=read(path); m=meter(path,x); results[str(path.relative_to(ROOT))]=m
        is_stem='stems' in path.parts
        if m['clipped_samples'] or m['ffmpeg_true_peak_dbtp']> -3 or m['rms_dbfs']< -60: failures.append(str(path))
        if is_stem and (m['leading_below_minus60_ms']>10 or abs(m['first_sample'])>1/32768 or abs(m['last_sample'])>1/32768): failures.append(str(path))
    for row in manifest['assets']:
        path=ROOT/row['path']; expected,_=render(row['chapter'],row['role'])
        expected=np.rint(np.clip(expected,-1,1)*32767).astype('<i2').astype(float)/32768
        if not np.array_equal(read(path),expected): failures.append('reproducibility: '+row['id'])
    for ch in REGIONS:
        body=read(OUT/'stems'/f'ch{ch:02d}_attack_body.wav'); detail=read(OUT/'stems'/f'ch{ch:02d}_attack_detail.wav')
        combo=body+detail
        if db(np.max(np.abs(resample_poly(combo,4,1))))> -3: failures.append(f'layer peak ch{ch}')
    report={'passed':not failures,'files_checked':len(results),'deterministic_stems_checked':24,
      'loop_policy':'All 24 are one-shots. loop=false; no loop seam acceptance claimed.',
      'metrics_note':'Integrated LUFS on short transients is descriptive, not a perceptual loudness target. 4x resampling true peak is an estimate; ffmpeg loudnorm also measures dBTP. Silence measured at -60dBFS, exact zero percentage separately. No listening acceptance performed. OGG auditions are decoded to PCM16 for RMS/silence checks and directly measured by ffmpeg loudnorm for LUFS/true peak.',
      'failures':failures,'tool_versions':{'numpy':np.__version__,'scipy':scipy.__version__,'ffmpeg':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0]},'measurements':results}
    (DOC/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('passed','files_checked','deterministic_stems_checked','failures')}))
    if failures: raise SystemExit(1)

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--verify-only',action='store_true'); a=p.parse_args()
    if not a.verify_only: build()
    verify()
