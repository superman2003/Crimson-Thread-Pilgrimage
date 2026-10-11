#!/usr/bin/env python3
"""Reproducible, original code-drawn icons and synthesized combat cues.
No sampled sound or third-party artwork. WAV mono 22050Hz, small bounded cues.
"""
from pathlib import Path
import math, random, wave, struct
ROOT=Path(__file__).resolve().parents[1]/'godot/assets'
ICONS={
'crimson':'<path d="M17 17L47 47M24 14L14 24M37 50L50 37"/><path class="thread" d="M13 45Q47 8 49 28Q48 53 23 45"/>',
'bell':'<path d="M18 40L21 22Q32 10 43 22L46 40Z M16 45H48M32 44V50"/>',
'salt':'<path d="M17 14H43L48 20V50H17Z M42 14V22H48M23 28H39M23 35H41M23 42H35"/>',
'cleave':'<path d="M12 39L51 24M43 22L53 23L48 32M13 26L21 23"/><path class="thread" d="M13 46Q26 30 47 36"/>',
'needle':'<path d="M12 48L48 12M40 15L46 21M18 42L23 47"/><path class="thread" d="M13 35Q32 47 34 30"/>',
'snare':'<path d="M13 44H51M18 44V23M46 44V23M17 25L47 39M47 25L17 39M26 21H38"/>',
'ward':'<path d="M15 16L32 44L49 16M19 24H45M23 32H41M32 44V51"/><path class="thread" d="M13 39L51 39"/>',
'shockwave':'<path d="M13 43H31M18 37V25Q24 19 30 25V37M40 24Q54 32 40 43M35 28Q44 32 35 39"/>',
'crosscut':'<path d="M13 17L49 47M15 48L49 17M10 23L20 12M43 52L53 41"/><path class="thread" d="M18 35Q32 51 46 35"/>',
'shard':'<path d="M19 22H44L47 46Q31 56 17 44ZM23 22V15H39V22M25 32L37 44M38 31L24 43"/>',
'mine':'<path d="M16 50V29M48 50V29M13 48H20M44 48H51M16 30L48 43M48 30L16 43"/>',
'fog':'<path d="M25 18H39V25L44 38Q46 49 32 50Q18 49 20 38L25 25ZM23 14H41M13 31H20M46 30H53M11 39H16M49 41H54"/>',
'lure':'<path d="M23 23Q32 14 41 23L44 39H20ZM18 44H46M32 44V50M13 20L8 29M51 20L56 29M32 12V7"/>',
'reflux':'<path d="M22 19H42M22 45H42M25 19V45M39 19V45M25 25L39 29L25 33L39 37L25 41"/>',
'spur':'<path d="M19 12H43V51L31 42L19 51ZM25 22H37M25 29H35"/><path class="thread" d="M15 16L11 23"/>',
'shell':'<path d="M18 19H46V43L32 51L18 43ZM24 25H40V39L32 44L24 39ZM32 25V44"/>',
'stride':'<path d="M20 16H34V34L48 40V47H16V37L20 32ZM19 24H33M19 30H33M16 42H46"/>',
'mender':'<path d="M21 23Q32 14 43 23L46 41H18ZM16 46H48M27 22L36 42M37 23L25 41M32 46V52"/>',
'needlecase':'<path d="M15 24L42 13L51 38L24 51ZM20 30L47 19M25 41L42 34M28 46L45 39M30 30L35 41"/>'}

def generate():
    (ROOT/'ui/seals').mkdir(parents=True,exist_ok=True)
    (ROOT/'audio/seals').mkdir(parents=True,exist_ok=True)
    for key,shape in ICONS.items():
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="3" y="3" width="58" height="58" rx="5" fill="#211c22" stroke="#a27b50" stroke-width="1.5"/><path d="M7 11V7H11M53 7H57V11M7 53V57H11M53 57H57V53" stroke="#6f5252" fill="none"/><g fill="none" stroke="#e5c795" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">{shape}</g><style>.thread{{stroke:#c56569}}</style></svg>'''
        (ROOT/'ui/seals'/f'{key}.svg').write_text(svg,encoding='utf-8')
    for idx,key in enumerate(ICONS):
        for stage,duration in [('prepare',.15),('active',.25),('hit',.13)]:
            rng=random.Random(idx*13+len(stage))
            samples=[]
            pitch=280+idx*23
            for n in range(int(22050*duration)):
                t=n/22050;u=t/duration
                envelope= min(1,t/.006)*math.exp(-u*(5 if stage=='hit' else 3))*(1-u)
                copper=(math.sin(2*math.pi*pitch*t)+.33*math.sin(2*math.pi*pitch*2.76*t)+.14*math.sin(2*math.pi*pitch*4.13*t))
                thread=math.sin(2*math.pi*(pitch*(1.9-u*.8))*t)
                signal=(.7*copper+.1*(rng.random()*2-1)) if key in ('bell','ward','shockwave','shard','lure','shell','mender') else (.45*thread+.16*(rng.random()*2-1))
                amplitude=.21 if stage=='active' else .11
                samples.append(struct.pack('<h',int(max(-1,min(1,signal*envelope*amplitude))*32767)))
            with wave.open(str(ROOT/'audio/seals'/f'{key}_{stage}.wav'),'wb') as wav:
                wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(22050);wav.writeframes(b''.join(samples))
    # Shared rough mechanical cue, explicitly separate from defensive sounds.
    rng=random.Random(1001);data=[]
    for n in range(6615):
        t=n/22050;env=min(1,t/.005)*math.exp(-t*11)
        s=(math.sin(2*math.pi*137*t)+.65*math.sin(2*math.pi*211*t)+.4*(rng.random()*2-1))*env*.18
        data.append(struct.pack('<h',int(s*32767)))
    with wave.open(str(ROOT/'audio/seals/unblockable.wav'),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(22050);wav.writeframes(b''.join(data))
    print(f'Generated {len(ICONS)} distinct SVG icons and {len(ICONS)*3+1} original WAV cues.')
if __name__=='__main__': generate()
