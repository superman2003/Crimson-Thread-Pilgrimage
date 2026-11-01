# 存档读取租约、旧实例保护与备份核验

从read或备份恢复取得的实例记录原始UTF8内容身份，旧读取实例不能覆盖别的实例已提交或删除的主档；重新读取才采用新身份。保留旧“不读先写”的权威候选接口兼容。备份先写独立pending副本，逐字核验后再替换正式备份，失败保持主档。该检查不是跨进程文件锁。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 9 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/world_state.gd，专项产生 3 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/09_save_writers/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/09_save_writers/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。

读取租约是乐观身份检查，不是跨进程文件锁；最终检查与文件重命名之间仍有竞争窗口。旧的不读先写调用保留权威覆盖语义。

本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
