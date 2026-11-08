#!/usr/bin/env python3
"""Generate original combat sound families once, retaining paid request receipts."""
from concurrent.futures import ThreadPoolExecutor,as_completed
from datetime import datetime,timezone
from pathlib import Path
import argparse
import base64
import hashlib
import json
import math
import os
import re
import subprocess
import threading
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"art_requests/combat_sfx_v1"
OUTPUT=ROOT/"godot/assets/audio/sfx/ai_combat"
MODEL="elevenlabs/sound-effects-v2"
ENDPOINT="https://ai-gateway.vercel.sh/v4/ai/speech-model"
BASE="Original isolated insect-fantasy game sound. No music, melody, voice, electronic beep or ambience. "
FAMILIES={
 "blade":("A swift thin metal needle or scythe slicing air: sharp airy swish, fine edge hiss and a tiny cloth flutter. A weapon swing only, no impact or hit.",3,1.3,-22),
 "heavy":("A heavy broad bladed weapon swinging with the body's weight: low airy whoom followed by a dry metallic edge sweep. Organic and weighty, not a cinematic explosion. No hit impact.",3,1.5,-20),
 "claw":("An insect's chitin jaw and claw snapping forward: dry articulated shell clicks leading into a compact cutting air swish. No gore, voice or damage impact.",3,1.2,-23),
 "wing":("A quick insect wingbeat surging into a diving pass: fluttering papery wings, a focused rushing air sweep and a short airy tail. No crash or impact.",3,1.3,-23),
 "seed":("A small organic seed-pod releasing its load: a soft elastic pop and dry grainy spore puff with a brief seed rattle. Single release, no explosion or continuous spray.",3,1.3,-23),
 "root":("A gnarled wooden root and reed staff releasing stored tension: close fibrous creak, compact wooden crack and light dry leaf movement. Short organic attack release, no long ambience.",3,1.5,-22),
 "bell":("An old small bronze shell releasing a brief magical pulse: a tactile muted bronze knock, a short diffuse glassy air shimmer, quickly damping away. Non-musical, no tune, electronic beep or giant cinematic bell.",3,1.5,-23),
 "impact":("A compact physical contact in an insect battle: a dull body thud layered with a brittle shell tick and short cloth rustle. Dry, punchy, restrained, no gore or human voice, no weapon whoosh.",3,1.2,-21),
 "prep_light":("An insect fighter drawing a light weapon back: subtle close cloth stretch, chitin joint tension and a tiny handle creak. Quiet anticipation only; no swing, impact or alert beep.",2,.9,-27),
 "prep_heavy":("A heavy insect warrior bracing to swing: low leather and wooden grip strain with a short restrained metallic tension scrape. Quiet physical anticipation only; no swing, impact or boom.",2,1.0,-26),
 "prep_cast":("An organic pod and dry leaf vessel tightening before a release: a close soft inhaling air draw, fibrous stretch and faint husk rattle. Quiet preparation only, no actual projectile release or synthetic charge tone.",2,.9,-27),
}

def now():return datetime.now(timezone.utc).isoformat()
def write(path,data):
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
def key():
 if os.environ.get("AI_GATEWAY_API_KEY"):return os.environ["AI_GATEWAY_API_KEY"]
 common=Path(subprocess.check_output(['git','rev-parse','--git-common-dir'],cwd=ROOT).decode('utf-8').strip()).parent
 for location in [ROOT/".env.local",common/".env.local"]:
  if location.is_file():
   for line in location.read_text(encoding='utf-8').splitlines():
    name,sep,value=line.partition('=')
    if sep and name.strip()=='AI_GATEWAY_API_KEY':return value.strip().strip('\"\'')
 raise ValueError('AI Gateway key is not available')
def run(*args):return subprocess.run(args,check=True,capture_output=True,text=True,encoding='utf-8')
def probe(path):return json.loads(run('ffprobe','-v','error','-show_format','-show_streams','-of','json',str(path)).stdout)

def prepare(name,receipt):
 source=SOURCE/'incoming'/(name+'.mp3');target=OUTPUT/(name+'.ogg')
 report=target.with_suffix('.json')
 if report.exists() and target.exists():
  d=json.loads(report.read_text(encoding='utf-8'))
  if d['sha256']==hashlib.sha256(target.read_bytes()).hexdigest():return d
  raise ValueError('Existing prepared output differs: '+name)
 family=name.rsplit('_',1)[0];desired=FAMILIES[family][3]
 OUTPUT.mkdir(parents=True,exist_ok=True);scratch=SOURCE/'build';scratch.mkdir(exist_ok=True)
 trimmed=scratch/(name+'.wav')
 run('ffmpeg','-v','error','-y','-i',str(source),'-af','silenceremove=start_periods=1:start_duration=0.005:start_threshold=-48dB,areverse,silenceremove=start_periods=1:start_duration=0.01:start_threshold=-52dB,areverse','-ar','48000','-ac','1',str(trimmed))
 info=probe(trimmed);duration=float(info['format']['duration'])
 if duration<.06:raise ValueError('Generated cue is empty after onset trimming: '+name)
 measured=run('ffmpeg','-hide_banner','-i',str(trimmed),'-af','volumedetect','-f','null','-')
 rms=float(re.findall(r'mean_volume:\s*([-\d.]+) dB',measured.stderr)[-1])
 true=run('ffmpeg','-hide_banner','-i',str(trimmed),'-af','loudnorm=I=-20:TP=-3:LRA=11:print_format=json','-f','null','-')
 stats,_=json.JSONDecoder().raw_decode(true.stderr[true.stderr.rfind('{'):]);peak=float(stats['input_tp'])
 gain=min(desired-rms,-3-peak)
 if not math.isfinite(gain):raise ValueError('Nonfinite source loudness: '+name)
 filters=f'volume={gain:.6f}dB,afade=t=in:d=0.003,afade=t=out:st={max(0,duration-.025):.6f}:d=0.025'
 run('ffmpeg','-v','error','-y','-i',str(trimmed),'-af',filters,'-c:a','libvorbis','-q:a','6',str(target))
 actual=probe(target);run('ffmpeg','-v','error','-i',str(target),'-f','null','-')
 d=dict(id=name,family=family,provider='ElevenLabs Sound Effects v2 via Vercel AI Gateway',model=MODEL,
  source=source.relative_to(ROOT).as_posix(),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
  path='res://'+target.relative_to(ROOT/'godot').as_posix(),sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
  duration_seconds=float(actual['format']['duration']),gain_db=gain,source_mean_dbfs=rms,source_true_peak_dbtp=peak,
  receipt=(source.relative_to(ROOT).as_posix()+'.receipt.json'),decode_verified=True,listen_status='pending_human_audition')
 write(report,d);return d

def generate(item,api_key,stop):
 name,family,variant=item;prompt,count,duration,target=FAMILIES[family]
 source=SOURCE/'incoming'/(name+'.mp3');path=source.with_suffix('.mp3.receipt.json')
 if source.exists() and path.exists():
  receipt=json.loads(path.read_text(encoding='utf-8'))
  if receipt.get('sha256')==hashlib.sha256(source.read_bytes()).hexdigest():return prepare(name,receipt)
 if path.exists() or stop.is_set():return None
 text=BASE+prompt+' Texture variation: '+['tight and precise articulation.','slightly hollow body resonance, a softer edge.','slightly rougher dry texture, restrained airy detail.'][variant-1]
 if len(text)>450:raise ValueError('Sound-effects prompt exceeds the provider 450-character boundary')
 body=dict(text=text,outputFormat='mp3',providerOptions=dict(elevenlabs=dict(durationSeconds=duration,promptInfluence=.85,loop=False)))
 receipt=dict(id=name,family=family,model=MODEL,provider='vercel_ai_gateway',status='submitted_result_pending',requested_at=now(),request=body)
 source.parent.mkdir(parents=True,exist_ok=True)
 with path.open('x',encoding='utf-8') as f:json.dump(receipt,f,ensure_ascii=False,indent=2)
 try:
  request=urllib.request.Request(ENDPOINT,data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+api_key,'Content-Type':'application/json','ai-gateway-protocol-version':'0.0.1','ai-speech-model-specification-version':'4','ai-model-id':MODEL})
  with urllib.request.urlopen(request,timeout=300) as response:
   receipt['response_id']=response.headers.get('x-vercel-id');result=json.load(response)
  audio=base64.b64decode(result['audio'],validate=True)
  if not audio:raise ValueError('Empty model audio')
  source.write_bytes(audio);receipt.update(status='generated',sha256=hashlib.sha256(audio).hexdigest(),bytes=len(audio),completed_at=now(),warnings=result.get('warnings',[]));write(path,receipt)
  d=prepare(name,receipt);print('SFX_READY',name,round(d['duration_seconds'],3),flush=True);return d
 except Exception as exc:
  if isinstance(exc,urllib.error.HTTPError):
   receipt['http_status']=exc.code
   receipt['error_body']=exc.read(12000).decode('utf-8',errors='replace').replace(api_key,'[REDACTED]')
  receipt.update(status='needs_inspection_no_automatic_retry',error=(type(exc).__name__+': '+str(exc)).replace(api_key,'[REDACTED]'));write(path,receipt);stop.set();print('SFX_INSPECT',name,type(exc).__name__,flush=True);return None

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--generate',action='store_true');parser.add_argument('--only');args=parser.parse_args()
 items=[(family+'_'+str(i),family,i) for family,(_,count,_,_) in FAMILIES.items() for i in range(1,count+1)]
 plan=dict(schema=1,model=MODEL,requests=len(items),estimated_usd=round(sum(FAMILIES[f][2] for n,f,i in items)/60*.06,5),
  pricing_source='https://vercel.com/ai-gateway/models/sound-effects-v2',authorization='User requested a comprehensive combat presentation benchmark and enemy/Boss motion and sound upgrades.',
  request_policy='One paid POST per new receipt; uncertain requests are never automatically resubmitted.',families={f:dict(variants=v[1],duration_seconds=v[2],prompt=BASE+v[0]) for f,v in FAMILIES.items()})
 write(SOURCE/'plan.json',plan);print('COMBAT_SFX_PLAN',plan['requests'],plan['estimated_usd'],'USD estimated',flush=True)
 if not args.generate:return
 api_key=key();stop=threading.Event();selected=[i for i in items if not args.only or i[0]==args.only];results=[]
 with ThreadPoolExecutor(max_workers=3) as pool:
  for future in as_completed([pool.submit(generate,i,api_key,stop) for i in selected]):
   result=future.result()
   if result:results.append(result)
 existing=[json.loads(p.read_text(encoding='utf-8')) for p in OUTPUT.glob('*.json') if p.name!='manifest.json']
 write(OUTPUT/'manifest.json',dict(schema=1,model=MODEL,provider='vercel_ai_gateway',status='prepared_pending_audition',entries=sorted(existing,key=lambda d:d['id'])))
 print('COMBAT_SFX_PREPARED',len(existing),flush=True)
 if stop.is_set():raise SystemExit('Inspect saved receipts before any further paid submission')

if __name__=='__main__':main()
