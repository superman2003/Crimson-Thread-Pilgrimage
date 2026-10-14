#!/usr/bin/env python3
"""Original additive scores; isolated candidate pack, no runtime mutations."""
from __future__ import annotations
import hashlib,json,math,re,subprocess,tempfile
from pathlib import Path
import numpy as np
import scipy
from scipy.signal import resample_poly
ROOT=Path(__file__).resolve().parents[3]
PACK=ROOT/'assets/proposals/audio_category_music'
DOC=ROOT/'docs/proposals/audio_category_music'
SR=48000
SEED=2026101417
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


REGIONS=[
 ('ch01','苔钟庭',72,[3]*8,[62,57,58,65,64,67,64,57],'bronze',[50,50,43,43,53,53,45,45]),
 ('ch02','铸雨渠',92,[4]*8,[55,58,57,62,65,63,62,57],'bow',[43,43,51,51,48,48,50,50]),
 ('ch03','盐白书库',60,[4]*8,[69,72,75,71,76,74,72,71],'celesta',[57,57,55,55,57,57,55,55]),
 ('ch04','断弦温室',58,[5,6]*4,[64,67,59,66,64,62,57,58],'glass',[40,38,36,35,40,43,45,35]),
 ('ch05','黑曜巡礼道',100,[4]*8,[50,51,45,48,46,51,57,50],'horn',[38,38,39,39,36,36,33,33]),
 ('ch06','无声王冠',48,[4]*8,[74,70,74,70,62,70,74,70],'voice',[50,50,46,46,50,50,46,46]),
]
SLUGS=['moss_bell_court','rain_foundry_canal','saltwhite_archive','broken_string_greenhouse','obsidian_pilgrim_road','silent_crown_core']
def spec(ident,title,region,role,bpm,bars,loop,desc,ids,path=None):
 return dict(id=ident,title=title,region_id=region,role=role,bpm=bpm,bars=bars,loop=loop,description=desc,runtime_ids=ids,existing_runtime_path=path,applicable_events=ids)
def catalogue():
 out=[]
 for j,(ch,name,bpm,bars,motif,kind,roots) in enumerate(REGIONS):
  for role in ['combat_layer','lullaby']:
   out.append(spec(ch+'_'+role,name+(' · 交锋织层' if role=='combat_layer' else ' · 钟龛息声'),ch,role,bpm,bars,True,
    ('区域动机拆为节奏应答，保留探索曲调性与拍网；稀疏低声部，不要求运行时相位锁定。' if role=='combat_layer' else '区域动机重写为慢呼吸问答；保留原拍网，移除战斗脉冲。')+f' 与 reverse_music_v2/{ch}_exploration 的音程与配器关联。',
    ['enter_combat','exit_combat'] if role=='combat_layer' else ['engage_shrine','start_lullaby','stop_lullaby'],
    f'res://assets/audio/bgm/generated/{ch}_{SLUGS[j]}_'+('combat_layer' if role=='combat_layer' else 'shrine_lullaby')+'.ogg'))
 for n in range(1,4):
  out.append(spec(f'final_mvt{n}',['王冠 · 封存','王冠 · 诸名相争','王冠 · 未答之钥'][n-1],'ch06','final_boss_movement',72,[4]*8,True,
   ['第一乐章：D—降B空白动机与沉钟固定音。','第二乐章：五城动机交错进入，不同节奏构成证词冲突。','第三乐章：绯线下降句接管节奏，王冠双音以扩展时值反问。'][n-1],['silent_crown_core',f'set_boss_phase({n})'],f'res://assets/audio/bgm/generated/boss_final_silent_crown_mvt{n}.ogg'))
 for key,title,desc in [('ending_a','重鸣 · 名字仍在钟里','青铜重现苔钟庭动机，持续低音不解除旧契约；不是胜利大调。'),('ending_b','断冠 · 众声初醒','前半截断钟令，后半由分离的木笛与弦音回答；声音归还与黑潮代价并存。'),('ending_c','绯线改写 · 自愿的守望','六区短句轮流回答同一绯线主题；最后六音共同收束，体现可退出的轮值。')]:
  out.append(spec(key,title,'global','ending',72,[4]*8,False,desc,[key,key+'_done'],f'res://assets/audio/bgm/generated/{key}_'+{'ending_a':'rebell','ending_b':'severance','ending_c':'reweave'}[key]+'.ogg'))
 out.append(spec('bellway_transit','钟道 · 候车的刻度','global','transit_loop',80,[4]*6,True,'苔钟庭钟音经盐页钢片音回答，六站交替但保持静候留白。',['on_room_changed:transit'], 'res://assets/audio/bgm/generated/bellway_transit_loop.ogg'))
 for key,title in [('depart','离站 · 向下一声'),('arrive','到站 · 落脚于此')]:
  out.append(spec('bellway_'+key,title,'global','transit_jingle',80,[4]*2,False,'离站为上行未决三音；到站为反向步进加主音停驻，非移调复用。',['bellway_'+key],f'res://assets/audio/bgm/generated/bellway_{key}_jingle.ogg'))
 extras=[
 ('bring_names_home','把名字带回来','global',[62,58,57,65,63,62,69,72],['npc_threadsmith_apprentice','npc_canal_child','npc_fugitive_scribe'],'雨渠切分经盐页逆行回到苔钟庭钟句；crimson印记在任务完成后授予。'),
 ('root_rescue','西门的灯','ch04',[64,59,67,66,62,57,58,64],['npc_root_prisoner'],'玻璃长音间出现分段拨弦，结尾从半音束缚走向开放五度。'),
 ('wax_lamps','补好检修灯','ch04',[67,64,71,66,69,67,64,62],['npc_beeswax_vendor'],'蜂蜡工序以短长短拨弦交替，温室动机在第二句接合成完整回答。'),
 ('lantern_watch','灯不召兵','ch05',[50,57,51,60,58,55,57,62],['npc_lantern_sister','npc_obsidian_guide'],'将巡礼号角的重拍移至木笛弱拍，灯号脉冲保留明确间隙。'),
 ('deserter_order','不用回答的军号','ch05',[50,51,45,57,55,53,52,50],['npc_deserter_flagbearer','npc_blind_bell_knight'],'军号首句被休止截断；后句由独立弦音回应，不采用未实现的烧旗任务。'),
 ('seal_restoration','旧印归手','global',[55,58,62,69,75,72,65,62],['npc_rain_smith_liu','npc_salt_librarian_ye','seal_bell_repaired','seal_salt_restored'],'锻打三音与盐页增四度交替，尾句拼合为修复印记主题。'),
 ('keepers_witness','守门者的证词','ch04',[64,67,59,58,62,65,64,57],['npc_old_gardener','npc_broken_singer','testimony_04'],'断弦温室短拨声由纯合成元音延续，见证保持留白而无录制人声。'),
 ('crown_confession','第一百零一把钥匙','ch06',[74,70,62,69,65,64,58,62],['npc_first_pilgrim_echo','npc_crown_tongue','npc_six_mark_keeper','npc_black_tide_child','testimony_06'],'王冠双音与绯线下降动机各自独立成句，结尾悬置，避免提前暗示任一结局。'),
 ]
 for i,(ident,title,ch,motif,ids,desc) in enumerate(extras):
  ids=ids+([ident,'quest_'+ident+'_complete'] if i<5 else [])
  s=spec(ident,title,ch,'quest_theme' if i<5 else 'character_world_theme', [72,70,88,80,76,84,60,54][i],[4]*6,True,desc,ids)
  s['theme_notes']=motif;s['variant']=i;out.append(s)
 return out

def compose(s,index):
 c=Score(s['bpm'],s['bars'],SEED+index);a=c.add; role=s['role'];n=len(s['bars'])
 if role in ['combat_layer','lullaby']:
  j=int(s['region_id'][2:])-1;ch,name,bpm,bars,motif,kind,roots=REGIONS[j]
  for b,meter in enumerate(bars):
   if role=='combat_layer':
    patterns=[[0,1.5,2.5],[0,1,2.5],[.5,2,3.5],[0,1.75,3.5],[0,1.5,3],[0,2.5]][j]
    for k,beat in enumerate(patterns):
     a(b,beat,roots[b]+(12 if k%2 else 0),.55,'pluck' if j!=2 else 'harpsi',.14,(-1)**k*.2)
     if j in [0,1,4]:a(b,beat,roots[b],.35,'thump',.09)
    if b%2==1:a(b,meter-.75,motif[(b+j)%8]-12,1.3,kind,.09,.3)
    if j==3:a(b,1,roots[b]+19,2,'bow',.075,-.3)
    if j==5 and b in [2,6]:a(b,.5,70,2.4,'voice',.11,-.3)
   else:
    a(b,0,roots[b]+12,meter+1,'flute' if j in [0,4] else 'bow',.06,-.2)
    a(b,.25,motif[b],meter*.7,kind,.14,.25)
    if b%2==1:a(b,meter-1,motif[(b+3)%8],1.6,'pluck' if j!=3 else 'voice',.075,-.3)
    if b in [2,6]:a(b,1.5,motif[(b+1)%8]+7,1.0,'celesta',.06,.4)
 elif role=='final_boss_movement':
  movement=int(s['id'][-1])
  for b in range(n):
   a(b,0,38 if b%4<2 else 34,4.2,'organ',.10,-.1)
   if movement==1:
    a(b,.5,74 if b%2==0 else 70,2.5,'voice',.14,.2)
    if b%2==0:a(b,0,50,2.8,'bronze',.13,-.3)
   elif movement==2:
    r=REGIONS[b%5];notes=r[4]
    for k,beat in enumerate([0,.75,2,3.25]):a(b,beat,notes[(b+k)%8],.8,r[5],.14,(-1)**k*.35)
    a(b,1.5,70,1.8,'voice',.07)
   else:
    for k,p in enumerate([62,70,69,67,65,64]):a(b,k*.5,p,.55,'pluck',.15,(-1)**k*.3)
    if b%2==0:a(b,0,74 if b%4==0 else 70,6,'voice',.12,.1)
   for beat in ([0,2.5] if movement<3 else [0,1.5,3]):a(b,beat,38,.4,'thump',.10)
 elif role=='ending':
  key=s['id'][-1]
  for b in range(7):
   if key=='a':
    for k,p in enumerate([62,57,58] if b%2==0 else [65,64,67,64]):a(b,k*.75,p,1.8,'bronze',.15,-.25)
    a(b,0,38,4.2,'organ',.085,.1)
   elif key=='b':
    if b<2:a(b,0,50 if b==0 else 51,.8,'horn',.16)
    else:
     for k,p in enumerate([[65,69,67],[62,64,70],[57,62,65],[69,67,64],[62,65,69]][b-2]):a(b,k+(.5 if b%2 else 0),p,1.3,'flute' if b%2 else 'bow',.15,(-1)**k*.35)
   else:
    r=REGIONS[b%6]
    for k,p in enumerate(r[4][:3]):a(b,k,p,1.7,r[5],.13,(-1)**k*.3)
    a(b,.5,62 if b%2==0 else 65,3,'pluck',.08)
  if key!='b':
   for k,p in enumerate([50,57,62] if key=='a' else [50,57,62,65,69,74]):a(6,2,p,4,'bow',.055,(-1)**k*.3)
 elif role.startswith('transit'):
  if role=='transit_loop':
   for b in range(n):
    a(b,0,[62,57,69,72,64,62][b],2.2,'celesta',.13,-.2)
    a(b,2,[57,58,71,69,67,57][b],1.8,'bronze',.075,.3)
  else:
   pitches=[57,62,69] if s['id'].endswith('depart') else [69,65,64,62]
   for k,p in enumerate(pitches):a(0,k*.6,p,1.5,'celesta' if k%2 else 'bronze',.20,(-1)**k*.25)
   if s['id'].endswith('arrive'):a(1,0,50,1.5,'pluck',.12)
 else:
  v=s['variant'];notes=s['theme_notes'];kinds=[('bow','bronze'),('pluck','glass'),('harpsi','pluck'),('flute','celesta'),('horn','bow'),('bronze','celesta'),('voice','pluck'),('voice','glass')][v]
  rhythms=[[0,1.5,2.25],[0,1.75,3],[0,.75,2.5],[.5,2,3.25],[0,2.5],[0,1,2.5],[.25,2.5],[0,2.75]][v]
  for b in range(n):
   for k,beat in enumerate(rhythms):a(b,beat,notes[(b*2+k)%8],1.1 if v not in [6,7] else 2,kinds[b%2],.15,(-1)**k*.3)
   if b%2==0:a(b,0,notes[b%8]-12,3.5,'bow',.07,-.1)
   if b in [1,4]:a(b,3,notes[(b+4)%8],1.3,kinds[1],.09,.4)
 x=c.finish()
 if not s['loop']:
  # One-shots must not wrap: remove residual circular tails at start and decay to silence.
  x[:round(.04*SR)]*=np.linspace(0,1,round(.04*SR))[:,None]
  tail=min(round(2*SR),len(x));x[-tail:]*=np.linspace(1,0,tail)[:,None]**2
 return c,x

def main():
 PACK.joinpath('audio').mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 items=[];metrics=[];scores={}
 with tempfile.TemporaryDirectory(prefix='audio_category_music_') as td:
  td=Path(td)
  for index,s in enumerate(catalogue()):
   c,x=compose(s,index);expected=len(x);raw=td/'raw.f32';wav=td/'measure.wav';write_float(raw,x)
   run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','2','-i',str(raw),str(wav)])
   target=-26 if s['role'] in ['lullaby','transit_loop'] else -24 if s['role']=='combat_layer' else -23
   measured=loudness(wav);gain=min(10**((target-float(measured['input_i']))/20),10**(-4.5/20)/np.max(np.abs(x)))
   x*=gain;write_float(raw,x);dest=PACK/'audio'/(s['id']+'.ogg')
   cmd=['ffmpeg','-v','error','-y','-fflags','+bitexact','-f','f32le','-ar',str(SR),'-ac','2','-i',str(raw),'-map_metadata','-1','-c:a','libvorbis','-q:a','0','-fflags','+bitexact','-flags:a','+bitexact','-serial_offset',str(SEED+index)]
   if s['loop']:cmd+=['-metadata','LOOPSTART=0','-metadata',f'LOOPEND={expected}']
   run(cmd+[str(dest)]);m=assess(dest,expected)
   m['target_lufs']=target;m['checks']['integrated_loudness_within_half_lu']=abs(m['integrated_lufs']-target)<.5;m['technical_pass']=all(m['checks'].values());metrics.append(m)
   boundaries=[round(float(b)*60/s['bpm'],9) for b in c.offset]
   item={k:v for k,v in s.items() if k not in ['bars','theme_notes','variant']}
   item.update(file=dest.relative_to(PACK).as_posix(),sample_rate=SR,channels=2,duration_seconds=expected/SR,recommended_playback_gain_db=-6 if s['role']=='combat_layer' else -3,source='Original deterministic additive synthesis; internal synthesis core adapted from tools/proposals/reverse_music_v2/build.py; no external recordings',license='CC0-1.0',human_listening_review='pending',integration_status='proposal_only_not_runtime_wired',bar_beats=s['bars'],bar_start_seconds=boundaries[:-1],phrase_boundaries_seconds=boundaries[::2],target_lufs=target)
   if s['loop']:item.update(loop_start_sample=0,loop_end_sample_exclusive=expected)
   items.append(item);scores[s['id']]={'seed':SEED+index,'events':c.events}
   print(s['id'],m['bytes'],m['integrated_lufs'],m['technical_pass'],flush=True)
 report=dict(schema_version=1,pack_id='audio_category_music',method='Decoded OGG, EBU R128 loudnorm, 4x polyphase true peak, seam sample-step vs interior slopes; no human listening',environment=dict(numpy=np.__version__,scipy=scipy.__version__,ffmpeg=run(['ffmpeg','-version']).stdout.decode().splitlines()[0]),total_bytes=sum(m['bytes'] for m in metrics),all_technical_checks_pass=all(m['technical_pass'] for m in metrics),tracks=metrics)
 for path,data in [(PACK/'manifest.json',dict(schema_version=1,pack_id='audio_category_music',kind='music',title='六城补全 · 战斗、安坐与见证候选音乐',items=items)),(DOC/'validation.json',report),(DOC/'score_events.json',scores)]:path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 assert report['total_bytes']<6000000
 assert report['all_technical_checks_pass'],'See validation.json'
if __name__=='__main__':main()
