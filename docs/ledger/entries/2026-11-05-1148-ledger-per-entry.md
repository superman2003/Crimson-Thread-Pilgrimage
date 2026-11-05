## 2026-11-05：台账改为每个 PR 一个独立文件

以前每个 PR 都往 `docs/UPGRADE_TASK_LEDGER.md` 顶部加一条记录，合进一个 PR，其余 PR 就全部冲突，必须重新同步、重跑整套 CI。现在台账拆成 `docs/ledger/` 下的源文件：每条记录一个 `entries/YYYY-MM-DD-HHMM-主题.md`，状态表每个任务一个 `status/<编号>.md`，由 `tools/build_ledger.py` 生成台账（状态表移到最前面）。

- PR 上，`.github/workflows/ledger.yml` 检查条目格式，并拒绝直接修改生成文件；
- 合入 main 后，同一工作流自动重新生成台账并提交。

迁移了原有 133 条记录和 46 行状态，迁移前后逐行对照内容不缺；原来 3 处日期倒序已按日期排正。自测 `test_build_ledger` 已加入 `npm run test:runner`。用法见 `docs/ledger/README.md`。
