# V04：契印动作装饰的全局预算

日期：2026-10-20。对应升级台账 V04 的“其它粒子预算”。本批基于 main 2571f891，独立于战具素材 PR #154，不带入该 PR 的改动。

原来每个 SealPresentation 各容纳 8 个动作装饰，多名角色会累加，而且普通装饰与不可格挡提示共用淘汰队列。现在整个 SceneTree 共用 8 个纯动作装饰名额；命中装饰原有的 12 名额仍独立。名额不足只省略装饰，动作、伤害、控制与声音调用继续执行。

不可格挡提示不占装饰名额，普通装饰也不能淘汰仍有效的提示。动作装饰使用绝对 BLADE_Z，不可格挡提示使用绝对 WARNING_Z；父节点的装饰层级不再把它们抬过危险层或压到刀光下面。原来的世界锚点、寿命、减少闪光与音频本地上限保留。

原 seal_presentation 验证保留，并增加多角色同帧饱和、父 Z 偏移、提示保留、所有者与场景退出释放的生产路径检查；combat_visual_budget 继续验证原有命中/闪光/危险层规则。逐套结果见 artifacts/v04_action_trace_budget/verification.json。本批不认证自然混战舒适度和长期帧时间，也不把 V04 整项关闭。

占用：combat_visual_policy.gd、seal_presentation.gd、seal_presentation_validation.gd。本报告作为独立台账补记，合入时可回填 V04，避免与 #154 的共享台账修改冲突。

本地 Godot 4.6.1 真实 GL：seal_presentation 175 项、combat_visual_budget 32 项、player_melee_feedback 112 项、enemy_effect_lifetime 46 项及 seal_combat（原 138＋素材 254）均通过；npm test 通过。
