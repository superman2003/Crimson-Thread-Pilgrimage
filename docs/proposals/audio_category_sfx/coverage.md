# 逐项覆盖表

映射类型：existing_signal / existing_audio_key / existing_function 表示代码中已有标识，不表示本包已接入；proposed_hook 表示代码分支上的未来接入点。

| ID | 名称 | 区域 | 真实标识/分支 | 映射类型 | 时序 |
| --- | --- | --- | --- | --- | --- |
| heal_crimson_started | 缝名契印·疗伤开始 | global | heal_state_changed("started") + _crest()=="crimson" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_crimson_completed | 缝名契印·疗伤成功 | global | heal_state_changed("completed") + _crest()=="crimson" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_crimson_interrupted | 缝名契印·疗伤打断 | global | heal_state_changed("interrupted") + _crest()=="crimson" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_bell_started | 司铸契印·疗伤开始 | global | heal_state_changed("started") + _crest()=="bell" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_bell_completed | 司铸契印·疗伤成功 | global | heal_state_changed("completed") + _crest()=="bell" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_bell_interrupted | 司铸契印·疗伤打断 | global | heal_state_changed("interrupted") + _crest()=="bell" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_salt_started | 校录契印·疗伤开始 | global | heal_state_changed("started") + _crest()=="salt" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_salt_completed | 校录契印·疗伤成功 | global | heal_state_changed("completed") + _crest()=="salt" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| heal_salt_interrupted | 校录契印·疗伤打断 | global | heal_state_changed("interrupted") + _crest()=="salt" | existing_signal | started: 接受并扣能后；completed: 实际回血后；interrupted: 取消时立即替换开始音，禁止尾部成功提示。 |
| skill_cleave_cast | 绯线穿刺·施放 | global | skill_cast("cleave") | existing_signal | 成功扣能、准备开始时一次；受击取消后不得延迟重播。 |
| skill_cleave_hit | 绯线穿刺·命中 | global | player_controller.gd:_apply_attack_hits | proposed_hook | 确认实际接触后一次；同次攻击多目标合并80ms。 |
| skill_needle_cast | 回声针·施放 | global | skill_cast("needle") | existing_signal | 成功扣能、准备开始时一次；受击取消后不得延迟重播。 |
| skill_needle_hit | 回声针·命中 | global | player_tool_effect.gd:_physics_process enemy.take_hit / apply_snare | proposed_hook | 确认实际接触后一次；同次攻击多目标合并80ms。 |
| skill_snare_cast | 盐印缚线·施放 | global | skill_cast("snare") | existing_signal | 成功扣能、准备开始时一次；受击取消后不得延迟重播。 |
| skill_snare_hit | 盐印缚线·命中 | global | player_tool_effect.gd:_physics_process enemy.take_hit / apply_snare | proposed_hook | 确认实际接触后一次；同次攻击多目标合并80ms。 |
| skill_ward_cast | 守钟架势·施放 | global | skill_cast("ward") | existing_signal | 成功扣能、准备开始时一次；受击取消后不得延迟重播。 |
| skill_ward_hit | 守钟架势·防御接触 | global | player_controller.gd:take_damage blockable/guard_timer branch | proposed_hook | 确认实际接触后一次；同次攻击多目标合并80ms。 |
| skill_shockwave_cast | 钟鸣震波·施放 | global | skill_cast("shockwave") | existing_signal | 成功扣能、准备开始时一次；受击取消后不得延迟重播。 |
| skill_shockwave_hit | 钟鸣震波·命中 | global | player_tool_effect.gd:_physics_process enemy.take_hit / apply_snare | proposed_hook | 确认实际接触后一次；同次攻击多目标合并80ms。 |
| skill_crosscut_cast | 断弦回斩·施放 | global | skill_cast("crosscut") | existing_signal | 成功扣能、准备开始时一次；受击取消后不得延迟重播。 |
| skill_crosscut_hit | 断弦回斩·命中 | global | player_controller.gd:_apply_attack_hits | proposed_hook | 确认实际接触后一次；同次攻击多目标合并80ms。 |
| tool_shard_use | 铜铃投罐·使用 | global | player_controller.gd:cast_tool(payload.id="shard") | proposed_hook | cast_tool返回true且次数提交后一次；失败/退款不播。 |
| tool_shard_effect | 铜铃投罐·生效 | global | player_tool_effect.gd:_physics_process id=="shard" | proposed_hook | 落地warning_timer 0.35秒结束、爆发时一次。 |
| tool_mine_use | 绊线钉·使用 | global | player_controller.gd:cast_tool(payload.id="mine") | proposed_hook | cast_tool返回true且次数提交后一次；失败/退款不播。 |
| tool_mine_effect | 绊线钉·生效 | global | player_tool_effect.gd:_physics_process id=="mine" | proposed_hook | 第一次命中并施加绊倒时一次；无目标不播。 |
| tool_fog_use | 盐雾瓶·使用 | global | player_controller.gd:cast_tool(payload.id="fog") | proposed_hook | cast_tool返回true且次数提交后一次；失败/退款不播。 |
| tool_fog_effect | 盐雾瓶·生效 | global | player_tool_effect.gd:_physics_process id=="fog" | proposed_hook | 首次施加干扰时一次/实例；不得每物理帧播放。 |
| tool_lure_use | 回响诱铃·使用 | global | player_controller.gd:cast_tool(payload.id="lure") | proposed_hook | cast_tool返回true且次数提交后一次；失败/退款不播。 |
| tool_lure_effect | 回响诱铃·生效 | global | player_tool_effect.gd:_physics_process id=="lure" | proposed_hook | 执行investigate_lure分支时一次；不按敌人数叠加。 |
| player_jump | 起跳 | global | jump | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_dash | 冲刺 | global | dash | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_land_soft | 轻落地 | global | land_soft | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_land_hard | 重落地 | global | land_hard | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_pogo | 下劈反弹 | global | pogo | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_wall_grip_attach | 攀壁附着 | global | wall_grip_attach | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_hook_latch | 钩索挂接 | global | hook_latch | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_hook_reel | 钩索收卷 | global | hook_reel | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_death_cocoon | 死亡结茧 | global | death_cocoon | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| player_respawn_weave | 恢复织身 | global | respawn_weave | existing_audio_key | 沿用player_controller.gd:_play_sfx对应调用；仅状态跃迁播放。 |
| feedback_purchase | 购买成功 | global | cartography_runtime.gd:purchase result.ok; main_level.gd:perform_build_action transact result.ok | proposed_hook | 持久化成功后一次，地图与构筑交易共享。 |
| feedback_reject | 购买/操作拒绝 | global | cartography_runtime.gd:purchase !result.ok; main_level.gd:perform_build_action !result.ok | proposed_hook | 只有主动提交失败时播；禁用按钮悬停与自动刷新不播。 |
| feedback_quest | 任务/证词完成 | global | ui_testimony_complete | existing_audio_key | 证词链集齐既有key；其他任务首次完成需新增hook，不能当作已存在事件。 |
| feedback_shrine_wrap | 钟龛安坐 | global | shrine_wrap | existing_audio_key | 安坐交互接受时一次；不代替回血成功。 |
| feedback_shrine_rest | 钟龛恢复 | global | shrine_rest_ch01..shrine_rest_ch06 | existing_audio_key | 完整恢复后一次；六区共享，地区个性由环境层负责。 |
| feedback_pickup | 拾取收纳 | global | pickup | existing_audio_key | 物品收入背包后一次；钱币/布料保留现有变体。 |
| npc_ch01_greeting | npc_gear_cartographer·非语义提示 | ch01 | play_npc_voice("npc_gear_cartographer", line, profile) | existing_function | 非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。 |
| npc_ch02_greeting | npc_canal_child·非语义提示 | ch02 | play_npc_voice("npc_canal_child", line, profile) | existing_function | 非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。 |
| npc_ch03_greeting | npc_salt_librarian_ye·非语义提示 | ch03 | play_npc_voice("npc_salt_librarian_ye", line, profile) | existing_function | 非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。 |
| npc_ch04_greeting | npc_old_gardener·非语义提示 | ch04 | play_npc_voice("npc_old_gardener", line, profile) | existing_function | 非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。 |
| npc_ch05_greeting | npc_obsidian_guide·非语义提示 | ch05 | play_npc_voice("npc_obsidian_guide", line, profile) | existing_function | 非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。 |
| npc_ch06_greeting | npc_six_mark_keeper·非语义提示 | ch06 | play_npc_voice("npc_six_mark_keeper", line, profile) | existing_function | 非空对白新开场一次；替换上一问候；禁止逐字重复，关闭对话立刻停止。 |
