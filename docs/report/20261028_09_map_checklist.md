# U04：按分区分层生成已知地图出行清单

本批是原台账的功能子项，不关闭整项最终验收。范围说明：[PR #416](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/416)。输入基线：`a9457669a4a1a08f885c96c95c80a069d059f7ff`；本批独立面向 main，不继承其余九批代码。

## 原有缺口与交付

已知地点目录可以筛选与定位，但无法将当前筛选整理为分区分层、可手工勾选的出行清单。

新增清单窗口，从当前筛选结果生成公开字段投影，按区域和作者层位整理；支持多选勾选/撤销、可选附公开说明、复制文本和重新生成。只在本次窗口保留，关闭地图目录即清理；最多1024条并明确超出数量。

## 验证

Godot `4.6.1.stable.official.14d19694e`，使用基线原文件加本批文件的独立副本，避免误用其他待提交批次的改动。执行：

```sh
python3 tools/run_ledger_20261028_09.py --engine /path/to/Godot_v4.6.1-stable_linux.x86_64 --log-dir /tmp/ledger-09
```

生产脚本及其真实预加载依赖逐项编译通过；本批原生行为 `18` 项通过，进程正常退出，严格运行器未检测到引擎/脚本 ERROR 或 ObjectDB 退出警告。原生投影与实际清单窗口：分区分层、可选说明、多选/撤销、隐藏ID和坐标排除、去重、超限说明、空清单、关闭子窗口及知识不变。

新增独立工作流 `.github/workflows/ledger-20261028-09.yml`，日志作为 CI artifact 保留；远端状态以本 PR 实际头提交为准。未用本地结果预先宣称远端 CI 成功。

## 边界

清单不记录玩家位置、不保证道路开放，也不把手工勾选当作到达或补绘；生成后地图状态变化需重新生成。复制文本仅由玩家显式按钮触发。

未完成六区自然全流程、实体控制器和最终发布包验收；局部模型/受控原生组件检查不替代 T04 或46项最终验收。

## 本批生产输入 SHA-256

- `godot/scripts/map_directory_dialog.gd`：`6228cddbbd0dd89f9d2bc8cfc623984f284a6feb4ce5c6f5a667b09785114e44`
- `godot/scripts/map_known_checklist.gd`：`6cae1452c9ba2bae6a54a7eae7b9eb05dccc7a422f2db88b985f03ac692d0bbd`
