# 活动区普通敌人同实例驻留

日期：2026-10-13。范围：W00b2b 活动区普通敌人的处理/物理/渲染驻留。本批采用同实例停用与恢复；节点、组成员关系、资源和内存仍保持常驻，不声称释放内存或给出帧率提升比例。

普通敌人位于活动摄像机窗口外、并越过带迟滞的保留窗后，服务关闭其 Area2D `monitoring` / `monitorable`，隐藏根 CanvasItem，并禁用该节点继承的处理模式。恢复时按原始 process mode、显隐、碰撞层/掩码与 Area 标记复原。HP、AI 状态、位置和计时状态在暂停期间保持。每个普通帧激活与暂停分别最多处理4个对象；到达视窗内的对象属于区域发布关键工作，在解除加载输入锁前就位。

Boss不加入普通敌人服务。正在死亡、攻击 windup/active 或持有活动攻击效果的普通敌人不会暂停。敌人继续留在 `enemy` group，以兼容世界重置、存档快照与状态清理；普攻、共鸣技、工具/诱饵、反射攻击、盐纹章 HUD/治疗续时和战斗音乐决策会跳过标记为 dormant 的对象。非世界试炼和单章节场景没有驻留元数据，保持原有行为。

`world_enemy_residency` 验证使用正式 World 场景和生产 `_travel_world` / 区域构建器，不通过手工合成敌人节点。最终独立复核为55项、零功能失败：六区各用实际生成敌人的定位夹具验证活动→远离暂停→返回恢复；六区当前服务的 authored/tracked 分别为14/14、15/15、14/14、14/14、14/14、14/14。各区末次样本的 active/suspended/arrival_suspended 分别为 2/12/12、2/13/12、4/10/8、3/11/9、5/9/6、5/9/4。末区快照为14 tracked、5 active、9 suspended。9/14 是指定焦点下的节点计数，不代表全地图平均值、帧时或内存下降。

同一套件另行通过近处AI命令采样、真实玩家普攻扣血、边界迟滞、Boss实例持续AI命令采样、实际普通敌死亡与8碎钱/配置掉落/击杀计数/存档一次性奖励、真实致死伤害至硬复活信号链、准确一半货币惩罚与同地区归途结保存、复活后玩家输入恢复和敌人新一代单实例创建。不是连续自然六区通关；Boss测试证明Boss不受普通敌驻留且AI继续采样，不验证Boss攻击伤害/阶段完整战斗。

到达区域时，发布锁内同步恢复当前视窗敌人并暂停视窗外敌人，确保解锁输入前关键窗口 ready；此批次不受普通帧4/4启停预算限制，可能形成集中CPU工作，不能据此声称没有加载顿帧。普通运行帧仍分别最多启用/暂停4个。候选运行环境为 Godot 4.6.1 stable、Mesa llvmpipe OpenGL 4.5；最终独立复核日志为 `/tmp/enemy-residency-qa-final-clean/world_enemy_residency.log`。命令：

```sh
DISPLAY=127.0.0.1:99 LIBGL_ALWAYS_SOFTWARE=1 \
python3 tools/run_godot_regressions.py \
  --engine /opt/godot-4.6.1/godot \
  --suite world_enemy_residency --timeout 300 --software-gl
```

此前14套邻接回归 runner 零失败。更新到最终到达调度代码后又独立重跑5套并通过：`world_enemy_residency`、`world_interaction_residency`、`world_async_loading`、`world_host`、`world_neighbor_gameplay_live`。14套较宽回归运行在到达调度修订前；其中 `world_async_loading`、`world_host`、`world_neighbor_gameplay_live`、`boss_trial` 和 `seal_acceptance` 出现的 ObjectDB 退出警告未做同场景基线归因。最终独立驻留复跑间歇观察到10个 Ogg 音频相关 ObjectDB RefCounted 泄漏及 orphan SFX StringName；本地一次同版本运行未观察到。未归因，不能归属于驻留服务，也不能声称已解决。没有发现 EnemyActor、MainLevel 或 residency service 的泄漏。

`npm test` 与 `npm run test:campaign` 通过；六区章节、路线、叙事/成长静态审计通过。地图唯一性审计保留已有重复碰撞轮廓警告，未将其作为本批变化处理。

相关 GDScript `--check-only` 与 `git diff --check` 通过。测试夹具退出时释放 World、等待两帧并清理独立进程中的 AudioDirector 静态流缓存；音频退出告警仍间歇出现，未归因。最终复验无脚本/引擎错误。完整项目 CI 与远端 CI 尚未由本地最终提交验证。完整自然六区路线、Boss攻击实战、长时帧率/内存稳定性和 NPC/交互对象驻留仍待验收。
