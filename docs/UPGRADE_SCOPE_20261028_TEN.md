# 2026-10-28 十批升级占用说明

基线：main `a9457669a4a1a08f885c96c95c80a069d059f7ff`（#415 已合入）。选题依据：`docs/SILKSONG_ALIGNMENT_REVISED_PLAN.md`、`docs/UPGRADE_TASK_LEDGER.md` 与 `docs/UPGRADE_COMPLETION_CHECKLIST.md`。2026-10-28 19:00 北京时间附近查询时无开放 PR；该时间仅为本次协调记录，不证明其他 agent 没有未发布工作。

本说明 PR 用于提前公开本轮占用范围，**不计入用户要求的十个功能 PR**。以下工作已在本轮独立工作区实施中，请其他 agent 暂避这些文件；如有已开工重叠，请以各自实际分支内容协调。每个功能 PR 独立面向 main，十批之间不互相继承代码。

| 批次 | 台账对应 | 本轮交付 | 已有生产文件占用 | 新增模块 |
| --- | --- | --- | --- | --- |
| 01 | C02 疗伤与线资源 / B03 守门者与Boss | 已保存战斗复盘的汇总、同地区同契印比较、零时长与缺少分母处理 | `godot/scripts/combat_desk.gd` | `godot/scripts/combat_review_analysis.gd` |
| 02 | T01 首段教学 | 训练分步成绩、失败进度、已保存尝试统计及旧记录兼容 | `godot/scripts/practice_curriculum.gd`、`godot/scripts/practice_desk.gd` | `godot/scripts/practice_attempt_review.gd` |
| 03 | W01 探索路线 / U04 完整地图系统 | 多站行程逐段核对；遵守完整补绘、能力、捷径、单向边与定位条件 | `godot/scripts/expedition_desk.gd` | `godot/scripts/expedition_route_review.gd` |
| 04 | N02 NPC与愿望 | 当前筛选内多份已完成契约统一核对；一次写档领取整批回礼 | `godot/scripts/field_contract_desk.gd` | `godot/scripts/contract_batch_settlement.gd` |
| 05 | G01 三类资源经济 | 按目标库存选择兑换量，确认前核对材料和碎钱余额 | `godot/scripts/material_exchange_desk.gd` | `godot/scripts/exchange_stock_plan.gd` |
| 06 | E04 工匠制作 | 自动分析前阶依赖、循环/异地工匠检查、按独立事务规划多批清单 | `godot/scripts/craft_cart.gd` | `godot/scripts/craft_dependency_plan.gd` |
| 07 | T02 存档迁移 | 三个存档槽及备份的只读总览，回到原确认流程核对操作 | `godot/scripts/save_desk.gd` | `godot/scripts/save_slot_overview.gd` |
| 08 | U03 战斗HUD / U05 旅记与对话 | 追踪HUD显示已公开下一步，统一核对后整理已完成追踪 | `godot/scripts/goal_desk.gd` | `godot/scripts/goal_watchlist_review.gd` |
| 09 | U04 完整地图系统 | 从当前筛选的公开目录生成分区分层出行清单，不导出隐藏坐标或内部ID | `godot/scripts/map_directory_dialog.gd` | `godot/scripts/map_known_checklist.gd` |
| 10 | G01 三类资源经济 / N04 用途与历史 | 资源用途按已知短缺、可用条件、名称与公开描述浏览 | `godot/scripts/resource_purpose_dialog.gd` | `godot/scripts/resource_purpose_browser.gd` |

每批同时独占自己的 `godot/scripts/ledger_20261028_XX_validation.gd`、`tools/run_ledger_20261028_XX.py`、`.github/workflows/ledger-20261028-XX.yml` 与 `docs/report/20261028_XX_*.md`。该命名空间 01–10 留作本轮验证与报告，避免共改全局回归清单。

## 避让边界

不修改 `main_level.gd`、`player_controller.gd`、`enemy_actor.gd`、`pilgrimage_interface.gd`、`build_system.gd`、`world_state.gd`、世界路线/地形生成器、剧情 JSON、音频/美术素材及共享升级台账。继承 #405–#415 的剧情重写，不重复修改叙事。现有单件报价、存档事务、能力门和奖励条件继续是权威来源。

说明 PR 只增加本文件。功能 PR 提交前会再次查询开放 PR 和改动文件；发现实际重叠时先缩小或调整范围。没有查询到的未发表分支无法由 GitHub PR 列表排除，因此这份占用说明用于提前协调。

## 验证与完成标准

每批补充与本次行为相关的原生 Godot 模型/组件边界验证，并如实记录验证范围。自动化模型检查不代替六区自然流程、实体手柄、听感或最终发布包验收；不会据此关闭台账46项最终验收。功能 PR 正式提交，不自动合并或关闭其他 PR。
