#!/usr/bin/env python3
"""Original seeded physical-impression synthesis; no samples. Python/numpy/scipy + ffmpeg."""
import argparse, hashlib, json, math, pathlib, subprocess, tempfile
import numpy as np
from scipy.signal import resample_poly
SR=48000
ROOT=pathlib.Path(__file__).resolve().parents[3]
REGIONS=[('苔钟庭','moss','湿苔滴水与短石腔','蓄水石槽','叶面滴落','苔石细砾'),('铸雨渠','foundry','机械转子与持续水流','排水泵','泄压余气','渠底金属沉落'),('盐白书库','archive','层叠纸页与细盐尘','通风书架','散页翻卷','盐晶微坠'),('断弦温室','glasshouse','玻璃振膜与缓慢根系应力','根系玻璃管','玻璃应力轻鸣','根鞘松脱'),('黑曜巡礼道','obsidian','风道涡旋与窄带哨音','裂谷风口','岩片滚落','侧孔短阵风'),('寂冠核心','crown','低频空腔与稀薄压力变化','封闭银线谐振腔','远腔闷响','压力膜回缩')]
def db(x):return float(20*np.log10(max(float(x),1e-12)))
def noise(n,rng,lo,hi):
 f=np.fft.rfftfreq(n,1/SR); z=rng.normal(size=len(f))+1j*rng.normal(size=len(f)); shape=np.exp(-(f/max(hi,1))**4)*(1-np.exp(-(f/max(lo,1))**4)); y=np.fft.irfft(z*shape,n=n);return y/max(np.std(y),1e-9)
def tone(t,f,dur):return np.sin(2*np.pi*round(f*dur)/dur*t)
def modal(dur,f,decay,rng,kind=0):
 t=np.arange(round(dur*SR))/SR
 ratios=[1,1.43,2.17,3.81] if kind else [1,2.73,4.31]
 y=sum(np.sin(2*np.pi*f*r*t)*np.exp(-t*decay*(1+i*.48))/(1+i)**1.5 for i,r in enumerate(ratios))
 y*=1-np.exp(-t*900); y*=np.minimum(1,(dur-t)/.06).clip(0,1)
 return y

def add(y,event,pos,pan=0):
 start=int(pos*SR)%len(y); ids=(start+np.arange(len(event)))%len(y)
 if y.ndim==1:np.add.at(y,ids,event)
 else:
  np.add.at(y[:,0],ids,event*np.sqrt((1-pan)/2));np.add.at(y[:,1],ids,event*np.sqrt((1+pan)/2))

def synth(region,role,seed):
 rng=np.random.default_rng(seed); duration=24 if role=='bed' else 8 if role=='landmark' else 3.5
 n=int(SR*duration);t=np.arange(n)/SR; chans=2 if role=='bed' else 1
 y=np.zeros((n,chans)) if chans==2 else np.zeros(n)
 def layer(v,g=.1,pan=0):add(y,v*g,0,pan)
 if role in ['bed','landmark']:
  local=role=='landmark'
  # Distinct excitation models: water droplets, rotating machinery, paper grains,
  # glass partials/root flexion, wind cavity modulation, pressure resonances.
  if region==0:
   layer(noise(n,rng,100,1100)*(.7+.3*tone(t,.125,duration)),.045)
   for k in range(25 if not local else 18):
    add(y,modal(.65,rng.uniform(420,1250),rng.uniform(8,14),rng)*rng.uniform(.13,.24),rng.uniform(0,duration),rng.uniform(-.85,.85))
   layer(tone(t,83,duration)*tone(t,.25,duration),.018)
  elif region==1:
   layer(noise(n,rng,100,2100)*(.62+.3*tone(t,1.25,duration)),.08)
   layer((tone(t,63,duration)+.4*tone(t,126,duration))*(.7+.3*tone(t,.375,duration)),.1 if local else .045)
   for k in range(int(duration*2)):
    add(y,modal(.4,170+(k%3)*33,18,rng,1)*(.13 if local else .065),k*.5+.04,rng.uniform(-.6,.6))
  elif region==2:
   layer(noise(n,rng,1500,6500),.009)
   for k in range(42 if not local else 25):
    d=rng.uniform(.09,.48);m=int(d*SR);u=np.arange(m)/SR
    v=noise(m,rng,650,5200)*np.sin(np.pi*u/d)**2*(.6+.4*np.sin(2*np.pi*31*u))
    add(y,v*.038,rng.uniform(0,duration),rng.uniform(-1,1))
   for k in range(10):add(y,modal(.16,rng.uniform(2800,4200),45,rng)*.018,rng.uniform(0,duration),rng.uniform(-1,1))
  elif region==3:
   for j,f in enumerate([311.25,523.5,873.75]):layer(tone(t,f,duration)*(.5+.5*tone(t,(j+1)/duration,duration)),.035/(j+1),[-.7,.65,0][j])
   layer(noise(n,rng,70,310)*(.4+.6*np.sin(np.pi*t/duration)**2),.04)
   for k in range(6 if not local else 4):
    add(y,modal(2.3,95+rng.uniform(-20,20),2.5,rng,1)*.095,rng.uniform(0,duration),rng.uniform(-.6,.6))
  elif region==4:
   wind=noise(n,rng,130,1450)*(.45+.3*tone(t,2/duration,duration)+.2*tone(t,5/duration,duration))
   layer(wind,.09)
   layer(np.sin(2*np.pi*round(390*duration)*t/duration+2*tone(t,3/duration,duration))*(.3+.3*tone(t,2/duration,duration)),.065,-.5)
   layer(tone(t,721,duration)*(.5+.5*tone(t,5/duration,duration)),.018,.65)
  else:
   for j,f in enumerate([43,61.25,97.5,151.75]):layer(tone(t,f,duration)*(.65+.35*tone(t,(j+1)/duration,duration)),.06/(j+1),[-.4,.4,-.7,.7][j])
   layer(noise(n,rng,35,180)*(.4+.6*np.sin(np.pi*t/duration)**4),.028)
   for k in range(3):add(y,modal(3,74,1.4,rng,1)*.025,k*duration/3+.5,0)
 else:
  v=0 if role=='event_a' else 1
  if region==0: e=modal(1.2,780 if not v else 250,7,rng)*.7+noise(int(1.2*SR),rng,1800,6000)*np.exp(-np.arange(int(1.2*SR))/SR*18)*.07
  elif region==1:e=noise(int(2.5*SR),rng,700,4400)*np.sin(np.pi*np.arange(int(2.5*SR))/(2.5*SR))**2*.25 if not v else modal(2.5,138,3,rng,1)
  elif region==2:
   d=1.6;u=np.arange(int(d*SR))/SR;e=noise(len(u),rng,850 if not v else 2600,5800)*np.sin(np.pi*u/d)**2*(.35+.3*np.sin(2*np.pi*(9 if not v else 29)*u))
  elif region==3:e=modal(3,1341 if not v else 116,2.4 if not v else 4,rng,1)
  elif region==4:
   e=modal(2.7,235,4,rng,1) if not v else noise(int(2.7*SR),rng,250,1800)*np.sin(np.pi*np.arange(int(2.7*SR))/(2.7*SR))**3
  else:e=modal(3,49 if not v else 113,1.7,rng,1)
  add(y,e,.12)
  if region in [0,4] and v:add(y,modal(.4,520,14,rng)*.3,1.15)
 y-=np.mean(y,axis=0)
 # Short cosine endpoint bridge; remove codec endpoint clicks without any silent gap.
 fade=int(SR*(.08 if role in ['bed','landmark'] else .04)); ramp=np.sin(np.linspace(0,np.pi/2,fade))**2
 if chans==2:ramp=ramp[:,None]
 y[:fade]*=ramp;y[-fade:]*=ramp[::-1]
 target=-27 if role=='bed' else -23 if role=='landmark' else -24
 y*=10**(target/20)/max(np.sqrt(np.mean(y*y)),1e-12)
 y*=min(1,10**(-9/20)/max(abs(y).max(),1e-12))
 return y.astype('<f4'),duration,chans

def encode(y,path):
 # bitexact fixes Vorbis stream serial; output names and timestamps never enter metadata.
 args=['ffmpeg','-v','error','-y','-fflags','+bitexact','-f','f32le','-ar',str(SR),'-ac',str(1 if y.ndim==1 else y.shape[1]),'-i','pipe:0','-map_metadata','-1','-c:a','libvorbis','-q:a','2','-flags:a','+bitexact','-fflags','+bitexact',str(path)]
 subprocess.run(args,input=y.tobytes(),check=True)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=pathlib.Path,default=ROOT/'assets/proposals/audio_category_ambience');args=ap.parse_args();out=args.out;out.mkdir(parents=True,exist_ok=True)
 items=[];profiles=[]
 for i,(title,slug,desc,land,a,b) in enumerate(REGIONS):
  ids={}
  for j,role in enumerate(['bed','landmark','event_a','event_b']):
   ident=f'amb_ch{i+1:02}_{slug}_{role}';ids[role]=ident;seed=731000+i*100+j
   y,d,c=synth(i,role,seed);file=ident+'.ogg';encode(y,out/file)
   items.append(dict(id=ident,title=f'{title} · '+{'bed':'环境床','landmark':land,'event_a':a,'event_b':b}[role],region_id=f'ch{i+1:02}',role=role,file=file,loop=role in ['bed','landmark'],loop_start_sample=0 if j<2 else None,loop_end_sample=int(d*SR) if j<2 else None,duration_seconds=d,sample_rate=SR,channels=c,recommended_playback_gain_db=-3 if j==0 else -7 if j==1 else -9,description=desc if j==0 else [land,a,b][j-1]+'；纯环境物理声，非交互反馈或NPC提示',source={'type':'original_mathematical_synthesis','generator':'tools/proposals/audio_category_ambience/build.py','seed':seed},license='CC0-1.0',human_listening_review='pending'))
  near,far=[(2,18),(3,28),(1.5,12),(2,20),(4,36),(3,26)][i]
  profiles.append(dict(region_id=f'ch{i+1:02}',title=title,bed_cue_id=ids['bed'],landmark_cue_id=ids['landmark'],bed_gain_db=-3,landmark_gain_db=-7,landmark_spatial=dict(near_distance_m=near,far_distance_m=far,attenuation='linear_amplitude_from_near_to_zero_at_far',pan='equal_power',occluded=dict(lowpass_hz=[1200,850,1800,1400,700,600][i],gain_db=[-8,-10,-7,-8,-11,-12][i]),position_note='建议设施锚点；米为审阅器抽象单位，不映射既有像素坐标'),reverb=dict(decay_seconds=[1.4,2.2,.7,1.8,2.6,4.2][i],wet=[.16,.13,.08,.19,.11,.24][i],predelay_ms=[18,24,8,19,33,42][i]),warning_duck=dict(gain_db=-9,attack_ms=45,release_ms=900,hold_ms=250,scope=['bed','landmark','events'],event_policy='pause_new_events_during_warning'),events=dict(cue_ids=[ids['event_a'],ids['event_b']],interval_seconds=[45+i*3,120+i*4],voice_limit=1,selection='seeded_shuffle_no_immediate_repeat',gain_db=-9)))
 (out/'manifest.json').write_text(json.dumps(dict(schema_version=1,pack_id='audio_category_ambience',kind='ambience',status='review_only_not_integrated',items=items),ensure_ascii=False,indent=2)+'\n')
 (out/'mix_profiles.json').write_text(json.dumps(dict(schema_version=1,pack_id='audio_category_ambience',status='review_only_not_integrated',gain_semantics='Absolute cue playback gains; profile gains repeat manifest values, never add both. Reverb and duck apply after cue gain.',global_voice_limit=4,transition_crossfade_seconds=2.5,profiles=profiles),ensure_ascii=False,indent=2)+'\n')
 print(f'Built {len(items)} cues: {sum(p.stat().st_size for p in out.glob("*.ogg"))} bytes')
if __name__=='__main__':main()
