"""Specify missing execution pixels, separately from v2 anticipation sheets."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LOOKS = {
    'boss_moss_scythe': 'A broad RIGHT-facing hooked crescent of torn wet moss, old brass flecks and pale root fibres. Strong sweeping slash with a ragged mossy leading edge, then large curling fibres separate. No smooth neon arc.',
    'boss_shears_close': 'Two opposing crimson silk cutting crescents CLOSE together on the RIGHT into a sharp crossed scissor bite, worn ivory edges and a tiny dull brass hinge glint, then loose clipped red strands scatter. No actual scissors or character.',
    'boss_shears_turn': 'A rotating pair of asymmetrical crimson silk cutting ribbons, spiralling clockwise toward the RIGHT, with ivory shear-edge glints and frayed cloth tails. A complete active airborne turning cut, then broken red threads peel away. No trajectory arrow or predicted landing mark.',
    'boss_mantis_guard': 'Two crossed ash-grey chitin cutting ridges snap open into a RIGHT-facing counterstrike, bone-white serrated tips and an ember-dark joint, followed by short drifting ash. Clearly a sharp active counter-cut, distinct from a passive shield or circular ward.',
    'boss_mantis_lunge': 'An elongated low RIGHT-facing ash-grey chitin lance-cut, a single sharp ivory tip tears forward with layered dark blade streaks and sparse cinder fragments behind it. Flat piercing momentum, no overhead hook and no generic arrow.',
    'boss_mantis_overhead': 'A tall hooked ash-grey chitin blade streak tears from upper LEFT down to lower RIGHT, pale bone serrations and a short ash burst at the bottom. Strong overhead cleave silhouette, not a flat thrust.',
    'boss_mantis_flurry': 'A three-beat RIGHT-facing series of distinct hooked mantis cuts: first a rising diagonal, second a descending diagonal, third a short horizontal finishing slash. Charred chitin, pale ivory blade ridges, very sparse ash. Each beat must have a different contour. No opaque full-screen fan.',
    'boss_bishop_staff': 'A hooked crozier-shaped copper-root striking arc sweeps down and RIGHT; bark fibres, oxidised copper-green edges and a few broken orange seed husks burst at the low point, then woody splinters disperse. No staff prop or character.',
    'boss_bride_crescent': 'A RIGHT-facing cold silver broken-mirror crescent slash, layered reflective shards wrapped in a flowing black-violet veil tail; pale ivory glints and delicate dark ripples, followed by larger fading mirror flakes. No golden generic slash.',
    'boss_bride_mirror': 'A local displacement rupture formed by split silver mirror flakes and twisting black-violet veil ribbons. The centre opens into a narrow transparent tear and folds away, with two offset cold-white glints. Compact local blink burst, no person, clone, projectile path or landing marker.',
    'boss_bride_dash': 'A low RIGHT-facing silver crescent with a trailing ribbon of torn black-violet bridal veil and thin mirror splinters; a fast active airborne moon-sweep, flowing backward to the LEFT before peeling into fading shards. No character or long predicted route.',
    'boss_key_cleave': 'A heavy RIGHT-facing descending fan of worn brass key-tooth cutting fragments, dark iron notch shadows, ivory edge glints and loose key-ring curls. Thick weighty cleave at its peak then separate brass slivers fall away. No full physical weapon or character.',
}
COMMON = '''Use case: stylized-concept
Asset type: production transparent sprite sheet of an ACTIVE boss combat effect for a hand-inked side-view 2D game.
Input image 1 is a REFERENCE ONLY for material, palette and identity. Do not copy the boss body, portrait, weapon prop or backdrop.
Only draw the independent effect. Inked irregular edges, matte gouache texture, restrained pale rim detail. Genuine alpha transparency, not black/white/checkerboard background. No text, labels, numbers, UI, borders or grid lines.
Exactly 6 distinct cels in a 3-column by 2-row grid, left-to-right then top-to-bottom. Requested canvas 1536x1024. Every cel has generous fully transparent gutters. Main effect remains within the middle 76% of its cell. All effect origins stay at the cell centre; RIGHT is the attack direction. Never let material cross into the next cel.
This is damaging RELEASE / EXECUTION, not anticipation. Do not reproduce the v2 warning shape as a hold. No generic clean line, arc, circle or glow disc; build the silhouette out of the boss's material.
'''

def main():
    source = json.loads((ROOT/'art_requests/combat_presentation_v2/requests.json').read_text(encoding='utf-8'))
    requests=[]
    for r in source['requests']:
        if not r.get('command') or r['command']['id'] not in LOOKS: continue
        cid=r['command']['id']; stem='FX_X_'+cid.removeprefix('boss_')
        plan=['Visible onset with a compact cutting edge.', 'The material opens into the first strong strike.', 'Peak silhouette with the clearest strongest cutting contour.', 'A changed follow-through contour; large material strands separate.', 'Sparse fragments retract or disperse, no solid opaque blob.', 'Last faint small fragments almost disappear; clear readable end.']
        if cid=='boss_mantis_flurry':
            plan=['First rising diagonal cut starts.', 'First cut follows through with small ash.', 'Second descending diagonal cut starts, different contour.', 'Second cut follows through.', 'Third horizontal finishing cut starts, different contour.', 'Third cut releases into sparse fading ash.']
        prompt=COMMON+'Effect: '+LOOKS[cid]+'\n'+'\n'.join(f'Cel {i+1}: {s}' for i,s in enumerate(plan))+'\n'
        ref=(Path('../combat_presentation_v2')/r['refs'][0]).as_posix()
        requests.append(dict(file=stem+'.png',name=r['name'].removesuffix('预警')+'生效',group='boss_execution',frame_count=6,requested_layout=dict(columns=3,rows=2,cel_size=[512,512],canvas_size=[1536,1024]),anchor='center',playback='active_progress',topology='source' if cid=='boss_bride_mirror' else 'sweep',refs=[ref],boss_kind=r['boss_kind'],command=r['command'],prompt=prompt))
        (HERE/'prompts').mkdir(parents=True,exist_ok=True)
        (HERE/'prompts'/f'{stem}.txt').write_text(prompt,encoding='utf-8',newline='\n')
    (HERE/'incoming').mkdir(exist_ok=True)
    (HERE/'requests.json').write_text(json.dumps(dict(version=3,total_sheets=len(requests),total_frames=6*len(requests),requests=requests),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f'BOSS_EXECUTION_BRIEFS sheets={len(requests)} frames={len(requests)*6}')

if __name__=='__main__':main()
