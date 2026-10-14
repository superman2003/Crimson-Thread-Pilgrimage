#!/usr/bin/env python3
"""Technical asset checks only. Does not assert live gameplay acceptance."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
PACK=ROOT/'assets/proposals/reverse_motion_v2'
REPORT=ROOT/'docs/proposals/reverse_motion_v2/verification.json'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def outputs():
    return {str(p.relative_to(PACK)):digest(p) for p in sorted(PACK.rglob('*')) if p.is_file() and p.suffix in ('.png','.svg','.json')}

def main(rebuild=False):
    errors=[]; reports=[]
    def check(ok,message):
        if not ok:errors.append(message)
    m=json.loads((PACK/'manifest.json').read_text())
    check(m['schema_version']==1 and m['pack_id']=='reverse_motion_v2','manifest version/pack')
    check(len(m['items'])==9,'nine actions required')
    check({(i['crest_id'],i['action']) for i in m['items']}=={(c,a) for c in ('crimson','bell','salt') for a in ('needle','down','heal')},'three-by-three coverage')
    trajectories={}
    for item in m['items']:
        key=item['id']; name=item['file']; file=PACK/name
        check(not Path(name).is_absolute() and '..' not in Path(name).parts,key+': safe pack path')
        check(file.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'),key+': actual PNG, not pointer')
        check(file.stat().st_size<350_000,key+': atlas byte budget')
        im=Image.open(file)
        check(im.mode=='RGBA',key+': RGBA')
        check(im.size==(1536,192),key+': atlas size')
        check(item['frame_count']==8 and item['columns']==8 and item['frame_width']==192 and item['frame_height']==192,key+': cell size')
        check(item['loop'] is False and item['pivot']==[86,172],key+': playback contract')
        fps=item['fps']; phases=item['timing']; total=0; prev=0
        for phase in ('windup','contact','recovery'):
            p=phases[phase]; a=p['start_frame']; b=p['end_frame']
            check(a==prev and b>=a,key+': contiguous '+phase)
            check(abs(p['duration_seconds']-(b-a+1)/fps)<1e-6,key+': phase duration')
            check(abs(p['start_seconds']-a/fps)<1e-6,key+': phase start')
            check(abs(p['end_seconds_exclusive']-(b+1)/fps)<1e-6,key+': phase end')
            total+=b-a+1; prev=b+1
        check(total==8,key+': complete phase coverage')
        check(item['events'][0]['frame']==phases['contact']['start_frame'],key+': event aligned')
        bounds=[]; frame_hashes=[]
        for n,g in enumerate(item['geometry']):
            frame=im.crop((n*192,0,(n+1)*192,192)); alpha=frame.getchannel('A')
            box=alpha.getbbox(); bounds.append(box)
            check(box is not None,key+': nonempty frame '+str(n))
            check(box[0]>=8 and box[1]>=8 and box[2]<=184 and box[3]<=184,key+': 8px safe gutter '+str(n))
            check(alpha.getpixel((0,0))==0 and alpha.getpixel((191,191))==0,key+': transparent corners')
            check(alpha.crop((0,0,192,1)).getbbox() is None and alpha.crop((0,191,192,192)).getbbox() is None,key+': no vertical clipping')
            check(alpha.crop((0,0,1,192)).getbbox() is None and alpha.crop((191,0,192,192)).getbbox() is None,key+': no horizontal clipping')
            hand=g['weapon_hand']; tip=g['needle_tip']; butt=g['needle_handle_end']
            check(abs(math.dist(hand,tip)-43)<1e-7,key+': constant needle length')
            check(abs(math.dist(hand,butt)-9)<1e-7,key+': constant handle length')
            check(alpha.getpixel(tuple(hand))>128,key+': visible hand attachment')
            if item['action']!='down':
                check(all(p[1]==168 for p in g['boot_soles']),key+': planted soles')
            for x,y in g['boot_soles']:
                check(alpha.getpixel((x,y-1))>128,key+': visible boot sole')
            frame_hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
        check(len(set(frame_hashes))>=7,key+': at least seven distinct poses (return frame may match start)')
        trajectories[(item['crest_id'],item['action'])]=[g['weapon_hand']+g['hip']+[g['needle_angle_degrees']] for g in item['geometry']]
        reports.append({'id':key,'bytes':file.stat().st_size,'sha256':digest(file),'alpha_bounds_per_frame':bounds,'unique_frames':len(set(frame_hashes)),
                        'duration_seconds':phases['duration_seconds'],'minimum_transparent_gutter':min(min(b[0],b[1],192-b[2],192-b[3]) for b in bounds)})
    for action in ('needle','down','heal'):
        a=[trajectories[(c,action)] for c in ('crimson','bell','salt')]
        check(len({json.dumps(t) for t in a})==3,action+': crest trajectories must differ beyond color')
    png_bytes=sum(p.stat().st_size for p in PACK.rglob('*.png'))
    check(png_bytes<2_000_000,'all PNGs including contact sheet under 2MB')
    reproducible=None
    if rebuild:
        before=outputs()
        subprocess.run([sys.executable,str(Path(__file__).with_name('build.py'))],check=True)
        after=outputs(); reproducible=before==after
        check(reproducible,'deterministic rebuild')
    report={'pack_id':'reverse_motion_v2','status':'pass' if not errors else 'fail','technical_scope':'Offline source, alpha, bounds, geometry, phase timing, binary size and deterministic rebuild only.',
            'runtime_verified':False,'invulnerability_implied':False,'checks':{'nine_actions':len(reports),'total_frames':72,'png_bytes_including_contact_sheet':png_bytes,'deterministic_rebuild':reproducible},
            'atlases':reports,'errors':errors}
    REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'status':report['status'],'errors':errors,'png_bytes':png_bytes,'reproducible':reproducible},ensure_ascii=False))
    return bool(errors)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rebuild',action='store_true')
    sys.exit(main(p.parse_args().rebuild))
