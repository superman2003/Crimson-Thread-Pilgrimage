#!/usr/bin/env python3
"""Original proposal scores, deterministic additive synthesis; no runtime writes.
Run from any cwd: python tools/proposals/reverse_music_v2/build.py
Dependencies: requirements.txt, ffmpeg/ffprobe with libvorbis. No sample libraries.
"""
from __future__ import annotations
import hashlib, json, math, re, subprocess, tempfile
from pathlib import Path
import numpy as np
import scipy
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT/'assets/proposals/reverse_music_v2'
DOC = ROOT/'docs/proposals/reverse_music_v2'
SR = 48000
SEED = 2026101406

def run(cmd, data=None):
    return subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

def db(v): return float(20*np.log10(max(float(v),1e-12)))
def note(s):
    if isinstance(s,(int,float)): return float(s)
    m=re.fullmatch(r'([A-G])([b#]?)(\d)',s)
    return 12*(int(m[3])+1)+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[m[1]]+{'':0,'b':-1,'#':1}[m[2]]

def synth(kind, midi, duration, rng):
    """All timbres are synthetic suggestions, never recordings or human voices."""
    n=round(duration*SR); t=np.arange(n)/SR; f=440*2**((note(midi)-69)/12)
    vibrato = 0.0008*np.sin(2*np.pi*4.8*t) if kind in ('bow','horn','voice','flute') else 0
    phase=2*np.pi*f*(t+vibrato)
    if kind in ('bronze','glass','celesta'):
        ratios={'bronze':[1,2.01,2.76,4.07,5.43], 'glass':[1,2,3.01,4.02], 'celesta':[1,2,3.98,5.02]}[kind]
        weights={'bronze':[1,.33,.16,.09,.04],'glass':[1,.19,.09,.03],'celesta':[1,.3,.09,.035]}[kind]
        y=sum(w*np.sin(phase*r)*np.exp(-t/(duration*(.34-.04*i))) for i,(r,w) in enumerate(zip(ratios,weights)))
        attack=.014 if kind=='bronze' else .009
    elif kind in ('pluck','harpsi'):
        weights=[1,.34,.17,.075,.035] if kind=='pluck' else [1,.5,.24,.14,.08,.04]
        y=sum(w*np.sin(phase*(i+1))*np.exp(-t/(duration*(.20/(1+.22*i)))) for i,w in enumerate(weights)); attack=.007
    elif kind=='voice':
        # Pure additive vowel-like partials: no recorded voice, words or impersonation.
        y=sum(w*np.sin(phase*(i+1)) for i,w in enumerate([1,.32,.16,.23,.09,.035]))
        y*=.87+.13*np.sin(np.pi*t/duration); attack=.38
    elif kind=='flute':
        y=np.sin(phase)+.1*np.sin(2*phase)+.028*np.sin(3*phase); attack=.11
    elif kind=='horn':
        y=sum(w*np.sin(phase*(i+1)) for i,w in enumerate([1,.55,.3,.17,.09,.04])); attack=.085
    elif kind=='organ':
        y=np.sin(phase)+.38*np.sin(phase*2)+.20*np.sin(phase*3)+.13*np.sin(phase/2); attack=.08
    elif kind=='bow':
        y=sum(w*np.sin(phase*(i+1)) for i,w in enumerate([1,.28,.16,.09,.05,.027])); attack=.16
    elif kind=='thump':
        y=np.sin(2*np.pi*(f*t+1.9*(1-np.exp(-t*32))))*np.exp(-t*16); attack=.012
    elif kind=='brush':
        noise=rng.standard_normal(n)
        freq=np.fft.rfftfreq(n,1/SR)
        spectrum=np.fft.rfft(noise)*np.exp(-((freq-850)/600)**2)
        y=np.fft.irfft(spectrum,n=n)*np.exp(-t*24)*.35; attack=.012
    else: raise ValueError(kind)
    a=np.minimum(t/max(attack,.001),1)
    release=min(.20,duration*.24)
    env=np.sin(a*np.pi/2)**2*np.minimum(np.maximum((duration-t)/release,0),1)**2
    return y*env/1.8

class Score:
    def __init__(self,bpm,bars,seed):
        self.bpm=bpm; self.bars=bars; self.offset=np.r_[0,np.cumsum(bars)]
        self.seconds=float(self.offset[-1]*60/bpm); self.n=round(SR*self.seconds)
        self.x=np.zeros((self.n,2)); self.rng=np.random.default_rng(seed); self.events=[]
    def add(self,bar,beat,pitch,length,kind='pluck',amp=.13,pan=0):
        onset=(self.offset[bar]+beat)*60/self.bpm
        duration=length*60/self.bpm
        y=synth(kind,pitch,duration,self.rng)*amp
        stereo=y[:,None]*np.array([np.cos((pan+1)*np.pi/4),np.sin((pan+1)*np.pi/4)])
        start=round(onset*SR)%self.n
        # Modulo overlap-add includes releases from the previous loop at frame 0.
        for j in range(0,len(y),self.n):
            z=stereo[j:j+self.n]; k=min(len(z),self.n-start)
            self.x[start:start+k]+=z[:k]
            if len(z)>k:self.x[:len(z)-k]+=z[k:]
        self.events.append(dict(bar=bar+1,beat=beat,midi=note(pitch),length_beats=length,timbre=kind,gain=amp,pan=pan))
    def line(self,bar,events,kind,amp,pan=0,shift=0):
        for beat,pitch,length in events:self.add(bar,beat,note(pitch)+shift,length,kind,amp,pan)
    def finish(self):
        dry=self.x.copy()
        # Circular stereo early reflections and decaying diffusion: no endpoint fade.
        for delay,gain in [(.071,.12),(.113,.10),(.179,.08),(.293,.065),(.431,.045),(.683,.026),(.947,.014)]:
            self.x+=np.roll(dry[:,::-1],round(delay*SR),axis=0)*gain
        freq=np.fft.rfftfreq(self.n,1/SR)
        response=(1-np.exp(-(freq/35)**4))/np.sqrt(1+(freq/6200)**8)
        response*=1-.28*np.exp(-((freq-2900)/1250)**2) # reduce masking of dialogue/cues
        self.x=np.fft.irfft(np.fft.rfft(self.x,axis=0)*response[:,None],n=self.n,axis=0)
        return self.x

REGIONS=[
 dict(id='ch06',name='无声王冠',alias='寂冠核心',bpm=48,bars=[4]*8,meter='4/4 (inaudible timing grid)',titles=['未落之名','百钥问名'],motif='D5—Bb4; long rest; Bb4—D5—Bb4',desc='删去纯四度的双音长句；合成元音与远钟留白，Boss 加入五城音色回忆。'),
 dict(id='ch05',name='黑曜巡礼道',alias='黑曜巡礼路',bpm=100,bars=[4]*16,meter='4/4',titles=['灯列越过黑曜','镜中新娘的步差'],motif='D3–Eb3–A2 | C3–Bb2–Eb3',desc='弗里几亚号角行列与弱拍闷刷；Boss 让三拍镜像旋律穿过四拍步伐。'),
 dict(id='ch04',name='断弦温室',alias='断弦温室',bpm=58,bars=[5,6]*4,meter='5/4 + 6/4 alternating',titles=['玻璃替花呼吸','铜根的第八次回返'],motif='E4…G4 | B3…F#4–E4; D4…A3–Bb3',desc='不等长乐句、截断拨弦、玻璃泛音；Boss 固定低音与合成元音增加压力。'),
 dict(id='ch03',name='盐白书库',alias='盐白档案馆',bpm=60,bars=[4]*8,meter='4/4',titles=['盐页背面的字','被复写的裁决'],motif='A4–C5–D#5–B4 | E5–D5–C5',desc='钢片琴利底亚亮色，延迟两拍的逆行模仿；Boss 羽管式短音加密，无鼓无低音。'),
 dict(id='ch02',name='铸雨渠',alias='铸雨渠',bpm=92,bars=[4]*16,meter='4/4',titles=['水轮记得姓名','双剪之间的余线'],motif='G3–Bb3–A3–D4 | F4–Eb4–D4',desc='2+3+3 锻打切分与大提琴式旋律；Boss 交错二拍与三拍，保持金属瞬态克制。'),
 dict(id='ch01',name='苔钟庭',alias='苔钟庭',bpm=72,bars=[3]*16,meter='6/8 (quarter-note BPM)',titles=['苔痕里的第三声','守母仍在摇钟'],motif='D4–A3–Bb3 | F4–E4–G4–E4',desc='青铜钟、竖琴式分解与木笛应答；Boss 弓弦、低鼓与绯线对题扩大摇摆。'),
]

def compose(r,boss):
    c=Score(r['bpm'],r['bars'],SEED+int(r['id'][2:])*100+boss)
    a=c.add; line=c.line; n=len(r['bars']); ch=r['id']
    if ch=='ch01':
        roots=['D3','D3','G2','G2','F3','F3','A2','A2']*2
        for b,root in enumerate(roots):
            a(b,0,root,3.4,'bow',.10 if boss else .07,-.15)
            for j,k in enumerate([0,7,14] if not boss else [0,7,12,14,7,12]):
                a(b,j*(.5 if boss else 1),note(root)+12+k,1.0,'pluck',.105 if boss else .085,(-1)**j*.4)
            if b%4==0:line(b,[(0,'D4',2.2),(1.5,'A3',1.0),(2,'Bb3',2.2)],'bronze',.22 if boss else .17,-.28)
            if b%4==2:line(b,[(.25,'F4',.9),(1,'E4',.7),(1.75,'G4',.7),(2.5,'E4',1.5)],'flute',.16,.24)
            if boss:
                for beat in [0,1.5]:a(b,beat,'D2',.5,'thump',.12)
                if b>=8 and b%4==1:line(b,[(0,'D4',.6),(.5,'Bb4',.5),(1,'A4',.5),(1.5,'G4',.5),(2,'F4',.5),(2.5,'E4',.6)],'pluck',.17,.18)
    elif ch=='ch02':
        roots=['G2','G2','Eb3','Eb3','C3','C3','D3','D3']*2
        for b,root in enumerate(roots):
            beats=[0,1,2.5] if not boss else [0,.5,1,1.5,2.5,3,3.5]
            for j,beat in enumerate(beats):
                a(b,beat,note(root)+(12 if j%2 else 0),.7,'pluck',.15 if boss else .13,-.15)
                a(b,beat, 'D4' if j%2 else 'A3',.55,'bronze',.043 if boss else .037,.4)
            if b%4 in [0,2]:
                m=[(0,'G3',1.3),(1.5,'Bb3',.6),(2.25,'A3',.6),(3,'D4',1.2)] if b%4==0 else [(0,'F4',1.2),(1.5,'Eb4',1),(3,'D4',1.4)]
                line(b,m,'bow',.20 if boss else .18,-.3)
            if boss:
                for beat in [0,1.5,3]:a(b,beat,'G2',.45,'thump',.11)
                if b%4==3:line(b,[(0,'D4',.4),(.5,'Bb4',.4),(1,'A4',.4),(1.5,'G4',.4),(2,'F4',.4),(2.5,'E4',.8)],'pluck',.13,.25)
    elif ch=='ch03':
        motif=[(0,'A4',.8),(1,'C5',.65),(1.75,'D#5',.5),(2.5,'B4',1.3)]
        answer=[(0,'E5',1.0),(1.5,'D5',.7),(2.5,'C5',1.5)]
        for b in range(n):
            events=motif if b%2==0 else answer
            line(b,events,'celesta',.19,-.45)
            # Reversed pitch order, onset delayed exactly two quarter notes.
            pitches=[e[1] for e in events][::-1]
            for j,(beat,_,length) in enumerate(events):
                pos=beat+2; dest=(b+int(pos//4))%n
                a(dest,pos%4,note(pitches[j])-12,length*1.18,'glass',.09 if not boss else .14,.5)
            if boss:
                arps=['A4','E5','B4','C5','D#5','E5','C5','B4'] if b%2==0 else ['G4','D5','A4','B4','C5','D5','B4','A4']
                for j,p in enumerate(arps):a(b,j*.5,p,.42,'harpsi',.075,(-1)**j*.15)
                if b in [3,7]:line(b,[(0,'D5',.4),(.5,'Bb5',.4),(1,'A5',.4),(1.5,'G5',.4),(2,'F5',.4),(2.5,'E5',.8)],'pluck',.08,.15)
    elif ch=='ch04':
        ground=['E2','D2','C2','B1','E2','G2','A2','B1']
        for b,meter in enumerate(r['bars']):
            if b%2==0:line(b,[(0,'E4',.6),(1.75,'G4',.5),(3.5,'B3',.65)],'pluck',.18,-.4)
            else:line(b,[(.5,'F#4',.6),(2,'E4',.7),(4,'D4',.5)],'pluck',.17,-.4)
            a(b,meter-1,'Bb4' if b%2 else 'A4',2.8,'glass',.105,.4)
            if b in [0,4]:a(b,1,'E4',3.4,'voice',.067,.2)
            if b in [2,6]:line(b,[(0,'D4',.7),(2,'A3',.6),(4,'Bb3',2.2)],'glass',.11,.3)
            if boss:
                a(b,0,ground[b],meter+.3,'organ',.18,-.15)
                a(b,0,note(ground[b])+19,meter*.75,'bow',.08,.1)
                for j in [1,2.5,4]:a(b,j,note(ground[b])+24,.4,'pluck',.11,.4)
                if b>=4:a(b,1,'B3' if b%2 else 'E4',meter-1,'voice',.08,.15)
    elif ch=='ch05':
        roots=['D2','D2','Eb2','Eb2','C2','C2','A1','A1']*2
        march=[(0,'D3',1.5),(2,'Eb3',.7),(3,'A2',1.0)]
        answer=[(0,'C3',1.4),(2,'Bb2',.7),(3,'Eb3',1.1)]
        for b,root in enumerate(roots):
            a(b,0,root,3.5,'bow',.10,-.2)
            if b%2==0:line(b,march if b%4==0 else answer,'horn',.19 if boss else .15,-.2)
            for beat in [1,3]:a(b,beat,'D3',.25,'brush',.035 if boss else .019,.25)
            if boss:
                a(b,0,'D2',.5,'thump',.10)
                # Three-beat cells move against four-beat procession; second half mirrored.
                contour=[0,1,7,5,3,1] if b<8 else [0,-1,-7,-5,-3,-1]
                for j in range(4):a(b,j*.75,62+contour[(b*4+j)%6],.8,'bow',.13,.35)
                if b%4==3:a(b,2,'Bb3',2.0,'celesta',.10,.5)
            elif b in [3,7,11,15]:a(b,0,'A3',3.3,'voice',.07,.3)
    elif ch=='ch06':
        for b in range(n):
            if b in [0,3,4,7]:a(b,.35,'D5' if b in [0,4] else 'Bb4',2.4,'voice',.16,-.15)
            if b in [1,5]:a(b,2,'Bb4',1.5,'voice',.10,.15)
        a(6,0,'D2',5.5,'bronze',.08,.4)
        if boss:
            # Composed roll-call, not copied audio from existing packs.
            line(0,[(0,'D4',1.5),(1.5,'A3',.6),(2.25,'Bb3',1.4)],'bronze',.10,-.4)
            line(1,[(0,'G3',.6),(1,'Bb3',.6),(2.5,'A3',.8)],'bow',.11,.3)
            line(2,[(0,'A4',.6),(1,'C5',.6),(2,'D#5',.6),(3,'B4',1)],'celesta',.10,-.35)
            line(3,[(0,'E4',.5),(1.5,'G4',.5),(3,'Bb4',1)],'pluck',.12,.35)
            line(4,[(0,'D3',1.4),(2,'Eb3',.6),(3,'A2',1)],'horn',.12,-.3)
            for b in [5,6]:
                a(b,0,'D3',4.5,'organ',.085,-.2)
                line(b,[(0,'D4',.5),(.5,'Bb4',.5),(1,'A4',.5),(1.5,'G4',.5),(2,'F4',.5),(2.5,'E4',1)],'pluck',.095,.3)
            # Last bar deliberately returns to exposed synthetic vowel, not an ending cadence.
    return c,c.finish()

def loudness(path):
    p=run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-23:TP=-3:LRA=11:print_format=json','-f','null','-'])
    text=p.stderr.decode(); return json.loads(text[text.rfind('{'):text.rfind('}')+1])

def write_float(path,x):path.write_bytes(np.asarray(x,dtype='<f4').tobytes())

def assess(path,expected):
    raw=run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-']).stdout
    x=np.frombuffer(raw,dtype='<f4').reshape(-1,2).astype(float)
    probe=json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(path)]).stdout)
    l=loudness(path); delta=np.abs(np.diff(x,axis=0)); seam=float(np.max(np.abs(x[0]-x[-1])))
    p99=float(np.quantile(delta,.99)); peak=float(np.max(np.abs(x)))
    # 4x polyphase estimate across a repeated boundary, not zero-padded seam.
    repeated=np.concatenate([x[-256:],x,x[:256]])
    truepeak=db(np.max(np.abs(resample_poly(repeated,4,1,axis=0)[1024:-1024])))
    w=SR//10; rmswin=np.sqrt(np.mean(x[:len(x)//w*w].reshape(-1,w,2)**2,axis=(1,2)))
    rms=np.sqrt(np.mean(x*x)); local=np.sqrt(np.mean(np.r_[x[-480:],x[:480]]**2))
    tests=dict(sample_rate_48000=probe['streams'][0]['sample_rate']=='48000',stereo=probe['streams'][0]['channels']==2,
        exact_decoded_frame_count=len(x)==expected,under_350000_bytes=path.stat().st_size<350000,
        true_peak_below_minus_3_db=truepeak<-3,finite=bool(np.all(np.isfinite(x))),
        seam_step_within_local_slope_budget=seam<max(.006,4*p99))
    return dict(file=path.relative_to(PACK).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bytes=path.stat().st_size,
        sample_rate=48000,channels=2,decoded_frames=len(x),expected_frames=expected,duration_seconds=len(x)/SR,
        sample_peak_dbfs=round(db(peak),3),true_peak_4x_dbtp=round(truepeak,3),ffmpeg_input_tp_dbtp=float(l['input_tp']),
        integrated_lufs=float(l['input_i']),loudness_range_lu=float(l['input_lra']),rms_dbfs=round(db(rms),3),crest_factor_db=round(db(peak/rms),3),
        window_rms_p90_minus_p10_db=round(db(np.quantile(rmswin,.9))-db(np.quantile(rmswin,.1)),3),
        loop_seam_max_step=round(seam,8),loop_seam_step_dbfs=round(db(seam),3),interior_step_p99=round(p99,8),
        seam_step_to_interior_p99=round(seam/max(p99,1e-12),3),seam_20ms_rms_dbfs=round(db(local),3),checks=tests,technical_pass=all(tests.values()))

def main():
    PACK.joinpath('audio').mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
    items=[];metrics=[];scores={}
    with tempfile.TemporaryDirectory(prefix='reverse_music_v2_') as td:
        td=Path(td)
        for r in REGIONS:
            for boss in [False,True]:
                role='boss' if boss else 'exploration'; ident=r['id']+'_'+role
                c,x=compose(r,boss); expected=len(x)
                raw=td/'raw.f32'; wav=td/'measure.wav';write_float(raw,x)
                run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','2','-i',str(raw),str(wav)])
                measured=loudness(wav);target=(-26 if boss else -29) if r['id']=='ch06' else (-21 if boss else -24)
                gain=min(10**((target-float(measured['input_i']))/20),10**(-4/20)/np.max(np.abs(x)))
                x*=gain;write_float(raw,x);dest=PACK/'audio'/f'{ident}.ogg'
                run(['ffmpeg','-v','error','-y','-fflags','+bitexact','-f','f32le','-ar',str(SR),'-ac','2','-i',str(raw),'-map_metadata','-1','-c:a','libvorbis','-q:a','0','-fflags','+bitexact','-flags:a','+bitexact','-serial_offset',str(SEED+len(items)),'-metadata','title='+r['titles'][boss],'-metadata','artist=Crimson Thread procedural score proposal','-metadata','LOOPSTART=0','-metadata',f'LOOPEND={expected}',str(dest)])
                m=assess(dest,expected)
                m['target_lufs']=target
                m['checks']['integrated_loudness_within_half_lu']=abs(m['integrated_lufs']-target)<.5
                m['technical_pass']=all(m['checks'].values())
                metrics.append(m)
                bars=[round(float(b)*60/r['bpm'],9) for b in c.offset]
                phrases=bars[::4 if len(r['bars'])==16 else 2]
                item=dict(id=ident,title=r['titles'][boss],region_id=r['id'],type='audio',role=role,file=dest.relative_to(PACK).as_posix(),duration_seconds=expected/SR,loop=True,bpm=r['bpm'],description=r['desc'],region_name=r['name'],region_legacy_alias=r['alias'],meter=r['meter'],bar_count=len(r['bars']),bar_start_seconds=bars[:-1],phrase_boundaries_seconds=phrases,loop_start_sample=0,loop_end_sample_exclusive=expected,sample_rate=SR,channels=2,motif=r['motif'],recommended_playback_gain_db=-5 if boss else -3,target_lufs=target,source='Original deterministic procedural composition and additive synthesis; no recordings',license='CC0-1.0',integration_status='proposal_only_not_runtime_wired',human_listening_review='pending')
                items.append(item);scores[ident]=dict(seed=SEED+int(r['id'][2:])*100+boss,events=c.events)
                print(ident,expected/SR,m['bytes'],m['integrated_lufs'],m['true_peak_4x_dbtp'],m['technical_pass'],flush=True)
    manifest=dict(schema_version=1,pack_id='reverse_music_v2',title='六城回声 · 六区探索与 Boss 原创循环提案',kind='music',items=items)
    report=dict(schema_version=1,pack_id='reverse_music_v2',method='Decoded OGG checks; FFmpeg EBU R128 loudnorm input measurements; 4x scipy resample_poly true-peak estimate; no listening approval',environment=dict(numpy=np.__version__,scipy=scipy.__version__,ffmpeg=run(['ffmpeg','-version']).stdout.decode().splitlines()[0]),total_bytes=sum(x['bytes'] for x in metrics),all_technical_checks_pass=all(x['technical_pass'] for x in metrics),tracks=metrics)
    (PACK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (DOC/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    (DOC/'score_events.json').write_text(json.dumps(scores,ensure_ascii=False,indent=2)+'\n')
    assert report['total_bytes']<4000000,report['total_bytes']
    assert report['all_technical_checks_pass'], 'See validation.json; technical checks failed'

if __name__=='__main__':main()
