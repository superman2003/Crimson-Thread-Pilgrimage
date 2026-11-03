# T03：HUD 战斗栏不再每帧重建整份构筑快照

2026-11-02。做 B03 Boss 招式验证时测到章节场景无头运行每帧约 12ms，其中 UI 外壳 `pilgrimage_interface._process` 一项就占 5.3–5.9ms。逐项计时后，绝大部分来自 `_refresh_combat_status`：它每帧调用 `_build_snapshot()`，而 `build_system.get_snapshot()` 会深拷贝全部契印、技能、战具、铭饰、配方目录并重算各槽位族——单次约 4.3–5.5ms。HUD 战斗栏实际只用其中的技能名、战具名与库存、槽位休眠原因。

## 改动

`pilgrimage_interface._combat_snapshot()`：以“构筑系统实例 + `state` 字典内容哈希”为键缓存快照，键不变就复用上一份。快照内容只来自 `state` 与静态目录（技能等级、战具库存、已装备槽、已修复机制、已制作部件都在 `state` 里）；冷却时间本来就直接读 `system.cooldowns`，不经快照，所以秒数仍逐帧更新。哈希本身约 1µs。构筑页、补给规划等其他调用点保持原样，每次仍取新快照。

## 结果（本机无头，固定 60fps，苔钟庭／断弦温室）

| 项 | 修改前 | 修改后 |
|---|---|---|
| `_refresh_combat_status` | 5.5ms／4.3ms | 0.45–0.8ms |
| 整个 HUD `_process` | 5.3ms／5.9ms | 1.1–1.3ms |
| 章节场景每帧 | 12.6ms／11.9ms | 9.2ms／9.5ms |

剩余的 HUD 开销已分散：战术卡片约 0.1ms，阈值刻度、遮挡淡出各约 0.1–0.2ms，治疗状态的主题色覆盖约 0.05ms。

## 验证

`seal_ui` 新增两项：构筑状态不变时 HUD 战斗栏文字不变；用正式 `refund_tool` 改变战具库存后，下一次刷新立即显示新库存（不会因缓存显示旧数）。HUD／构筑相关套件（seal_ui、tactical_readiness、heal_resource_readout、combat_resource_cycle、build_slots_ui、ui_build_accessibility、ui_world_integration、danger_captions 等）复跑结果见 PR。

## 边界

- 数字是无头模式；真实 GL 下还有绘制开销，HUD 节省的约 4ms CPU 在任何渲染方式下都成立，但实际帧率提升需在真机上看。
- 如果以后有代码绕过 `state` 直接改目录（`catalog`）内容，缓存不会察觉；目前目录只在加载时读入。
