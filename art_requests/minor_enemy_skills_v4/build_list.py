"""All ordinary species, base/elite command warnings, missing release and triggered skills."""
from __future__ import annotations
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
ACTIVE={'melee','lunge','dive','guard','combo','vault','feint','blink','retreat'}
MATERIALS={
'moss_larva':'wet moss, pale root fibres and small worn ivory mandible ridges; soft green-brown organic material',
'spore_bellmaker':'olive-green spore husks, pale gold fungal gills and moss fibres, with sparse tiny amber spores',
'bronze_moth':'ragged oxidised bronze wing-edge flakes and dusty warm gold pollen; a thin dark patina rim',
'gear_sentinel':'worn bronze gear teeth, dark iron nicks and pale ivory cutting rims, with small gear-tooth debris',
'corridor_heavy':'thick weathered brass bell-shell ridges, cracked dark stone grit and dull gold clapper curls',
'bellroot_acolyte':'curling brown bellroots with tarnished little brass chimes and pale wood fibres',
'drain_leech':'dark wet rust-brown segmented ridges, pale hook teeth and sparse murky water droplets',
'pipe_thrower':'rusty iron pipe collars, copper rivet flecks and compact grey steam wisps with pale edges',
'waterwheel_knight':'bronze paddle-wheel ridges, turquoise copper patina and clear cold water droplets',
'rust_diver':'rusted diving-brass strips, thin old spear-tip glints and broken blue-grey water curls',
'bell_mote':'small tarnished gold bell fragments, ivory ringing ridges and thin pale moth dust',
'valve_crawler':'red-brown valve-wheel teeth, worn brass spokes, grey-white steam and iron grit',
'rain_censer_mote':'grey-violet incense fibres, dull copper censer ridges and tiny muted orange ember grains',
'salt_bookmite':'torn salt-white parchment flakes, black ink edges and small translucent salt teeth',
'index_scribe':'creased ivory index-paper ribbons, dark ink seals and dull brass index-tab glints; no legible glyphs',
'page_duelist':'sharp folded parchment cutting planes, black ink ridges, silver nib-tip glints and loose paper strips',
'wax_lancer':'solid amber wax lance streaks, dark iron tips, drooping ochre wax threads and pale warm edges',
'erasure_bailiff':'dark iron cleaving planes with scraped ivory paper edges and scattered black ink erasures',
'summoned_page':'folded ivory parchment wings, crisp black ink folds and delicate torn page fringes, no text',
'vine_crawler':'wet emerald-brown vines, pale sap-edged thorn teeth and curled small leaf strips',
'root_cage_hunter':'knotted brown root fibres, crimson binding threads and pale sharp bark splinters',
'wax_bee':'amber wax stinger ridges, dark chitin shards and sparse honey-gold dust',
'thorn_sentinel':'dark glossy green-brown thorns, pale bone tips and dry curled leaf fibres',
'pollen_lutist':'fine pale gold pollen clusters threaded with green-brown plant strings and small copper seed husks',
'thorn_bloom_mote':'purple-green flower husks, yellow-green anther needles and dark tangled thorn fibres',
'obsidian_spearman':'angular glossy black obsidian spear shards, grey ivory edge glints and sparse ash',
'phase_censor':'thin pale silver crescent shards, dark violet censor-veil folds and small cold ivory glints',
'pilgrim_chariot':'black iron wheel-tooth strips, worn brass pilgrim fittings and sparse grey ash nails',
'silent_bugbler':'tarnished brass trumpet-rim crescents, hollow ivory ringing ridges and dark cloth wisps',
'kneeling_crossbowman':'dark iron bolt-head ridges, tensioned brown sinew fibres and sparse grey fletching strips',
'ash_banner_imp':'frayed ash-red banner strips, thin black flagpole-tip slashes, brass thread knots and pale ash; support magic uses pale ivory stitched red cloth',
'obsidian_bellwheel':'dark obsidian bellwheel segments, narrow old brass rims and coarse grey ringing ash',
'echo_waterwheel_knight':'pale tarnished bronze wheel ridges, cool teal echo fragments and translucent grey water scraps',
'echo_moss_larva':'desaturated moss husks, pale root fibres and muted turquoise echo fragments',
'echo_thorn_sentinel':'grey-green spectral thorn tips with pale ivory edges and sparse muted turquoise leaf dust',
'echo_contract_scribe':'torn pale grey contract ribbons, dark ink seals and muted turquoise echo edges; no readable text',
'falling_clapper':'heavy tarnished brass clapper ridges, dark iron bell chips and ivory ringing dust',
'delayed_shadow':'black-violet torn shadow veil, narrow silver blade glints and faded grey afterimage strands',
'echo_pilgrim_commander_minor':'dark iron spear-edge strips, worn gold military thread knots and muted pale turquoise echo ash',
'isotope_lumen':'pale gold light filaments surrounding a dark-rimmed ivory core, with tiny amber flecks and a restrained luminous edge',
}

def shape(a,mode):
 t=a['type'];n=a['name'];elite=a.get('_elite',False)
 phrase={
 'melee':'a sharp RIGHT-facing contact bite or weapon cut matching the attack name; use a tall rising cut when hit offset_y is high, a broad horizontal cleave when its width is wide',
 'lunge':'a low elongated RIGHT-facing thrust/ram edge with material streaming backward LEFT; one pointed front, no complete predicted travel lane',
 'dive':'a compact diagonal upper-LEFT to lower-RIGHT diving cutting streak; no target marker or projected flight path',
 'guard':'an asymmetrical RIGHT-facing braced defensive wedge made of overlapping material plates; open back, no invulnerability bubble',
 'combo':'three successive different short RIGHT-facing cutting contours: rising diagonal, falling diagonal, and horizontal finishing slash',
 'vault':'a compact curled RIGHT-facing upward-turning blade/ram tension; no landing target or drawn travel arc',
 'feint':'two offset short opposed paper/blade curls gathering to the RIGHT, a deceptive crooked cutting gesture',
 'retreat':'a hooked RIGHT-facing trailing thrust, fibres moving LEFT behind it; no drawn movement arrow',
 'blink':'a small local split veil/mirror rupture around a transparent slit, silver tip glints; no clone, victim or distant landing mark',
 'fan':'a small LOCAL clustered muzzle/casting tension with a few closed pods or folded fragments; no launched shots and no fan of predicted trajectories',
 'projectile':'a small LOCAL muzzle/casting tension, with one tight material bud or nocked fragment; no projectile path or giant target zone',
 'nova':'a compact LOCAL casting knot with several small folded material tips around its core; no arena-wide radial paths or danger disc',
 'mortar':'a small LOCAL pressure knot, rusty collar scraps and curled steam; no flying canister and no predicted parabola',
 'wave':'a compact grounded material pressure coil ready to release a travelling ground pulse; no full future wave route',
 'pool':'a material-woven danger perimeter with a transparent centre, built from folded/clumped material at a fixed outer footprint; not a plain circle',
 'rootline':'a low flat branching fissure made of folded material at the ground baseline; fixed full horizontal footprint, NO risen spikes',
 'beam':'a horizontal RIGHT-facing seamless repeating warning corridor tile made of woven/overlapping material; flat side-view, no end caps, no arrow, no perspective and no long full-screen line',
 }[t]
 if mode=='execution':
  phrase=phrase.replace('tension','active released strike').replace('braced defensive wedge','snapping counter-cut wedge').replace('ready to release','releasing')
  phrase+='; clearly ACTIVE release and follow-through, not an anticipation hold'
 else:phrase+='; ANTICIPATION ONLY, never completed impact or released attack'
 return f'Attack identity {a["id"]} ({n}); {phrase}.'+(' Elite variant has a more complex broken contour and extra material knots, never merely a recolour.' if elite else '')

def collect():
 profiles=json.loads((ROOT/'godot/data/original_creature_combat.json').read_text(encoding='utf-8'));jobs=[]
 for kind,material in MATERIALS.items():
  p=profiles[kind];rows=[]
  for a in p['attacks']+[dict(a,_elite=True) for a in p.get('elite',{}).get('attacks',[])]:
   t=a['type'];topology='pool' if t=='pool' else 'eruption' if t=='rootline' else 'beam' if t=='beam' else 'guard' if t=='guard' else 'source' if t in ['fan','projectile','mortar','nova','wave','blink','vault','dive'] else 'sweep'
   for mode in ['warning']+(['execution'] if t in ACTIVE else []):
    look=shape(a,mode)
    plan=['Full footprint present immediately, inner material lightly gathered.','Inner tension becomes stronger, identical fixed outer bounds.','Full readable tension; outer footprint stays fixed, no release and no fade.'] if mode=='warning' else ['Readable onset of the active released strike.','Peak active cut, visibly different contour from onset.','Follow-through separating into fewer fading pieces; no opaque blob.']
    if mode=='execution' and t=='combo':plan=['First rising diagonal active cut.','Second falling diagonal active cut, a new silhouette.','Third horizontal finishing cut, a new silhouette.']
    # A vault/dive winds up locally, but the released body/weapon strike must
    # cover its contact hitbox rather than remain a small casting knot.
    row_topology='sweep' if mode=='execution' and t in ['vault','dive'] else topology
    rows.append(dict(key=a['id']+'_'+mode,command_id=a['id'],mode=mode,type=t,topology=row_topology,command=a,look=look,plan=plan))
  if kind=='wax_lancer':
   for mode in ['warning','execution']:
    rows.append(dict(key='wax_trail_'+mode,extra='wax_trail',mode=mode,topology='pool',look='A small amber melted-wax ground patch with pale wax drips and dark iron grit; '+('a coiled low wax perimeter, no risen flame or active splash, fixed footprint' if mode=='warning' else 'active molten wax surges then a held viscous puddle, no fire'),plan=['Clear first material footprint.','Thicker gathered wax detail, fixed footprint.','Changed viscous wax contour, fixed footprint.']))
  if kind=='pipe_thrower':rows.append(dict(key='pipe_impact_warning',extra='pipe_impact',mode='warning',topology='pool',look='A small flattened rusty slag footprint circled by coiled steam and loose iron filings; fixed perimeter, no active explosion, ground impact anticipation.',plan=['Full visible slag footprint.','Inner steam gathers, same footprint.','Full tension steam, same footprint.']))
  if kind=='ash_banner_imp':
   for mode,look in [('channel','a small LOCAL gathered knot of pale ivory stitches and ash-red banner threads; healing preparation, no danger disc'),('link','a continuous thin horizontal repeating strand of pale ivory woven stitches and ash-red cloth fibres, suitable as a seamless LEFT-RIGHT support tether, no caps or arrow'),('release','a compact burst of pale ivory healing stitches opening into soft ash-red thread petals and fading small fibres, no character')]:
    rows.append(dict(key='support_'+mode,extra='support',mode=mode,topology='beam' if mode=='link' else 'source',look=look,plan=['Visible onset or first loop pose.','Changed hand-inked contour or second loop pose.','Released strands fade for release; seamless third loop pose for channel or link.']))
  ref='art_requests/creature_attacks_v1/refs/'+kind+'.png'
  count=len(rows)*3
  text=f'''Use case: stylized-concept
Asset type: production transparent sprite sheet for an ordinary enemy's missing combat effects, hand-inked side-view 2D dark fairytale game.
Reference image is MATERIAL/PALETTE IDENTITY ONLY. Do not draw any character, face, body, full physical weapon, victim, floor, scenery or UI.
Material: {material}. Match its illustrated ink/gouache texture, organic irregular contours, solid readable high contrast cores and very restrained pale rims. Effects will display at 30-160 game pixels: strong simple material silhouette, no tiny clutter.
Exactly {count} separate cels: THREE COLUMNS by {len(rows)} ROWS. Each ROW is one different effect, described below in TOP-TO-BOTTOM order. Each row's three cels progress LEFT to RIGHT. Equal cell dimensions, every cel isolated, no labels, no row names, no grid lines, no text or numbers.
Critical: real transparent alpha. Every cell has fully empty alpha=0 gutters on ALL FOUR SIDES of at least 20% cell size. Long tips, fragments and any soft halo stay within the middle 60% of each cel. No inter-cell contamination, no shared glow, no background, no checkerboard. Use modest compact shapes, never fill the cell. Effects all face RIGHT unless described as a local cue or ground patch. Keep the registration at the centre of each cel. No generic featureless geometric circles, arcs, arrows, triangles or lines: the EFFECT BODY must be built of the specified material.
For a warning row all three cels have the identical visible outer footprint, already readable at cel 1; only internal tension changes. For an execution row make all three contours different. Seamless tile rows may reach only the LEFT/RIGHT cel edges; top/bottom remain empty. Distinct attack rows must differ by silhouette and material gesture, not just rotation, scale or colour.
'''
  for i,row in enumerate(rows):text+=f'\nROW {i+1}: {row["key"]}. {row["look"]}\n'+ '\n'.join(f'Cell {j+1}: {v}' for j,v in enumerate(row['plan']))+'\n'
  jobs.append(dict(file='FX_M_'+kind+'.png',kind=kind,reference=ref,columns=3,rows=len(rows),frame_count=count,animations=rows,prompt=text))
 return jobs

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();jobs=collect()
 payload={'schema':4,'ordinary_species':40,'commands':90,'warning_animations':90,'missing_execution_animations':42,'source_sheets':40,'total_cels':sum(j['frame_count'] for j in jobs),'extras':['wax_trail_warning','wax_trail_execution','pipe_impact_warning','support_channel','support_link','support_release'],'jobs':jobs}
 files={'requests.json':json.dumps(payload,ensure_ascii=False,indent=2)+'\n',**{'prompts/'+Path(j['file']).stem+'.txt':j['prompt'] for j in jobs}}
 for path,text in files.items():
  dst=HERE/path
  if a.check:
   if not dst.is_file() or dst.read_text(encoding='utf-8')!=text:raise ValueError('Stale '+str(dst))
  else:dst.parent.mkdir(parents=True,exist_ok=True);dst.write_text(text,encoding='utf-8',newline='\n')
 (HERE/'incoming').mkdir(exist_ok=True)
 print('MINOR_ENEMY_BRIEFS species=40 commands=90 warnings=90 executions=42 extras=6 cels='+str(payload['total_cels']))
if __name__=='__main__':main()
