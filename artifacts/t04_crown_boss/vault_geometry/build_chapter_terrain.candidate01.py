#!/usr/bin/env python3
"""Turn horizontal routes into continuous ground while retaining branch entrances."""
import json,math
from pathlib import Path
from build_original_creature_art import atlas_frames

ROOT=Path(__file__).resolve().parents[1]
GROUPS={
'moss_cavern':[
 ('root_road','soil','start_ground entry_step_a entry_step_b md_run md_step shrine_floor'),
 ('burrow','tunnel','crawl_floor'),('west_bank','soil','hub_floor_w'),('east_bank','soil','hub_floor_e'),
 ('bell_viaduct','bridge','hg_w hg_c1 hg_c2 hg_c3 hub_balcony_e'),
 ('old_maze','tunnel','tm_a tm_b'),('pilgrim_road','ruin','ra_a ra_b gt_floor pbs_floor'),
 ('matriarch_court','arena','boss_floor'),('well_bank','soil','uw_b uw_a'),('buried_chapel','ruin','sl_floor')],
'rain_foundry':[
 ('canal_road','soil','start_ground us_step_a aq_deck aq_lip'),
 ('drainage_descent','ruin','rd_run rd_step sl_lock_a sl_lock_b shrine_floor_a'),
 ('pipe_tunnel','tunnel','cf'),('gear_aqueduct','bridge','gg_w gg_c1 gg_c2 hub_balcony_e'),
 ('pump_west_bank','soil','hub_floor_w'),('pump_east_bank','soil','hub_floor_e'),
 # Keep the spillway shaft open under its one-way metal crossing.
 ('smith_west','ruin','ra_a'),('forge_landing','ruin','fs_floor'),('scissor_forge','arena','boss_floor')],
'salt_archive':[
 ('archive_street','ruin','gate_porch gate_lantern_step spine_run_a spine_book_step spine_run_b spine_tall_shelf'),
 ('candle_arcade','tunnel','candle_floor candle_east_walk candle_gap_stand'),
 ('inverted_gallery','bridge','inv_gallery_a inv_page_step inv_gallery_b inv_east_shelf'),
 # The stair shaft rises through the hanging crest deck from below.
 ('crest_east','ruin','crest_east_walk'),('salt_basin','soil','sg_run_a sg_run_b sg_run_c'),
 ('judgement_approach','ruin','index_run_a boss_threshold'),('mantis_court','arena','mantis_floor'),
 ('archive_exit','ruin','exit_dock dock_step dock_walk')],
'string_greenhouse':[
 ('entry_root','soil','gate_floor'),
 ('garden_floor','soil','south_run_a south_bed_b south_run_c south_bed_d south_run_e south_bed_f south_run_g south_bed_h south_run_i'),
 ('wax_bank','ruin','bw_step bw_floor'),('canopy_east','bridge','canopy_e_b canopy_e_a'),
 ('canopy_west','bridge','canopy_w_c canopy_w_b canopy_w_a'),('garden_heart','soil','heart_floor'),
 ('root_vault','tunnel','vault_floor'),('broken_spoke','ruin','spoke_run_b spoke_run_a'),
 ('bishop_approach','ruin','overlook_walk boss_threshold'),('root_dome','arena','dome_floor')],
'obsidian_pilgrim':[
 ('pilgrim_street','ruin','gate_floor gate_flag_step base_run_a base_cart_stand base_run_b base_shrine_step base_run_c'),
 ('ash_basin','soil','ash_slope ash_floor'),('rest_camp','soil','camp_floor lsw_camp_step'),
 ('lower_scree','soil','lsw_out_f lsw_rise_e lsw_rise_d lsw_flag_c lsw_rise_b lsw_rise_a'),
 ('upper_scree','soil','usw_rise_a usw_rise_b usw_flag_c usw_rise_d usw_rise_e usw_out_f'),
 ('mirror_approach','bridge','mirror_walk_a mirror_rest_b boss_threshold'),('mirror_court','arena','mirror_floor'),
 ('pilgrim_exit','ruin','exit_dock')],
'silent_crown':[
 ('crown_antechamber','ruin','ante_floor ante_east_step'),('sewn_slope','soil','sew_bone_a sew_bone_b sew_bone_c'),
 ('echo_canal','soil','rain_pool_floor rain_wheel_stand'),('rib_gallery','ruin','ringE_lip ringE_walk_b ringE_walk_a'),
 ('bell_vault','tunnel','vault_floor'),('moss_memory','soil','moss_court_floor moss_bell_perch'),
 ('throne_approach','ruin','throne_walk_a throne_rest_b boss_threshold'),('last_court','arena','throne_floor'),
 ('ascension','ruin','asc_step_a asc_step_b exit_dais')]
}

def intersects_gate(a,b,gate,depth):
    gx,gy,gw,gh=gate['rect']
    if b[0]<=gx or a[0]>=gx+gw: return False
    for x in [max(a[0],gx),min(b[0],gx+gw)]:
        t=(x-a[0])/max(1,b[0]-a[0]); y=a[1]+(b[1]-a[1])*t
        if gy-8<=y+depth and y<=gy+gh+8: return True
    return False

def build(path):
    d=json.loads(path.read_text());theme=d.get('art',{}).get('theme',d.get('art_theme',''))
    if not theme: theme=d.get('art_theme', 'moss_cavern')
    # Main runtime uses art_theme directly.
    theme=d.get('art_theme',theme)
    if theme not in GROUPS:return
    plats={p['id']:p for p in d['platforms']}
    for p in plats.values():p.pop('terrain_id',None);p.pop('terrain_flat_span',None)
    results=[]
    for group_id,kind,ids in GROUPS[theme]:
        selected=[plats[x] for x in ids.split() if x in plats]
        selected.sort(key=lambda p:p['rect'][0]); chunks=[];chunk=[]
        for p in selected:
            x,y,w,h=p['rect'];left,right=x,x+w
            # Preserve the authored 110px drop slot between the crown rain banks.
            if chunk and theme=='silent_crown' and group_id=='echo_canal' and p['id']=='rain_wheel_stand':
                chunks.append(chunk);chunk=[]
            if chunk:
                previous=chunk[-1]; px,py,pw,_=previous['rect']
                gap=x-(px+pw);rise=abs(y-py)
                if gap<0 or gap>420 or rise>300:
                    chunks.append(chunk);chunk=[]
            chunk.append(p)
        if chunk:chunks.append(chunk)
        for ci,part in enumerate(chunks):
            flats=[]
            for p in part:
                x,y,w,_=p['rect'];flats.append([x,y,x+w])
            for i in range(len(flats)-1):
                a,b=flats[i],flats[i+1]
                required=abs(b[1]-a[1])/math.tan(math.radians(32))
                deficit=max(0,required-(b[0]-a[2]))
                trim=min(deficit/2,(a[2]-a[0]-100)/2,(b[2]-b[0]-100)/2)
                a[2]-=max(0,trim);b[0]+=max(0,trim)
            surface=[]; current=[];parts=[]; owners=[];current_owners=[]
            for i,(p,f) in enumerate(zip(part,flats)):
                left,y,right=f
                if current:
                    prev=current[-1]; steep=abs(y-prev[1])>max(1,left-prev[0])*math.tan(math.radians(32))+.1
                    blocked=any(intersects_gate(prev,[left,y],g,84) for g in d.get('locked_gates',[]))
                    if steep or blocked:
                        parts.append((current,current_owners));current=[];current_owners=[]
                current += [[round(left,2),y],[round(right,2),y]];current_owners.append((p,f))
            if current:parts.append((current,current_owners))
            for pi,(surface,owners) in enumerate(parts):
                tid=f'terrain_{group_id}_{ci}_{pi}'
                depth=140 if kind=='arena' else (72 if kind=='bridge' else 104)
                if theme=='obsidian_pilgrim' and group_id=='lower_scree' and any(p['id']=='lsw_rise_a' for p,f in owners):
                    depth=18  # 90px headroom above the lower road (2716-2608-18).
                results.append({'id':tid,'kind':kind,'surface':surface,'depth':depth,
                    'texture_variants':[0,3,1,2] if kind=='soil' else ([4,2,1] if kind in ['ruin','bridge','arena'] else [3,1,5]),
                    'platform_ids':[p['id'] for p,f in owners]})
                if theme=='silent_crown' and group_id=='echo_canal' and any(p['id']=='rain_pool_floor' for p,f in owners):
                    # A short thin outflow lip keeps 90px clearance above the lower step.
                    edge=surface[-1][0]; level=surface[-1][1]
                    surface[-1][0]=edge-64
                    results.append({'id':tid+'_outflow_lip','kind':kind,
                        'surface':[[edge-64,level],[edge,level]],'depth':30,
                        'texture_variants':[0,3,1,2],'platform_ids':[]})
                if theme=='silent_crown' and group_id=='bell_vault' and any(p['id']=='vault_floor' for p,f in owners):
                    # Preserve the upper vault while opening the two lower shrine approaches.
                    left,right=surface[0][0],surface[-1][0];level=surface[0][1]
                    surface[0][0]=left+64;surface[-1][0]=right-80
                    for suffix,a,b in [('west',left,left+64),('east',right-80,right)]:
                        results.append({'id':tid+'_door_'+suffix,'kind':kind,
                            'surface':[[a,level],[b,level]],'depth':70,
                            'texture_variants':[3,1,5],'platform_ids':[]})
                for p,f in owners:p['terrain_id']=tid;p['terrain_flat_span']=[round(f[0],2),round(f[2],2)]
    d['terrain']=results
    d['terrain_design']={'view':'orthographic_side_2d','max_ramp_degrees':32,'route_kinds':['ground','slope','tunnel','bridge','basin','vertical_climb'],
        'notes':'Continuous horizontal ground, open branch shafts, short bridges and retained vertical traversal challenges.'}
    path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    print(path.name,len(results),'landforms,',sum(len(x['platform_ids']) for x in results),'converted anchors')

def main():
    for theme in GROUPS:
        folder=ROOT/'godot/assets/sprites/flat_maps'/theme
        manifest=json.loads((folder/'manifest.json').read_text())
        rects,size=atlas_frames(folder/'terrain_atlas.png',3,2)
        manifest['terrain_regions']=rects;manifest['terrain_atlas']='terrain_atlas.png'
        (folder/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    for p in sorted((ROOT/'godot/data').glob('demo_ch0*.json')):
        if 'boss_trial' not in p.name: build(p)

if __name__=='__main__':main()
