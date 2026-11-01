# T01：训练分步成绩与失败进度回看

本批是原台账的功能子项，不关闭整项最终验收。范围说明：[PR #416](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/416)。输入基线：`a9457669a4a1a08f885c96c95c80a069d059f7ff`；本批独立面向 main，不继承其余九批代码。

## 原有缺口与交付

训练旧记录只保存课程成功与否、总时间和结束原因，离场时无法回看做到第几步。

真实课程推进时记录每步接受次数与有效用时；失败或主动结束同样保存部分进度，待写入尝试仍沿用原重试机制。回看包括最近尝试的分步明细和保留记录中的完成次数、最好/最慢完成用时。旧记录不补造分步数据，重复配置不重复载入历史。

## 验证

Godot `4.6.1.stable.official.14d19694e`，使用基线原文件加本批文件的独立副本，避免误用其他待提交批次的改动。执行：

```sh
python3 tools/run_ledger_20261028_02.py --engine /path/to/Godot_v4.6.1-stable_linux.x86_64 --log-dir /tmp/ledger-02
```

生产脚本及其真实预加载依赖逐项编译通过；本批原生行为 `24` 项通过，进程正常退出，严格运行器未检测到引擎/脚本 ERROR 或 ObjectDB 退出警告。生产课程的真实 start/tick/accept/finish/retry、重复帧拒绝、失败写入、实际辅助文件重载、完整课程结束与非法分步计数。

原有 `run_practice_review_contract.py` 复验 19 项通过；只在旧复制列表增加本批新增依赖，未改旧断言、超时或诊断门禁。

新增独立工作流 `.github/workflows/ledger-20261028-02.yml`，日志作为 CI artifact 保留；远端状态以本 PR 实际头提交为准。未用本地结果预先宣称远端 CI 成功。

## 边界

课程仍以实际接受动作计数，不授予能力、校习资格或奖励；分步时间不包含打开菜单的时间。历史只保留24条，不作为全旅途永久成绩。

未完成六区自然全流程、实体控制器和最终发布包验收；局部模型/受控原生组件检查不替代 T04 或46项最终验收。

## 本批生产输入 SHA-256

- `godot/scripts/practice_curriculum.gd`：`ec179f054fc49fab630033acb70eb6920af045afc04c8eada3f2199262b745b7`
- `godot/scripts/practice_desk.gd`：`6c54736463de4b4be9c8704b4263c4796cacdafcc25f584fcc44117c5950656e`
- `godot/scripts/practice_attempt_review.gd`：`021b3cfcd8d2e6028bb414b3fb7c0300e1f4992f1215371ce2f8e006a67cda63`
