# 保存构筑内容预览、规范目标复核与提交收尾

管理方案时可查看保存的契印和四类槽位内容，采用真实目录名称；展示规范化后的目标名称以及复制/更名结果。源快照、目标或模式变化时要求复核；明确Enter提交，隐藏或处理中窗口拒绝再次提交，写入失败保留内容与重试入口。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 6 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/loadout_manager.gd，专项产生 1 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/04_loadout_review/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/04_loadout_review/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。
- 已检查真实 GL 截图 ui.png；截图为隔离功能夹具，不作为完整关卡验收。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。



本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
