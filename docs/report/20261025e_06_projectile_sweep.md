# 敌方及反射弹道的连续接触与地形先后判定

敌方直射弹及反射弹改为检查本物理步路径的最早接触，保留既有碰撞半径；玩家、可招架正面与地形按先后解决，反射弹按路径选择最近敌人，不再取组枚举顺序。墙体优先于同刻接触，墙后不命中；原波浪、光束、地刺与毒池规则保留。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 12 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/attack_sweep.gd，专项产生 4 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/06_projectile_sweep/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/06_projectile_sweep/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。



本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
