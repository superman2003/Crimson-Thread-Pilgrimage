# 四种补给清单预设、部分报价与滚动明细

补给清单支持补齐缺额、每种一份、补到半满、清空四种选择；显示申请/可购/未满足数量和逐项部分报价。清单与报价分开滚动，原生窗口固定在700×600内，确认区保持可见；预设只改请求，不扣款或恢复次数，空清单不能回落为旧自动全补行为。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 13 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/resupply_planner.gd，专项产生 5 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/03_resupply_presets/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/03_resupply_presets/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。
- 已检查真实 GL 截图 ui.png；截图为隔离功能夹具，不作为完整关卡验收。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。



本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
