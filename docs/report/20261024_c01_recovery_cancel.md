# C01：普攻收招可被跳跃／冲刺取消，代价是欠下的收招仍要还

本批从台账 C01 的“取消有代价”继续（计划原文：命中同步、取消有代价），起点为 main `e632d44d`。所有 46 个任务包的最终验收仍开放。

## 改动前

整次挥针（起手＋判定＋收招，普攻 `attack_1` 0.34 秒、重挥 `attack_2` 0.48 秒）期间跳跃、蹬墙跳、二段跳和冲刺全部被锁，只能以 45% 速度挪动；按下的跳跃与冲刺只能靠 0.12／0.10 秒缓冲在整段结束后才生效。没有任何取消，也就谈不上取消代价。

## 现在的规则

- **承诺段不能取消**：起手与判定帧期间按跳跃或冲刺，挥针照常进行，不会提前离开判定。
- **收招段可以取消**：判定帧结束后，普攻（`attack_1`／`attack_2`，含 `bell` 契印把普攻换成的重挥）的收招可被跳跃、蹬墙跳、二段跳或冲刺立刻打断。判定帧期间缓冲的跳跃／冲刺若仍在缓冲时间内，会在收招一开始生效。
- **代价**：被跳过的收招时间记为 `attack_cancel_lock`，在这段时间内不能再挥针、掷钩或施放线术；期间按下的普攻会留在缓冲里，等欠下的时间还完再出手；重挥的收招（0.13 秒）比 0.10 秒的输入缓冲长，所以欠账期间缓冲会延长到还清为止，不会把这一刀吞掉。因此“挥针→跳跃取消→再挥针”的节奏不会快于原地连挥；能换到的只是位移与躲避。格挡、疗伤和移动不受这把锁影响。
- **不能取消的动作**：掷钩（`hook_throw`）与所有线术保留完整收招。
- HUD 的技能就绪查询在欠收招期间显示“收势”。读档、切区、复活和构筑重算都会清除欠下的收招。

## 验证

- `melee_recovery`：原有 35 项保留，新增 21 项，合计 56 项通过（`--fixed-fps 60`，全部用真实 InputMap 输入）：判定帧按跳跃／冲刺确被读到但不取消；收招按跳跃离地、按冲刺实际位移；欠下的锁不超过剩余收招；锁内普攻停在缓冲、线术被拒且 HUD 显示“收势”；缓冲普攻在还清后出手（含欠账长于输入缓冲的情形）；从第一刀起到第二刀的间隔不短于原挥针时长；掷钩不能取消；重置清锁。
- 反向检查四组，均为行为断言失败：
  - 关闭取消：7 项失败；
  - 取消但不记欠账：4 项失败，其中节奏断言实测 0.300 秒，短于原挥针的 0.340 秒；
  - 判定帧也允许取消：8 项失败。
  - 欠账期间不延长输入缓冲：1 项失败（欠账长于缓冲时这一刀被吞掉）。
- `player_action_buffer` 的“新冲刺替换待处理普攻”探针原把剩余挥针设为 0.08 秒，按新规则已处于收招段，冲刺会立即取消而不再留在缓冲里（1 项失败）。现把探针放回判定帧内（剩余 0.2 秒），保留“最新指令替换”的原意，32 项通过；该探针在旧控制器上会因冲刺要等整刀结束、0.1 秒缓冲先过期而失败，两种规则无法用同一数值兼容，这是本批唯一改动的既有断言。
- 相关套件（runner，`--fixed-fps` 按 runner 列表）：`player_motion_continuity`、`player_melee_feedback`、`spike_pogo`、`combat_resource_cycle`、`ability_movement`、`hero_animation`、`combat`、`player_state_cleanup`、`player_upgrade_regression`、`seal_identity`、`seal_system`、`seal_acceptance`、`skill_branches`、`build_transaction_runtime`、`player_dash_art`、`player_movement_art`、`input_settings_regression`、`world_ability_acquisition` 通过。真实 GL：`seal_combat` 194、`build_slots_ui` 37、`combat_visual_budget` 44、`tool_practice` 98、`player_layered_idle` 212、`melee_recovery` 56、`player_action_buffer` 32，均零 ERROR。`tool_practice` 与 `player_layered_idle` 在 headless 下因需要真实 GL 读回而不出完成标记，GL 下通过。
- 合约测试、`npm test`、`npm run test:campaign` 通过；合并 #226 后的 main 上 `melee_recovery` 与合约测试复跑通过。

## 边界

这是实际输入下的规则与时序验证，不是手感验收；收招长度、缓冲窗口和是否也允许取消掷钩，需要 T04 实机试玩判断。此前 T04 的实际输入回放（`world_*_playback.gd`，不在默认套件中）若在收招中按过跳跃或冲刺，动作时序会与录制时不同，本批未重放。“命中同步”部分（判定帧与六格挥针动画按同一起手／判定／收招边界切换）沿用已有实现，本批未改。
