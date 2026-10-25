# 2026-10-25：五批完整系统升级

本轮以完整功能包组织，每批包含生产模型、实际菜单/运行时、持久恢复与失败边界、默认回归接入及报告。按下表顺序合并，后批基于前批分支。旧PR不合并、不关闭。

| 批次 | 交付 | PR | 验证 | 报告 |
| --- | --- | --- | --- | --- |
| 1 | 已知任务工作台、三目标HUD、首要排序与逐目标备注 | [#264](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/264) | goal_desk 24 | [报告](report/20261025d_01_goal_desk.md) |
| 2 | 六站行程、勾选排序、恢复、罗盘/能力/单向边约束的邻接参考 | [#267](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/267) | expedition_desk 27 | [报告](report/20261025d_02_expedition_desk.md) |
| 3 | 十二门分阶段训练、实际动作计数、最好成绩与记录重试 | [#274](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/274) | practice_curriculum 22 | [报告](report/20261025d_03_practice_curriculum.md) |
| 4 | 六套设置方案、输入编解码、整套冲突检查与原子分范围应用 | [#275](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/275) | settings_profiles 33 | [报告](report/20261025d_04_settings_profiles.md) |
| 5 | 战斗观察、20次复盘、60条时间线、比较与导出 | [#276](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/276) | combat_ledger 40 | [报告](report/20261025d_05_combat_ledger.md) |

最终还复验真实UI整合、旧输入91项、三契印恢复循环149项；npm与campaign检查通过。设置启动首次超时和早期夹具兼容错误保留在第五批证据中，未降低原门槛。GitHub CI以各PR最新提交检查为准。46项最终游戏验收保持OPEN。
