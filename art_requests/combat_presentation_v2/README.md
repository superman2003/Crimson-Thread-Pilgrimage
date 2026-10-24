# 主角动作特效与 Boss 技能预警出图清单（v2）

2026-10-23 按本地当前源码、主角实际动画清单、六章 Boss 配置和正式 Boss 资源登记核对。**全部 52 张源图已交付并通过基础检查；其中 36 张已登记运行时接入，16 张仍待接入。** 源图交付完成不代表所有技能特效完成。本次补漏与逐招接入见 [Boss 生效特效与预警接入](../boss_execution_v3/README.md)，机器可读进度见 [delivery_status.json](incoming/delivery_status.json)。

新增 **52 张、320 格**：主角 22 张、当前六个 Boss 的 24 招预警 24 张、Boss 专属施法／转阶段蓄势 6 张。每项完整英文提示词在 `prompts/`，结构化数量、布局、引用和真实招式参数在 [requests.json](requests.json)。

## 先纠正上次遗漏

- [v1 攻击特效](../attack_effects_v1/README.md) 的 39 张／288 格已经交付源图，其中敌人弹体、地面陷阱、地波／根刺、光束已由对应 `*_art.gd` 接入。这份 v2 清单补预警、格挡等随身效果；Boss 近战／位移生效特效的 12 张缺项另见 v3，不能以 v2 清单完成冒充全技能完成。
- 主角 `guard` 已有 4 张人物姿势，问题在外层护幕和受击反馈：起手、普通挡击、完美格挡目前复用 `_ability_ring`。本批不重画人物，而是分别补 3 套可辨认的效果；普通挡击不能冒用完美格挡的成功闪光。
- **预警也要素材。** 代码负责位置、方向、范围、遮挡裁切、前摇进度和取消清理；贴图负责材质、轮廓、动画和 Boss 主题。细边界可辅助精确读范围，主体不能仍只是一条线或一个圈。
- 按当前六章真正生成的 Boss 核对，共 24 招。仓库虽有 20 套 Boss 资源，余下 14 套没有在这六章中启用；这里不虚称完成 20 个可战斗 Boss。
- `kind` 是旧内部键，不一定等于人物身份。例如 `sunken_hammer_smith` 当前显示“绯线执剪者”，不能照旧键画锤子；应以所附正式 Boss 概念图为准。

## 通用要求与交付

1. 逐项打开提示词并附上该项列出的参考图，参考图只用于配色、材质与主题；只画特效，不画角色、武器、地板、场景或 UI。主角动画和特效分层，避免左右翻转、不同配装时出现双人物。
2. 真透明 PNG，独立格有透明留白；只有注明横向平铺的钩绳／光束通道可以在左右接边。不得黑底、白底、棋盘格、文字、编号或格线。
3. 6 格使用 3×2，8 格使用 4×2，钩绳 4 格使用 2×2；精确画布尺寸见各自提示词。生成器实际输出尺寸不同，要记录实际切格坐标，不能按期望尺寸盲切。
4. 将选定的原始图放进 `incoming/`，使用清单文件名；当次**实际使用**的提示词同名保存为 `.txt`。另附同名 `.json`，记录原图尺寸、每格 `rect_xyxy`（右下不含）、有效材质范围、锚点、透明通道与检查结论。`prompts/` 是出图前任务提示词，不冒充实际生成记录。
5. 不同效果不能靠纯换色区分。格挡要有护幕／撞凹／针尖反弹差异；六个 Boss 要有苔根、剪线、灰螳刃、铜根、镜池、钥冠的材质差异。
6. 预警首帧就可读，最后一帧仍是预警；中途不消失、不淡到看不见、不把边界越扩越大。到出手时由游戏切换生效素材，被打断、死亡、切区时立即取消。
7. 不能用所有预警都铺圆圈的方式交付。近战按刀势，防御按护刃，远程只提示枪口／施法点；落点、根刺与光束必须使用独立地面／通道素材。
8. 默认警戒色服从游戏的温暖危险提示，再叠各 Boss 材质；色弱下仍凭轮廓识别。主动伤害判定、不可格挡规则与无障碍亮度规则保持由游戏驱动，不能从素材颜色猜规则。

## 接入时必须对齐的范围

- 近战：从实际 `hit_width / hit_height / offset` 和出手方向定位，不能让大刀光自行决定判定。普通挥刀材质沿实测刀根、刀尖贴合，不拉成整个矩形判定框。
- 光束：`enemy_attack_effect.gd` 的起点沿 `heading` 到 `length`，横向半宽 `radius`。`length` 已受墙体截断，按裁切后的值铺材质；不能把贴图拉出墙外。
- 池区：原点在地面附近，但当前命中使用圆心距离 `< radius + 23`（含玩家中心的近似体积），不是一个扁椭圆。贴图的水平实体边界对齐基础半径；垂直范围必须保留清楚的危险薄幕／边界，不能画成看似能安全站进去的细地缝。
- 根刺：当前命中矩形为原点 `(-radius,-92)` 到 `(radius,8)`；预警必须让人读出将向上刺出，不能只缩成脚下一粒点。素材地缝对齐左右 `radius`，竖向危险提示由游戏按真实矩形补足。
- 远程扇射／地波／瞬移／翻越：当前没有完整未来轨迹判定。只画局部蓄力，不凭空画“安全保证”的整条路径或落点圈。
- 主角防御：只保护朝向的一侧；护幕朝向随 `facing` 镜像，不画成全向罩。Q 格挡 0.42 秒，防御技能 `ward` 时长读取技能参数；前 0.14 秒为完美窗口。护幕须持续到防御结束或受击；结算后切普通／完美挡击反馈。
- 帧数不决定时长：预警 6 格按各招 `windup`／每个效果实际 `arm_delay` 的归一化进度取帧，不能统一播放固定半秒；根刺还包含逐个递增延迟。

## 建议出图顺序

先做主角格挡三项 → 六 Boss 的地刺、池区、光束预警 → 其余逐招预警与蓄势 → 主角恢复、位移、战斗、死亡效果。v1 的 39 张可同时安排接入，无需等新图全部完成。

## A. 主角动作特效

1. **格挡起手／护幕** · `FX_H2_guard_raise.png` · 6 格

   - [完整提示词](prompts/FX_H2_guard_raise.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_guard](refs/hero_guard.png)。
   - 触发：`_try_guard; _apply_special_skill defense（ward）`；锚点 `front`，播放方案 `guard`。

2. **普通挡击** · `FX_H2_guard_block.png` · 6 格

   - [完整提示词](prompts/FX_H2_guard_block.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_guard](refs/hero_guard.png)。
   - 触发：`take_damage: blockable and guard_timer; perfect=false`；锚点 `front`，播放方案 `burst`。

3. **完美格挡** · `FX_H2_guard_perfect.png` · 6 格

   - [完整提示词](prompts/FX_H2_guard_perfect.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_guard](refs/hero_guard.png)。
   - 触发：`take_damage: perfect=true（首0.14秒）`；锚点 `front`，播放方案 `burst`。

4. **缝补蓄力** · `FX_H2_heal_channel.png` · 8 格

   - [完整提示词](prompts/FX_H2_heal_channel.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_heal](refs/hero_heal.png)。
   - 触发：`_try_heal; heal_timer; heal_state_changed started`；锚点 `body`，播放方案 `channel`。

5. **缝补完成** · `FX_H2_heal_complete.png` · 6 格

   - [完整提示词](prompts/FX_H2_heal_complete.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_heal](refs/hero_heal.png)。
   - 触发：`_update_heal: successful completion; heal_state_changed`；锚点 `body`，播放方案 `burst`。

6. **缝补被打断** · `FX_H2_heal_interrupt.png` · 6 格

   - [完整提示词](prompts/FX_H2_heal_interrupt.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_heal](refs/hero_heal.png)。
   - 触发：`_interrupt_heal（仅已有缝补时触发）`；锚点 `body`，播放方案 `burst`。

7. **二段跳丝翼** · `FX_H2_double_jump.png` · 6 格

   - [完整提示词](prompts/FX_H2_double_jump.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`_spawn_double_jump_vfx`；锚点 `feet`，播放方案 `burst`。

8. **冲刺收线轨迹** · `FX_H2_dash_ribbon.png` · 6 格

   - [完整提示词](prompts/FX_H2_dash_ribbon.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`_spawn_dash_trail（角色残影继续复用当前角色帧）`；锚点 `center`，播放方案 `burst`。

9. **回声钩头** · `FX_H2_hook_head.png` · 6 格

   - [完整提示词](prompts/FX_H2_hook_head.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_hook_throw](refs/hero_hook_throw.png)。
   - 触发：`_try_start_grapple; _spawn_hook_trail_vfx: HookTipVfx`；锚点 `center`，播放方案 `loop`。

10. **回声钩绳纹理** · `FX_H2_hook_cord.png` · 4 格

   - [完整提示词](prompts/FX_H2_hook_cord.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_hook_throw](refs/hero_hook_throw.png)。
   - 触发：`_try_start_grapple: grapple_line（随真实两端铺纹理）`；锚点 `tile`，播放方案 `tile`。

11. **钩索命中／收回** · `FX_H2_hook_latch.png` · 6 格

   - [完整提示词](prompts/FX_H2_hook_latch.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_hook_throw](refs/hero_hook_throw.png)。
   - 触发：`钩索有效挂接、收回边界；_stop_grapple`；锚点 `center`，播放方案 `burst`。

12. **荆针下砸落地** · `FX_H2_downstrike.png` · 6 格

   - [完整提示词](prompts/FX_H2_downstrike.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`thorn_downstrike: traversal_downstrike_active 落地分支`；锚点 `ground`，播放方案 `burst`。

13. **灯相进入／维持／退出** · `FX_H2_phase.png` · 8 格

   - [完整提示词](prompts/FX_H2_phase.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_phase](refs/hero_phase.png)。
   - 触发：`_update_phase; phase_active; _stop_phase`；锚点 `body`，播放方案 `phase`。

14. **王冠共鸣** · `FX_H2_resonance.png` · 8 格

   - [完整提示词](prompts/FX_H2_resonance.txt)；参考：[hero_idle](refs/hero_idle.png)、[hero_resonance](refs/hero_resonance.png)。
   - 触发：`_try_resonance; _apply_special_skill: resonance`；锚点 `body`，播放方案 `channel`。

15. **技能重斩／交叉斩** · `FX_H2_skill_slash.png` · 6 格

   - [完整提示词](prompts/FX_H2_skill_slash.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`_spawn_skill_slash_vfx; cleave/crosscut 的有效帧`；锚点 `center`，播放方案 `burst`。

16. **受伤断线** · `FX_H2_hurt_snap.png` · 6 格

   - [完整提示词](prompts/FX_H2_hurt_snap.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`_spawn_thread_snap_vfx`；锚点 `body`，播放方案 `burst`。

17. **落地尘絮** · `FX_H2_land.png` · 6 格

   - [完整提示词](prompts/FX_H2_land.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`_spawn_land_vfx（轻重落地可调数量与缩放）`；锚点 `ground`，播放方案 `burst`。

18. **蹬墙／攀附擦丝** · `FX_H2_wall_grip.png` · 6 格

   - [完整提示词](prompts/FX_H2_wall_grip.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`wall_sliding 进入、蹬墙离开；silk_wall_grip`；锚点 `contact`，播放方案 `burst`。

19. **死亡散线** · `FX_H2_death_unweave.png` · 8 格

   - [完整提示词](prompts/FX_H2_death_unweave.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`take_damage: hp<=0; death_timer（保留角色死亡姿势）`；锚点 `body`，播放方案 `phase`。

20. **复活织回** · `FX_H2_respawn_weave.png` · 8 格

   - [完整提示词](prompts/FX_H2_respawn_weave.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`respawn_reveal_timer; _set_death_visibility`；锚点 `body`，播放方案 `phase`。

21. **普通挥刀材质** · `FX_H2_blade_trace.png` · 6 格

   - [完整提示词](prompts/FX_H2_blade_trace.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`player_melee_feedback.gd: spawn_swing（沿实测刀根／刀尖贴合）`；锚点 `center`，播放方案 `burst`。

22. **近战命中碎屑** · `FX_H2_hit_spark.png` · 6 格

   - [完整提示词](prompts/FX_H2_hit_spark.txt)；参考：[hero_idle](refs/hero_idle.png)。
   - 触发：`player_melee_feedback.gd: spawn_hit; enemy_actor.gd: HitSpark`；锚点 `contact`，播放方案 `burst`。

主角持续方案：格挡 1–2 起手、3–4 持守、5–6 收回；缝补／共鸣 1–2 聚起、3–6 循环、7–8 收束；灯相 1–2 进入、3–6 可循环、7–8 退出。死亡与复活 8 格顺播，禁止将其当循环。钩绳和钩头为可循环材质。所有循环在状态取消时立即终止；缝补被打断只能播断线，不能继续播完成。

## B. 六个 Boss 逐招预警

### 苔钟守母 · `rust_crown_guardian`

配置：`godot/data/demo_ch01_boss_trial.json`。参考正式登记：`res://assets/sprites/bosses/boss_01_moss_bell_matriarch/manifest.json`。

- **苔镰横扫** · `boss_moss_scythe` · `melee`

  素材 `FX_T_moss_scythe.png`，6 格，[完整提示词](prompts/FX_T_moss_scythe.txt)，[角色参考](refs/rust_crown_guardian.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.68`，`active=0.24`，`recover=0.7`，`hit_width=210`，`hit_height=105`，`offset=100`。

- **钟冠重压** · `boss_moss_stamp` · `wave`

  素材 `FX_T_moss_stamp.png`，6 格，[完整提示词](prompts/FX_T_moss_stamp.txt)，[角色参考](refs/rust_crown_guardian.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=1.05`，`active=0.24`，`recover=1.05`，`radius=23`，`hit_width=90`，`hit_height=70`，`offset=48`，`shot_count=2`，`projectile_speed=230`。

- **守庭孢子** · `boss_moss_spores` · `fan`

  素材 `FX_T_moss_spores.png`，6 格，[完整提示词](prompts/FX_T_moss_spores.txt)，[角色参考](refs/rust_crown_guardian.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=0.9`，`active=0.24`，`recover=0.8`，`hit_width=90`，`hit_height=70`，`offset=48`，`shot_count=5`，`spread=0.85`，`projectile_speed=185`。

- **根冠苏醒** · `boss_moss_roots` · `rootline`

  素材 `FX_T_moss_roots.png`，6 格，[完整提示词](prompts/FX_T_moss_roots.txt)，[角色参考](refs/rust_crown_guardian.png)。

  用途：**逐点根刺地缝**。当前参数：`windup=1.1`，`active=0.24`，`recover=1.1`，`phase=2`，`radius=25`，`hit_width=90`，`hit_height=70`，`offset=48`，`warning=0.72`，`shot_count=5`，`spacing=98`，`hazard_life=0.55`。

- **通用施法／转阶段蓄势** · `FX_C_rust_crown_guardian.png`，6 格，[完整提示词](prompts/FX_C_rust_crown_guardian.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。

### 绯线执剪者 · `sunken_hammer_smith`

配置：`godot/data/demo_ch02_rain_foundry_canal.json`。参考正式登记：`res://assets/sprites/bosses/boss_02_crimson_thread_scissor_apostle/manifest.json`。

- **合剪夹击** · `boss_shears_close` · `melee`

  素材 `FX_T_shears_close.png`，6 格，[完整提示词](prompts/FX_T_shears_close.txt)，[角色参考](refs/sunken_hammer_smith.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.7`，`active=0.24`，`recover=0.8`，`hit_width=230`，`hit_height=115`，`offset=105`。

- **绯线封路** · `boss_shears_thread` · `beam`

  素材 `FX_T_shears_thread.png`，6 格，[完整提示词](prompts/FX_T_shears_thread.txt)，[角色参考](refs/sunken_hammer_smith.png)。

  用途：**真实光束通道**。当前参数：`windup=1.0`，`active=0.24`，`recover=0.8`，`radius=15`，`hit_width=90`，`hit_height=70`，`offset=48`，`beam_length=650`，`hazard_life=0.42`。

- **断线结阵** · `boss_shears_knots` · `pool`

  素材 `FX_T_shears_knots.png`，6 格，[完整提示词](prompts/FX_T_shears_knots.txt)，[角色参考](refs/sunken_hammer_smith.png)。

  用途：**真实危险池区**。当前参数：`windup=0.9`，`active=0.24`，`recover=0.5`，`radius=31`，`hit_width=90`，`hit_height=70`，`offset=48`，`warning=0.75`，`shot_count=3`，`spacing=116`，`hazard_life=1.25`。

- **跃转双剪** · `boss_shears_turn` · `vault`

  素材 `FX_T_shears_turn.png`，6 格，[完整提示词](prompts/FX_T_shears_turn.txt)，[角色参考](refs/sunken_hammer_smith.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=0.75`，`active=0.85`，`recover=1.05`，`phase=2`，`hit_width=190`，`hit_height=140`，`offset=48`。

- **通用施法／转阶段蓄势** · `FX_C_sunken_hammer_smith.png`，6 格，[完整提示词](prompts/FX_C_sunken_hammer_smith.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。

### 灰冠螳将 · `saltwhite_contract_judge`

配置：`godot/data/demo_ch03_saltwhite_archive.json`。参考正式登记：`res://assets/sprites/bosses/boss_03_ash_crowned_mantis_warlord/manifest.json`。

- **交刃反击** · `boss_mantis_guard` · `guard`

  素材 `FX_T_mantis_guard.png`，6 格，[完整提示词](prompts/FX_T_mantis_guard.txt)，[角色参考](refs/saltwhite_contract_judge.png)。

  用途：**前侧防御**。当前参数：`windup=0.9`，`active=0.32`，`recover=0.72`，`hit_width=200`，`hit_height=70`，`offset=95`。

- **灰冠长突** · `boss_mantis_lunge` · `lunge`

  素材 `FX_T_mantis_lunge.png`，6 格，[完整提示词](prompts/FX_T_mantis_lunge.txt)，[角色参考](refs/saltwhite_contract_judge.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.72`，`active=0.52`，`recover=0.85`，`hit_width=185`，`hit_height=58`，`offset=90`。

- **冠刃下劈** · `boss_mantis_overhead` · `melee`

  素材 `FX_T_mantis_overhead.png`，6 格，[完整提示词](prompts/FX_T_mantis_overhead.txt)，[角色参考](refs/saltwhite_contract_judge.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.9`，`active=0.24`，`recover=1`，`hit_width=155`，`hit_height=160`，`offset=48`。

- **左右三连斩** · `boss_mantis_flurry` · `combo`

  素材 `FX_T_mantis_flurry.png`，6 格，[完整提示词](prompts/FX_T_mantis_flurry.txt)，[角色参考](refs/saltwhite_contract_judge.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.7`，`active=0.82`，`recover=1.1`，`phase=2`，`hit_width=190`，`hit_height=110`，`offset=48`。

- **通用施法／转阶段蓄势** · `FX_C_saltwhite_contract_judge.png`，6 格，[完整提示词](prompts/FX_C_saltwhite_contract_judge.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。

### 铜根主教 · `broken_string_gardener`

配置：`godot/data/demo_ch04_broken_string_greenhouse.json`。参考正式登记：`res://assets/sprites/bosses/boss_04_copperroot_bishop/manifest.json`。

- **根杖敲击** · `boss_bishop_staff` · `melee`

  素材 `FX_T_bishop_staff.png`，6 格，[完整提示词](prompts/FX_T_bishop_staff.txt)，[角色参考](refs/broken_string_gardener.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.8`，`active=0.24`，`recover=0.8`，`hit_width=180`，`hit_height=125`，`offset=48`。

- **藤种布道** · `boss_bishop_seeds` · `fan`

  素材 `FX_T_bishop_seeds.png`，6 格，[完整提示词](prompts/FX_T_bishop_seeds.txt)，[角色参考](refs/broken_string_gardener.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=0.95`，`active=0.24`，`recover=0.5`，`hit_width=90`，`hit_height=70`，`offset=48`，`shot_count=5`，`spread=0.68`，`projectile_speed=160`。

- **循地根刺** · `boss_bishop_roots` · `rootline`

  素材 `FX_T_bishop_roots.png`，6 格，[完整提示词](prompts/FX_T_bishop_roots.txt)，[角色参考](refs/broken_string_gardener.png)。

  用途：**逐点根刺地缝**。当前参数：`windup=0.9`，`active=0.24`，`recover=0.5`，`radius=26`，`hit_width=90`，`hit_height=70`，`offset=48`，`warning=0.68`，`shot_count=4`，`spacing=110`，`hazard_life=0.72`。

- **交错根笼** · `boss_bishop_cage` · `pool`

  素材 `FX_T_bishop_cage.png`，6 格，[完整提示词](prompts/FX_T_bishop_cage.txt)，[角色参考](refs/broken_string_gardener.png)。

  用途：**真实危险池区**。当前参数：`windup=1.15`，`active=0.24`，`recover=1.2`，`phase=2`，`radius=34`，`hit_width=90`，`hit_height=70`，`offset=48`，`warning=0.9`，`shot_count=4`，`spacing=120`，`hazard_life=1.6`。

- **通用施法／转阶段蓄势** · `FX_C_broken_string_gardener.png`，6 格，[完整提示词](prompts/FX_C_broken_string_gardener.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。

### 镜池新娘 · `silent_pilgrim_commander`

配置：`godot/data/demo_ch05_obsidian_pilgrim_road.json`。参考正式登记：`res://assets/sprites/bosses/boss_05_mirrorpool_bride/manifest.json`。

- **镜杖弧扫** · `boss_bride_crescent` · `melee`

  素材 `FX_T_bride_crescent.png`，6 格，[完整提示词](prompts/FX_T_bride_crescent.txt)，[角色参考](refs/silent_pilgrim_commander.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.6`，`active=0.24`，`recover=0.65`，`hit_width=215`，`hit_height=100`，`offset=48`。

- **镜像侧刺** · `boss_bride_mirror` · `blink`

  素材 `FX_T_bride_mirror.png`，6 格，[完整提示词](prompts/FX_T_bride_mirror.txt)，[角色参考](refs/silent_pilgrim_commander.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=0.9`，`active=0.24`，`recover=0.7`，`hit_width=90`，`hit_height=70`，`offset=48`，`projectile_speed=290`。

- **镜池迟影** · `boss_bride_pools` · `pool`

  素材 `FX_T_bride_pools.png`，6 格，[完整提示词](prompts/FX_T_bride_pools.txt)，[角色参考](refs/silent_pilgrim_commander.png)。

  用途：**真实危险池区**。当前参数：`windup=0.75`，`active=0.24`，`recover=0.5`，`radius=36`，`hit_width=90`，`hit_height=70`，`offset=48`，`warning=1.2`，`shot_count=3`，`spacing=135`，`hazard_life=0.65`。

- **月镜掠袭** · `boss_bride_dash` · `vault`

  素材 `FX_T_bride_dash.png`，6 格，[完整提示词](prompts/FX_T_bride_dash.txt)，[角色参考](refs/silent_pilgrim_commander.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=0.65`，`active=0.75`，`recover=0.9`，`phase=2`，`hit_width=175`，`hit_height=90`，`offset=48`。

- **通用施法／转阶段蓄势** · `FX_C_silent_pilgrim_commander.png`，6 格，[完整提示词](prompts/FX_C_silent_pilgrim_commander.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。

### 百钥看门人 · `silent_crown_core`

配置：`godot/data/demo_ch06_silent_crown_core.json`。参考正式登记：`res://assets/sprites/bosses/boss_06_hundred_key_gatekeeper/manifest.json`。

- **百钥重劈** · `boss_key_cleave` · `melee`

  素材 `FX_T_key_cleave.png`，6 格，[完整提示词](prompts/FX_T_key_cleave.txt)，[角色参考](refs/silent_crown_core.png)。

  用途：**刀势／出手方向**。当前参数：`windup=0.85`，`active=0.24`，`recover=0.9`，`hit_width=245`，`hit_height=130`，`offset=115`。

- **回旋钥阵** · `boss_key_return` · `fan`

  素材 `FX_T_key_return.png`，6 格，[完整提示词](prompts/FX_T_key_return.txt)，[角色参考](refs/silent_crown_core.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=1.0`，`active=0.24`，`recover=0.5`，`radius=13`，`hit_width=90`，`hit_height=70`，`offset=48`，`shot_count=4`，`spread=0.58`，`projectile_speed=260`。

- **冠门封线** · `boss_key_gate` · `beam`

  素材 `FX_T_key_gate.png`，6 格，[完整提示词](prompts/FX_T_key_gate.txt)，[角色参考](refs/silent_crown_core.png)。

  用途：**真实光束通道**。当前参数：`windup=1.15`，`active=0.24`，`recover=1`，`phase=2`，`radius=18`，`hit_width=90`，`hit_height=70`，`offset=48`，`beam_length=720`，`hazard_life=0.42`。

- **钥环震地** · `boss_key_rings` · `wave`

  素材 `FX_T_key_rings.png`，6 格，[完整提示词](prompts/FX_T_key_rings.txt)，[角色参考](refs/silent_crown_core.png)。

  用途：**施法点局部蓄力**。当前参数：`windup=0.95`，`active=0.24`，`recover=1.1`，`phase=2`，`radius=23`，`hit_width=90`，`hit_height=70`，`offset=48`，`shot_count=4`，`projectile_speed=190`。

- **通用施法／转阶段蓄势** · `FX_C_silent_crown_core.png`，6 格，[完整提示词](prompts/FX_C_silent_crown_core.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。

## 状态与验收

- 本目录 `needs_generation` 代表尚未出图；`source_saved_pending_review` 代表已保存、待检查；`source_reviewed_runtime_pending` 代表源图基础检查通过、仍待接入；`runtime_connected` 代表运行时清单登记的源图哈希相符，实机与回归结果见 v3 文档。v1 源图有独立交付状态；各批互不覆盖。
- 出图验收：逐格清点、有真 alpha、无串格、材质有可见变化、固定锚点与大小。预警不得混入生效格；缩到真实游戏尺寸后仍能凭材质分辨，深浅背景都可读。
- 接入验收：分别截格挡起手／普通挡击／完美格挡；六 Boss 每招至少取起始预警、临出手、生效、取消四状态，并叠真实判定核对。确认切区／死亡／打断会清掉随身和地面预警，暂停／UI 锁定时不偷跑播放。
- 源图交付与基础检查独立记录，未执行游戏运行时验收；不得把提示词或源图数量当作游戏视觉已经修复。

## 源码定位与复核

- `godot/scripts/player_controller.gd:1081` — `_try_guard`
- `godot/scripts/player_controller.gd:1170` — `_ability_ring`
- `godot/scripts/player_controller.gd:1938` — `_spawn_heal_effect`
- `godot/scripts/player_controller.gd:2114` — `take_damage`
- `godot/scripts/enemy_actor.gd:161` — `_spawn_command_effects`
- `godot/scripts/enemy_actor.gd:1837` — `_show_telegraph`
- `godot/scripts/enemy_actor.gd:2488` — `_original_attack_arc`
- `godot/scripts/enemy_attack_effect.gd:151` — `_draw`
- `godot/scripts/enemy_attack_effect.gd:142` — `_hits_player`

在仓库根目录运行 `python -X utf8 art_requests/combat_presentation_v2/build_list.py --check`，核对 24 招完整覆盖、参考文件与已生成清单／提示词无漂移。不带 `--check` 可按当前配置重新生成本目录；不会修改运行时代码或替换 `incoming/` 原始图。
