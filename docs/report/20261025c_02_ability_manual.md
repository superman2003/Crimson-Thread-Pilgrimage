# feat(T01): 八项已获能力操作手册与实时改键说明

本轮体验升级第 2/5 项。基于 main `43fbcf888abdf618825b04701a70afb3370dba8c` 独立分支；无需先合入本轮其它 PR。任务编号见标题，46项最终游戏验收保持OPEN。

## 行为

操作手册在原四条通用说明之外，按真实库存为八项永久能力提供操作、组合键、取消及限制说明。每次打开旅记重新读取当前键鼠/手柄提示；只展示已获得的能力，拒绝布尔、字符串、分数、非有限值与异常库存。保留旧三参数调用兼容和原有已知内容检索边界。

## 验证

- 独立代码树 `dd226508e44ad4a84b246569a161898e451b3f3d`，Godot 4.6.1 / llvmpipe真实GL执行 `ui_world_integration`，完成标记通过且无SCRIPT ERROR或ERROR。原始日志：[专项日志](../../artifacts/upgrade_20261025c_02/ui_world_integration.log)。
- 五项组合下的 `map_directory`、`ui_world_integration`、`controller_comfort`、`journal_desk` 四套通过；组合版本 `npm test`、`npm run test:campaign` 通过，包含实际导出可达性审计。
- 地图目录、校准窗口与长对话在1280×720渲染取样检查；校准窗口为720×620，差异可滚动，确认按钮可见。
- 直接修改文件的SHA256：[输入清单](../../artifacts/upgrade_20261025c_02/source_sha256.json)。没有降低原套件门禁。

## 边界

说明来自现有动作规则；本批未完成陌生玩家理解度、实体手柄操作手感与开启伤害全流程验收。
