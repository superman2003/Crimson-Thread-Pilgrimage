#!/usr/bin/env python3
"""Original, deterministic vector motion studies. Only writes proposal paths."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / 'assets/proposals/reverse_motion_v2'
DOC = ROOT / 'docs/proposals/reverse_motion_v2'
W = H = 192
INK = '#17262c'
TEAL = '#386671'
CRESTS = {'crimson': '缝名', 'bell': '司铸', 'salt': '校录'}
ACTIONS = {'needle': '针击', 'down': '下击', 'heal': '疗伤'}

# Each pose is authored independently: hip x/y, torso lean in degrees,
# weapon hand x/y, needle angle, free hand x/y, rear/front boot x, boot y,
# cloth lag. The same needle always starts at the weapon-hand socket.
# Positive y points down; zero weapon angle points right.
POSES = {
 'crimson_needle': [
  (82,124,0,108,111,15,72,117,66,96,168,0),
  (79,127,-10,87,108,-25,68,119,63,96,168,-3),
  (78,128,-16,79,102,-12,63,118,61,98,168,-8),
  (90,124,24,128,105,0,63,111,62,111,168,-16),
  (94,128,30,133,109,5,67,107,62,115,168,-20),
  (88,129,14,116,112,16,71,111,64,106,168,-8),
  (84,126,5,111,114,22,74,115,66,99,168,3),
  (82,124,0,108,111,15,72,117,66,96,168,0)],
 'bell_needle': [
  (82,128,-3,101,103,-25,96,112,59,105,168,0),
  (79,132,-12,88,86,-65,87,97,58,105,168,3),
  (77,134,-18,80,81,-58,82,92,57,105,168,5),
  (79,132,-10,92,91,-35,88,103,57,106,168,-5),
  (92,132,20,125,115,4,116,115,55,115,168,-14),
  (93,137,23,123,123,13,113,125,55,115,168,-8),
  (86,133,8,108,119,10,99,123,57,109,168,4),
  (82,128,-3,101,103,-25,96,112,59,105,168,0)],
 'salt_needle': [
  (82,124,-3,103,109,0,113,119,72,96,168,0),
  (80,125,-8,99,99,-16,113,116,72,95,168,3),
  (79,126,-12,96,93,-8,114,111,72,95,168,4),
  (84,122,7,133,92,0,108,112,71,103,168,-4),
  (82,123,2,129,97,6,110,114,71,102,168,-5),
  (77,126,-14,107,105,12,114,117,68,95,168,5),
  (79,124,-7,102,108,5,115,117,70,95,168,3),
  (82,124,-3,103,109,0,113,119,72,96,168,0)],
 'crimson_down': [
  (83,106,8,108,93,35,68,91,73,101,150,0),
  (81,100,-13,93,74,-42,69,83,76,103,143,-5),
  (81,99,-20,89,72,-65,67,85,78,108,142,-10),
  (87,109,15,107,129,80,68,95,67,104,151,-20),
  (88,115,20,105,137,87,70,96,65,106,157,-15),
  (86,109,4,102,121,60,75,95,68,102,151,-7),
  (84,107,3,109,104,40,73,93,72,101,149,3),
  (83,106,8,108,93,35,68,91,73,101,150,0)],
 'bell_down': [
  (82,107,-4,100,90,-45,95,98,62,110,151,0),
  (79,103,-14,89,66,-82,87,75,62,112,147,4),
  (77,102,-20,83,65,-88,83,74,60,113,146,6),
  (78,105,-13,96,78,-15,89,89,60,113,149,-5),
  (86,124,18,101,137,88,97,128,58,115,168,-17),
  (86,130,25,101,139,90,97,130,57,117,168,-5),
  (84,128,12,104,131,70,99,123,59,111,168,5),
  (82,124,3,107,117,45,97,120,62,106,168,0)],
 'salt_down': [
  (82,104,-5,112,102,35,110,85,75,100,148,0),
  (80,102,-10,113,92,10,111,82,77,102,146,5),
  (79,103,-16,120,106,38,108,79,77,103,147,7),
  (83,111,0,118,131,66,107,89,74,103,155,-6),
  (81,114,-5,117,135,73,109,92,71,101,158,-4),
  (77,110,-18,114,119,45,113,90,68,98,154,6),
  (79,106,-10,111,109,38,111,86,71,99,150,4),
  (82,104,-5,112,102,35,110,85,75,100,148,0)],
 'crimson_heal': [
  (82,124,0,108,111,15,72,117,66,96,168,0),
  (81,126,2,107,105,-110,90,107,66,96,168,2),
  (80,129,6,103,112,-128,94,102,66,96,168,3),
  (80,130,9,96,109,-147,99,105,66,96,168,1),
  (81,129,7,102,102,-136,90,108,66,96,168,-1),
  (81,127,4,108,108,-112,88,111,66,96,168,-2),
  (82,125,2,107,111,-15,78,115,66,96,168,-1),
  (82,124,0,108,111,15,72,117,66,96,168,0)],
 'bell_heal': [
  (82,128,-3,101,103,-25,96,112,59,105,168,0),
  (81,132,4,114,128,70,95,113,58,107,168,2),
  (79,138,13,119,133,90,91,117,58,109,168,4),
  (78,142,18,119,136,90,91,122,58,110,168,3),
  (78,142,17,119,136,90,96,121,58,110,168,1),
  (79,138,12,118,133,85,93,119,58,109,168,-1),
  (81,132,3,108,118,35,95,115,59,107,168,-1),
  (82,128,-3,101,103,-25,96,112,59,105,168,0)],
 'salt_heal': [
  (82,124,-3,103,109,0,113,119,72,96,168,0),
  (81,125,-6,105,112,-97,120,107,72,96,168,2),
  (80,127,-9,110,113,-104,122,107,72,96,168,3),
  (80,128,-8,113,109,-116,122,108,72,96,168,1),
  (81,128,-5,111,115,-108,121,109,72,96,168,0),
  (81,126,-3,109,114,-93,117,114,72,96,168,-1),
  (82,125,-3,106,111,-25,115,117,72,96,168,-1),
  (82,124,-3,103,109,0,113,119,72,96,168,0)],
}

META = {
 'crimson_needle': (14,3,4,'后手收针，低身直刺，前脚拉长后迅速收线。'),
 'bell_needle': (11,4,4,'后肩承重，针柄抬高，两手合力压送，沉肩收势。'),
 'salt_needle': (13,3,4,'抬腕校准高位，窄步平刺，命中姿态后撤回校读。'),
 'crimson_down': (14,3,4,'空中收膝引针，斜转竖直下缝，回弹收腿。'),
 'bell_down': (10,4,4,'双手举针蓄重，垂直落下，宽脚低身承住余势。'),
 'salt_down': (12,3,4,'抬起校页，腕转斜下定点，后撤收针再读页。'),
 'crimson_heal': (10,3,4,'左手牵住衣前线结，右手短程穿缝，再拉紧断线。'),
 'bell_heal': (9,3,4,'屈膝稳住针架，左手压紧铜扣，承重后起身。'),
 'salt_heal': (10,3,4,'展开掌中盐页，以针尖逐行校读，合页结束。'),
}

def pt(p):
    return f'{p[0]:.2f},{p[1]:.2f}'

def path(d, fill, stroke=INK, width=1.7, extra=''):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'

def line(points, color, width):
    return path('M'+' L'.join(pt(p) for p in points),'none',color,width)

def circ(x,y,r,fill,stroke=INK,width=1):
    return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def pose_svg(key, i, p):
    crest, action=key.split('_')
    hx,hy,lean,wx,wy,angle,lx,ly,rear,front,feet,lag=p
    rad=math.radians(lean)
    def body(x,y):
        return hx+x*math.cos(rad)-y*math.sin(rad),hy+x*math.sin(rad)+y*math.cos(rad)
    shoulder=body(3,-35)
    neck=body(0,-43)
    hand=(wx,wy)
    free=(lx,ly)
    backshoulder=body(-6,-33)
    elbow=((shoulder[0]+wx)/2-5,(shoulder[1]+wy)/2+10)
    backelbow=((backshoulder[0]+lx)/2-9,(backshoulder[1]+ly)/2+8)
    needle_rad=math.radians(angle)
    axis=(math.cos(needle_rad),math.sin(needle_rad))
    tip=(wx+43*axis[0],wy+43*axis[1])
    butt=(wx-9*axis[0],wy-9*axis[1])
    out=[]
    # Soft hand-drawn shapes, all bounded by a shared 192px registration box.
    tail=body(-26+lag,-3)
    cape=[body(-7,-41),body(-24+lag,-26),tail,body(-7+lag,8),body(8,-17)]
    out.append(path(f'M{pt(cape[0])} Q{pt(body(-28+lag,-30))} {pt(cape[2])} L{pt(body(-15+lag,-1))} L{pt(cape[3])} Q{pt(body(12,-10))} {pt(cape[4])} Z',TEAL))
    out.append(line([body(-14,-31),body(-19+lag,-11),body(-10+lag,0)],'#66868a',1.1))
    # Rear and front legs share locked boot sole coordinates; knee bend changes.
    for x,offset,col in [(rear,-6,'#27343c'),(front,6,'#35434c')]:
        hip=body(offset,0)
        knee=(x+(hx-x)*.35+(4 if offset>0 else -3),(hy+feet-5)/2)
        ankle=(x,feet-9)
        out.append(line([hip,knee,ankle],INK,10))
        out.append(line([hip,knee,ankle],col,6.6))
        out.append(path(f'M{x-4},{feet-19} L{x+4},{feet-19} L{x+4},{feet-7} Q{x+14},{feet-4} {x+13},{feet} L{x-5},{feet} Z','#765449'))
        out.append(line([(x-2,feet-15),(x+3,feet-15)],'#b29370',1.2))
    out.append(line([backshoulder,backelbow,free],INK,8.5))
    out.append(line([backshoulder,backelbow], '#304954',5.5))
    out.append(line([backelbow,free], '#d5b698',4.8))
    # Torso local coordinates; silhouette and clothing remain identical across crests.
    out.append(f'<g transform="translate({hx},{hy}) rotate({lean})">')
    out.append(path('M-9,-38 Q-2,-44 10,-35 L12,-6 L7,5 L-14,4 L-13,-17 Z','#30424b'))
    out.append(path('M-7,-37 L2,-34 L-2,-8 L-10,-9 Z','#4d6770',width=1))
    out.append(path('M-14,-9 L12,-10 L13,-4 L-14,-3 Z','#775746',width=1))
    out.append(path('M-4,-10 L3,-10 L3,-3 L-4,-3 Z','#c3a466',width=.9))
    out.append(path('M-10,-39 Q-21,-48 -28,-38 Q-18,-38 -22,-27 L-7,-34 Z','#a33f45'))
    out.append(path('M-11,-43 Q1,-45 10,-39 L9,-32 Q-3,-32 -11,-37 Z','#bf5454'))
    # Human profile, visible brow and eye, original compact face, no mask or horns.
    out.append(path('M-8,-68 Q-5,-78 6,-75 Q16,-71 12,-58 L16,-55 L11,-52 Q10,-45 3,-45 L-5,-51 Z','#e1c3a2'))
    out.append(path('M-11,-57 Q-19,-69 -9,-78 Q0,-86 10,-77 Q18,-72 13,-62 L8,-70 L1,-60 L-4,-64 L-6,-52 Z','#292a30'))
    out.append(path('M-12,-71 Q-29,-85 -31,-66 Q-31,-50 -39,-47 Q-24,-46 -20,-59 Q-17,-67 -12,-66 Z','#303038'))
    out.append(line([(-26,-69),(-26,-58),(-32,-51)],'#50505a',1))
    out.append(line([(6,-59),(9,-60)],INK,1.4))
    out.append(line([(10,-51),(7,-51)],'#ad8771',.8))
    out.append(circ(-13,-69,2,'#bc4a4a',width=.7))
    # Tiny crest hardware only, with topology distinction, not recolored clothes.
    if crest=='crimson':
        out.append(path('M4,-30 L8,-26 L4,-22 L0,-26 Z','#b75a50','#d7bb78',.7))
        out.append(line([(4,-29),(4,-23)],'#f0dbba',.7))
    elif crest=='bell':
        out.append(path('M0,-23 Q1,-30 5,-30 Q9,-30 10,-23 Z','#c09a5f',width=.8))
        out.append(circ(5,-22,1,'#dfc28c',width=.6))
    else:
        out.append(path('M0,-30 L8,-29 L8,-21 L0,-22 Z','#e2d9bc',width=.7))
        out.append(line([(2,-27),(6,-26)],'#747b70',.6))
    out.append('</g>')
    # Free-hand practical gesture: thread, bracing hand or physical paper; no aura.
    if crest=='salt':
        out.append(path(f'M{lx-8},{ly-7} L{lx+1},{ly-9} L{lx+12},{ly-5} L{lx+9},{ly+7} L{lx},{ly+4} L{lx-10},{ly+6} Z','#ded9bc',width=1.2))
        out.append(line([(lx,ly-6),(lx,ly+3)],'#929c91',1))
        out.append(line([(lx+3,ly-3),(lx+8,ly-1)],'#929c91',.8))
    out.append(circ(lx,ly,3.1,'#d5b698',width=1.1))
    out.append(line([shoulder,elbow,hand],INK,9))
    out.append(line([shoulder,elbow],'#3b555f',6.5))
    out.append(line([elbow,hand],'#d7b799',5.2))
    # Fixed-length 43px needle, 9px handle; hilt rotates about the exact hand socket.
    out.append(f'<g transform="translate({wx},{wy}) rotate({angle})">')
    out.append(path('M3,-1.8 L43,0 L3,1.8 Z','#d4e2dc','#34464d',.8))
    out.append(line([(-9,0),(3,0)],'#ba9454',3.4))
    out.append(path('M1,-5 Q-5,-6 -5,0 Q-5,6 1,5','none','#d4b776',1.6))
    out.append('</g>')
    out.append(circ(wx,wy,3.1,'#d9bca0',width=1.1))
    if crest=='crimson' and action=='heal' and i in (1,2,3,4,5):
        out.append(path(f'M{lx},{ly} Q{hx+14},{hy-3} {wx-7},{wy+3}','none','#ca6962',1.15))
    if crest=='bell' and action=='heal' and i in (2,3,4,5):
        out.append(path(f'M{lx-3},{ly-3} L{lx+4},{ly-3} L{lx+4},{ly+3} L{lx-3},{ly+3} Z','#c3a466',width=.8))
    geometry={'frame':i,'origin':[86,172],'hip':[hx,hy], 'shoulder':list(shoulder),
              'weapon_hand':[wx,wy],'free_hand':[lx,ly],'needle_tip':list(tip),
              'needle_handle_end':list(butt),'needle_length':43,
              'needle_angle_degrees':angle,'boot_soles':[[rear,feet],[front,feet]],
              'airborne':action=='down' and feet<168}
    return ''.join(out), geometry

def svg_atlas(key):
    frames=[]; geometry=[]
    for i,p in enumerate(POSES[key]):
        drawing,g=pose_svg(key,i,p)
        frames.append(f'<g id="frame_{i}" transform="translate({i*W},0)">{drawing}</g>')
        geometry.append(g)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="192" viewBox="0 0 1536 192">'
            '<title>Original motion research: '+key+'</title>'+''.join(frames)+'</svg>'),geometry

def save_json(path,data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def font(size):
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',size)

def contact_sheet(items):
    # A separate opaque review image; atlases themselves contain only transparent sprites.
    canvas=Image.new('RGB',(1600,2130),'#111c26'); d=ImageDraw.Draw(canvas)
    d.text((32,24),'CRIMSON THREAD / MOTION V02',font=font(28),fill='#eadcc2')
    d.text((32,65),'9 authored studies / 8 frames each / 192 px / shared palette, distinct mechanics',font=font(15),fill='#8faab1')
    d.text((32,92),'Research silhouettes. Frames are zero-based. CONTACT = visual proposal, not a live hitbox.',font=font(14),fill='#c5a774')
    for row,item in enumerate(items):
        y=137+row*213
        key=item['id']; fps=item['fps']; contact=item['events'][0]['frame']
        d.text((32,y),f"{key.upper()}  |  {fps} fps  |  contact {contact}  |  {8/fps:.3f}s",font=font(15),fill='#eadcc2')
        atlas=Image.open(PACK/item['file']).convert('RGBA')
        for i in range(8):
            x=32+i*192
            d.rectangle((x,y+24,x+190,y+202), fill='#1a2934' if i%2==0 else '#20313a')
            d.line((x+6,y+17+168,x+185,y+17+168),fill='#496169',width=1)
            if i==contact:d.rectangle((x,y+24,x+190,y+202),outline='#cda15a',width=2)
            canvas.paste(atlas.crop((i*192,0,(i+1)*192,192)),(x,y+17),atlas.crop((i*192,0,(i+1)*192,192)))
            phase='LOAD' if i<contact else ('CONTACT' if i<=item['timing']['contact']['end_frame'] else 'RECOVER')
            d.text((x+6,y+27),f'{i:02d} / {phase}',font=font(10),fill='#c7b185' if i==contact else '#84999e')
    d.text((32,2071),'Same dark ponytail, red scarf, teal split cape, dark tunic, brown boots and brass needle in every crest.',font=font(14),fill='#8faab1')
    d.text((32,2096),'No invulnerability, armor, healing amount, collision or runtime timing is implied by these drawings.',font=font(14),fill='#b59a79')
    canvas.save(PACK/'contact_sheet.png',optimize=True)

def build():
    (PACK/'sources').mkdir(parents=True,exist_ok=True)
    (PACK/'atlases').mkdir(exist_ok=True)
    DOC.mkdir(parents=True,exist_ok=True)
    items=[]
    for key in POSES:
        svg,geometry=svg_atlas(key)
        source=PACK/'sources'/f'{key}.svg'; dest=PACK/'atlases'/f'{key}.png'
        source.write_text(svg+'\n')
        subprocess.run(['inkscape',str(source),'--export-type=png',f'--export-filename={dest}','--export-background-opacity=0'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        im=Image.open(dest).convert('RGBA'); im.save(dest,optimize=True)
        crest,action=key.split('_'); fps,start,end,description=META[key]
        phase=lambda a,b:{'start_frame':a,'end_frame':b,'start_seconds':round(a/fps,6),'end_seconds_exclusive':round((b+1)/fps,6),'duration_seconds':round((b-a+1)/fps,6)}
        items.append({'id':key,'title':f'{CRESTS[crest]} · {ACTIONS[action]}','region_id':None,'crest_id':crest,'type':'animation',
                      'file':f'atlases/{key}.png','source':f'sources/{key}.svg','frame_width':W,'frame_height':H,'frame_count':8,'columns':8,
                      'fps':fps,'loop':False,'events':[{'frame':start,'name':'接触帧' if action!='heal' else '修补接触帧'}],
                      'description':description+' 原创简化动作研究候选；接触帧仅供视觉评审，不改变命中或治疗判定，也不表示免伤。',
                      'action':action,'timing':{'windup':phase(0,start-1),'contact':phase(start,end),'recovery':phase(end+1,7),'duration_seconds':round(8/fps,6)},
                      'pivot':[86,172],'nominal_ground_sole_y':168,'geometry':geometry,'status':'research_candidate_not_runtime_replacement'})
    manifest={'schema_version':1,'pack_id':'reverse_motion_v2','title':'三契印原创动作研究 V02','kind':'animation',
              'baseline_commit':'6544cceff5e812b5295b97204d7c55a4b8933de9','frame_indexing':'zero_based',
              'contact_sheet':'contact_sheet.png','visual_identity':'current generated_hero_v3, simplified human ponytail study',
              'items':items,'limitations':['未接入控制器；没有实机命中、取消窗口、治疗或无敌帧验收。','本包是新绘制的矢量研究轮廓，不能视为现有 V3 高精人物的无缝替代。','下击姿态含空中起手；固定 pivot 不等同于固定每帧脚底。boot_soles 记录各帧脚底位置。']}
    save_json(PACK/'manifest.json',manifest)
    contact_sheet(items)
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    build()
    print(f'Built 9 SVG/PNG atlases and contact sheet under {PACK.relative_to(ROOT)}')
