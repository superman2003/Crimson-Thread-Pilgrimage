#!/usr/bin/env python3
"""Original, deterministic, code-native scenic SVGs. No runtime files are touched.
Requires Python 3.10+, Pillow, numpy and Inkscape CLI for review renders.
"""
from pathlib import Path
import math, random, json, subprocess, tempfile, hashlib, io
from xml.etree import ElementTree as ET
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/proposals/reverse_scenery_v2'
DOC=ROOT/'docs/proposals/reverse_scenery_v2'
SEED=260614
W,H=960,540

def p(d,fill,stroke=None,sw=1,opacity=1):
 return f'<path d="{d}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"' if stroke else '')+(f' opacity="{opacity}"' if opacity!=1 else '')+'/>'
def line(x,y,X,Y,col,sw=1,opacity=1):return p(f'M{x} {y}L{X} {Y}','none',col,sw,opacity)
def circle(x,y,r,fill,stroke=None,sw=1):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{sw}"' if stroke else '')+'/>'
def ell(x,y,rx,ry,fill,stroke=None,sw=1):return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{sw}"' if stroke else '')+'/>'
def rect(x,y,w,h,fill,rx=0,stroke=None):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"'+(f' stroke="{stroke}"' if stroke else '')+'/>'
def group(content,trans='',opacity=1):return f'<g transform="{trans}" opacity="{opacity}">{content}</g>'
def arch(x,y,w,h,c,sw=3):return p(f'M{x} {y+h}V{y+w/2}Q{x} {y} {x+w/2} {y}Q{x+w} {y} {x+w} {y+w/2}V{y+h}','none',c,sw)
def gear(x,y,r,c,inner):
 s=circle(x,y,r,'none',c,8)+circle(x,y,r*.78,'none',c,2)
 for j in range(12):
  a=j*math.tau/12;ca,sa=math.cos(a),math.sin(a)
  s+=line(round(x+ca*r*.23,2),round(y+sa*r*.23,2),round(x+ca*r*.8,2),round(y+sa*r*.8,2),c,7)
 s+=circle(x,y,r*.23,c)+circle(x,y,r*.12,inner)
 return s
def bell(x,y,s,col,detail):
 d=p('M-34 62Q-24 53 -24 25Q-23 4 0 0Q23 4 24 25Q24 53 34 62Q0 75 -34 62Z',col,detail,1.3)
 d+=ell(0,62,29,7,col,detail)+line(0,63,0,81,detail,3)+ell(0,82,4,5,detail)
 d+=p('M-15 49Q-12 33 -12 24M15 49Q12 33 12 24','none',detail,1)
 d+=circle(0,20,5,'none',detail)
 return group(d,f'translate({x} {y}) scale({s})')
def leaves(x,y,length,dir,c,detail):
 s=p(f'M{x} {y}Q{x+dir*36} {y+length*.6} {x+dir*14} {y+length}','none',detail,2)
 for i in range(9):
  yy=y+i*length/10;xx=x+dir*math.sin(i/9*math.pi)*20
  side=(-1)**i; s+=p(f'M{xx} {yy}q{side*24} -10 {side*26} 4q{-side*4} 16 {-side*26} -4Z',c)
 return s
def rivets(x,y,n,step,col):return ''.join(circle(x,y+i*step,1.6,col) for i in range(n))

DATA=[
 ('ch06','无声王冠 · 镇潮银线汇流室','silent_crown_core',['#111c2b','#273c50','#476071','#8e9fa5','#751f3e'], '同心冠骨、针状悬垂件、封闭银线汇流器。镇潮钟网的传动终端，不是可交互开关。'),
 ('ch05','黑曜巡礼道 · 蜡誓风驿','obsidian_pilgrim_road',['#201c2a','#3a3547','#575066','#9e7962','#7e3c40'], '陡直黑曜片、弯背蜡像与风蚀火龛。路旁收集誓蜡、维持驿火的设施，没有绘制裂谷桥面。'),
 ('ch04','断弦温室 · 母株调弦腔','broken_string_greenhouse',['#122c2a','#23453e','#47685a','#a38d59','#794348'], '弧形温室肋、下垂根囊与铜制共鸣弦。母株营养与花粉回收设施，碎弦向上收束。'),
 ('ch03','盐白书库 · 删名封存柜','saltwhite_archive',['#282936','#454854','#6d737b','#b2ac99','#85505a'], '竖向折页柜、扇形卷宗与细长盐结晶。密封已删名契约的保存库，柜底隐入雾中。'),
 ('ch02','铸雨渠 · 双缸计时泵室','rain_foundry_canal',['#102932','#21424d','#44616a','#9b8060','#824b42'], '大直径叶轮、圆头铸铁压力缸与回弯管。排水计量泵，配重和仪表全在背景层。'),
 ('ch01','苔钟庭 · 雨铃养根庭','moss_bell_court',['#152c29','#29483e','#4d6a54','#998861','#80474b'], '钟形花萼、尖拱遗构与细垂根。旧雨铃给根系灌水计时，苔藓吞没铜壳。'),
]

def far(idx,C,rng):
 base,deep,mute,metal,red=C
 s=rect(0,0,W,H,'url(#air)')
 # Atmosphere remains broad and low frequency; no traversable ground line.
 if idx==6:
  s+=ell(480,80,265,330,'url(#halo)')
  for rx,ry in [(300,410),(235,330),(171,242)]:s+=ell(480,85,rx,ry,'none',mute,1.5)
  for x in [86,180,293,667,780,874]:
   s+=p(f'M{x-19} 540V154L{x} 67L{x+19} 154V540Z',deep)+line(x,155,x,495,mute,1,.3)
  s+=p('M338 91L355 162L393 133L430 182L480 71L528 183L568 133L605 163L624 91L604 228Q480 269 357 228Z',deep,mute,1)
  s+=ell(480,226,118,24,'none',mute,1)
  for a in range(0,360,30):
   xx=480+math.cos(math.radians(a))*169;yy=153+math.sin(math.radians(a))*120
   s+=circle(round(xx,2),round(yy,2),3,mute)
 elif idx==5:
  for n,(x,y,w) in enumerate([(0,183,138),(148,102,91),(270,200,72),(631,216,91),(745,115,127),(891,59,80)]):
   s+=p(f'M{x} 540L{x+8} {y+132}L{x+w*.28} {y+54}L{x+w*.55} {y}L{x+w*.77} {y+92}L{x+w} {y+158}L{x+w+24} 540Z',deep)
   s+=p(f'M{x+w*.55} {y}L{x+w*.44} 365L{x+w*.7} 540L{x+w*.77} {y+92}Z',mute,opacity=.24)
  for y in [119,159,204]:s+=p(f'M50 {y}Q450 {y+22} 900 {y-25}','none',mute,1,.25)
  s+=ell(471,180,72,93,'none',mute,1)
 elif idx==4:
  s+=ell(480,213,342,362,'url(#halo)')
  for x in [110,212,330,630,748,850]:
   s+=p(f'M{x} 540Q{x-14} 205 480 14','none',mute,3,.45)
  s+=p('M10 188Q480 -116 950 188M10 266Q480 -38 950 266','none',mute,2,.3)
  for x,y,sz in [(240,280,1.5),(682,245,1.8),(398,190,.65),(554,157,.8)]:
   s+=group(p('M0 250Q-27 132 0 0Q43 72 14 250Z',deep)+p('M0 91Q-121 35 -87 139Q-29 153 0 91Z',deep)+p('M7 140Q129 73 89 188Q48 207 7 140Z',deep),f'translate({x} {y}) scale({sz})')
 elif idx==3:
  for x,h in [(90,436),(205,390),(320,337),(570,337),(685,390),(800,436)]:
   s+=arch(x,540-h,70,h,deep,20)+arch(x+13,555-h,44,h,mute,1)
   for xx in range(x+22,x+54,7):s+=line(xx,561-h,xx,535,mute,1,.3)
  s+=ell(480,120,88,97,'none',mute,1)
  for a in range(205,337,11):
   rad=math.radians(a);x=480+math.cos(rad)*170;y=235+math.sin(rad)*170
   s+=line(480,235,round(x,2),round(y,2),mute,2,.5)
 elif idx==2:
  s+=gear(484,211,142,deep,base)
  for x,y,w,h in [(72,108,106,445),(746,51,128,490),(232,167,59,385),(644,169,47,380)]:
   s+=rect(x,y,w,h,deep,w/2)+ell(x+w/2,y+70,w*.36,18,'none',mute,1)+line(x+w*.65,y+94,x+w*.65,530,mute,1,.25)
  s+=p('M0 39H122Q165 39 165 89V176M960 37H817Q781 37 781 84V183','none',mute,6,.35)
 elif idx==1:
  for x,y,w,h in [(102,121,150,430),(280,206,104,345),(578,206,104,345),(713,121,150,430)]:
   s+=p(f'M{x} 540V{y+100}Q{x+8} {y+45} {x+w/2} {y}Q{x+w-8} {y+45} {x+w} {y+100}V540H{x+w-15}V{y+103}Q{x+w-28} {y+52} {x+w/2} {y+26}Q{x+28} {y+52} {x+15} {y+103}V540Z',deep)
  s+=bell(480,98,1.6,deep,mute)
  s+=line(480,0,480,98,mute,2,.4)
  for x,y,le in [(65,50,350),(886,50,310),(180,0,120),(754,0,120)]:s+=leaves(x,y,le,1,deep,mute)
 # Sparse original specks, not game pickups; all subdued.
 for i in range(32):
  x=rng.randint(34,926); y=rng.randint(26,490)
  s+=circle(x,y,rng.choice([.6,.8,1.1]),mute)
 s+=rect(0,275,960,265,'url(#floorMist)')
 return s

def mid(idx,C,rng):
 base,deep,mute,metal,red=C;s=''
 if idx==6:
  for flip in [False,True]:
   t='translate(960 0) scale(-1 1)' if flip else ''
   z=p('M30 0H117L140 101L130 390L104 475L76 390L65 112Z',base,mute,1.5)
   z+=p('M102 20L114 96L106 341L103 383L93 341L91 97Z',deep,metal,1)
   for x in [52,151,182]:z+=p(f'M{x} 0V78Q{x} 112 {x+27} 136V230','none',mute,3)
   z+=ell(178,242,40,83,base,mute,2)+ell(178,242,27,63,'none',metal,1)
   z+=p('M178 158V324M145 199L211 284M145 284L211 199','none',mute,1)
   z+=circle(178,242,10,red,metal)+line(178,325,178,371,mute,2)+p('M178 371l-5 11 5 14 5-14Z',metal)
   z+=p('M216 0Q254 90 360 112','none',mute,2)+p('M224 0Q266 73 360 98','none',metal,1)
   s+=group(z,t)
 elif idx==5:
  # Wax collection shrine: rounded melted edges, no projecting ledges.
  for x,y,sz in [(104,145,1.1),(833,113,1.2)]:
   z=p('M-45 270L-37 101Q-38 45 -15 34L0 0L19 35Q43 41 39 103L46 270Q0 292 -45 270Z',base,mute,1.5)
   z+=p('M-24 204V106Q-28 70 0 55Q27 72 25 108V201Q12 225 -3 205Q-17 234 -24 204Z',deep,metal,1)
   z+=p('M-16 145Q-20 127 -4 108Q-5 87 9 80Q7 113 18 132Q21 148 6 157Z',metal)
   z+=p('M-4 148Q-8 138 5 122Q4 139 10 145Z',red)
   z+=p('M-28 75Q-39 109 -28 131V187M30 83Q19 105 31 137V173','none',mute,3)
   s+=group(z,f'translate({x} {y}) scale({sz})')
  for x,y,sz in [(207,305,.65),(752,321,.65),(32,383,.8),(916,349,.85)]:
   z=p('M-19 178Q-26 117 -16 66Q-27 52 -13 25Q1 5 17 27Q27 43 16 58L32 147L27 178Q8 193 -19 178Z',deep,mute,1)
   z+=p('M-12 61Q10 72 18 47M-14 28Q2 27 5 41L-1 45','none',metal,1)
   s+=group(z,f'translate({x} {y}) scale({sz})')
  s+=p('M42 0Q40 79 113 101L160 73L157 172L115 144Q59 150 60 45Z',deep,mute,1)
  s+=p('M844 0V36L787 55L793 173L829 135L879 154V0Z',deep,mute,1)
 elif idx==4:
  for flip in [False,True]:
   z=p('M40 540Q75 392 44 205Q10 96 123 0M85 540Q117 313 106 194Q85 65 203 0','none',deep,17)
   z+=p('M45 536Q81 370 58 184Q40 101 130 11','none',metal,2)
   z+=p('M173 0Q188 81 170 117Q221 188 184 238Q149 267 126 228Q101 187 151 117Q131 69 146 0Z',deep,mute,2)
   z+=ell(164,182,26,54,'none',metal,1)
   z+=p('M145 165Q164 143 182 165M139 188Q164 165 188 188M144 214Q164 192 184 214','none',mute,1)
   z+=line(164,241,164,287,metal,2)+ell(164,302,8,17,deep,mute)
   for x,h in [(227,157),(245,208),(266,102)]:z+=p(f'M{x} 0L{x-9} {h}l8 14 -6 12','none',mute,1)
   z+=p('M61 256Q172 243 111 316Q79 323 61 256ZM86 380Q191 345 139 427Q103 436 86 380Z',deep,mute,1)
   s+=group(z,'translate(960 0) scale(-1 1)' if flip else '')
 elif idx==3:
  for flip in [False,True]:
   z=p('M57 540V130L93 68L134 91L163 136V540Z',deep,mute,2)
   z+=p('M93 70V540M134 92V540','none',metal,1)
   for y in range(164,479,39):
    z+=p(f'M66 {y}l20 -8v24l-20 8ZM101 {y-5}l24 3v24l-24-3ZM142 {y+6}l14 7v24l-14-7Z',base,mute,1)
    z+=line(108,y+5,118,y+6,metal,1)
   z+=p('M194 0L201 89L223 117L213 304L204 318L197 300L187 118L194 88Z',mute,metal,1)
   z+=p('M208 119L215 134L208 284L204 296L201 276Z',deep)
   z+=line(52,0,52,99,mute,2)+circle(52,112,13,deep,metal)+p('M44 111l8-6 8 6-8 7Z',red)
   z+=p('M258 0L264 81L273 109L267 160L260 178L255 159L248 111Z',deep,mute,1)
   s+=group(z,'translate(960 0) scale(-1 1)' if flip else '')
 elif idx==2:
  s+=gear(139,276,130,deep,base)+gear(139,276,84,mute,base)
  s+=circle(139,276,30,deep,metal,2)+circle(139,276,13,base,mute,2)
  s+=rect(787,91,87,434,base,38,mute)+ell(830,131,32,24,deep,metal)
  s+=rect(810,164,39,143,deep,19,mute)+line(829,182,829,291,metal,2)
  for y in range(190,284,18):s+=line(818,y,823,y,metal,1)
  s+=p('M900 540V122Q900 47 824 47H731V0','none',deep,23)+p('M900 540V122Q900 47 824 47H731V0','none',mute,3)
  s+=p('M51 0V101Q51 151 105 151H171Q208 151 208 201','none',deep,27)+p('M51 0V101Q51 151 105 151H171Q208 151 208 201','none',metal,1)
  for x,y in [(731,35),(899,168),(51,50)]:
   s+=rect(x-18,y-6,36,12,deep,3,mute)+circle(x-12,y,2,metal)+circle(x+12,y,2,metal)
  s+=circle(754,365,38,base,mute,3)+circle(754,365,29,deep,metal)
  for a in range(210,511,30):
   xx=754+math.cos(math.radians(a))*23; yy=365+math.sin(math.radians(a))*23
   s+=line(round(xx,2),round(yy,2),round(754+(xx-754)*.8,2),round(365+(yy-365)*.8,2),metal,1)
  s+=line(754,365,741,352,red,2)+circle(754,365,3,metal)
 elif idx==1:
  s+=p('M72 540V182Q79 90 184 28M100 540V194Q99 114 184 57','none',deep,20)
  s+=p('M86 520V179Q85 110 179 47','none',mute,2)
  s+=p('M811 540V178Q811 95 740 38M844 540V168Q835 77 737 11','none',deep,17)
  s+=line(198,0,198,122,mute,2)+bell(198,122,1.05,deep,metal)
  s+=p('M200 202Q177 243 201 278Q230 309 192 350','none',mute,1)
  s+=line(760,0,760,207,mute,2)+bell(760,207,.67,deep,mute)
  for x,y,le,dr in [(51,20,319,1),(122,43,220,-1),(892,12,387,-1),(836,37,228,1)]:s+=leaves(x,y,le,dr,deep,mute)
  for x,y in [(174,148),(209,172),(760,220)]:s+=p(f'M{x} {y}q-14-20-26-7q2 19 26 7Z',mute)
 # Facility shafts terminate outside the panel or in rounded tips; no walkable baseline.
 return group(s, opacity=.82)

def front(idx,C,rng):
 base,deep,mute,metal,red=C;s=''
 # Front silhouettes are explicitly restricted to frame margins by clipFront.
 if idx==6:
  for flip in [False,True]:
   z=p('M0 0H128L108 26L66 37L46 133L30 191L18 350L0 392Z',base,mute,1)
   z+=p('M18 0L27 129L47 46L103 19','none',metal,1.4)
   for x,y in [(60,20),(90,13)]:z+=circle(x,y,4,deep,metal)
   z+=p('M0 540V501L37 479L57 519L116 540Z',base,mute,1)
   s+=group(z,'translate(960 0) scale(-1 1)' if flip else '')
 elif idx==5:
  s+=p('M0 0H167L118 28L102 14L54 63L37 221L0 276ZM960 0H823L877 30L903 96L926 282L960 370ZM0 540V476L21 419L48 511L83 540ZM960 540V452L931 477L909 533L846 540Z',base,mute,1)
  s+=p('M19 0L21 200L54 63M938 11L924 191M30 466L37 517','none',metal,1)
  s+=p('M134 0L143 18L127 54L116 43L110 59L92 39L110 5Z',red)
 elif idx==4:
  for flip in [False,True]:
   z=p('M0 0H161Q106 16 63 60Q33 107 30 232L0 319Z',base,mute,1)
   z+=p('M14 0Q86 0 47 117M8 64Q76 84 118 41','none',mute,3)
   z+=p('M33 153Q114 91 94 180Q70 220 33 153ZM76 29Q132 82 162 19Q118 9 76 29Z',base,mute,1)
   z+=p('M0 540L0 462Q52 443 76 481Q72 517 119 540Z',base,mute,1)
   s+=group(z,'translate(960 0) scale(-1 1)' if flip else '')
 elif idx==3:
  s+=p('M0 0H150L132 19L83 29L65 91L44 74L32 170L0 192ZM960 0H808L853 27L876 17L899 101L916 84L927 221L960 278ZM0 540V457L23 430L47 499L83 540ZM960 540V433L931 474L907 464L891 529L858 540Z',base,mute,1)
  s+=p('M28 0L30 145L44 74M930 0L928 174L917 84M23 448L23 505L47 528','none',metal,1)
 elif idx==2:
  for flip in [False,True]:
   z=p('M0 0H156V19H79Q33 19 33 72V363H0Z',base,mute,2)
   z+=line(19,87,19,347,metal,1)+rect(2,167,46,21,base,3,mute)+rivets(41,172,2,11,metal)
   z+=p('M0 540V486Q9 450 34 439L64 450L49 472Q20 483 24 540Z',base,mute,2)
   s+=group(z,'translate(960 0) scale(-1 1)' if flip else '')
 elif idx==1:
  for flip in [False,True]:
   z=p('M0 0H160Q135 26 97 31Q49 25 42 93Q36 183 0 227Z',base,mute,1)
   z+=leaves(40,16,164,1,base,mute)+leaves(107,0,85,-1,base,mute)
   z+=p('M0 540V491Q31 455 42 487Q77 477 80 521L126 540Z',base,mute,1)
   s+=group(z,'translate(960 0) scale(-1 1)' if flip else '')
 return '<g clip-path="url(#clipFront)">'+s+'</g>'

def svg(body,C,title):
 base,deep,mute,metal,red=C
 defs=f'''<defs>
 <linearGradient id="air" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{base}"/><stop offset=".52" stop-color="{deep}"/><stop offset="1" stop-color="{base}"/></linearGradient>
 <radialGradient id="halo"><stop stop-color="{mute}" stop-opacity=".22"/><stop offset="1" stop-color="{mute}" stop-opacity="0"/></radialGradient>
 <linearGradient id="floorMist" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{base}" stop-opacity="0"/><stop offset="1" stop-color="{base}" stop-opacity=".85"/></linearGradient>
 <clipPath id="frame"><rect width="960" height="540"/></clipPath>
 <clipPath id="clipFront"><path d="M0 0H960V84H0ZM0 84H144V540H0ZM816 84H960V540H816ZM144 504H816V540H144Z"/></clipPath>
 </defs>'''
 return f'<svg xmlns="http://www.w3.org/2000/svg" width="960" height="540" viewBox="0 0 960 540"><title>{title}</title>{defs}<g clip-path="url(#frame)">{body}</g></svg>\n'

def render(path,png):
 subprocess.run(['inkscape',str(path),'--export-type=png','--export-filename='+str(png),'--export-width=960','--export-height=540'],check=True,capture_output=True)
 return Image.open(png).convert('RGBA')

def main():
 OUT.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 (OUT/'.gitattributes').write_text('* -filter\n*.png -diff -merge -text\n*.svg text eol=lf diff\n*.json text eol=lf diff\n.gitattributes text diff\n')
 manifest={'schema_version':1,'pack_id':'reverse_scenery_v2','title':'绯线巡礼 V03 · 六区设施景深','kind':'scenery','seed':SEED,'baseline_commit':'6544cceff5e812b5295b97204d7c55a4b8933de9','items':[]}
 report=[]
 with tempfile.TemporaryDirectory() as td:
  for cid,title,slug,C,desc in DATA:
   idx=int(cid[-2:]);layers=[];imgs=[]
   for li,(name,cn,fn,para,z) in enumerate([('far','远景',far,.15,-30),('mid','中景设施',mid,.4,-20),('front','边角前景',front,.75,20)]):
    file=f'{cid}_{name}.svg';src=svg(fn(idx,C,random.Random(SEED+idx*101+li)),C,title+' · '+cn)
    (OUT/file).write_text(src)
    im=render(OUT/file,Path(td)/f'{cid}_{name}.png');imgs.append(im)
    a=np.asarray(im);safe=a[100:490,160:800,3]
    if name=='front':assert not safe.any(),f'{cid} foreground intersects action safe rect'
    if name=='far':assert a[:,:,3].min()==255
    rgb_luma=a[:,:,:3]@np.array([.2126,.7152,.0722])/255
    painted=a[:,:,3]>0
    layers.append({'luma_p95':round(float(np.quantile(rgb_luma[painted],.95)),4),'painted_fraction':round(float(painted.mean()),4),'contrast_budget':{'luma_p95_max':{'far':.32,'mid':.52,'front':.44}[name],'painted_fraction_max':{'far':1.,'mid':.25,'front':.12}[name]},'id':name,'title':cn,'file':file,'parallax':para,'z_index':z,'horizontal_tiling':False,'alpha':'opaque' if name=='far' else 'transparent','render_alpha_bounds_px':list(im.getbbox()),'contrast_intent':'broad low-frequency atmosphere' if name=='far' else 'muted facility silhouette; upper/side accents' if name=='mid' else 'dark corner silhouette; empty central action area'})
   combined=imgs[0]
   for im in imgs[1:]:combined=Image.alpha_composite(combined,im)
   preview=f'{cid}_preview.png';combined.convert('RGB').quantize(colors=192,method=Image.Quantize.MEDIANCUT).save(OUT/preview,optimize=True)
   assert (OUT/preview).stat().st_size<250000
   item={'id':cid+'_scene','title':title,'region_id':cid,'region_data_id':cid+'_'+slug,'type':'layers','width':W,'height':H,'layers':layers,'preview':preview,'description':desc,'horizontal_tiling':False,'palette':dict(zip(['void','atmosphere','structure','muted_accent','crimson'],C)),'recommended_order':['far','mid','gameplay_world','front'],'foreground_safe_rect_px':[160,100,640,390],'placement':'room-local single scenic panel; reposition per room; do not mirror/repeat as terrain','collision':False,'navigation':False}
   manifest['items'].append(item)
   # Statistics describe rendered artwork only, not actual-game readability.
   lum=np.asarray(combined.convert('RGB'))@np.array([.2126,.7152,.0722])/255
   report.append({'region':cid,'preview_bytes':(OUT/preview).stat().st_size,'rendered_luma_p05_p50_p95':[round(float(x),4) for x in np.quantile(lum,[.05,.5,.95])],'foreground_safe_rect_alpha_max':0})
 (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (DOC/'render_report.json').write_text(json.dumps({'seed':SEED,'resolution':[W,H],'checks':report,'total_pack_bytes':sum(x.stat().st_size for x in OUT.iterdir() if x.is_file())},ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'svg_count':18,'preview_count':6,'total_pack_bytes':sum(x.stat().st_size for x in OUT.iterdir() if x.is_file()),'reports':report},ensure_ascii=False))
if __name__=='__main__':main()
