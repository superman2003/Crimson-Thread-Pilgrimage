# T02：三个存档槽与备份的只读总览

本批是原台账的功能子项，不关闭整项最终验收。范围说明：[PR #416](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/416)。输入基线：`a9457669a4a1a08f885c96c95c80a069d059f7ff`；本批独立面向 main，不继承其余九批代码。

## 原有缺口与交付

恢复确认页只比较当前所选槽的主档与备份，难以一次看清三个槽哪些可读、哪些有可读备份。

新增三槽与备份只读总览，可刷新磁盘快照，分别标记空槽、不可读主档和可读备份；显示文件指纹关系与时间顺序，但不把时间新旧当作进度优劣。选择主档或备份后回到原确认流程，不直接切换。

## 验证

Godot `4.6.1.stable.official.14d19694e`，使用基线原文件加本批文件的独立副本，避免误用其他待提交批次的改动。执行：

```sh
python3 tools/run_ledger_20261028_07.py --engine /path/to/Godot_v4.6.1-stable_linux.x86_64 --log-dir /tmp/ledger-07
```

生产脚本及其真实预加载依赖逐项编译通过；本批原生行为 `19` 项通过，进程正常退出，严格运行器未检测到引擎/脚本 ERROR 或 ObjectDB 退出警告。真实 WorldState 文件与 SaveInspector 读取、精确字节不变；实际原生总览窗口、选槽返回原核对、不可读说明、重复槽、错误身份、空选择与副作用检查。

原有 `run_save_backup_difference_contract.py` 复验 18 项通过；只在旧复制列表增加本批新增依赖，未改旧断言、超时或诊断门禁。

新增独立工作流 `.github/workflows/ledger-20261028-07.yml`，日志作为 CI artifact 保留；远端状态以本 PR 实际头提交为准。未用本地结果预先宣称远端 CI 成功。

## 边界

总览为磁盘快照，不自动保存当前内存进度；缺少或损坏的记录不当作零进度比较。未执行完整 World 的跨槽切换与自然恢复流程。

未完成六区自然全流程、实体控制器和最终发布包验收；局部模型/受控原生组件检查不替代 T04 或46项最终验收。

## 本批生产输入 SHA-256

- `godot/scripts/save_desk.gd`：`e5c7510bc3718d569d196e509f10636f1ad97283d775602b562ac7d3210a3c5e`
- `godot/scripts/save_slot_overview.gd`：`527781a6428d39ef16f19f5a107038696bccc77d56339c1a0ad92a6bb763b8a8`
