# 2026-10-24 后续八个 PR 批次

用户要求：前置 #228 进度图、#229 导出审计之外，继续至少八个新的升级 PR，完成一批立即上传。为避免公共 UI／台账的交叉冲突，八个 PR 依序串接，每个相对前一分支只包含本批改动；合并顺序从 1 到 8。所有最终验收项保持 OPEN，子项通过不等于全游戏验收。

| 批次 | 台账方向 | 本批目标 | 状态／证据 |
| --- | --- | --- | --- |
| 1 | U06 改键 | 失焦／离开设置的退路，防止松开扳机误绑定 | 已上传 [#231](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/231)；[报告](report/20261024_u06_remap_lifecycle.md) |
| 2 | E05 构筑 | 八套方案、旧自定义名称、覆盖确认与删除事务 | 已上传 [#232](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/232)；[报告](report/20261024_e05_loadout_management.md) |
| 3 | U04 多层地图 | 已知邻室的上／下／相近高度，区域图与世界图共用 | 已上传 [#233](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/233)；[报告](report/20261024_u04_map_height.md) |
| 4 | U04 图钉 | 查看已知图钉，跨区只切地图，不写进度 | 已上传 [#234](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/234)；[报告](report/20261024_u04_pin_view.md) |
| 5 | U05 旅记 | 键盘／肩键翻页、首尾、会话书签与文本更新退路 | 已上传 [#235](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/235)；[报告](report/20261024_u05_journal_reading.md) |
| 6 | T01 教学 | 四篇手册，读取当前按键／疗伤报价，沿用召回门槛 | 已上传 [#236](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/236)；[报告](report/20261024_t01_field_guide.md) |
| 7 | N03 主角表达 | 已持有八能力的短自述，库存推导，无探索弹窗 | 已上传 [#238](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/238)；[报告](report/20261024_n03_earned_voice.md) |
| 8 | T03／T05 | 冷/暖/立即退出编辑器、工具栏资源所有权、串接分支发布门 | 已上传 [#241](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/241)；[报告](report/20261024_t03_editor_cold_start.md) |

计划允许按已证明缺口调整，不能把已有功能重新开发以凑数。每批记录实际输入、回归结果与未验证边界；远端 CI 和合并状态分别记录。

远端核对（2026-10-24）：第1至7批已合入main；第8批#241已直接面向main。整合当前main仅有三份公共台账重叠，保留双方记录；本批功能文件与并行main改动无重叠。功能提交本地验证结果与整合头远端CI分开，后者运行状态以PR为准。
