#!/usr/bin/env python3
"""Author distinct combat contracts for forty creatures and six chapter bosses."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1];DATA=ROOT/'godot/data'

def attack(id,name,kind,reach=180,windup=.45,active=.24,recover=.5,**kw):
    result=dict(id=id,name=name,type=kind,range=reach,windup=windup,active=active,recover=recover,cooldown=2.1,
        hit_width=90,hit_height=70,offset=48,damage=1,telegraph='c99558',vertical_tolerance=190,
        animation='attack',desire_cost=.7,mechanic=name)
    result.update(kw);return result

def profile(motion,identity,attacks,**kw):
    result=dict(locomotion=motion,combat_identity=identity,move_speed=62,aggro_range=440 if motion=='stationary' else 300,
        preferred_range=230 if motion=='stationary' else (135 if motion=='flight' else 66),
        attack_desire_threshold=.58,attack_desire_gain=1.1,aggro_vertical_tolerance=220 if motion=='flight' else 140,
        leash_radius=300,attacks=attacks)
    result.update(kw);return result

def A(id,name,t,**kw):return attack(id,name,t,**kw)

PROFILES={
'moss_larva':profile('ground','短促咬击；蜷壳蓄力后扑身',[
 A('larva_snap','抬头咬击','melee',reach=85,windup=.25,hit_width=66,recover=.55),
 A('larva_curl','蜷壳扑身','lunge',reach=190,windup=.65,lunge_speed=260,active=.32,recover=.8)]),
'spore_bellmaker':profile('stationary','驻足摇铃，孢子扇射与延迟菌圈',[
 A('bell_spores','孢子扇射','fan',reach=460,shot_count=3,spread=.50,projectile_speed=190,skin='spore',windup=.7),
 A('bell_fungus','菌圈落点','pool',reach=420,radius=45,warning=.85,hazard_life=1.8,skin='spore',cooldown=4)]),
'bronze_moth':profile('flight','横向掠飞后锁定俯冲，翼粉呈弧形散开',[
 A('moth_dive','铜翼俯冲','dive',reach=260,windup=.6,active=.55,recover=.9),
 A('moth_dust','翼粉弧射','fan',reach=340,shot_count=3,spread=.72,projectile_speed=170,skin='pollen')],hover_height=95),
'gear_sentinel':profile('ground','架盾诱击后盾突，长矛保持距离',[
 A('gear_guard','架盾反突','guard',reach=160,windup=.7,active=.25,hit_width=115,recover=.7),
 A('gear_spear','齿矛长刺','melee',reach=160,windup=.48,hit_width=150,offset=76,hit_height=42)],front_guard=True),
'corridor_heavy':profile('ground','笨重冲撞与近身震地，收招较长',[
 A('heavy_roll','钟壳滚撞','lunge',reach=330,windup=.8,lunge_speed=300,active=.55,hit_width=125,recover=1.1),
 A('heavy_stamp','重壳震地','wave',reach=240,windup=.9,shot_count=2,projectile_speed=200,radius=20,recover=1)],move_speed=38),
'bellroot_acolyte':profile('ground','铃杖近击与双向低空钟波',[
 A('root_staff','铃杖敲击','melee',reach=120,windup=.55,hit_width=118,hit_height=100),
 A('root_bell_wave','贴地双钟波','wave',reach=400,shot_count=2,projectile_speed=210,windup=.72)]),
'drain_leech':profile('ground','低位潜咬吸血，弧跃贴近目标',[
 A('leech_drain','吸血咬','melee',reach=88,windup=.35,leech=True,hit_height=48),
 A('leech_leap','渠虫弧跃','vault',reach=215,windup=.55,active=.65,jump_height=105,lunge_speed=210,recover=.8)]),
'pipe_thrower':profile('stationary','向上抛射管弹，落地溅出短暂危险区',[
 A('pipe_mortar','管弹曲射','mortar',reach=510,shot_count=3,gravity=540,projectile_speed=185,skin='metal',impact_pool=True,windup=.8),
 A('pipe_backblast','近身蒸汽反喷','beam',reach=145,beam_length=160,radius=17,windup=.65,hazard_life=.38,cooldown=3.1)]),
'waterwheel_knight':profile('ground','轮盾冲锋，回旋刃飞出后返身',[
 A('wheel_charge','轮盾推进','lunge',reach=260,windup=.7,active=.4,lunge_speed=250,hit_width=124),
 A('wheel_return','返轮刃','projectile',reach=410,returning=True,projectile_speed=270,skin='wheel',radius=17,windup=.75)]),
'rust_diver':profile('ground','跳刺后落地水波，腾空时可绕到身后',[
 A('diver_vault','锈枪跃刺','vault',reach=280,active=.75,jump_height=135,lunge_speed=250,windup=.55,recover=.85),
 A('diver_splash','潜盔涌浪','wave',reach=370,shot_count=2,projectile_speed=200,radius=16,windup=.7)]),
'bell_mote':profile('flight','慢速追踪钟珠，与短距离扑击交替',[
 A('mote_seek','缓追钟珠','projectile',reach=400,projectile_speed=150,steering=135,skin='light',windup=.7),
 A('mote_peck','铃蛾扑击','dive',reach=190,active=.5,windup=.48,recover=.7)],hover_height=110),
'valve_crawler':profile('ground','滚阀靠近，停下排出水平蒸汽',[
 A('valve_roll','阀轮滚撞','lunge',reach=240,lunge_speed=200,active=.4,windup=.7),
 A('valve_vent','排汽横扫','beam',reach=280,beam_length=300,radius=13,windup=.9,hazard_life=.4)]),
'rain_censer_mote':profile('flight','悬空撒落香灰弹，持续迫使玩家移动',[
 A('censer_rain','雨香落弹','fan',reach=370,shot_count=4,spread=.64,projectile_speed=185,gravity=130,skin='pollen',snare=.55,windup=.75),
 A('censer_cloud','香灰落圈','pool',reach=300,radius=48,warning=.65,hazard_life=1.6,cooldown=4)],hover_height=145),
'salt_bookmite':profile('ground','伏低钻行突咬，纸壳前摇明显',[
 A('book_burrow','伏书钻咬','lunge',reach=220,windup=.75,active=.38,lunge_speed=260,burrow=True,recover=.85),
 A('book_bite','啮页咬','melee',reach=80,windup=.28,hit_width=62)]),
'index_scribe':profile('stationary','纸页横扇与脚下索引封印',[
 A('index_pages','索引页扇','fan',reach=500,shot_count=3,spread=.35,projectile_speed=245,skin='page',windup=.65),
 A('index_seal','落点封印','pool',reach=460,warning=.8,radius=37,hazard_life=1.25,snare=.9,cooldown=3.8)]),
'page_duelist':profile('ground','虚晃短刺后退，双段追刺',[
 A('page_feint','虚晃退刺','feint',reach=135,windup=.48,active=.26,hit_width=118,recover=.38),
 A('page_combo','双段追刺','combo',reach=225,windup=.62,active=.55,lunge_speed=175,hit_width=128,offset=75,recover=.7)]),
'wax_lancer':profile('ground','蜡枪冲刺留下地面烛蜡，需跃过尾迹',[
 A('wax_charge','熔蜡冲枪','lunge',reach=330,windup=.82,active=.6,lunge_speed=300,trail=True,hit_width=145,recover=.95),
 A('wax_high','挑枪截空','melee',reach=150,windup=.45,hit_height=150,offset_y=-74,hit_width=100)]),
'erasure_bailiff':profile('ground','慢刀断页与蓄力擦除光束',[
 A('bailiff_cleave','断页大刀','melee',reach=175,windup=.85,hit_width=175,hit_height=110,recover=1),
 A('bailiff_erase','擦除直线','beam',reach=430,beam_length=455,radius=18,windup=1.1,hazard_life=.36,cooldown=4)],move_speed=40),
'summoned_page':profile('flight','绕飞纸刃散射后俯掠',[
 A('page_orbit','环页散刃','nova',reach=270,shot_count=5,projectile_speed=160,skin='page',windup=.7),
 A('page_skim','折页俯掠','dive',reach=240,windup=.5,active=.55,recover=.7)],hover_height=105),
'vine_crawler':profile('ground','藤口咬击，身前三段根刺依次冒出',[
 A('vine_bite','藤口咬','melee',reach=92,windup=.42,hit_width=82),
 A('vine_roots','三段根刺','rootline',reach=320,shot_count=3,spacing=85,warning=.55,hazard_life=.5,radius=24,windup=.7)]),
'root_cage_hunter':profile('ground','投出根网减速，再长距离扑刺',[
 A('cage_net','根网投掷','projectile',reach=360,projectile_speed=220,skin='thorn',radius=14,snare=1.2,windup=.7),
 A('cage_pounce','根笼扑刺','vault',reach=280,active=.6,jump_height=100,lunge_speed=290,windup=.55)]),
'wax_bee':profile('flight','快速蜂刺俯冲，双针封住后撤方向',[
 A('bee_dive','蜡蜂刺冲','dive',reach=280,active=.48,windup=.62,recover=.85),
 A('bee_stingers','双针连射','fan',reach=400,shot_count=2,spread=.22,projectile_speed=310,skin='thorn',windup=.65)],move_speed=80,hover_height=125),
'thorn_sentinel':profile('stationary','守住根床，放射荆针与横向根墙',[
 A('thorn_ring','荆针轮射','nova',reach=400,shot_count=6,projectile_speed=185,skin='thorn',windup=.85),
 A('thorn_wall','根墙封路','rootline',reach=380,shot_count=3,spacing=90,warning=.8,radius=24,hazard_life=.75,cooldown=4)]),
'pollen_lutist':profile('stationary','拨弦散出缓速花粉，错位落圈',[
 A('pollen_arcs','弦音花粉','fan',reach=440,shot_count=4,spread=.6,projectile_speed=145,skin='pollen',snare=.85,windup=.85),
 A('pollen_spots','错位花粉圈','pool',reach=400,shot_count=2,spacing=105,radius=36,warning=.95,hazard_life=1.5,windup=.7)]),
'thorn_bloom_mote':profile('flight','花心投种，落点生刺；近处吐针',[
 A('bloom_seeds','花种落刺','rootline',reach=340,shot_count=2,spacing=80,targeted=True,warning=.7,radius=25,windup=.7),
 A('bloom_needle','花蕊针','projectile',reach=340,projectile_speed=240,skin='thorn',windup=.5)],hover_height=135),
'obsidian_spearman':profile('ground','长枪平刺与上挑，攻击距离不同',[
 A('obsidian_thrust','黑曜直刺','lunge',reach=240,active=.3,lunge_speed=230,hit_width=172,offset=82,hit_height=42,windup=.6),
 A('obsidian_raise','抬枪截空','melee',reach=120,hit_width=95,hit_height=150,offset_y=-80,windup=.6)]),
'phase_censor':profile('flight','前摇标记位置，闪到侧面投出弯刃',[
 A('censor_blink','侧移弯刃','blink',reach=320,windup=.8,active=.32,blink_offset=115,skin='thorn',projectile_speed=245),
 A('censor_fan','审灯三刃','fan',reach=420,shot_count=3,spread=.42,projectile_speed=200,skin='thorn',windup=.7)],hover_height=80),
'pilgrim_chariot':profile('ground','战车重冲，抛出灰钉形成暂时路障',[
 A('chariot_charge','巡礼战车','lunge',reach=380,windup=.95,active=.65,lunge_speed=350,hit_width=158,recover=1.15),
 A('chariot_caltrops','灰钉阵','pool',reach=380,shot_count=3,spacing=90,radius=28,warning=.8,hazard_life=2.1,windup=.8)],move_speed=40),
'silent_bugbler':profile('stationary','号音扇弹与贴身钟波，不能追击',[
 A('bugle_volley','无声号阵','fan',reach=540,shot_count=5,spread=.6,projectile_speed=250,skin='metal',windup=.95),
 A('bugle_pulse','号口震波','wave',reach=230,shot_count=2,projectile_speed=205,radius=19,windup=.65)]),
'kneeling_crossbowman':profile('stationary','跪姿瞄准后窄幅三连射，瞄准阶段可脱离射线',[
 A('crossbow_burst','锁线三矢','fan',reach=580,shot_count=3,spread=.15,projectile_speed=350,skin='thorn',windup=1),
 A('crossbow_low','贴地重矢','projectile',reach=440,projectile_speed=300,radius=12,skin='thorn',windup=.8)]),
'ash_banner_imp':profile('ground','短身旗枪连击，跃后退刺',[
 A('imp_flurry','旗枪三连','combo',reach=160,windup=.42,active=.55,lunge_speed=95,hit_width=98,recover=.55),
 A('imp_retreat','回旗退刺','retreat',reach=145,windup=.45,active=.3,retreat_speed=165,hit_width=110)]),
'obsidian_bellwheel':profile('ground','钟轮冲身，双向低波逼迫起跳',[
 A('bellwheel_roll','黑钟滚撞','lunge',reach=330,windup=.7,active=.55,lunge_speed=300,hit_width=130),
 A('bellwheel_waves','双向钟涟','wave',reach=390,shot_count=2,projectile_speed=265,radius=19,windup=.82)]),
'echo_waterwheel_knight':profile('ground','回声盾反击，交替快慢波',[
 A('echo_wheel_guard','回声盾反','guard',reach=180,windup=.8,active=.3,hit_width=142,recover=.7),
 A('echo_wheel_wave','快慢双轮波','wave',reach=450,shot_count=4,projectile_speed=190,speed_step=65,windup=.9)],front_guard=True),
'echo_moss_larva':profile('ground','潜壳长扑，迟发回声落点',[
 A('echo_larva_burrow','回声潜扑','lunge',reach=260,windup=.7,active=.42,lunge_speed=290,burrow=True),
 A('echo_larva_mark','迟发苔音','pool',reach=300,radius=39,warning=1.15,hazard_life=.55,windup=.6)]),
'echo_thorn_sentinel':profile('stationary','双环荆针，间隔根刺留下穿行空隙',[
 A('echo_thorn_double','双环荆针','nova',reach=470,shot_count=10,projectile_speed=200,skin='thorn',windup=1),
 A('echo_thorn_roots','间隔根刺','rootline',reach=430,shot_count=4,spacing=92,radius=22,warning=.85,hazard_life=.6,windup=.7)]),
'echo_contract_scribe':profile('flight','悬浮封印师，低位纸页与脚下封圈',[
 A('echo_scribe_pages','冠页斜射','fan',reach=430,shot_count=3,spread=.3,projectile_speed=225,skin='page',windup=.7),
 A('echo_scribe_seals','双落印','pool',reach=420,shot_count=2,spacing=135,radius=30,warning=.9,hazard_life=1.05,windup=.6)],hover_height=75),
'falling_clapper':profile('flight','高悬钟舌先标记俯冲，再放低位钟浪',[
 A('clapper_fall','标记落锤','dive',reach=300,windup=.95,active=.48,recover=1.15),
 A('clapper_wave','钟浪斜射','fan',reach=360,shot_count=3,spread=.52,projectile_speed=210,skin='metal',windup=.75)],hover_height=175,move_speed=35),
'delayed_shadow':profile('flight','闪位后的迟发影刃，位置预警保留到出手',[
 A('shadow_blink','迟影侧刺','blink',reach=370,windup=.95,blink_offset=135,projectile_speed=270,skin='thorn'),
 A('shadow_echo','影落封圈','pool',reach=390,radius=36,warning=1.2,hazard_life=.6,windup=.55)],hover_height=60),
'echo_pilgrim_commander_minor':profile('ground','长枪连段与军旗落阵，攻后停顿明显',[
 A('minor_lances','巡礼三枪','combo',reach=260,windup=.75,active=.7,lunge_speed=175,hit_width=165,offset=83,recover=.95),
 A('minor_banner','军旗落阵','rootline',reach=440,shot_count=4,spacing=88,radius=22,warning=.7,hazard_life=.6,windup=.85)],move_speed=48),
'isotope_lumen':profile('flight','微光环弹与延迟聚光，弹体可以斩回',[
 A('lumen_orbits','光核环弹','nova',reach=380,shot_count=7,projectile_speed=145,skin='light',windup=.8),
 A('lumen_focus','延迟聚光','pool',reach=400,radius=48,warning=1.0,hazard_life=.8,windup=.6)],hover_height=130)
}

def boss(identity,attacks,**kw):
    for a in attacks:
        a['id']='boss_'+a['id'];a['vertical_tolerance']=260;a['damage']=a.get('damage',1)
        a['cooldown']=max(2.7,a['cooldown']);a['desire_cost']=.8
    return profile('ground',identity,attacks,tactical_ai=True,aggro_range=780,leash_radius=9999,
        move_speed=66,preferred_range=145,phase_threshold=.55,attack_desire_threshold=.5,**kw)

PROFILES.update({
'rust_crown_guardian':boss('沉重钟压、低波、孢子；半血后根阵缩窄落脚点',[
 A('moss_scythe','苔镰横扫','melee',reach=210,windup=.68,hit_width=210,hit_height=105,offset=100,recover=.7),
 A('moss_stamp','钟冠重压','wave',reach=620,windup=1.05,shot_count=2,projectile_speed=230,radius=23,animation='heavy',recover=1.05),
 A('moss_spores','守庭孢子','fan',reach=620,windup=.9,shot_count=5,spread=.85,projectile_speed=185,skin='spore',animation='cast',recover=.8),
 A('moss_roots','根冠苏醒','rootline',reach=640,windup=1.1,shot_count=5,spacing=98,warning=.72,radius=25,hazard_life=.55,animation='phase',phase=2,cooldown=5,recover=1.1)],phase_name='根冠苏醒'),
'sunken_hammer_smith':boss('剪口夹击、交叉绯线；半血后跃转剪迫使换边',[
 A('shears_close','合剪夹击','melee',reach=225,windup=.7,hit_width=230,offset=105,hit_height=115,animation='heavy',recover=.8),
 A('shears_thread','绯线封路','beam',reach=650,windup=1.0,beam_length=650,radius=15,hazard_life=.42,animation='cast',recover=.8),
 A('shears_knots','断线结阵','pool',reach=570,windup=.9,shot_count=3,spacing=116,radius=31,warning=.75,hazard_life=1.25,animation='cast'),
 A('shears_turn','跃转双剪','vault',reach=460,windup=.75,active=.85,jump_height=170,lunge_speed=380,hit_width=190,hit_height=140,animation='phase',phase=2,recover=1.05)],phase_name='双剪回旋'),
'saltwhite_contract_judge':boss('架刃反击、长距离突刺；半血后左右连斩',[
 A('mantis_guard','交刃反击','guard',reach=230,windup=.9,active=.32,hit_width=200,offset=95,animation='cast',recover=.72),
 A('mantis_lunge','灰冠长突','lunge',reach=540,windup=.72,active=.52,lunge_speed=440,hit_width=185,offset=90,hit_height=58,recover=.85),
 A('mantis_overhead','冠刃下劈','melee',reach=190,windup=.9,hit_width=155,hit_height=160,offset_y=-60,animation='heavy',recover=1),
 A('mantis_flurry','左右三连斩','combo',reach=430,windup=.7,active=.82,lunge_speed=230,hit_width=190,hit_height=110,animation='phase',phase=2,recover=1.1)],front_guard=True,phase_name='灰冠三连'),
'broken_string_gardener':boss('定点根刺、缓速藤种；半血后交错根墙',[
 A('bishop_staff','根杖敲击','melee',reach=185,windup=.8,hit_width=180,hit_height=125,animation='heavy',recover=.8),
 A('bishop_seeds','藤种布道','fan',reach=680,windup=.95,shot_count=5,spread=.68,projectile_speed=160,skin='pollen',snare=.8,animation='cast'),
 A('bishop_roots','循地根刺','rootline',reach=650,windup=.9,shot_count=4,spacing=110,warning=.68,radius=26,hazard_life=.72,animation='cast'),
 A('bishop_cage','交错根笼','pool',reach=670,windup=1.15,shot_count=4,spacing=120,radius=34,warning=.9,hazard_life=1.6,animation='phase',phase=2,recover=1.2)],phase_name='根笼讲坛'),
'silent_pilgrim_commander':boss('镜刃斜射、侧移影刺；半血后延迟镜池与掠袭',[
 A('bride_crescent','镜杖弧扫','melee',reach=220,windup=.6,hit_width=215,hit_height=100,animation='heavy',recover=.65),
 A('bride_mirror','镜像侧刺','blink',reach=590,windup=.9,blink_offset=155,projectile_speed=290,skin='thorn',animation='cast',recover=.7),
 A('bride_pools','镜池迟影','pool',reach=680,windup=.75,shot_count=3,spacing=135,radius=36,warning=1.2,hazard_life=.65,animation='cast'),
 A('bride_dash','月镜掠袭','vault',reach=500,windup=.65,active=.75,jump_height=130,lunge_speed=410,hit_width=175,hit_height=90,animation='phase',phase=2,recover=.9)],phase_name='镜池重影'),
'silent_crown_core':boss('钥戟压迫、回旋钥阵；半血后冠门封线与轮波',[
 A('key_cleave','百钥重劈','melee',reach=240,windup=.85,hit_width=245,hit_height=130,offset=115,animation='heavy',recover=.9),
 A('key_return','回旋钥阵','fan',reach=680,windup=1.0,shot_count=4,spread=.58,projectile_speed=260,returning=True,skin='key',radius=13,animation='cast'),
 A('key_gate','冠门封线','beam',reach=700,windup=1.15,beam_length=720,radius=18,hazard_life=.42,animation='phase',phase=2,cooldown=4.8,recover=1),
 A('key_rings','钥环震地','wave',reach=680,windup=.95,shot_count=4,projectile_speed=190,speed_step=80,radius=23,animation='phase',phase=2,recover=1.1)],phase_name='冠门审判')
})

def main():
    (DATA/'original_creature_combat.json').write_text(json.dumps(PROFILES,ensure_ascii=False,indent=2)+'\n')
    for path in DATA.rglob('demo*.json'):
        data=json.loads(path.read_text());changed=False
        for actor in data.get('enemy_spawns',[])+([data['boss']] if isinstance(data.get('boss'),dict) else []):
            kind=actor.get('kind','')
            if kind not in PROFILES:continue
            data.setdefault('ai_profiles',{})[kind]=PROFILES[kind]
            actor['locomotion']=PROFILES[kind]['locomotion'];actor['combat_identity']=PROFILES[kind]['combat_identity'];changed=True
        if changed:path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    path=DATA/'original_creature_designs.json';data=json.loads(path.read_text())
    for design in data['designs']:
        design['motion']=PROFILES[design['kind']]['locomotion']
        if design['boss']:design['special_animations']=['heavy','cast','phase']
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('Distinct combat profiles:',len(PROFILES),'attacks:',sum(len(p['attacks']) for p in PROFILES.values()))

if __name__=='__main__':main()
