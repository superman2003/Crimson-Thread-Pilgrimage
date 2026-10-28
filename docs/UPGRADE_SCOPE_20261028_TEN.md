# 2026-10-28 十批升级占用说明

基线：main `a9457669a4a1a08f885c96c95c80a069d059f7ff`（#415 已合入）。选题依据：`docs/SILKSONG_ALIGNMENT_REVISED_PLAN.md`、`docs/UPGRADE_TASK_LEDGER.md` 与 `docs/UPGRADE_COMPLETION_CHECKLIST.md`。2026-10-28 本轮查询时无开放 PR；该时间仅为本次协调记录，不证明其他 agent 没有未发布工作。

本说明 PR 用于提前公开本轮占用范围，**不计入用户要求的十个功能 PR**。以下十批已提交正式 PR（交付链接见文末），请其他 agent 暂避这些文件；如有已开工重叠，请以各自实际分支内容协调。每个功能 PR 独立面向 main，十批之间不互相继承代码。

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

旧隔离运行器需要随新增依赖同步登记：批次02占用 `tools/run_practice_review_contract.py`，批次04占用 `tools/run_field_contract_browser_contract.py`，批次05占用 `tools/run_material_exchange_maximum_contract.py`，批次07占用 `tools/run_save_backup_difference_contract.py`。这四个文件各自只补本批模块到既有复制列表，不改原断言、超时或诊断门禁。

每批同时独占自己的 `godot/scripts/ledger_20261028_XX_validation.gd`、`tools/run_ledger_20261028_XX.py`、`.github/workflows/ledger-20261028-XX.yml` 与 `docs/report/20261028_XX_*.md`。该命名空间 01–10 留作本轮验证与报告，避免共改全局回归清单。

## 避让边界

不修改 `main_level.gd`、`player_controller.gd`、`enemy_actor.gd`、`pilgrimage_interface.gd`、`build_system.gd`、`world_state.gd`、世界路线/地形生成器、剧情 JSON、音频/美术素材及共享升级台账。继承 #405–#415 的剧情重写，不重复修改叙事。现有单件报价、存档事务、能力门和奖励条件继续是权威来源。

说明 PR 只增加本文件。功能 PR 提交前会再次查询开放 PR 和改动文件；发现实际重叠时先缩小或调整范围。没有查询到的未发表分支无法由 GitHub PR 列表排除，因此这份占用说明用于提前协调。

## 验证与完成标准

每批补充与本次行为相关的原生 Godot 模型/组件边界验证，并如实记录验证范围。自动化模型检查不代替六区自然流程、实体手柄、听感或最终发布包验收；不会据此关闭台账46项最终验收。功能 PR 正式提交，不自动合并或关闭其他 PR。

## 已提交的十个功能 PR

十批均为正式 PR，分别独立面向 main，无互相继承依赖。提交后核对各 PR 当前头：实际变更文件与认领一致、GitHub mergeable 为 true；与当前另九个开放 PR 没有文件交集。该状态为本次核对快照，后续改动须再次检查。

| 批次 | 功能 PR | 本批原生检查 |
| --- | --- | --- |
| 01 | [#424 C02/B03：战斗复盘汇总与同构筑观察比较](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/424) | 21 项通过 |
| 02 | [#425 T01：训练分步成绩与失败进度回看](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/425) | 24 项通过 |
| 03 | [#426 W01/U04：多站行程逐段核对已知道路](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/426) | 15 项通过 |
| 04 | [#428 N02：已完成契约整批核对与原子领取](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/428) | 21 项通过 |
| 05 | [#429 G01：按目标库存规划兑换并核对收支](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/429) | 19 项通过 |
| 06 | [#430 E04：制作前阶依赖检查与分批清单](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/430) | 18 项通过 |
| 07 | [#431 T02：三个存档槽与备份的只读总览](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/431) | 19 项通过 |
| 08 | [#432 U03/U05：公开下一步提示与完成追踪整理](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/432) | 15 项通过 |
| 09 | [#434 U04：按分区分层生成已知地图出行清单](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/434) | 18 项通过 |
| 10 | [#435 G01/N04：已知资源短缺与用途浏览](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/435) | 20 项通过 |

本轮新增原生检查190项、四组既有定向回归84项，共274项通过。各批采用 main a945766 加本批文件的独立副本验证，未借用其它九批改动。远端 Actions 仍在排队，未宣称 CI 或最终发行验收完成。未合并或关闭这些 PR。本说明 PR 仍不计入十个功能 PR。
