# 2026-10-25：五批独立体验升级

五项均基于 main `43fbcf888abdf618825b04701a70afb3370dba8c`，分别以 main 为目标分支，不依赖本轮其它 PR。未合并的改动不计为主线已交付；46项最终游戏验收保持 OPEN。

| PR | 台账任务 | 交付 | 报告 | 独立真实GL验证 |
| --- | --- | --- | --- | --- |
| [#257](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/257) | U04 | 地图目录区域筛选、结果计数与列表确认查看 | [报告](report/20261025c_01_map_regions.md) | `map_directory` |
| [#258](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/258) | T01 | 八项已获能力操作手册与实际改键说明 | [报告](report/20261025c_02_ability_manual.md) | `ui_world_integration` |
| [#259](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/259) | U06 | 手柄四轴死区响应图、多设备选择与差异滚动 | [报告](report/20261025c_03_stick_preview.md) | `controller_comfort` |
| [#260](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/260) | U05 | 46种已击败敌人的观察信号与应对笔记 | [报告](report/20261025c_04_enemy_notes.md) | `journal_desk` |
| [#261](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/261) | U05 | 长对话全文显示、翻页与阅读位置 | [报告](report/20261025c_05_dialogue_reader.md) | `ui_world_integration` |

每项保留直接输入SHA256与专项原始日志，路径见各报告。五项组合的四套专项、`npm test`、`npm run test:campaign` 已通过。地图、校准及长对话在1280×720实际渲染取样核对；手柄图形使用显式合成轴样本，没有实体手柄验收。敌人图鉴首次独立启动触发既有15秒World就绪超时，同一代码和时限重跑通过，首次失败日志也保留。GitHub CI以各PR实际检查状态为准。

第2与第5项修改同一界面的不同函数，其余生产文件各自独立；本轮组合检查包含两者同时存在的代码。没有自动合并、关闭旧PR或改写主线。
