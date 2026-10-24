# T05 导出审计覆盖证据

基线 main `93365331bc8d0bcf588244c2000c43df7be16f04`；只验证工具，不代替实际发布包。

- `before_after.json`：同样临时项目输入下的 10 组新旧结果，含旧工具源 SHA-256；8 组危险配置由误放行改为拒绝，2 组合法过滤配置由误拒改为接受。
- `compare.py`：复现以上对照，旧工具从固定基线 Git 对象读取，运行 `python artifacts/t05_export_audit/compare.py`。
- `unit-tests.log`：17 个测试方法全部通过（另含子案例）。
- `inputs.json`：最终两个工具、正式预设与项目配置的原字节 SHA-256。
- `current-audit.log`／`current_summary.json`：2 个正式预设、93 个脚本／场景、3,730 个运行时显式引用资源与空错误列表；摘要保留完整报告 SHA-256。
- `npm-test.log`／`npm-campaign.log`：完整静态与章节门禁输出，两次均 exit 0，保留 npm 环境警告。

复现完整资源列表（不提交重复的 3,730 行长路径）：

```sh
python tools/audit_export_contents.py --report /tmp/export-audit.json
python tools/test_export_audit.py
PYTHONUTF8=1 npm test
PYTHONUTF8=1 npm run test:campaign
```

工具输出只证明静态配置与明确引用图；拼接资产、二进制资源内部引用、插件、最终包运行与人工验收范围见[本批报告](../../docs/report/20261024_t05_export_audit_coverage.md)。
