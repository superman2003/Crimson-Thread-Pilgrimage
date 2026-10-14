#!/usr/bin/env python3
"""Static asset contract checks, render bounds, and optional Godot native raster checks."""
from pathlib import Path
import argparse, json, re, subprocess, tempfile, hashlib
from xml.etree import ElementTree as ET
from PIL import Image
import numpy as np
from build_pack import ROOT, OUT, DOC

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--godot');args=ap.parse_args()
 m=json.loads((OUT/'manifest.json').read_text());assert m['schema_version']==1
 assert [x['region_id'] for x in m['items']]==['ch06','ch05','ch04','ch03','ch02','ch01']
 ns='{http://www.w3.org/2000/svg}'
 allowed={'svg','title','defs','g','path','circle','ellipse','rect','linearGradient','radialGradient','stop','clipPath'}
 checks=[]
 with tempfile.TemporaryDirectory() as td:
  td=Path(td)
  if args.godot:
   result=subprocess.run([args.godot,'--headless','--path',str(td),'--script',str(Path(__file__).with_name('check_svg_godot.gd')),'--',str(OUT),str(td)],check=True,capture_output=True,text=True)
   assert 'SCENERY_SVG_RASTER_OK 18' in result.stdout
  for item in m['items']:
   assert [x['id'] for x in item['layers']]==['far','mid','front']
   assert item['collision'] is False and item['horizontal_tiling'] is False
   im=Image.open(OUT/item['preview']);im.load();assert im.size==(960,540)
   assert (OUT/item['preview']).stat().st_size<250000
   for layer in item['layers']:
    path=OUT/layer['file'];assert path.parent==OUT
    src=path.read_text();root=ET.fromstring(src)
    assert root.get('viewBox')=='0 0 960 540'
    assert root.get('width')=='960' and root.get('height')=='540'
    assert not re.search(r'\b(?:NaN|Infinity)\b',src)
    ids=[];refs=[]
    for el in root.iter():
     assert el.tag.removeprefix(ns) in allowed,el.tag
     if el.get('id'):ids.append(el.get('id'))
     for k,v in el.attrib.items():
      assert 'href' not in k and not k.startswith('on')
      for ref in re.findall(r'url\(([^)]+)\)',v):assert ref.startswith('#');refs.append(ref[1:])
    assert len(ids)==len(set(ids)) and set(refs)<=set(ids)
    assert layer['luma_p95']<=layer['contrast_budget']['luma_p95_max']
    assert layer['painted_fraction']<=layer['contrast_budget']['painted_fraction_max']
    # Expand only the SVG viewport. Artwork still uses the explicit authored frame clip.
    root.set('width','1000');root.set('height','580');root.set('viewBox','-20 -20 1000 580')
    overscan=td/'overscan.svg';ET.ElementTree(root).write(overscan)
    png=td/'overscan.png'
    subprocess.run(['inkscape',str(overscan),'--export-type=png','--export-filename='+str(png)],check=True,capture_output=True)
    a=np.array(Image.open(png).convert('RGBA'))[:,:,3]
    assert not a[:20,:].any() and not a[-20:,:].any() and not a[:,:20].any() and not a[:,-20:].any()
    check={'file':layer['file'],'xml_dimensions_references':'pass','rendered_bounds_no_bleed':'pass','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    if args.godot:
     native=Image.open(td/path.with_suffix('.png').name).convert('RGBA');arr=np.array(native)
     assert native.size==(960,540) and arr[:,:,3].max()>0
     if layer['id']=='front':assert not arr[100:490,160:800,3].any()
     if layer['id']=='far':assert arr[:,:,3].min()==255
     check['godot_native_raster']='pass';check['native_painted_pixels']=int((arr[:,:,3]>0).sum())
    checks.append(check)
 report={'schema_version':1,'scope':'SVG syntax, rendered clip bounds, dimensions, local references, PNG decode, contrast budgets; optional Godot SVG rasterization only. No gameplay or collision acceptance.','svg_count':len(checks),'preview_count':len(m['items']),'horizontal_tiling':False,'tiling_edge_check':'not applicable: every layer explicitly non-tiling','checks':checks}
 (DOC/'validation_report.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'svg_checked':len(checks),'preview_checked':len(m['items']),'godot_native':bool(args.godot),'pass':True}))
if __name__=='__main__':main()
