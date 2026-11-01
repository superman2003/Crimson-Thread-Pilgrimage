# feat(U04): 已知地图目录区域筛选、计数与快捷查看

本轮体验升级第 1/5 项。基于 main `43fbcf888abdf618825b04701a70afb3370dba8c` 独立分支；无需先合入本轮其它 PR。任务编号见标题，46项最终游戏验收保持OPEN。

## 行为

地图目录新增已知区域筛选，与文字、类型筛选取交集；显示结果数量，保留仍可见的选中身份。搜索确认后可聚焦列表，列表确认/双击查看地点。清空搜索按钮立即刷新，空结果禁用查看。区域选项只从已购且已补绘的目录行生成，沿用实际知识重验与仅移动地图视野的运行时入口。

## 验证

- 独立代码树 `b2ec04593f4a4708eb1d14acdf92138700f21ed6`，Godot 4.6.1 / llvmpipe真实GL执行 `map_directory`，完成标记通过且无SCRIPT ERROR或ERROR。原始日志：[专项日志](../../artifacts/upgrade_20261025c_01/map_directory.log)。
- 五项组合下的 `map_directory`、`ui_world_integration`、`controller_comfort`、`journal_desk` 四套通过；组合版本 `npm test`、`npm run test:campaign` 通过，包含实际导出可达性审计。
- 地图目录、校准窗口与长对话在1280×720渲染取样检查；校准窗口为720×620，差异可滚动，确认按钮可见。
- 直接修改文件的SHA256：[输入清单](../../artifacts/upgrade_20261025c_01/source_sha256.json)。没有降低原套件门禁。

## 边界

只改进已有地点的查找，不新增地图知识，也不代表自然路线或秘密发现验收。
