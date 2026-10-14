"""Rebuild original authored vector warning candidates; requires Pillow + Inkscape.
No external image, image generation, runtime asset, or runtime script is modified.
"""
from pathlib import Path
import json, subprocess, hashlib
from PIL import Image, ImageDraw, ImageFont, ImageOps
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/proposals/reverse_art'
DOC = Path(__file__).resolve().parent
INK = '#10272B'
BONE = '#FFF4E6'
DESIGNS = {
 'parry': {'color':'#FFB847','label':'PARRY / shield','width':4,
  'outline':'M35 34 Q49 31 64 24 Q78 31 93 34 L89 67 Q83 88 64 99 Q44 87 39 67 Z',
  'mark':'M47 61 L59 74 L82 48',
  'detail':'M45 38 L48 51 M81 37 L79 42 M47 77 L53 84'},
 'evade': {'color':'#E63950','label':'EVADE / split diamond','width':6,
  'outline':'M55 24 L27 55 M24 67 L55 101 M73 103 L102 73 M103 57 L72 24',
  'mark':'M48 44 L80 84 M79 44 L48 84',
  'detail':'M35 50 L41 44 M83 91 L89 85'},
 'impact': {'color':'#7FD6CA','label':'IMPACT / landing target','width':4,
  'outline':'M31 73 C17 86 34 104 64 103 C93 103 112 87 96 74 M36 85 Q64 101 92 85',
  'mark':'M64 25 L64 73 M48 57 L64 75 L80 57',
  'detail':'M25 60 L25 69 M103 60 L103 69 M48 32 L48 40 M80 32 L80 40'}
}
PHASES = ['notice','focus','locked']

def assert_same_visible_rgba(actual, expected):
 """Ignore hidden RGB at alpha zero, but compare every visible channel exactly."""
 assert actual.size == expected.size
 assert actual.getchannel('A').tobytes() == expected.getchannel('A').tobytes()
 for left, right in zip(actual.getdata(), expected.getdata()):
  assert left[3] == 0 or left == right

def path(d, color, width, opacity=1):
 return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" opacity="{opacity}" stroke-linejoin="round" stroke-linecap="round"/>'

def svg(data, phase):
 color=data['color']; width=data['width']
 ticks = [
  'M16 41 L16 21 L36 21 M92 21 L112 21 L112 41 M16 91 L16 111 L36 111 M92 111 L112 111 L112 91',
  'M22 40 L22 27 L35 27 M93 27 L106 27 L106 40 M22 92 L22 105 L35 105 M93 105 L106 105 L106 92',
  'M25 36 L25 30 L31 30 M97 30 L103 30 L103 36 M25 96 L25 102 L31 102 M97 102 L103 102 L103 96'
 ][phase]
 result='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
 result+=f'<title>Original {data["label"]} warning — {PHASES[phase]}</title>'
 # The continuous semantic silhouette stays visible in every phase.
 for d,w in [(data['outline'],width),(data['mark'],width),(ticks,3)]:
  result+=path(d,INK,w+5)+path(d,color,w)
 result+=path(data['detail'],BONE,1.7,.8)
 if phase>0:
  result+=path('M58 13 L64 9 L70 13',INK,7)+path('M58 13 L64 9 L70 13',color,2)
 if phase==2:
  result+=path('M58 117 L64 121 L70 117',INK,7)+path('M58 117 L64 121 L70 117',color,2)
 return result+'</svg>\n'

manifest={'status':'candidate_not_integrated','version':1,'authorship':'Original hand-authored SVG paths; rasterized with Inkscape. Not AI image generation.','canvas':[128,128],'pivot':[64,64],'alpha':'straight RGBA, transparent exterior','frame_order':PHASES,'loop':False,'timing':'Drive by existing windup progress, not fixed FPS. See README.','assets':[]}
for name,data in DESIGNS.items():
 frames=[]
 for i,phase in enumerate(PHASES):
  source=OUT/'source'/f'{name}_{phase}.svg'; source.write_text(svg(data,i))
  dest=OUT/'frames'/f'{name}_{phase}.png'
  subprocess.run(['inkscape',str(source),'--export-type=png','--export-filename='+str(dest)],check=True)
  frames.append(Image.open(dest).convert('RGBA'))
 sheet=Image.new('RGBA',(384,128));
 for i,frame in enumerate(frames): sheet.alpha_composite(frame,(i*128,0))
 sheet.save(OUT/'sheets'/f'{name}_sheet.png')
 manifest['assets'].append({'id':name,'color':data['color'],'sheet':f'sheets/{name}_sheet.png','size':[384,128],'frames':3,'cell':[128,128],'semantic':data['label']})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
fontpath='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
font=ImageFont.truetype(fontpath,17); small=ImageFont.truetype(fontpath,13); title=ImageFont.truetype(fontpath,30)
preview=Image.new('RGB',(1200,1020),'#0A171B'); draw=ImageDraw.Draw(preview)
draw.text((36,28),'CRIMSON THREAD / ENEMY WARNING STUDY',font=title,fill='#FFF4E6')
draw.text((36,73),'ORIGINAL VECTOR CANDIDATES  /  NOT IN-GAME CAPTURE  /  128 px source',font=font,fill='#B69A6B')
for row,(name,data) in enumerate(DESIGNS.items()):
 y=125+row*275
 draw.text((36,y),data['label'],font=font,fill=data['color'])
 for col,phase in enumerate(PHASES):
  x=40+col*175
  draw.rounded_rectangle((x,y+32,x+152,y+201),8,fill='#21454A')
  im=Image.open(OUT/'frames'/f'{name}_{phase}.png').convert('RGBA')
  preview.paste(im,(x+12,y+38),im)
  draw.text((x+20,y+174),phase.upper(),font=small,fill='#FFF4E6')
 locked=Image.open(OUT/'frames'/f'{name}_locked.png').convert('RGBA')
 for col,bg in enumerate(['#0C1C21','#D5CFBA']):
  x=600+col*285
  draw.rounded_rectangle((x,y+32,x+258,y+201),8,fill=bg)
  for j,size in enumerate([64,48,32]):
   im=locked.resize((size,size),Image.Resampling.LANCZOS)
   px=x+24+j*78; py=y+73+(64-size)//2
   preview.paste(im,(px,py),im)
   draw.text((px,y+156),str(size)+'px',font=small,fill='#789A96' if col==0 else '#254348')
 draw.text((600,y+217),'INK / BONE BACKGROUND — reduced size inspection',font=small,fill='#9EAFAA')
draw.text((36,963),'Shape is the primary cue. Color is redundant. Timing and hit area remain owned by combat data.',font=font,fill='#E0D6C0')
preview.save(DOC/'preview.png')
ImageOps.grayscale(preview).save(DOC/'preview_grayscale.png')
report=[]
for p in sorted((OUT/'frames').glob('*.png'))+sorted((OUT/'sheets').glob('*.png')):
 im=Image.open(p).convert('RGBA'); a=im.getchannel('A'); bbox=a.getbbox()
 assert im.size == ((384,128) if p.parent.name=='sheets' else (128,128)), (p,im.size)
 assert a.getextrema()==(0,255),(p,a.getextrema())
 assert a.getpixel((0,0))==0 and a.getpixel((im.width-1,im.height-1))==0
 assert bbox[0]>0 and bbox[2]<im.width and bbox[1]>0 and bbox[3]<im.height,(p,bbox)
 if p.parent.name=='sheets':
  for i,phase in enumerate(PHASES):
   expected=Image.open(OUT/'frames'/f'{p.stem.removesuffix("_sheet")}_{phase}.png').convert('RGBA')
   assert_same_visible_rgba(im.crop((128*i,0,128*(i+1),128)), expected)
 report.append({'file':str(p.relative_to(ROOT)),'size':list(im.size),'alpha_range':list(a.getextrema()),'content_bbox':list(bbox),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(DOC/'validation.json').write_text(json.dumps({'checks':'PNG decode, expected dimensions from manifest, alpha range, transparent corners, no border crop, atlas alpha and visible RGBA equality (hidden RGB at alpha zero ignored). Visual review recorded separately in README.','files':report},indent=2)+'\n')
print('Built 9 SVGs, 9 transparent frames, 3 atlases, 2 review boards, manifest and validation.')
