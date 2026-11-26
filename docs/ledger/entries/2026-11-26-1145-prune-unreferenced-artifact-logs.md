## 2026-11-26 11:45 (北京时间) — 清理未被引用的历史诊断日志与归档

- 清理 `artifacts/` 下 2,012 个未被引用的历史诊断日志与压缩归档（释放约 163.26 MiB），完整保留 43 个受 CI/验证脚本保护的目录及所有保留 JSON 报告/清单引用的日志路径。
- 验证：`verify_crown_return_proofs.py`、`test_verify_second_order_crown.py`、`contracts.py lint`、`build_ledger.py --validate`、`npm test`、`npm run test:campaign` 均通过，且保留 `artifacts/**/*.json` 断链为 0。
