# feat(U06): 手柄逐轴死区预览、多设备选择与可滚动差异

本轮体验升级第 3/5 项。基于 main `43fbcf888abdf618825b04701a70afb3370dba8c` 独立分支；无需先合入本轮其它 PR。任务编号见标题，46项最终游戏验收保持OPEN。

## 行为

手柄校准窗口增加四轴原始/暂存死区响应图和设备选择，连接变化按设备身份保持选择，断开后清除读数。灰区、原始白点、预估金点和带符号读数共同解释死区。预估采用普通单轴动作的死区缩放，不替代实际改键，也不更改输入；仍由原有确认入口应用设置。差异置于滚动区，窗口保持在720p内。运行时图表脚本使用meter命名，避免现有发布过滤器排除preview文件。

## 验证

- 独立代码树 `56773331e28239896d2930ca2459a29eade228a6`，Godot 4.6.1 / llvmpipe真实GL执行 `controller_comfort`，完成标记通过且无SCRIPT ERROR或ERROR。原始日志：[专项日志](../../artifacts/upgrade_20261025c_03/controller_comfort.log)。
- 五项组合下的 `map_directory`、`ui_world_integration`、`controller_comfort`、`journal_desk` 四套通过；组合版本 `npm test`、`npm run test:campaign` 通过，包含实际导出可达性审计。
- 地图目录、校准窗口与长对话在1280×720渲染取样检查；校准窗口为720×620，差异可滚动，确认按钮可见。
- 直接修改文件的SHA256：[输入清单](../../artifacts/upgrade_20261025c_03/source_sha256.json)。没有降低原套件门禁。

## 边界

本环境没有实体手柄；图形布局用显式合成轴样本检查，不能作为真实漂移、设备兼容性或舒适度结论。
