# feat(U05): 46种已击败敌人的预警信号与应对笔记

本轮体验升级第 4/5 项。基于 main `43fbcf888abdf618825b04701a70afb3370dba8c` 独立分支；无需先合入本轮其它 PR。任务编号见标题，46项最终游戏验收保持OPEN。

## 行为

为40种普通敌人和6位首领补全“观察信号”和“应对思路”，依据已有战斗身份编写，原习性文本保留。只在实际击败标志为布尔true后拼入公开旅记，未遭遇名称、未来地点和总数不提前进入页面或搜索。数据校验新增两字段中文内容完整性检查，接入既有campaign命令。

## 验证

- 独立代码树 `81d1cb5be7ae8626a6bb2fd4698f4b4a8f05d831`，Godot 4.6.1 / llvmpipe真实GL执行 `journal_desk`，完成标记通过且无SCRIPT ERROR或ERROR。原始日志：[专项日志](../../artifacts/upgrade_20261025c_04/journal_desk.log)。
- 五项组合下的 `map_directory`、`ui_world_integration`、`controller_comfort`、`journal_desk` 四套通过；组合版本 `npm test`、`npm run test:campaign` 通过，包含实际导出可达性审计。
- 地图目录、校准窗口与长对话在1280×720渲染取样检查；校准窗口为720×620，差异可滚动，确认按钮可见。
- 直接修改文件的SHA256：[输入清单](../../artifacts/upgrade_20261025c_04/source_sha256.json)。没有降低原套件门禁。

## 边界

战术建议未改变敌人行为、伤害和难度；自然遭遇的可读性、建议效果与整体平衡仍需实机体验。

首次独立GL启动触发既有15秒World就绪超时，随后夹具访问未创建玩家产生Nil错误；原日志保留为 `first_attempt.log`。同一代码树、同一命令未改时限重跑通过。该结果不证明所有机器均能在15秒内启动。
