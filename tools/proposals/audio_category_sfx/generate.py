#!/usr/bin/env python3
"""Original deterministic S02 synthesis. Standard-library Python; no downloaded audio."""
import argparse, array, hashlib, json, math, random, sys, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
RATE=48000
SOURCE='Original procedural synthesis; tools/proposals/audio_category_sfx/generate.py; no samples, recordings, speech, or model output.'

def specs():
    catalog=json.loads((ROOT/'godot/data/build_catalog.json').read_text())
    out=[]
    def add(id,title,role,duration,mode,freq,event,timing,description,region='global',status='proposed_hook',priority=1):
        out.append(dict(id=id,title=title,region_id=region,role=role,file='wav/'+id+'.wav',loop=False,duration_seconds=duration,sample_rate=RATE,channels=1,recommended_playback_gain_db=-10 if role!='npc_greeting' else -15,description=description,source=SOURCE,license='CC0-1.0',human_listening_review='pending',runtime_mapping=dict(identifier=event,status=status),event_timing=timing,priority=priority,max_voices=1 if role in ['healing','npc_greeting','feedback'] else 2,min_interval_seconds=.45 if role=='npc_greeting' else .08,synthesis=dict(mode=mode,frequency_hz=freq,seed=int.from_bytes(hashlib.sha256(id.encode()).digest()[:8],'big'),fade_in_ms=5,fade_out_ms=25)))
    for crest,freq,mode,desc in [('crimson',520,'thread','纤维捻紧与细线泛音'),('bell',235,'metal','厚铜钟壳与承力低共振'),('salt',840,'glass','盐晶轻擦与干燥玻璃泛音')]:
        for stage,duration in [('started',.76),('completed',.52),('interrupted',.22)]:
            add('heal_'+crest+'_'+stage,catalog['crests'][crest]['name']+'·'+{'started':'疗伤开始','completed':'疗伤成功','interrupted':'疗伤打断'}[stage],'healing',duration,mode if stage!='interrupted' else 'break',freq,'heal_state_changed("'+stage+'") + _crest()=="'+crest+'"','started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。',desc+'；阶段音独立，开始音不预告成功。',status='existing_signal')
    smodes={'cleave':('thread',440),'needle':('glass',1100),'snare':('rattle',660),'ward':('metal',290),'shockwave':('low',95),'crosscut':('double',570)}
    for skill,(mode,freq) in smodes.items():
        add('skill_'+skill+'_cast',catalog['skills'][skill]['name']+'·施放','skill_cast',.32,mode,freq,'skill_cast("'+skill+'")','成功扣能、准备开始时一次；受击取消后不得延迟重播。','施放只表示动作接受，不表示命中。',status='existing_signal')
        hook='player_controller.gd:take_damage blockable/guard_timer branch' if skill=='ward' else ('player_controller.gd:_apply_attack_hits' if skill in ['cleave','crosscut'] else 'player_tool_effect.gd:_physics_process enemy.take_hit / apply_snare')
        add('skill_'+skill+'_hit',catalog['skills'][skill]['name']+('·防御接触' if skill=='ward' else '·命中'),'skill_hit',.40,mode,freq*.74,hook,'确认实际接触后一次；同次攻击多目标合并80ms。','守钟架势为成功挡击提示，不是造成伤害；其余为技能确认层，勿叠加重复敌人细节。' if skill=='ward' else '技能命中确认层；保留旧包对应地区敌人受击主体。')
    for tool,mode,freq in [('shard','metal',340),('mine','rattle',760),('fog','air',420),('lure','bell',610)]:
        add('tool_'+tool+'_use',catalog['tools'][tool]['name']+'·使用','tool_use',.26,mode,freq,'player_controller.gd:cast_tool(payload.id="'+tool+'")','cast_tool返回true且次数提交后一次；失败/退款不播。','手部投掷/布置提示；与生效时点分离。')
        timing={'shard':'落地warning_timer 0.35秒结束、爆发时一次。','mine':'第一次命中并施加绊倒时一次；无目标不播。','fog':'首次施加干扰时一次/实例；不得每物理帧播放。','lure':'执行investigate_lure分支时一次；不按敌人数叠加。'}[tool]
        add('tool_'+tool+'_effect',catalog['tools'][tool]['name']+'·生效','tool_effect',.55,mode if tool!='shard' else 'low',freq*.7,'player_tool_effect.gd:_physics_process id=="'+tool+'"',timing,'铜罐短爆 / 绊线拉紧 / 盐雾散开 / 引诱钟鸣，均为有限单次提示。')
    for key,title,dur,mode,freq in [('jump','起跳',.18,'air',450),('dash','冲刺',.24,'air',240),('land_soft','轻落地',.15,'low',125),('land_hard','重落地',.30,'rattle',110),('pogo','下劈反弹',.25,'thread',420),('wall_grip_attach','攀壁附着',.19,'rattle',820),('hook_latch','钩索挂接',.21,'metal',720),('hook_reel','钩索收卷',.38,'rattle',490),('death_cocoon','死亡结茧',.90,'fall',160),('respawn_weave','恢复织身',.90,'rise',310)]:
        add('player_'+key,title,'movement' if key not in ['death_cocoon','respawn_weave'] else 'death_recovery',dur,mode,freq,key,'沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。','全地区共享；轻重落地分别保留，钩索挂接与收卷独立。',status='existing_audio_key',priority=0 if key in ['death_cocoon','respawn_weave'] else 1)
    feedback=[('purchase','购买成功',.35,'metal',780,'cartography_runtime.gd:purchase result.ok; main_level.gd:perform_build_action transact result.ok','持久化成功后一次，地图与构筑交易共享。','proposed_hook'),('reject','购买/操作拒绝',.20,'double',210,'cartography_runtime.gd:purchase !result.ok; main_level.gd:perform_build_action !result.ok','只有主动提交失败时播；禁用按钮悬停与自动刷新不播。','proposed_hook'),('quest','任务/证词完成',.68,'rise',640,'ui_testimony_complete','证词链集齐既有key；其他任务首次完成需新增hook，不能当作已存在事件。','existing_audio_key'),('shrine_wrap','钟龛安坐',.40,'thread',280,'shrine_wrap','安坐交互接受时一次；不代替回血成功。','existing_audio_key'),('shrine_rest','钟龛恢复',.75,'bell',390,'shrine_rest_ch01..shrine_rest_ch06','完整恢复后一次；六区共享，地区个性由环境层负责。','existing_audio_key'),('pickup','拾取收纳',.23,'glass',980,'pickup','物品收入背包后一次；钱币/布料保留现有变体。','existing_audio_key')]
    for key,title,dur,mode,freq,event,timing,status in feedback:add('feedback_'+key,title,'feedback',dur,mode,freq,event,timing,'共享交互语法；不包含UI移动/展开音，避免与S03重叠。',status=status)
    sellers=json.loads((ROOT/'godot/data/cartography_sellers.json').read_text())
    profiles=[('rattle',355,'齿轮短点、谨慎停顿'),('glass',710,'明亮上扬、两颗水滴'),('glass',920,'干盐页擦、克制三点'),('thread',240,'低木弦拨、缓慢回落'),('low',165,'低沉石质两拍、沉稳'),('bell',465,'空心细钟、长短间隔')]
    for (chapter,seller),(mode,freq,desc) in zip(sellers.items(),profiles):
        region=chapter.split('_')[1]
        add('npc_'+region+'_greeting',seller['npc_id']+'·非语义提示','npc_greeting',.48,mode,freq,'play_npc_voice("'+seller['npc_id']+'", line, profile)','非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。',desc+'；纯器物合成，无录制人声、无字词、无假中文。',region,status='existing_function',priority=2)
    return out

def synth(item):
    p=item['synthesis']; rng=random.Random(p['seed']); n=round(item['duration_seconds']*RATE); f=p['frequency_hz']; mode=p['mode']; values=[]; smooth=0.
    for i in range(n):
        t=i/RATE; u=i/(n-1); noise=rng.uniform(-1,1); smooth=.88*smooth+.12*noise
        phase=2*math.pi*f*t
        if item['id'].endswith('_completed'): phase*=1+.18*u
        if item['role']=='npc_greeting':
            # Each seller has a different beat grouping, without speech formants.
            beat=int(item['region_id'][-1]); phase*=1+(.07 if beat%2 else -.05)*u
        if mode in ['metal','bell','glass']:
            ratios=[1,2.71,4.07] if mode=='metal' else ([1,2.01,3.93] if mode=='bell' else [1,1.61,3.13])
            v=sum(a*math.sin(phase*r)*math.exp(-t*(4+j*4)) for j,(a,r) in enumerate(zip([.65,.24,.11],ratios)))+.10*(noise-smooth)*math.exp(-t*25)
        elif mode in ['thread','air']:
            v=(.6*smooth+.12*(noise-smooth)+(.20 if mode=='thread' else .06)*math.sin(phase*(1+.25*u)))*math.sin(math.pi*u)**.65
        elif mode=='rattle':
            v=(.40*(noise-smooth)+.4*math.sin(phase)+.2*math.sin(phase*2.7))*math.exp(-7*u)*(.35+.65*max(0,math.cos(2*math.pi*23*t))**4)
        elif mode=='low':v=(.8*math.sin(phase*(1-.45*u))+.3*smooth)*math.exp(-7*u)
        elif mode=='break':v=(.6*(noise-smooth)+.3*math.sin(phase*(1-.7*u)))*math.exp(-6*u)
        elif mode=='double':
            v=(.5*math.sin(phase)+.3*(noise-smooth))*(math.exp(-28*t)+(.7*math.exp(-28*(t-.12)) if t>=.12 else 0))
        else:
            sweep=(1+.7*u) if mode=='rise' else (1-.6*u)
            v=(.6*math.sin(phase*sweep)+.22*math.sin(phase*sweep*1.5)+.22*smooth)*math.sin(math.pi*u)**1.4
        if item['id'].endswith('_started'): v*=.18+.82*math.sin(math.pi*u/2)
        if item['role']=='npc_greeting':
            beats={1:3,2:2,3:4,4:2,5:2,6:3}[int(item['region_id'][-1])]
            v*=.12+.88*max(0,math.sin(math.pi*beats*u))**2
        v*=min(1,i/(RATE*.005))**2*min(1,(n-1-i)/(RATE*.025)); values.append(v)
    peak=max(abs(v) for v in values); target=10**(-6/20)
    pcm=array.array('h',(round(v/peak*target*32767) for v in values))
    if sys.byteorder!='little':pcm.byteswap()
    return pcm.tobytes()

def generate(dest):
    items=specs(); (dest/'wav').mkdir(parents=True,exist_ok=True)
    for item in items:
        with wave.open(str(dest/item['file']),'wb') as w:w.setparams((1,2,RATE,0,'NONE','not compressed')); w.writeframes(synth(item))
    manifest=dict(schema_version=1,pack_id='audio_category_sfx',kind='sfx',status='proposal_only_not_runtime_integrated',items=items)
    (dest/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'items':len(items),'wav_bytes':sum(p.stat().st_size for p in (dest/'wav').glob('*.wav'))}))
if __name__=='__main__':
    a=argparse.ArgumentParser(); a.add_argument('--output',type=Path,default=ROOT/'assets/proposals/audio_category_sfx'); generate(a.parse_args().output)
