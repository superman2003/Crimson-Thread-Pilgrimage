# 2026-10-25 后续十个完整升级批次

按用户最新要求：前置#241冲突修复之后再新增十个PR。相关功能、输入边界和验证合成一个完整批次，不按单个按钮拆PR。每批验证完立即上传；下表仅在实际完成后填PR链接。原46项最终游戏验收保持OPEN，组件/自动验证不等于自然流程或人工体验。

| 批次 | 台账 | 完整批次范围 | 状态 |
| --- | --- | --- | --- |
| 1 | E02/E05 | 数量购物清单、优先顺序、部分报价、二次核价和持久事务 | 已上传 [#242](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/242)；[报告](report/20261025_01_resupply_planner.md) |
| 2 | E05 | 重命名、深拷贝、实际槽位/战斗数值差异、源变化复核和持久事务 | 已上传 [#243](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/243)；[报告](report/20261025_02_loadout_workbench.md) |
| 3 | U05 | 公开文字检索、交集筛选、排序、内容版本未读、槽隔离收藏和输入生命周期 | 已上传 [#244](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/244)；[报告](report/20261025_03_journal_desk.md) |
| 4 | U06 | 摇杆校准、设备读数、预设预览确认、范围恢复和偏好同步 | 已上传 [#245](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/245)；[报告](report/20261025_04_controller_comfort.md) |
| 5 | U04 | 已补绘地点/标记目录、检索、分段框取、端点保密和弹窗输入闭环 | 已上传 [#246](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/246)；[报告](report/20261025_05_map_directory.md) |
| 6 | S02/S03 | NPC空间拟声、近邻轮询、危险退让、叠加混音、独立开关与退役 | 已上传 [#247](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/247)；[报告](report/20261025_06_audio_landmarks.md) |
| 7 | N02 | 已知心愿交付报价、成本/回礼与容量预览、状态复核、原子确认和弹窗输入闭环 | 已上传 [#248](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/248)；[报告](report/20261025_07_wish_preview.md) |
| 8 | E04 | 同工匠多件清单、合计成本、全单模拟、价格复核、两步确认与单次持久事务 | 已上传 [#249](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/249)；[报告](report/20261025_08_craft_cart.md) |
| 9 | T02 | 主档/备份状态、实际当前路径、切换/恢复预览、文件复核、保存失败留场与原档保留 | 已上传 [#250](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/250)；[报告](report/20261025_09_save_desk.md) |
| 10 | W05/T04 | 实体升降方向/耗时/呼叫状态、实时按键、界面暂停、载人防穿顶与六区整合 | 本地通过；[报告](report/20261025_10_lift_service.md)，上传中 |

范围会根据代码与台账中已证明的缺口调整，已有子项不重复开发凑数。各PR暂依前一分支串接，前项合入main后再核对基分支与冲突；不自动合并。
