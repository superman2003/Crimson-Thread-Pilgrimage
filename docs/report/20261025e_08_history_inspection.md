# 环境旧物聚焦说明、已读标记与视线交互

实际被选中的环境旧物显示简短观察提示与静态聚焦角标；未读时用通用描述，读后显示已记录及标题。窗口打开时隐藏探索说明。读取视线从玩家胸口连接物件，低地面凸缘不再误挡阅读，同时保留墙体、距离和隐身检查。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 8 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/scene_history_prop.gd，专项产生 2 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/08_history_inspection/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/08_history_inspection/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。



本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
