# NPC声音地标公平轮询、限频与来源退役

NPC声音地标优先轮到最久未听到的附近角色，同等条件按距离与稳定ID选择，避免近处角色反复压过邻居。空轮询与失败退让500ms，保留每NPC12秒和全局4秒间隔；隐藏、退场、换物理世界或超出听距的来源会立即释放声音，重新开启开关会延迟入场。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 13 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/npc_landmark_schedule.gd，专项产生 2 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/10_npc_schedule/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/10_npc_schedule/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。

声音仅使用现有非语言声音流；限频字典沿用64项上限。

本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
