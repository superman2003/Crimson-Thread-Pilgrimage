# feat(U05): 长对话全文显示、翻页与阅读位置提示

本轮体验升级第 5/5 项。基于 main `43fbcf888abdf618825b04701a70afb3370dba8c` 独立分支；无需先合入本轮其它 PR。任务编号见标题，46项最终游戏验收保持OPEN。

## 行为

长对话下方增加显示全文、上翻、下翻和逐字/位置百分比。显示全文只更新当前字幕显现量与原计时器，不调用继续交谈、剧情提交、记录或心愿交付；隐藏窗口或无效发言人不能触发全文显示。翻页按可视高度移动并限制在实际滚动范围内，边界按钮禁用，沿用现有键鼠和手柄焦点导航。

## 验证

- 独立代码树 `f1b77875156629ab92cf63224308909608000e70`，Godot 4.6.1 / llvmpipe真实GL执行 `ui_world_integration`，完成标记通过且无SCRIPT ERROR或ERROR。原始日志：[专项日志](../../artifacts/upgrade_20261025c_05/ui_world_integration.log)。
- 五项组合下的 `map_directory`、`ui_world_integration`、`controller_comfort`、`journal_desk` 四套通过；组合版本 `npm test`、`npm run test:campaign` 通过，包含实际导出可达性审计。
- 地图目录、校准窗口与长对话在1280×720渲染取样检查；校准窗口为720×620，差异可滚动，确认按钮可见。
- 直接修改文件的SHA256：[输入清单](../../artifacts/upgrade_20261025c_05/source_sha256.json)。没有降低原套件门禁。

## 边界

布局检查使用显式长文本与发言人夹具；没有用该夹具证明自然剧情通关或奖励流程验收。
