# 2026-10-25 追加五批升级

用户要求在#242—#251十批之后再新增五个完整PR。按游玩行为成批实施，每批包含实现、状态边界、最终回归与语义负例，验证完立即上传。不自动合并；既有46项最终实机/自然流程验收仍OPEN。

| 批次 | 台账 | 完整范围 | 状态 |
| --- | --- | --- | --- |
| 1 | G02 | 归途结同档提交、现场重试、召回距离/报价复核与死亡暂记 | 已上传 [#252](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/252)；[报告](report/20261025b_01_return_knot.md) |
| 2 | C04/T01 | 真实技能来源、独立施放计数、训练进度、达标持久提交与失败重试 | 已上传 [#253](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/253)；[报告](report/20261025b_02_practice_coach.md) |
| 3 | B04 | 挑战奖励独立候选、胜利待领取凭据、跨重启回钟重试与防重复 | 已上传 [#254](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/254)；[报告](report/20261025b_03_challenge_claims.md) |
| 4 | U04/G01 | 地图/绘针/罗盘报价确认、核价、实际保存后发布与迟到回调隔离 | 本地通过，上传中；[报告](report/20261025b_04_cartographer_trade.md) |
| 5 | A01/N02 | 永久能力/关键物品拾取的单次提交与失败重试 | 待实施 |

实现以当前源码与完成清单的真实缺口为准，已有子项不重复凑数。首批基于#251已验证树，后继暂串接前一分支；上传前检查远端头，保留外部审查修改。
