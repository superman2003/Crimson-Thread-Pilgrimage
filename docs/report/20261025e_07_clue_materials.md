# 六区材料化密道线索与发现后静态反馈

密道入口线索按真实地区显示苔纹、铜管、纸屑、根须、灰晶、缝线六种几何材料，保留原入口位置和光缝。发现后降低亮度并显示固定记录缺口，停止装饰动画；隐藏时停处理，重新显现后再恢复。没有改变地图保密、发现触发或奖励。

## 可复现验证

- Godot 4.6.1，独立原始基线 856010d8；仅叠加本项生产文件和专项测试，无其它未合并 PR 依赖。
- 专项 32 项真实 Mesa llvmpipe OpenGL 检查通过；headless 日志也附在同目录。
- 临时修改 godot/scripts/hidden_route_clue.gd，专项产生 1 个预期语义失败，退出码 1，无 SCRIPT ERROR；改动仅在隔离测试目录中使用。
- 恢复后重新运行的 13 套既有回归通过；npm test、test:campaign、两次严格资源导入通过。完整批次与最新 main 的组合结果另见本轮索引。
- 生产文件与测试的 SHA256：../../artifacts/upgrade_20261025e/07_clue_materials/source_sha256.json。
- 正反日志：../../artifacts/upgrade_20261025e/07_clue_materials/positive.log、real_gl.log、negative-control.log；故障注入内容：mutation.json。
- 已检查真实 GL 截图 ui.png；截图为隔离功能夹具，不作为完整关卡验收。

## 集成范围

PR 提交基于 main d335d707。已逐项检查 14 个其它开放 PR，生产文件没有重叠；本轮各项生产文件也互不重叠。没有修改共享回归注册表，新增独立工作流检查精确 PR head，校验 Godot 压缩包 SHA256，运行真实 GL 与故障注入并保留日志。

图案从现有 hidden_route 元数据取地区，不增加发现范围，也不修改地图解锁。

本项属于功能与回归升级；原项目最终验收状态不由这些专项测试自动关闭。
