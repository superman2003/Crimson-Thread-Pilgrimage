# 角色动作 v5 出图接入运行时（32 张、67 格）

## 背景

v5 清单（#138，`art_requests/character_motion_v5/`）按 2026-10-19 的 main 重新核对后，列出四类仍有问题的角色帧：

- **E**：铜根主教、苔钟守母、灰冠螳将、绯线执剪者的二阶段出招 4 帧，像素与普通攻击完全相同。
- **F**：6 个 Boss 的重击、施法、二阶段攻击结束后直接跳到同一套通用收招，姿势跳变明显。
- **G**：ash_banner_imp 前摇与待机几乎一样、出招第 1 帧旗色不一致、收招没有过渡；echo_contract_scribe 出招第 4 帧缩成一团；wax_lancer 收招没有过渡。
- **H**：5 张在原始生成时就被裁到边的单帧（含 2 个 NPC）。

32 张源图已交齐并逐张验收（含两轮重画），本批把它们接进游戏。

## 接入方式

新工具 `tools/build_character_motion_v5.py` 只计算登记信息，写入 13 个角色的 `motion_generation.json`；像素仍由 `tools/build_expanded_character_motion.py` 打包进 `motion_runtime.png`。源图字节不改，不生成任何中间帧。

| 组 | 写入方式 |
|---|---|
| E | 取代 `phase` 的 4 格 |
| F | 新动画 `<招式>_bridge`（2 格），播完接通用 `recover` |
| F（铜根主教 heavy、phase） | 新动画 `<招式>_settle`，播完直接接 `idle`（这两张过渡的第 2 格已经站直，而通用收招第 1 格是蹲姿） |
| G | ash_banner_imp 取代 `windup` 4 格与 `attack[0]`，`recover` 前插 2 格；echo_contract_scribe 取代 `attack[3]`；wax_lancer `recover` 前插 2 格 |
| H | 取代对应的那一格 |

- **切格**：按网格切；每格保留所有面积 ≥20 px 的连通块，旗子、缎带等分离部件也会带上。交付时已校验每个轮廓都不跨格。
- **比例**：配对姿势的 alpha 面积平方根之比，对照本批之前的运行时姿势。
  - E 没有同姿势可对：用被取代的 4 格的面积中位数。
  - F 一律对齐它要接上的通用收招第 1 格；招式末格只决定水平锚点（部分 Boss 原有的招式末格本来就画得比收招小）。另用身高交叉核对，18 张中 16 张两种比例相差在 7% 以内；另外两张是铜根主教 phase（过渡第 2 格已站直，与蹲姿的收招本就不同高）和绯线执剪者 heavy（14%）。
  - G：对照被取代或被接上的那一格。
  - H：对照被裁的原帧，以及同一动画的前后两格（原帧缺了一小块轮廓）。
- **水平锚点**：沿用 `build_creature_attack_motion.py` 的做法，alpha 质量列中位数加上配对姿势到骨架原点的偏移。
- **色彩校正**：这批源图普遍比原图饱和（E 组约高 0.09–0.15），绯线执剪者和蜡枪蜂还偏粉。每张源图算一个 HSV 饱和度增益和一组 RGB 三通道增益，对齐它旁边那些姿势的平均色（配对姿势、被取代或被延长的动画，E 组另加二阶段前摇）。打包器新增 `grade` 字段，在缩放前套用；只改颜色，不改轮廓和 alpha。
- **可重建**：校准结果按源图 SHA-256 存进记录，`--check` 只验证不重算。被取代的原条目也记在记录里，重跑前会先还原。要重新校准重交的源图：`--undo` → 打包 → 再跑本工具。

## 引擎改动（`enemy_actor.gd`）

收招沿用前摇“一次性前段 + 后续循环”的机制：

- 招式没有自己的 `<id>_recover` 时，若有 `<动画>_bridge`，先播它 0.18 秒，再接通用 `recover`，并把 `recover` 拉伸到剩余时间；有 `<动画>_settle` 则接 `idle`。
- 收招总长仍由招式数值决定，玩家的惩罚窗口不变。
- `_update_recover` 现在也会推进后续动画。

二阶段转场（血量跌破门槛时播 0.9 秒 `phase`）沿用原规则，所以这 4 个 Boss 的转场画面也换成了新出招；无声王冠、静音巡礼统帅原本就是这样。

## 结果

前后对比图在 `artifacts/character_motion_v5/`，由 `tools/render_character_motion_v5.py` 从打包后的运行时帧按游戏画布排列生成（上排 main，下排本批）。

- 4 个 Boss 的二阶段出招各有 4 格自己的动作。
- 6 个 Boss 共 22 招重击、施法、二阶段攻击的收招都先播 2 格过渡。
- ash_banner_imp 前摇能看出要出招，出招旗色一致，收招多了 2 格过渡；echo_contract_scribe 出招第 4 格不再像受击；wax_lancer 收招多了 2 格过渡。
- 5 张裁边帧补全。

## 验证

以下均在合并 main（含 #139）之后的本分支上执行：

- `npm run test:character-motion`：新增本批登记 `--check`（含“4 个 Boss 的二阶段出招不再重复普通攻击帧”的像素检查），71 个角色的打包重现检查全部通过。
- `npm test`、`npm run test:boss-assets` 通过；recovery-mode 双导入通过。
- `expanded_character_motion`：5052 项全部通过，71 个角色、2828 帧。新增检查：6 个 Boss 共 22 招收招先播 2 格过渡、0.18 秒后接通用收招（或待机），通用收招拉伸到剩余时间。
- 通过的套件：`enemy_ai_behavior`、`boss_trial`、`combat`、`character_art_prewarm`、`silent_crown_experience`、`obsidian_experience`、`greenhouse_experience`。合并 main 之前另跑过 `enemy_lifecycle_regression`、`enemy_effect_lifetime`、`enemy_visibility`、`enemy_encounter_roles`、`melee_recovery`、`combat_resource_cycle`、`all_chapters_demo`、`first_court_experience`、`rain_foundry_experience`、`salt_archive_experience`、`world_enemy_residency`、`world_neighbor_entities`、`seal_combat`，全部通过。
- `enemy_atlas_integrity`：本机用 x11 + llvmpipe 真实显示直接运行，3325 项全部通过（本机没有 Xvfb，运行器本身要求 Xvfb）。

## 仍需目检（OPEN）

- **静音巡礼统帅**：过渡帧的头比原图画得稍大。按身高和面积两种方式都已对齐收招第 1 格，属于画稿比例差异。原有重击末格本身就比其他格小，从末格接到过渡帧时会略微变大。
- **盲钟骑士交谈第 4 格**：按面积（对照被裁原帧和前后两格）对齐后，目测仍比前后格大约 4%，是重画时盾和头的比例略大；只出现在交谈动画的一格。
- **色彩校正**以平均色对齐，局部颜色（如蜡枪蜂披风）仍可能和原图略有差别。
- 连续播放的手感以实机目检为准。
