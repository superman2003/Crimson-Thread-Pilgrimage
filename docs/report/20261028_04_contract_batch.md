# N02：已完成契约整批核对与原子领取

本批是原台账的功能子项，不关闭整项最终验收。范围说明：[PR #416](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/416)。输入基线：`a9457669a4a1a08f885c96c95c80a069d059f7ff`；本批独立面向 main，不继承其余九批代码。

## 原有缺口与交付

当前筛选的多份已完成契约只能逐份确认；连续领取时需要重复开窗核对。

新增当前筛选全部回礼的统一确认。最多三份，复用每份原始领取报价；以同一基线计算奖励增量，合并领取标记，重新核对整批指纹后只调用一次 FieldTransaction.commit。任何单份失效、库存溢出、意外扣除或写入失败均不发布半批状态。

## 验证

Godot `4.6.1.stable.official.14d19694e`，使用基线原文件加本批文件的独立副本，避免误用其他待提交批次的改动。执行：

```sh
python3 tools/run_ledger_20261028_04.py --engine /path/to/Godot_v4.6.1-stable_linux.x86_64 --log-dir /tmp/ledger-04
```

生产脚本及其真实预加载依赖逐项编译通过；本批原生行为 `21` 项通过，进程正常退出，严格运行器未检测到引擎/脚本 ERROR 或 ObjectDB 退出警告。原生批量模型与实际契约窗口，使用真实契约目录、原单份报价与原生产 FieldTransaction；注入存档写入拒绝后重试，验证两份回礼只经一次成功写入，重复确认不再领取。持久写入器和宿主上下文为受控夹具。

原有 `run_field_contract_browser_contract.py` 复验 19 项通过；只在旧复制列表增加本批新增依赖，未改旧断言、超时或诊断门禁。

新增独立工作流 `.github/workflows/ledger-20261028-04.yml`，日志作为 CI artifact 保留；远端状态以本 PR 实际头提交为准。未用本地结果预先宣称远端 CI 成功。

## 边界

确认名单绑定打开时的当前筛选结果；确认期间若筛选变化仍只处理已列出的原名单，世界/库存/报价变化则要求重核。未替换游戏存档格式或原存档事务。

未完成六区自然全流程、实体控制器和最终发布包验收；局部模型/受控原生组件检查不替代 T04 或46项最终验收。

## 本批生产输入 SHA-256

- `godot/scripts/field_contract_desk.gd`：`8103c4d031d32f52f44322d6d92932de2b33ed65d436299130d6e5f4cfb6739a`
- `godot/scripts/contract_batch_settlement.gd`：`d4bf1161b50c3b504df3f8a82754fecdae169816b89682a6aae9f51b5316f0a0`
